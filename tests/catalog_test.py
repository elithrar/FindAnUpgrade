"""Owned catalogue provenance, deterministic generation and conservative parsing."""
from pathlib import Path
import copy, hashlib, importlib.util, json, unittest
ROOT = Path(__file__).resolve().parents[1]

def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name+".py"))
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); return mod

IMPORT = module("import_catalog"); GENERATE = module("generate_catalog")
SOURCE = json.loads((ROOT / "data/catalog-source.json").read_bytes())
PROVENANCE = json.loads((ROOT / "data/catalog-sources.json").read_bytes())

class CatalogueTests(unittest.TestCase):
    def test_generated_output_and_coverage_are_exact(self):
        output = GENERATE.render(SOURCE, PROVENANCE)
        self.assertEqual(output, (ROOT / "QuestBrief/Data/Catalog.lua").read_bytes())
        self.assertEqual(GENERATE.coverage(SOURCE, output), json.loads((ROOT / "data/catalog-coverage.json").read_bytes()))

    def test_complete_mit_notice_and_matching_source_hash(self):
        notice = (ROOT / "QuestBrief/Data/ATT-LICENSE.txt").read_bytes()
        license_record = next(s for s in PROVENANCE["files"] if s["path"] == "LICENSE")
        self.assertEqual(hashlib.sha256(notice).hexdigest(), license_record["sha256"])
        self.assertIn(b"Copyright (c) 2026 AllTheThings WoW Addon", notice)

    def test_objective_starter_vendor_and_nested_loot_are_not_rewards(self):
        text = 'q(98403,{qi=281023,provider={"i",999},groups={objective(1,{providers={{"i",281023}}}),n(54,{groups={i(123)}}),i(282284)}})'
        rows, _ = IMPORT.parse(text, "fixture", {})
        self.assertEqual([i["itemID"] for i in rows[0]["items"]], [282284])
        self.assertNotIn("quantity", rows[0]["items"][0]); self.assertNotIn("group", rows[0]["items"][0])

    def test_source_prerequisite_threshold_is_preserved(self):
        rows, _ = IMPORT.parse('q(92868,{sourceQuests={93460,93461},sourceQuestNumRequired=1,groups={i(263511)}})', "fixture", {})
        self.assertEqual(rows[0]["prerequisiteCount"], 1)

    def test_unsupported_selected_constraints_omit_the_record(self):
        for field in ("classes=GetClasses()", "races=ComputeRaces()"):
            rows, skips = IMPORT.parse('q(9,{'+field+',groups={i(123)}})', "fixture", {})
            self.assertEqual(rows, []); self.assertIn("unsupported", skips[0]["reason"])
        for field in ("lvl=GetLevel()", "sourceQuest=GetPrereq()"):
            rows, skips=IMPORT.parse('q(9,{'+field+',groups={i(123)}})',"fixture",{})
            self.assertTrue(rows[0]["eligibilityUnknown"]); self.assertIn("field omitted",skips[0]["reason"])

    def test_ambiguous_alternate_titles_and_metadata_are_not_names(self):
        self.assertIsNone(IMPORT.label(['q(923, { -- Tumors / Mossy Tumors [CATA+]'], 1))
        self.assertIsNone(IMPORT.label(['q(172, { -- [Horde - Orc - START]'], 1))
        self.assertEqual(IMPORT.label(['i(123), -- Exact Item [CATA+]'], 1), "Exact Item")

    def test_self_prerequisite_stays_unconfirmed(self):
        rows, skips = IMPORT.parse('q(3522,{sourceQuest=3522,groups={i(10655)}})', "fixture", {})
        self.assertNotIn("prerequisites", rows[0]); self.assertTrue(rows[0]["eligibilityUnknown"]); self.assertEqual(len(skips), 1)

    def test_forever_conditions_are_explicit_and_unknown_conditions_fail(self):
        text = '-- #if SEASON_OF_DISCOVERY\nq(9,{groups={i(123)}})\n-- #else\nq(14,{groups={i(124)}})\n-- #endif\n'
        rows, _ = IMPORT.parse(text, "fixture", {}); self.assertEqual([r["id"] for r in rows], [14])
        with self.assertRaises(ValueError): IMPORT.preprocess('-- #if UNKNOWN\nx\n-- #endif\n')

    def test_unresolved_maps_and_multigiver_coordinates_stay_unknown(self):
        rows, _ = IMPORT.parse('q(9,{qg=54,coord={50,60,MAP.UNKNOWN},groups={i(123)}})', "fixture", {})
        self.assertNotIn("mapID", rows[0]["locations"][0])
        rows, _ = IMPORT.parse('q(9,{qgs={54,55},coords={{50,60,MAP.OK}},groups={i(123)}})', "fixture", {"MAP.OK":100})
        self.assertTrue(all("mapID" not in loc for loc in rows[0]["locations"]))

    def test_minimum_level_is_not_difficulty_and_new_race_ids_are_preserved(self):
        rows, _ = IMPORT.parse('q(9,{lvl={4,60},races={SKYBORNE_ALLIANCE},groups={i(123)}})', "fixture", {}, {"SKYBORNE_ALLIANCE":95})
        self.assertEqual((rows[0]["minimum"], rows[0]["maximum"], rows[0]["races"]), (4,60,[95]))
        self.assertNotIn("level", rows[0])

    def test_fabricated_quantities_and_groups_are_rejected(self):
        for key, value in (("quantity",1), ("group","guaranteed")):
            modified=copy.deepcopy(SOURCE); modified["quests"][0]["items"][0][key]=value
            with self.assertRaises(AssertionError): GENERATE.validate(modified, PROVENANCE)

    def test_out_of_bounds_coordinates_and_unprovenance_rows_are_rejected(self):
        modified=copy.deepcopy(SOURCE); row=next(q for q in modified["quests"] if any("x" in p for p in q.get("locations", []))); row["locations"][0]["x"]=1.1
        with self.assertRaises(AssertionError): GENERATE.validate(modified, PROVENANCE)
        modified=copy.deepcopy(SOURCE); modified["quests"][0]["sources"][0]["path"]="unverified.lua"
        with self.assertRaises(AssertionError): GENERATE.validate(modified, PROVENANCE)

if __name__ == "__main__": unittest.main()
