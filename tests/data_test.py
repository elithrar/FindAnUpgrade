from pathlib import Path
import hashlib, json, subprocess, sys, unittest
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".work/pydeps"))
from lupa.lua51 import LuaRuntime

class DataTest(unittest.TestCase):
    def setUp(self):
        self.source = json.loads((ROOT / "data/primary-statuses.json").read_bytes())
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute("N = {}")
        self.lua.globals().SOURCE = str(ROOT / "QuestBrief/Data/Quests.lua").replace("\\", "/")
        self.lua.execute('assert(loadfile(SOURCE))("QuestBrief", N)')
        self.actual = dict(self.lua.globals().N.Data.statusById.items())

    def test_every_id_matches_per_variant_primary_status(self):
        mapped = {"New": "verifiedNew", "Updated": "verifiedUpdated", "Unchanged": "verifiedUnchanged"}
        expected = {row["id"]: mapped[row["status"]] for row in self.source["quests"]}
        self.assertEqual(self.actual, expected)
        self.assertEqual(len(expected), 1194)
        self.assertEqual(sum(s == "verifiedNew" for s in expected.values()), 218)

    def test_provenance_is_exact_source_version(self):
        self.assertEqual(self.source["libraryFileId"], "libfile_7a7d39bd0d1c81919be5ccb96b9c6b9c")
        self.assertEqual(self.source["version"], "1")
        self.assertEqual((self.source["zoneCount"], self.source["titleGroupCount"]), (18, 998))
        self.assertEqual(len({q["zone"] for q in self.source["quests"]}), 18)

    def test_mixed_variants_and_unknown_are_not_new(self):
        for quest in [286, 356, 921, 928, 929, 933, 934, 935, 7383, 932, 422, 423, 99, 424]:
            self.assertNotEqual(self.actual[quest], "verifiedNew")
        for quest in [98189, 99156, 98046, 98065, 98403, 98298, 92124]:
            self.assertEqual(self.actual[quest], "verifiedNew")
        self.assertNotIn(10000000, self.actual)

    def test_generated_output_is_reproducible(self):
        subprocess.run([sys.executable, str(ROOT / "tools/generate_data.py"), "--check"], check=True)

    def test_frozen_evidence_hash(self):
        raw = (ROOT / "data/primary-statuses.json").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), "64017ae90fe4e16323044064b0ac5ba6102fba147446660fb1fd863eaf8e9ae5")

if __name__ == "__main__": unittest.main()
