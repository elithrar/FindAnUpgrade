import copy
import hashlib
import json
import subprocess
import sys
import unittest
from collections import Counter
from pathlib import Path

from lupa.lua51 import LuaRuntime

from fau_tools import classification as importer

ROOT = Path(__file__).resolve().parents[1]


class DataTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((ROOT / "data/primary-statuses.json").read_bytes())
        cls.evidence = json.loads(
            (ROOT / "data/classification-source.json").read_bytes()
        )
        cls.report = json.loads(
            (ROOT / "data/classification-reconciliation.json").read_bytes()
        )
        cls.baseline_raw = (ROOT / "data/classification-baseline.json").read_bytes()
        cls.baseline = json.loads(cls.baseline_raw)
        cls.lua = LuaRuntime(unpack_returned_tuples=True)
        cls.lua.execute("N = {}")
        cls.lua.globals().SOURCE = str(ROOT / "FindAnUpgrade/Data/Quests.lua").replace(
            "\\", "/"
        )
        cls.lua.execute('assert(loadfile(SOURCE))("FindAnUpgrade", N)')
        cls.actual = dict(cls.lua.globals().N.Data.statusById.items())

    def test_every_id_matches_per_variant_primary_status(self):
        mapped = {
            "New": "verifiedNew",
            "Updated": "verifiedUpdated",
            "Unchanged": "verifiedUnchanged",
        }
        expected = {row["id"]: mapped[row["status"]] for row in self.source["quests"]}
        self.assertEqual(self.actual, expected)
        self.assertEqual(len(expected), 2931)
        self.assertEqual(
            Counter(expected.values()),
            {"verifiedUnchanged": 2367, "verifiedUpdated": 176, "verifiedNew": 388},
        )

    def test_source_receipts_and_original_baseline_are_preserved(self):
        self.assertEqual(self.source["schemaVersion"], 2)
        self.assertEqual(
            hashlib.sha256(self.baseline_raw).hexdigest(),
            "64017ae90fe4e16323044064b0ac5ba6102fba147446660fb1fd863eaf8e9ae5",
        )
        self.assertEqual(
            self.baseline["libraryFileId"], "libfile_7a7d39bd0d1c81919be5ccb96b9c6b9c"
        )
        self.assertEqual(
            self.source["sources"]["websiteReceipts"], self.evidence["receipts"]
        )
        self.assertEqual(
            self.source["sources"]["normalized"]["sha256"],
            hashlib.sha256(
                (ROOT / "data/classification-source.json").read_bytes()
            ).hexdigest(),
        )
        self.assertEqual(
            [r["sha256"] for r in self.evidence["receipts"]],
            [
                "4899d7c24a292bbc3de140a4106e4c7c0e89f7211d8252abca2d7be9c23e5f66",
                "6f757fad2acc3dbd70d75d28bf9c4c6d8194c96a7d02a5fdf9092e900a260a46",
            ],
        )

    def test_all_website_ids_are_in_the_broader_catalog(self):
        catalog = {
            r["id"]
            for r in json.loads(
                (ROOT / "data/catalog-complete-source.json").read_bytes()
            )["quests"]
        }
        website = {v["id"] for c in self.evidence["categories"] for v in c["variants"]}
        classified = {r["id"] for r in self.source["quests"]}
        self.assertEqual(len(website), 2919)
        self.assertTrue(website <= catalog)
        self.assertTrue(classified <= catalog)
        self.assertEqual(len(catalog - classified), len(catalog) - 2931)

    def test_exact_categories_and_title_counts_are_distinct(self):
        report = self.report["website"]
        self.assertEqual(
            (report["mainCategoryCount"], report["ancillaryCategoryCount"]), (42, 16)
        )
        totals = report["projections"]["All"]
        self.assertEqual(
            (totals["questIdCount"], totals["titleGroupCount"]), (2919, 2355)
        )
        self.assertEqual(
            totals["exactIdStatuses"], {"Unchanged": 2359, "Updated": 176, "New": 384}
        )
        self.assertEqual(
            totals["titleGroupStatuses"],
            {"Unchanged": 1846, "Updated": 155, "New": 354},
        )
        for category, original in zip(
            self.report["categories"], self.evidence["categories"]
        ):
            counts = importer.counts(original["variants"])
            self.assertEqual(category["projections"]["All"], counts)
            self.assertEqual(counts["questIdCount"], original["sourceQuestIdCount"])
            self.assertEqual(
                counts["titleGroupCount"], original["sourceTitleCounts"]["total"]
            )

    def test_factions_filter_variants_before_regrouping(self):
        category = next(
            c for c in self.evidence["categories"] if c["name"] == "Desolace"
        )
        variants = [v for v in category["variants"] if v["title"] == "Khan Hratha"]
        self.assertEqual(importer.counts(variants)["titleGroupStatuses"]["New"], 1)
        alliance = [
            v for v in variants if v["faction"] in importer.FACTIONS["Alliance"]
        ]
        self.assertEqual(
            importer.counts(alliance)["titleGroupStatuses"],
            {"Unchanged": 0, "Updated": 1, "New": 0},
        )
        projections = self.report["website"]["projections"]
        self.assertEqual(
            [projections[f]["questIdCount"] for f in ("Alliance", "Horde", "Neutral")],
            [1979, 1765, 825],
        )
        self.assertEqual(
            projections["Alliance"]["questIdCount"]
            + projections["Horde"]["questIdCount"]
            - projections["Neutral"]["questIdCount"],
            2919,
        )

    def test_thirty_mixed_groups_keep_their_exact_variant_labels(self):
        mixed = self.report["mixedStatusTitleGroups"]
        self.assertEqual(len(mixed), 30)
        for group in mixed:
            self.assertGreater(len({v["status"] for v in group["variants"]}), 1)
            for variant in group["variants"]:
                self.assertEqual(
                    self.actual[variant["id"]], "verified" + variant["status"]
                )
        for quest in [
            286,
            356,
            921,
            928,
            929,
            933,
            934,
            935,
            7383,
            932,
            422,
            423,
            99,
            424,
        ]:
            self.assertNotEqual(self.actual[quest], "verifiedNew")
        for quest in [98189, 99156, 98046, 98065, 98403, 98298, 92124, 92460, 91736]:
            self.assertEqual(self.actual[quest], "verifiedNew")
        for quest in [79090, 79098]:
            self.assertEqual(self.actual[quest], "verifiedUnchanged")
        self.assertNotIn(10000000, self.actual)

    def test_twelve_exclusions_retain_status_without_display_membership(self):
        expected = {
            785,
            787,
            908,
            934,
            1099,
            1174,
            7961,
            7962,
            95771,
            95816,
            95819,
            98447,
        }
        excluded = self.report["retainedWebsiteExclusions"]
        self.assertEqual({r["id"] for r in excluded}, expected)
        self.assertEqual(
            Counter(r["status"] for r in excluded), {"Unchanged": 8, "New": 4}
        )
        lookup = dict(self.lua.globals().N.Data.websiteExcludedById.items())
        categories = dict(self.lua.globals().N.Data.categoryById.items())
        self.assertEqual(set(lookup), expected)
        for row in excluded:
            self.assertFalse(row["websiteDisplay"])
            self.assertEqual(row["faction"], "Unknown")
            self.assertTrue(
                all("Side: None" in reason for reason in row["exclusionReasons"])
            )
            self.assertNotIn(row["id"], categories)
            self.assertEqual(lookup[row["id"]].reason, "sideNone")
        self.assertEqual(len(self.evidence["excludedVariants"]), 65)
        self.assertEqual(self.report["baseline"]["sharedWebsiteQuestIdCount"], 1182)
        self.assertEqual(
            self.report["baseline"]["newlyClassifiedWebsiteQuestIdCount"], 1737
        )
        self.assertEqual(self.report["baseline"]["statusDisagreements"], [])

    def test_shipped_category_lookup_matches_every_membership_and_count(self):
        actual = dict(self.lua.globals().N.Data.categoryById.items())
        summaries = self.lua.globals().N.Data.categories
        self.assertEqual(len(actual), 2919)
        self.assertEqual(len(summaries), 58)
        reports = {c["name"]: c for c in self.report["categories"]}
        for category in self.evidence["categories"]:
            for variant in category["variants"]:
                self.assertEqual(
                    summaries[actual[variant["id"]]].name, category["name"]
                )
        for index in range(1, len(summaries) + 1):
            summary = summaries[index]
            expected = reports[summary.name]["projections"]["All"]
            self.assertEqual(summary.questIdCount, expected["questIdCount"])
            self.assertEqual(summary.titleGroupCount, expected["titleGroupCount"])
            self.assertEqual(
                dict(summary.exactIdStatuses.items()), expected["exactIdStatuses"]
            )
            self.assertEqual(
                dict(summary.titleGroupStatuses.items()), expected["titleGroupStatuses"]
            )
        empty = next(
            c for c in self.evidence["categories"] if c["name"] == "Abyssal Sands"
        )
        self.assertEqual(empty["variants"], [])

    def test_conflicting_or_duplicate_exact_ids_fail_instead_of_guessing(self):
        conflicting = copy.deepcopy(self.baseline)
        website_ids = {
            v["id"] for c in self.evidence["categories"] for v in c["variants"]
        }
        row = next(
            v
            for v in conflicting["quests"]
            if v["id"] in website_ids and v["status"] == "Unchanged"
        )
        row["status"] = "New"
        with self.assertRaisesRegex(AssertionError, "Conflicting exact-ID"):
            importer.reconcile(self.evidence, conflicting, self.baseline_raw)
        duplicate = copy.deepcopy(self.evidence)
        duplicate["categories"][1]["variants"].append(
            duplicate["categories"][0]["variants"][0]
        )
        with self.assertRaises(AssertionError):
            importer.reconcile(duplicate, self.baseline, self.baseline_raw)
        missing_exclusion = copy.deepcopy(self.evidence)
        missing_exclusion["excludedVariants"] = [
            r for r in missing_exclusion["excludedVariants"] if r["id"] != 98447
        ]
        with self.assertRaises(KeyError):
            importer.reconcile(missing_exclusion, self.baseline, self.baseline_raw)

    def test_generated_outputs_are_reproducible_without_website_checkout(self):
        for command in ("classify", "quests"):
            subprocess.run(
                [sys.executable, "-m", "fau_tools", "data", command, "--check"],
                cwd=ROOT,
                check=True,
            )

    def test_retained_exclusion_requires_nonempty_string_reasons(self):
        for invalid in (
            [],
            None,
            "Side: None",
            [None],
            [""],
            ["Side: None", 1],
            ["Unconfirmed"],
        ):
            with self.subTest(reasons=invalid):
                source = copy.deepcopy(self.evidence)
                next(r for r in source["excludedVariants"] if r["id"] == 785)[
                    "reasons"
                ] = invalid
                with self.assertRaisesRegex(
                    AssertionError, "nonempty exact Side: None"
                ):
                    importer.reconcile(source, self.baseline, self.baseline_raw)

    def test_source_receipts_require_both_named_files_and_valid_hash_lengths(self):
        chart, ledger = self.evidence["receipts"]
        cases = [
            [chart, chart],
            [ledger, ledger],
            [dict(chart, file="wrong.json"), ledger],
            [dict(chart, sha256="g" * 64), ledger],
            [dict(chart, sha256="a" * 63), ledger],
            [dict(chart, sha256=64), ledger],
        ]
        cases.extend(
            [dict(chart, bytes=value), ledger]
            for value in (True, False, 0, -1, 1.5, "10")
        )
        for invalid in cases:
            with self.subTest(receipts=invalid):
                source = copy.deepcopy(self.evidence)
                source["receipts"] = invalid
                with self.assertRaises(AssertionError):
                    importer.reconcile(source, self.baseline, self.baseline_raw)


if __name__ == "__main__":
    unittest.main()
