"""Owned catalogue provenance, deterministic generation and conservative parsing."""

import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


IMPORT = module("import_catalog")
GENERATE = module("generate_catalog")
SOURCE = json.loads((ROOT / "data/catalog-source.json").read_bytes())
PROVENANCE = json.loads((ROOT / "data/catalog-sources.json").read_bytes())


class CatalogueTests(unittest.TestCase):
    def test_generated_output_and_coverage_are_exact(self):
        current, provenance = GENERATE.load_inputs()
        output = GENERATE.render(current, provenance)
        self.assertEqual(output, (ROOT / "FindAnUpgrade/Data/Catalog.lua").read_bytes())
        self.assertEqual(
            GENERATE.coverage(current, output),
            json.loads((ROOT / "data/catalog-coverage.json").read_bytes()),
        )

    def test_complete_mit_notice_and_matching_source_hash(self):
        notice = (ROOT / "FindAnUpgrade/Data/ATT-LICENSE.txt").read_bytes()
        license_record = next(s for s in PROVENANCE["files"] if s["path"] == "LICENSE")
        self.assertEqual(hashlib.sha256(notice).hexdigest(), license_record["sha256"])
        self.assertIn(b"Copyright (c) 2026 AllTheThings WoW Addon", notice)

    def test_objective_starter_vendor_and_nested_loot_are_not_rewards(self):
        text = 'q(98403,{qi=281023,provider={"i",999},groups={objective(1,{providers={{"i",281023}}}),n(54,{groups={i(123)}}),i(282284)}})'
        rows, _ = IMPORT.parse(text, "fixture", {})
        self.assertEqual([i["itemID"] for i in rows[0]["items"]], [282284])
        self.assertNotIn("quantity", rows[0]["items"][0])
        self.assertNotIn("group", rows[0]["items"][0])

    def test_source_prerequisite_threshold_is_preserved(self):
        rows, _ = IMPORT.parse(
            "q(92868,{sourceQuests={93460,93461},sourceQuestNumRequired=1,groups={i(263511)}})",
            "fixture",
            {},
        )
        self.assertEqual(rows[0]["prerequisiteCount"], 1)

    def test_objective_inputs_and_transitive_intermediates_are_not_rewards(self):
        text = """q(9,{groups={
            objective(1,{provider={"i",100},cost={{"i",101,1}}}),
            i(101,{provider={"o",999},cost={{"i",102,1}}}),
            i(102,{description="Issued while doing this quest"}),
            i(103,{crs={54,55}}),i(104),i(100)
        }})"""
        rows, skips = IMPORT.parse(text, "fixture", {})
        self.assertEqual([item["itemID"] for item in rows[0]["items"]], [104])
        self.assertEqual({skip["itemID"] for skip in skips}, {100, 101, 102, 103})
        self.assertTrue(
            all(
                skip["line"] > 0 and "reward pair omitted" in skip["reason"]
                for skip in skips
            )
        )

    def test_issued_items_and_unknown_component_ids_fail_closed(self):
        rows, skips = IMPORT.parse(
            "q(9,{qi=123,groups={i(123),i(124)}})", "fixture", {}
        )
        self.assertEqual([item["itemID"] for item in rows[0]["items"]], [124])
        self.assertEqual(skips[0]["itemID"], 123)
        rows, skips = IMPORT.parse(
            'q(9,{groups={objective(1,{cost={{"i",ComputeItem(),1}}}),i(123)}})',
            "fixture",
            {},
        )
        self.assertEqual(rows, [])
        self.assertEqual(skips[0]["itemID"], 123)
        self.assertIn("unresolved", skips[0]["reason"])

    def test_unknown_or_invalid_prerequisite_threshold_omits_the_group(self):
        for threshold in ("ComputeRequired()", "0", "3"):
            rows, skips = IMPORT.parse(
                "q(9,{sourceQuests={1,2},sourceQuestNumRequired="
                + threshold
                + ",groups={i(123)}})",
                "fixture",
                {},
            )
            self.assertNotIn("prerequisites", rows[0])
            self.assertNotIn("prerequisiteCount", rows[0])
            self.assertTrue(rows[0]["eligibilityUnknown"])
            self.assertTrue(any(skip.get("field") == "prerequisites" for skip in skips))

    def test_literal_unresolved_class_and_race_constraints_omit_records(self):
        for field in (
            "races={FUTURE_RACE}",
            "races={0}",
            "races={}",
            "classes=17",
            "classes={}",
            "classes={FUTURE_CLASS}",
        ):
            rows, skips = IMPORT.parse(
                "q(9,{" + field + ",groups={i(123)}})", "fixture", {}
            )
            self.assertEqual(rows, [])
            self.assertIn("record omitted", skips[0]["reason"])

    def test_main_omits_the_entire_quest_for_any_unresolved_restriction(self):
        (ROOT / ".work").mkdir(exist_ok=True)
        allowed = {
            tuple(pair)
            for pair in json.loads(
                (ROOT / "data/catalog-compiled-membership.json").read_bytes()
            )["pairs"]
        }
        self.assertTrue({(9, 1561), (9, 3578)} <= allowed)
        for field in (
            "classes=ComputeClasses()",
            "races=ComputeRaces()",
            "classes={FUTURE_CLASS}",
        ):
            for invalid_first in (False, True):
                for helper_only in (False, True):
                    with (
                        self.subTest(
                            field=field,
                            invalid_first=invalid_first,
                            helper_only=helper_only,
                        ),
                        tempfile.TemporaryDirectory(
                            prefix="catalog-aggregation-", dir=ROOT / ".work"
                        ) as temporary,
                    ):
                        workspace = Path(temporary)
                        source_root = workspace / "source"
                        (workspace / "data").mkdir()
                        shutil.copyfile(
                            ROOT / "data/catalog-compiled-membership.json",
                            workspace / "data/catalog-compiled-membership.json",
                        )
                        valid = IMPORT.PREFIX + (
                            "z-valid.lua" if invalid_first else "a-valid.lua"
                        )
                        invalid = IMPORT.PREFIX + (
                            "a-invalid.lua" if invalid_first else "z-invalid.lua"
                        )
                        texts = {
                            valid: "q(9,{groups={i(1561)}})",
                            invalid: "q(9,{"
                            + field
                            + ("" if helper_only else ",groups={i(3578)}")
                            + "})",
                            IMPORT.PREFIX + ".config/constants/maps.lua": "",
                            ".contrib/.db/shared/constants/raceIDs.lua": "",
                            IMPORT.PREFIX + ".config/forever.config": "",
                            "LICENSE": "fixture",
                        }
                        files = []
                        for path, text in texts.items():
                            raw = text.encode()
                            target = source_root / path
                            target.parent.mkdir(parents=True, exist_ok=True)
                            target.write_bytes(raw)
                            files.append(
                                {
                                    "path": path,
                                    "sha256": hashlib.sha256(raw).hexdigest(),
                                    "gitBlob": hashlib.sha1(
                                        b"blob " + str(len(raw)).encode() + b"\0" + raw
                                    ).hexdigest(),
                                    "url": "https://github.com/ATTWoWAddon/AllTheThings/blob/"
                                    + IMPORT.PIN
                                    + "/"
                                    + path,
                                }
                            )
                        (source_root / "ACQUISITION.json").write_text(
                            json.dumps(
                                {
                                    "repository": "ATTWoWAddon/AllTheThings",
                                    "commit": IMPORT.PIN,
                                    "files": files,
                                }
                            )
                        )
                        with (
                            mock.patch.object(IMPORT, "ROOT", workspace),
                            mock.patch.object(
                                sys,
                                "argv",
                                [
                                    "import_catalog.py",
                                    "--source-root",
                                    str(source_root),
                                ],
                            ),
                            contextlib.redirect_stdout(io.StringIO()),
                        ):
                            IMPORT.main()
                        generated = json.loads(
                            (workspace / "data/catalog-source.json").read_bytes()
                        )
                        provenance = json.loads(
                            (workspace / "data/catalog-sources.json").read_bytes()
                        )
                        self.assertEqual(generated["quests"], [])
                        diagnosed = {
                            (row["id"], row["itemID"])
                            for row in provenance["omissions"]
                            if "itemID" in row
                        }
                        expected = (
                            {(9, 1561)} if helper_only else {(9, 1561), (9, 3578)}
                        )
                        self.assertTrue(expected <= diagnosed)
                        self.assertEqual(
                            provenance["excludedRewardPairCount"], len(diagnosed)
                        )

    def test_only_immutable_file_prefix_literal_aliases_are_resolved(self):
        text = "local earlier={1,2}\nq(9,{sourceQuests=earlier,sourceQuestNumRequired=1,groups={i(123)}})"
        rows, skips = IMPORT.parse(text, "fixture", {})
        self.assertEqual(rows[0]["prerequisites"], [1, 2])
        self.assertEqual(rows[0]["prerequisiteCount"], 1)
        self.assertEqual(skips, [])
        for modified in (
            text + "\nearlier={3}",
            "do " + text + " end",
            text.replace("{1,2}", "ComputeQuests()"),
            text + "\nearlier[1]=3",
            text + "\ntable.insert(earlier,3)",
            text + "\nlocal escaped=earlier; escaped[1]=3",
            text + "\nlocal function f(earlier) end",
        ):
            rows, skips = IMPORT.parse(modified, "fixture", {})
            self.assertNotIn("prerequisites", rows[0])
            self.assertTrue(rows[0]["eligibilityUnknown"])
        text = 'local COIN=21100;\nq(9,{cost={{"i",COIN,5}},groups={i(123)}})'
        rows, skips = IMPORT.parse(text, "fixture", {})
        self.assertEqual([item["itemID"] for item in rows[0]["items"]], [123])
        self.assertEqual(skips, [])
        for modified in (text.replace("21100;", "21100+1;"), text + "\nCOIN=123;"):
            rows, skips = IMPORT.parse(modified, "fixture", {})
            self.assertEqual(rows, [])
            self.assertIn("unresolved", skips[0]["reason"])

    def test_invalid_recorded_level_is_diagnosed(self):
        for level in ("0", "{60,5}"):
            rows, skips = IMPORT.parse(
                "q(9,{lvl=" + level + ",groups={i(123)}})", "fixture", {}
            )
            self.assertNotIn("minimum", rows[0])
            self.assertTrue(rows[0]["eligibilityUnknown"])
            self.assertEqual(skips[0]["field"], "lvl")

    def test_reviewed_production_rewards_exclude_components(self):
        quests = {row["id"]: row for row in SOURCE["quests"]}
        for quest, expected in (
            (4763, {15202, 15203, 15204}),
            (3924, {11854, 11855}),
            (7509, {18348}),
        ):
            self.assertEqual(
                {item["itemID"] for item in quests[quest]["items"]}, expected
            )
        self.assertNotIn(6022, quests)
        self.assertNotIn(1016, quests)
        exclusions = {
            (row["id"], row["itemID"])
            for row in PROVENANCE["omissions"]
            if "itemID" in row
        }
        self.assertEqual(len(exclusions), PROVENANCE["excludedRewardPairCount"])
        self.assertTrue(
            {(4763, 12347), (3924, 11148), (7509, 18489), (6022, 15454), (1016, 5456)}
            <= exclusions
        )
        kept = {
            (row["id"], item["itemID"])
            for row in SOURCE["quests"]
            for item in row["items"]
        }
        self.assertFalse(exclusions & kept)

    def test_unsupported_selected_constraints_omit_the_record(self):
        for field in ("classes=GetClasses()", "races=ComputeRaces()"):
            rows, skips = IMPORT.parse(
                "q(9,{" + field + ",groups={i(123)}})", "fixture", {}
            )
            self.assertEqual(rows, [])
            self.assertIn("unsupported", skips[0]["reason"])
        for field in ("lvl=GetLevel()", "sourceQuest=GetPrereq()"):
            rows, skips = IMPORT.parse(
                "q(9,{" + field + ",groups={i(123)}})", "fixture", {}
            )
            self.assertTrue(rows[0]["eligibilityUnknown"])
            self.assertIn("field omitted", skips[0]["reason"])

    def test_ambiguous_alternate_titles_and_metadata_are_not_names(self):
        self.assertIsNone(
            IMPORT.label(["q(923, { -- Tumors / Mossy Tumors [CATA+]"], 1)
        )
        self.assertIsNone(IMPORT.label(["q(172, { -- [Horde - Orc - START]"], 1))
        self.assertEqual(
            IMPORT.label(["i(123), -- Exact Item [CATA+]"], 1), "Exact Item"
        )

    def test_self_prerequisite_stays_unconfirmed(self):
        rows, skips = IMPORT.parse(
            "q(3522,{sourceQuest=3522,groups={i(10655)}})", "fixture", {}
        )
        self.assertNotIn("prerequisites", rows[0])
        self.assertTrue(rows[0]["eligibilityUnknown"])
        self.assertEqual(len(skips), 1)

    def test_forever_conditions_are_explicit_and_unknown_conditions_fail(self):
        text = "-- #if SEASON_OF_DISCOVERY\nq(9,{groups={i(123)}})\n-- #else\nq(14,{groups={i(124)}})\n-- #endif\n"
        rows, _ = IMPORT.parse(text, "fixture", {})
        self.assertEqual([r["id"] for r in rows], [14])
        with self.assertRaises(ValueError):
            IMPORT.preprocess("-- #if UNKNOWN\nx\n-- #endif\n")

    def test_unresolved_maps_and_multigiver_coordinates_stay_unknown(self):
        rows, _ = IMPORT.parse(
            "q(9,{qg=54,coord={50,60,MAP.UNKNOWN},groups={i(123)}})", "fixture", {}
        )
        self.assertNotIn("mapID", rows[0]["locations"][0])
        rows, _ = IMPORT.parse(
            "q(9,{qgs={54,55},coords={{50,60,MAP.OK}},groups={i(123)}})",
            "fixture",
            {"MAP.OK": 100},
        )
        self.assertTrue(all("mapID" not in loc for loc in rows[0]["locations"]))

    def test_minimum_level_is_not_difficulty_and_new_race_ids_are_preserved(self):
        rows, _ = IMPORT.parse(
            "q(9,{lvl={4,60},races={SKYBORNE_ALLIANCE},groups={i(123)}})",
            "fixture",
            {},
            {"SKYBORNE_ALLIANCE": 95},
        )
        self.assertEqual(
            (rows[0]["minimum"], rows[0]["maximum"], rows[0]["races"]), (4, 60, [95])
        )
        self.assertNotIn("level", rows[0])
        rows, _ = IMPORT.parse(
            "q(9,{races=SKYBORNE_ALLIANCE,groups={i(123)}})",
            "fixture",
            {},
            {"SKYBORNE_ALLIANCE": 95},
        )
        self.assertEqual(rows[0]["races"], [95])

    def test_fabricated_quantities_and_groups_are_rejected(self):
        for key, value in (("quantity", 1), ("group", "guaranteed")):
            modified = copy.deepcopy(SOURCE)
            modified["quests"][0]["items"][0][key] = value
            with self.assertRaises(AssertionError):
                GENERATE.validate(modified, PROVENANCE)

    def test_out_of_bounds_coordinates_and_unprovenance_rows_are_rejected(self):
        modified = copy.deepcopy(SOURCE)
        row = next(
            q
            for q in modified["quests"]
            if any("x" in p for p in q.get("locations", []))
        )
        row["locations"][0]["x"] = 1.1
        with self.assertRaises(AssertionError):
            GENERATE.validate(modified, PROVENANCE)
        modified = copy.deepcopy(SOURCE)
        modified["quests"][0]["sources"][0]["path"] = "unverified.lua"
        with self.assertRaises(AssertionError):
            GENERATE.validate(modified, PROVENANCE)

    def test_inverted_owned_level_range_and_reintroduced_component_are_rejected(self):
        modified = copy.deepcopy(SOURCE)
        modified["quests"][0].update(minimum=60, maximum=5)
        with self.assertRaises(AssertionError):
            GENERATE.validate(modified, PROVENANCE)
        modified = copy.deepcopy(SOURCE)
        row = next(row for row in modified["quests"] if row["id"] == 4763)
        row["items"].append({"itemID": 12347})
        with self.assertRaises(AssertionError):
            GENERATE.validate(modified, PROVENANCE)

    def test_generator_rejects_maps_and_duplicates_as_constraint_arrays(self):
        for field, shapes in (
            ("classTokens", ({"SHAMAN": True}, "SHAMAN", [], ["SHAMAN", "SHAMAN"])),
            ("races", ({95: True}, 95, [], [95, 95])),
            ("prerequisites", ({1: True}, 1, [], [1, 1])),
        ):
            for shape in shapes:
                with self.subTest(field=field, shape=shape):
                    modified = copy.deepcopy(SOURCE)
                    row = next(row for row in modified["quests"] if row["id"] == 96)
                    row[field] = shape
                    with self.assertRaises(AssertionError):
                        GENERATE.validate(modified, PROVENANCE)
        rows, _ = IMPORT.parse(
            "q(9,{classes={SHAMAN,SHAMAN},races={SKYBORNE_ALLIANCE,SKYBORNE_ALLIANCE},sourceQuests={1,1},groups={i(123)}})",
            "fixture",
            {},
            {"SKYBORNE_ALLIANCE": 95},
        )
        self.assertEqual(rows[0]["classTokens"], ["SHAMAN"])
        self.assertEqual(rows[0]["races"], [95])
        self.assertEqual(rows[0]["prerequisites"], [1])


if __name__ == "__main__":
    unittest.main()
