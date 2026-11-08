"""Whole-inventory reconciliation and independent failure inputs for public facts."""

import copy
import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from fau_tools.att import merge, parse
from fau_tools.catalog import (
    apply_reviewed_update,
    build_complete,
    merge_reviewed_additions,
    read_inputs,
    reviewed_additions,
    reviewed_categories,
    reviewed_partial_rewards,
    reviewed_updates,
    validate_complete,
)
from fau_tools.html import quest_detail, quest_index
from fau_tools.importer import native_ids

ROOT = Path(__file__).resolve().parents[1]


def page(body="", quest=9, extra="", label="Forever"):
    return (
        '<html><body><a href="https://www.wowhead.com/forever/quest='
        + str(quest)
        + '">Quest</a>'
        + extra
        + '<section><div class="label">'
        + label
        + '</div><div class="wow-tt"><div class="font-semibold">Exact quest</div><div>Level 20</div>'
        + body
        + "</div></section></body></html>"
    )


def item(group="You will receive:", domain="forever", quantity=""):
    return (
        "<div><div>"
        + group
        + '</div><div><a href="/items/123" data-wowhead="item=123&amp;domain='
        + domain
        + '"><span>Item</span><span>'
        + quantity
        + "</span></a></div></div>"
    )


class CompleteCatalogTests(unittest.TestCase):
    def test_website_review_changes_only_receipted_quests_and_preserves_original_sources(
        self,
    ):
        provenance, inputs = read_inputs(ROOT)
        original = copy.deepcopy(inputs)
        source, report = build_complete(ROOT)
        without_review = {
            key: value for key, value in inputs.items() if key != "reviewed"
        }
        with mock.patch(
            "fau_tools.catalog.read_inputs", return_value=(provenance, without_review)
        ):
            baseline, _ = build_complete(ROOT)
        before = {row["id"]: row for row in baseline["quests"]}
        after = {row["id"]: row for row in source["quests"]}
        self.assertEqual(after.keys() - before.keys(), {93161, 89013, 91608})
        self.assertEqual(before.keys() - after.keys(), set())
        self.assertEqual(
            {quest for quest in before if before[quest] != after[quest]},
            {
                4561,
                4661,
                7704,
                92841,
                92844,
                92846,
                93176,
                95816,
                95819,
                11,
                224,
                474,
                565,
                5151,
                91751,
                91740,
                91723,
                91724,
                91746,
                91732,
                88756,
                968,
                303,
                421,
                600,
                628,
                673,
                971,
                79361,
                79363,
                86757,
                87491,
                92597,
                95189,
                95195,
                95204,
                95216,
                95250,
                96137,
                96138,
                96139,
                96222,
                96241,
                96243,
                96259,
                96260,
                96261,
                96783,
                96784,
                96822,
                97223,
                97253,
                97282,
                97288,
                97289,
                97290,
                97291,
                97292,
                98027,
                98069,
                98070,
                98155,
                98156,
                98251,
                98252,
                98417,
                99048,
                99049,
                99051,
                99052,
                99053,
                99080,
                99082,
                99156,
                414,
                648,
                697,
                836,
                1156,
                1425,
                2987,
                79358,
                82208,
                92847,
                92873,
                92893,
                92894,
                93034,
                93035,
                93037,
                93041,
                93044,
                93045,
                93058,
                93062,
                93066,
                96785,
                96786,
                630,
                646,
                762,
                1139,
                1172,
                3062,
                5668,
                5669,
                5670,
                5671,
                7701,
                8554,
                93072,
                93122,
                93125,
                93128,
                93129,
                93188,
                93196,
                206,
                608,
                611,
                1166,
                8551,
                98025,
                98093,
                614,
                2994,
                3463,
                3518,
                4491,
                5214,
            },
        )
        self.assertEqual(
            after[93176]["items"],
            [
                {
                    "itemID": 280456,
                    "name": "Weevil K. Neevil",
                    "quantity": 1,
                    "group": "guaranteed",
                    "slot": 1,
                }
            ],
        )
        for quest, name in (
            (4561, "Un'Goro Tested Sample"),
            (4661, "Corrupt Tested Sample"),
            (7704, "Evonice's Landin' Pilla"),
        ):
            self.assertEqual(after[quest]["items"][0]["name"], name)
        for quest in (92841, 92844, 92846):
            self.assertEqual(after[quest]["minimum"], 35)
        for quest in (95816, 95819):
            self.assertEqual(after[quest]["items"], [])
            self.assertEqual(after[quest]["itemState"], "unknown")
            self.assertEqual(after[quest]["fieldStates"]["items"], "unknown")
            self.assertEqual(
                after[quest]["confirmation"], before[quest]["confirmation"]
            )
            self.assertEqual(
                after[quest]["rewardValues"], before[quest]["rewardValues"]
            )
        self.assertEqual(inputs, original)
        self.assertEqual(report["reviewedUpdates"], inputs["reviewed"])
        ancient = after[93161]
        self.assertEqual(
            (ancient["title"], ancient["level"], ancient["minimum"]),
            ("The Ancient Hilt", 60, 1),
        )
        self.assertEqual(
            ancient["items"],
            [
                {
                    "itemID": 282315,
                    "name": "Ancient Hilt",
                    "quantity": 1,
                    "group": "guaranteed",
                    "slot": 1,
                }
            ],
        )
        self.assertTrue(ancient["eligibilityUnknown"])
        for key in ("faction", "locations", "classTokens", "rewardValues"):
            self.assertNotIn(key, ancient)
        self.assertEqual(report["counts"]["reviewedWebsiteIdentities"], 3)

    def test_recovered_cached_metadata_preserves_unconfirmed_identity_and_unknown_rewards(
        self,
    ):
        source, _ = build_complete(ROOT)
        row = next(q for q in source["quests"] if q["id"] == 1156)
        self.assertEqual(row["title"], "<NYI> <TXT> speak to alchemist pestlezugg")
        self.assertEqual((row["level"], row["minimum"]), (58, 25))
        self.assertEqual(row["confirmation"], "unconfirmed")
        self.assertEqual((row["items"], row["itemState"]), ([], "unknown"))
        for key in ("title", "level", "minimum"):
            self.assertEqual(row["fieldStates"][key], "recorded")
        for key in ("faction", "locations", "rewardValues", "recordedCategory"):
            self.assertNotIn(key, row)
        _, inputs = read_inputs(ROOT)
        update = reviewed_updates(inputs["reviewed"])[1156]
        current = {"id": 1156, **update["expected"]}
        apply_reviewed_update(current, update)
        apply_reviewed_update(current, update)
        for fields in ({"title": "Different"}, {"minimum": 1}):
            with self.subTest(fields=fields), self.assertRaises(ValueError):
                apply_reviewed_update({**current, **fields}, update)
        for mutation in ("no-native", "null-after", "bad-label"):
            doc = copy.deepcopy(inputs["reviewed"])
            record = next(q for q in doc["records"] if q["id"] == 1156)
            if mutation == "no-native":
                record.pop("nativeObservation")
            elif mutation == "null-after":
                record["changes"]["level"] = None
            else:
                record["title"] = "Different label"
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                reviewed_updates(doc)

    def test_recorded_categories_do_not_rewrite_primary_status_or_coordinates(self):
        provenance, inputs = read_inputs(ROOT)
        source, _ = build_complete(ROOT)
        records = {q["id"]: q for q in source["quests"]}
        self.assertEqual(
            records[414]["recordedCategory"], {"sourceZoneID": 38, "name": "Loch Modan"}
        )
        self.assertEqual(
            records[93161]["recordedCategory"],
            {"sourceZoneID": 16593, "name": "Zephras Isle"},
        )
        doc = copy.deepcopy(inputs["reviewed"])
        doc.pop("categoryUpdates")
        with mock.patch(
            "fau_tools.catalog.read_inputs",
            return_value=(provenance, {**inputs, "reviewed": doc}),
        ):
            baseline, _ = build_complete(ROOT)
        originals = {q["id"]: q for q in baseline["quests"]}
        for qid in (414, 93161):
            observed = dict(records[qid])
            observed.pop("recordedCategory")
            self.assertEqual(observed, originals[qid])
        primary = json.loads((ROOT / "data/primary-statuses.json").read_bytes())
        self.assertEqual(
            next(q for q in primary["quests"] if q["id"] == 414)["zoneId"], 1
        )
        self.assertNotIn(93161, {q["id"] for q in primary["quests"]})

    def test_recorded_categories_reject_conflicts_unmapped_areas_and_unbound_receipts(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        for mutation in (
            "prior",
            "target",
            "name",
            "duplicate",
            "no-native",
            "no-changelog",
            "missing-prior",
        ):
            doc = copy.deepcopy(inputs["reviewed"])
            update = doc["categoryUpdates"][0]
            if mutation == "prior":
                update["expected"] = {"sourceZoneID": 36, "name": "Alterac Mountains"}
            elif mutation == "target":
                update["changes"]["sourceZoneID"] = 999999
            elif mutation == "name":
                update["changes"]["name"] = "Wrong name"
            elif mutation == "duplicate":
                doc["categoryUpdates"].append(copy.deepcopy(update))
            elif mutation == "no-native":
                update.pop("nativeObservation")
            elif mutation == "no-changelog":
                update["evidence"] = ["nativeCatalogNovember7"]
            else:
                update.pop("expected")
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                reviewed_categories(doc, ROOT)

    def test_recorded_categories_accept_already_adopted_primary_and_reject_third_category(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        primary = json.loads((ROOT / "data/primary-statuses.json").read_bytes())
        quest = next(q for q in primary["quests"] if q["id"] == 414)
        quest["zoneId"], quest["zone"] = 38, "Loch Modan"
        with mock.patch("fau_tools.catalog.json.loads", return_value=primary):
            self.assertIn(414, reviewed_categories(inputs["reviewed"], ROOT))
        quest["zoneId"], quest["zone"] = 36, "Alterac Mountains"
        with mock.patch("fau_tools.catalog.json.loads", return_value=primary):
            with self.assertRaisesRegex(ValueError, "primary conflict"):
                reviewed_categories(inputs["reviewed"], ROOT)

    def test_reviewed_title_changes_are_exact_idempotent_and_reject_primary_conflicts(
        self,
    ):
        provenance, inputs = read_inputs(ROOT)
        update = reviewed_updates(inputs["reviewed"])[92597]
        row = {"id": 92597, "title": "Reading the Ley Lines"}
        apply_reviewed_update(row, update)
        self.assertEqual(row["title"], "Reading the Leylines")
        apply_reviewed_update(row, update)
        for changed in ({"title": "A different quest"}, {"id": 92598}):
            with (
                self.subTest(changed=changed),
                self.assertRaisesRegex(ValueError, "identity"),
            ):
                apply_reviewed_update({**row, **changed}, update)
        for title in (
            "Reading the Ley Lines",
            "Reading the Leylines",
            "Unreviewed spelling",
        ):
            changed = copy.deepcopy(inputs)
            for record in changed["primary"]["records"]:
                if record["id"] == 92597:
                    record["title"] = title
                    break
            else:
                original = next(
                    r for r in changed["public"]["records"] if r["id"] == 92597
                )
                changed["primary"]["records"].append({**original, "title": title})
            with mock.patch(
                "fau_tools.catalog.read_inputs", return_value=(provenance, changed)
            ):
                if title == "Unreviewed spelling":
                    with self.assertRaisesRegex(ValueError, "primary conflict"):
                        build_complete(ROOT)
                else:
                    source, _ = build_complete(ROOT)
                    self.assertEqual(
                        next(q for q in source["quests"] if q["id"] == 92597)["title"],
                        "Reading the Leylines",
                    )

    def test_reviewed_title_and_native_observation_validation(self):
        _, inputs = read_inputs(ROOT)
        for mutation in (
            "unbound-title",
            "blank-title",
            "control-title",
            "native-hash",
            "native-source",
            "native-build",
        ):
            document = copy.deepcopy(inputs["reviewed"])
            row = next(r for r in document["records"] if r["id"] == 92597)
            if mutation == "unbound-title":
                row["expected"]["title"] = "Another identity"
            elif mutation == "blank-title":
                row["changes"]["title"] = ""
            elif mutation == "control-title":
                row["changes"]["title"] = "bad\nname"
            elif mutation == "native-hash":
                row["nativeObservation"]["payloadSha256"] = True
            elif mutation == "native-source":
                row["nativeObservation"]["source"] = "changelogNovember6Afternoon"
            else:
                row["nativeObservation"]["build"] = True
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                reviewed_updates(document)

    def test_additional_website_identity_rejects_unsupported_or_conflicting_evidence(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        document = inputs["reviewed"]
        for mutation in (
            "duplicate",
            "overlap",
            "evidence",
            "field",
            "boolean",
            "item",
            "name",
        ):
            changed = copy.deepcopy(document)
            addition = changed["additions"][0]
            row = addition["record"]
            if mutation == "duplicate":
                changed["additions"].append(copy.deepcopy(addition))
            elif mutation == "overlap":
                row["id"] = 11
            elif mutation == "evidence":
                addition["evidence"] = ["missing"]
            elif mutation == "field":
                row["faction"] = "Alliance"
            elif mutation == "boolean":
                row["level"] = True
            elif mutation == "item":
                row["items"][0]["quantity"] = 0
            else:
                row["items"][0]["name"] = ""
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                reviewed_additions(changed)
        additions = reviewed_additions(document)
        public = {}
        merge_reviewed_additions(public, additions)
        merge_reviewed_additions(public, additions)
        public[93161]["minimum"] = 20
        with self.assertRaisesRegex(ValueError, "source conflict"):
            merge_reviewed_additions(public, additions)

    def test_new_primary_level_cannot_be_hidden_by_reviewed_website_correction(self):
        provenance, inputs = read_inputs(ROOT)
        inputs["primary"]["records"].append(
            {"id": 91751, "title": "Rough Wolf Pelts", "items": [], "level": 12}
        )
        with mock.patch(
            "fau_tools.catalog.read_inputs", return_value=(provenance, inputs)
        ):
            with self.assertRaisesRegex(ValueError, "primary conflict"):
                build_complete(ROOT)

    def test_additional_website_identity_rejects_primary_conflicts(self):
        for field, value in (
            ("title", "Another Quest"),
            ("level", 10),
            ("minimum", 5),
            ("items", []),
        ):
            provenance, inputs = read_inputs(ROOT)
            record = {
                "id": 93161,
                "title": "The Ancient Hilt",
                "level": 60,
                "minimum": 1,
                "items": [
                    {"itemID": 282315, "quantity": 1, "group": "guaranteed", "slot": 1}
                ],
            }
            record[field] = value
            inputs["primary"]["records"].append(record)
            with (
                self.subTest(field=field),
                mock.patch(
                    "fau_tools.catalog.read_inputs", return_value=(provenance, inputs)
                ),
            ):
                with self.assertRaisesRegex(ValueError, "conflict"):
                    build_complete(ROOT)

    def test_reviewed_updates_reject_missing_receipts_duplicate_ids_and_unsupported_fields(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        document = inputs["reviewed"]
        for mutation in (
            "receipt",
            "duplicate",
            "field",
            "evidence",
            "quantity",
            "removal",
        ):
            with self.subTest(mutation=mutation):
                changed = copy.deepcopy(document)
                row = next(row for row in changed["records"] if row["id"] == 93176)
                if mutation == "receipt":
                    changed["sources"]["rewards"]["sha256"] = "broken"
                elif mutation == "duplicate":
                    changed["records"].append(copy.deepcopy(row))
                elif mutation == "field":
                    row["expected"]["confirmation"] = "unconfirmed"
                    row["changes"]["confirmation"] = "published"
                elif mutation == "evidence":
                    row["evidence"] = ["missing"]
                elif mutation == "quantity":
                    row["changes"]["items"][0]["quantity"] = True
                else:
                    row["expected"], row["changes"] = row["changes"], row["expected"]
                with self.assertRaises(ValueError):
                    reviewed_updates(changed)

    def test_partial_reward_groups_require_receipts_and_never_remove_identity_or_quantity(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        document = inputs["reviewed"]
        for mutation in (
            "native",
            "changelog",
            "unknown",
            "prior",
            "removal",
            "quantity",
            "group",
            "unmarked",
        ):
            with self.subTest(mutation=mutation):
                changed = copy.deepcopy(document)
                row = next(
                    row for row in changed["partialRewardUpdates"] if row["id"] == 630
                )
                if mutation == "native":
                    row.pop("nativeObservation")
                elif mutation == "changelog":
                    row["evidence"].remove("changelogNovember8")
                elif mutation == "unknown":
                    row["changes"]["itemGroupStates"]["guaranteed"] = "published-empty"
                elif mutation == "prior":
                    row["expected"]["itemGroupStates"] = {"guaranteed": "published"}
                elif mutation == "removal":
                    row["changes"]["items"].pop(0)
                elif mutation == "quantity":
                    row["changes"]["items"][0]["quantity"] = 2
                elif mutation == "group":
                    row["changes"]["items"][0]["group"] = "guaranteed"
                else:
                    for fields in (row["expected"], row["changes"]):
                        fields.pop("itemGroupStates")
                with self.assertRaises(ValueError):
                    reviewed_partial_rewards(changed)

    def test_partial_groups_are_idempotent_and_preserve_other_facts_and_unknowns(self):
        _, inputs = read_inputs(ROOT)
        updates = reviewed_partial_rewards(inputs["reviewed"])
        source, _ = build_complete(ROOT)
        rows = {row["id"]: row for row in source["quests"]}
        for quest in (
            206,
            608,
            611,
            630,
            762,
            1139,
            1166,
            8551,
            8554,
            97282,
            98025,
            98093,
        ):
            update = updates[quest]
            row = {
                "id": quest,
                "title": update["title"],
                **copy.deepcopy(update["expected"]),
                "moneyCost": 123,
                "confirmation": "historical",
            }
            apply_reviewed_update(row, update)
            apply_reviewed_update(row, update)
            adopted = {
                "id": quest,
                "title": update["title"],
                **copy.deepcopy(update["changes"]),
            }
            adopted.pop("itemGroupStates")
            apply_reviewed_update(adopted, update)
            self.assertEqual(
                adopted["itemGroupStates"], update["changes"]["itemGroupStates"]
            )
            self.assertEqual(row["moneyCost"], 123)
            self.assertEqual(row["confirmation"], "historical")
            self.assertEqual(
                rows[quest]["itemGroupStates"],
                {"guaranteed": "unknown", "choice": "published"},
            )
            self.assertTrue(
                all(item["group"] == "choice" for item in rows[quest]["items"])
            )
            row["itemGroupStates"]["guaranteed"] = "published-empty"
            with self.assertRaisesRegex(ValueError, "source conflict"):
                apply_reviewed_update(row, update)
        for quest in (5668, 5669, 5670, 5671):
            self.assertEqual(rows[quest]["confirmation"], "unconfirmed")
            self.assertEqual(rows[quest]["itemState"], "unknown")
            self.assertEqual(rows[quest]["items"], [])
            self.assertEqual(rows[quest]["fieldStates"]["title"], "recorded")

    def test_guaranteed_only_additions_preserve_unknown_choices_and_separate_variants(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        updates = reviewed_partial_rewards(inputs["reviewed"])
        source, _ = build_complete(ROOT)
        rows = {row["id"]: row for row in source["quests"]}
        for quest in (89013, 91608):
            row = rows[quest]
            self.assertEqual(
                (row["title"], row["level"], row["minimum"]), ("Gettin' Buzzed", 48, 45)
            )
            self.assertEqual(
                [(r["itemID"], r["quantity"], r["group"]) for r in row["items"]],
                [
                    (290333, 1, "guaranteed"),
                    (250999, 1, "guaranteed"),
                    (250955, 5, "guaranteed"),
                ],
            )
            self.assertEqual(
                row["itemGroupStates"], {"guaranteed": "published", "choice": "unknown"}
            )
            self.assertEqual(
                row["recordedCategory"], {"sourceZoneID": 16, "name": "Azshara"}
            )
            self.assertTrue(row["eligibilityUnknown"])
            for field in (
                "locations",
                "faction",
                "classTokens",
                "races",
                "moneyCost",
                "rewardValues",
            ):
                self.assertNotIn(field, row)
            update = updates[quest]
            adopted = {
                "id": quest,
                "title": row["title"],
                **copy.deepcopy(update["changes"]),
            }
            adopted.pop("itemGroupStates")
            apply_reviewed_update(adopted, update)
            self.assertEqual(adopted["itemGroupStates"], row["itemGroupStates"])
            for mutation in ("empty", "mixed", "quantity", "unbound"):
                changed = copy.deepcopy(inputs["reviewed"])
                entry = next(
                    r for r in changed["partialRewardUpdates"] if r["id"] == quest
                )
                if mutation == "empty":
                    entry["changes"]["itemGroupStates"]["choice"] = "published-empty"
                elif mutation == "mixed":
                    entry["changes"]["items"][0]["group"] = "choice"
                elif mutation == "quantity":
                    entry["changes"]["items"][-1]["quantity"] = 1
                else:
                    entry.pop("nativeObservation")
                with (
                    self.subTest(quest=quest, mutation=mutation),
                    self.assertRaises(ValueError),
                ):
                    reviewed_partial_rewards(changed)
        self.assertEqual(rows[614]["questKind"], "hidden-trigger")
        self.assertEqual(
            rows[614]["itemGroupStates"],
            {"guaranteed": "unknown", "choice": "published"},
        )

    def test_unreviewed_or_conflicting_public_group_authority_is_rejected(self):
        for quest in (6, 630):
            provenance, inputs = read_inputs(ROOT)
            published = next(
                row for row in inputs["public"]["records"] if row["id"] == quest
            )
            published["itemGroupStates"] = {
                "guaranteed": "published-empty",
                "choice": "published",
            }
            with (
                self.subTest(quest=quest),
                mock.patch(
                    "fau_tools.catalog.read_inputs", return_value=(provenance, inputs)
                ),
            ):
                with self.assertRaisesRegex(ValueError, "Unreviewed|source conflict"):
                    build_complete(ROOT)

    def test_reviewed_update_conflicts_abort_and_already_adopted_values_are_idempotent(
        self,
    ):
        _, inputs = read_inputs(ROOT)
        updates = reviewed_updates(inputs["reviewed"])
        update = updates[93176]
        row = {
            "id": 93176,
            "title": update["title"],
            **copy.deepcopy(update["expected"]),
        }
        apply_reviewed_update(row, update)
        apply_reviewed_update(row, update)
        self.assertEqual(row["items"], update["changes"]["items"])
        row["items"][0]["quantity"] = 2
        with self.assertRaisesRegex(ValueError, "source conflict"):
            apply_reviewed_update(row, update)
        row["title"] = "Different identity"
        with self.assertRaisesRegex(ValueError, "identity"):
            apply_reviewed_update(row, update)
        for quest in (95816, 95819):
            row = {
                "id": quest,
                "title": updates[quest]["title"],
                "itemState": "published",
                "items": [
                    {"itemID": 123, "quantity": 1, "group": "guaranteed", "slot": 1}
                ],
            }
            with self.assertRaisesRegex(ValueError, "source conflict"):
                apply_reviewed_update(row, updates[quest])

    def test_new_primary_minimum_cannot_be_hidden_by_reviewed_public_correction(self):
        provenance, inputs = read_inputs(ROOT)
        inputs["primary"]["records"].append(
            {"id": 92841, "title": "Valley of Bones", "items": [], "minimum": 40}
        )
        with mock.patch(
            "fau_tools.catalog.read_inputs", return_value=(provenance, inputs)
        ):
            with self.assertRaisesRegex(ValueError, "primary conflict"):
                build_complete(ROOT)

    def test_output_reproduces_every_source_id_and_explicit_unknown(self):
        source, report = build_complete(ROOT)
        actual = json.loads((ROOT / "data/catalog-complete-source.json").read_bytes())
        self.assertEqual(source, actual)
        self.assertEqual(report["publicIdsAbsentOutput"], [])
        self.assertEqual(
            sum(report["fieldCoverage"]["items"].values()), len(source["quests"])
        )
        self.assertGreater(report["counts"]["publishedEmptyItems"], 1837)
        self.assertGreater(report["counts"]["rowsWithGivers"], 3500)
        _, inputs = read_inputs(ROOT)
        self.assertEqual(report["counts"]["publicIndex"], inputs["public"]["expected"])
        identity = set(inputs["compiled"]["questIDs"]) | set(
            inputs["client"]["questIDs"]
        )
        identity.update(row["id"] for row in inputs["public"]["records"])
        identity.update(row["id"] for row in inputs["legacy"]["quests"])
        identity.update(
            row["id"]
            for row in json.loads((ROOT / "data/primary-statuses.json").read_bytes())[
                "quests"
            ]
        )
        identity.update(inputs.get("history", {}).get("questIDs", []))
        identity.update(reviewed_additions(inputs.get("reviewed")))
        self.assertEqual({row["id"] for row in source["quests"]}, identity)
        output = {row["id"]: row for row in source["quests"]}
        for quest in inputs["compiled"].get("hiddenTriggerIDs", []):
            self.assertEqual(output[quest]["questKind"], "hidden-trigger")
        for published in inputs["public"]["records"]:
            row = output[published["id"]]
            reviewed = {}
            for key in ("records", "partialRewardUpdates"):
                for entry in inputs.get("reviewed", {}).get(key, []):
                    if entry["id"] == published["id"]:
                        reviewed.update(entry["changes"])
            for field in ("items", "itemState"):
                self.assertEqual(row[field], reviewed.get(field, published[field]))
            for field in ("xp", "money", "reputation"):
                if field in published:
                    self.assertEqual(row["rewardValues"][field], published[field])

    def test_canonical_truncation_and_changed_reward_groups_are_rejected(self):
        source, _ = build_complete(ROOT)
        provenance, _ = read_inputs(ROOT)
        changed = copy.deepcopy(source)
        changed["quests"].pop()
        with self.assertRaisesRegex(ValueError, "reconciliation"):
            validate_complete(changed, provenance, ROOT)
        changed = copy.deepcopy(source)
        row = next(row for row in changed["quests"] if row["id"] == 682)
        row["items"] = [item for item in row["items"] if item["group"] != "guaranteed"]
        with self.assertRaisesRegex(ValueError, "reconciliation"):
            validate_complete(changed, provenance, ROOT)

    def test_missing_and_truncated_panels_are_unknown_not_empty(self):
        for html in (page(label="Classic Era"), page()[:-7], page(quest=10)):
            result = quest_detail(html, 9)
            self.assertEqual(result["itemState"], "unknown")
            self.assertEqual(result["items"], [])
        self.assertEqual(quest_detail(page(), 9)["itemState"], "published-empty")

    def test_classic_rewards_and_change_summaries_do_not_become_forever_rewards(self):
        classic = (
            '<section><div class="label">Classic Era</div><div class="wow-tt">'
            + item(domain="classic")
            + "</div></section>"
        )
        changed = '<div><div>Changes in Forever</div><a href="/items/456">Historical change</a></div>'
        result = quest_detail(page(changed, extra=classic), 9)
        self.assertEqual(result["items"], [])
        self.assertEqual(result["itemState"], "published-empty")
        with self.assertRaisesRegex(ValueError, "environment"):
            quest_detail(page(item(domain="classic")), 9)

    def test_reward_groups_keep_duplicate_identity_across_groups_and_quantities(self):
        result = quest_detail(
            page(
                item(quantity="\u00d72")
                + item("You will be able to choose one of these rewards:")
            ),
            9,
        )
        self.assertEqual(
            [(i["group"], i["itemID"], i["quantity"]) for i in result["items"]],
            [("guaranteed", 123, 2), ("choice", 123, 1)],
        )
        repeated = quest_detail(
            page(item(quantity="\u00d720") + item(quantity="\u00d710")), 9
        )
        self.assertEqual(
            [(row["slot"], row["quantity"]) for row in repeated["items"]],
            [(1, 20), (2, 10)],
        )
        with self.assertRaisesRegex(ValueError, "quantity"):
            quest_detail(page(item(quantity="\u00d70")), 9)

    def test_explicit_units_and_names_are_required_for_published_amounts(self):
        body = "<div><div>You will also receive:</div><div>1,450 experience</div><div>1g 4s 2c</div><div>+50 reputation with Ironforge</div></div>"
        row = quest_detail(page(body), 9)
        self.assertEqual(
            (row["xp"], row["money"], row["reputation"]),
            (1450, 10402, [{"name": "Ironforge", "amount": 50}]),
        )
        row = quest_detail(
            page("<div><div>You will also receive:</div><div>40</div></div>"), 9
        )
        self.assertNotIn("money", row)
        self.assertNotIn("xp", row)
        self.assertEqual(row["fieldStates"]["money"], "unknown")

    def test_index_retains_unconfirmed_discovery_ids_without_changing_their_environment(
        self,
    ):
        html = '<html><span>2<!-- --> results</span><a href="/quests/9" data-wowhead="quest=9&amp;domain=forever">A</a><a href="/quests/10" data-wowhead="quest=10&amp;domain=classic">B</a></html>'
        self.assertEqual(quest_index(html), (2, [9, 10]))

    def test_metadata_does_not_require_an_item_reward_or_invent_one(self):
        text = "q(9,{qg=54,lvl=15,coord={50,60,MAP.ZONE}})"
        self.assertEqual(parse(text, "fixture", {"MAP.ZONE": 100})[0], [])
        rows, _ = parse(text, "fixture", {"MAP.ZONE": 100}, include_empty=True)
        self.assertEqual(rows[0]["items"], [])
        self.assertEqual(rows[0]["locations"][0]["npcID"], 54)

    def test_independent_giver_metadata_survives_an_unsupported_restriction_for_separate_resolution(
        self,
    ):
        rows, _ = parse(
            "q(792,{classes=exclude(WARLOCK,ALL_CLASSES),qg=3145,coord={42,68,MAP.ZONE}})",
            "fixture",
            {"MAP.ZONE": 1411},
            include_empty=True,
        )
        self.assertEqual(rows[0]["unresolvedRestrictions"], ["classes"])
        self.assertEqual(
            rows[0]["locations"][0],
            {"npcID": 3145, "mapID": 1411, "x": 0.42, "y": 0.68},
        )
        self.assertEqual(rows[0]["items"], [])

    def test_typed_object_and_item_starters_never_become_npc_associations_or_coordinates(
        self,
    ):
        text = 'q(9,{provider={"i",123},providers={{"o",456},{"n",789}},coord={20,30,MAP.ZONE},groups={objective(1,{provider={"n",999}})}})'
        rows, _ = parse(text, "fixture", {"MAP.ZONE": 1411}, include_empty=True)
        self.assertEqual(
            rows[0]["locations"], [{"itemID": 123}, {"objectID": 456}, {"npcID": 789}]
        )
        rows, omissions = parse(
            "q(9,{provider={n,123}})", "fixture", {}, include_empty=True
        )
        self.assertNotIn("locations", rows[0])
        self.assertTrue(any(row.get("field") == "providers" for row in omissions))

    def test_unresolved_restrictions_accumulate_across_exact_id_occurrences(self):
        a = {"id": 9, "items": [], "sources": [], "unresolvedRestrictions": ["classes"]}
        b = {"id": 9, "items": [], "sources": [], "unresolvedRestrictions": ["races"]}
        self.assertEqual(merge(a, b)["unresolvedRestrictions"], ["classes", "races"])

    def test_native_identity_validation_requires_current_build_and_complete_framing(
        self,
    ):
        raw = (
            b"TSQW"
            + struct.pack("<I", 70374)
            + b"\0" * 16
            + struct.pack("<III", 9, 4, 9)
            + b"\0" * 8
        )
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as tmp:
            path = Path(tmp) / "questcache.wdb"
            path.write_bytes(raw)
            row = native_ids(path)
            self.assertEqual(row["questIDs"], [9])
            self.assertFalse(row["rewardLayoutVerified"])
            for bad in (
                raw[:-1],
                raw[:-8],
                raw[:4] + struct.pack("<I", 70338) + raw[8:],
            ):
                path.write_bytes(bad)
                with self.assertRaises(ValueError):
                    native_ids(path)


if __name__ == "__main__":
    unittest.main()
