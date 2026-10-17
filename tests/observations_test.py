"""Challenge data-only submission boundaries and native export interoperability."""

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from lupa.lua51 import LuaRuntime

from fau_tools import observations as O
from fau_tools.context import ROOT


def exported(lifecycle=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = ROOT.as_posix()
    lua.globals().CAPTURE_LIFECYCLE = lifecycle
    return lua.execute("""
        local W=assert(loadfile(ROOT..'/tests/wow_mock.lua'))()
        local N=W.Reset(); GetBuildInfo=function()return '1.60.1','70425','2026-10-15',16001 end
        GetLocale=function()return 'enUS'end;UnitName=function()return 'Matt'end
        C_QuestLog.ShouldShowQuestRewards=function()return true end
        C_QuestLog.GetTitleForQuestID=function()return 'A \\"quest\\" with Unicode: \\228\\184\\173'end
        GetNumQuestRewards=function()return 1 end;GetNumQuestChoices=function()return 2 end
        GetQuestItemInfoLootType=function(_,i)return i==1 and 0 or 1 end
        GetQuestItemInfo=function()return nil,nil,3,2,true,90001,4 end
        C_QuestOffer={GetQuestRewardCurrencyInfo=function()return {currencyID=55,totalRewardAmount=8}end}
        W.Event('ADDON_LOADED','FindAnUpgrade');N.Recorder:Enable(true);W.quest=6
        W.npcGuid='Creature-0-1-2-3-12345-0001';W.Event('QUEST_DETAIL')
        if CAPTURE_LIFECYCLE then
            W.Event('QUEST_ACCEPTED',6)
            W.Event('QUEST_TURNED_IN',6,123,456);W.Event('QUEST_TURNED_IN',6,123,456)
        end
        return N.ObservationData:Export()
    """).encode("utf-8")


class ObservationTests(unittest.TestCase):
    def setUp(self):
        self.payload = exported()
        self.data = O.load(self.payload)
        self.row = self.data["records"][0]

    def reject(self, data):
        with self.assertRaises(ValueError):
            O.load(json.dumps(data).encode())

    def test_real_lua_export_round_trips_unicode_empty_unknown_and_mixed_choices(self):
        self.assertIn("中", self.row["title"])
        rewards = self.row["rewards"]
        self.assertEqual(rewards["choices"]["slots"][1]["kind"], "currency")
        self.assertEqual(rewards["guaranteed"]["slots"][0]["quantity"], 3)
        self.assertEqual(rewards["xp"], {"state": "unknown"})
        self.assertEqual(rewards["otherRewards"], "unknown")

    def test_native_lifecycle_export_keeps_stages_counts_and_player_reward_values(self):
        data = O.load(exported(lifecycle=True))
        offered, accepted, turned_in = data["records"]
        self.assertEqual(
            [row["stage"] for row in data["records"]],
            ["offered", "accepted", "turned_in"],
        )
        self.assertEqual(accepted["source"], offered["source"])
        self.assertEqual(turned_in["source"], {"kind": "unknown", "role": "unknown"})
        self.assertEqual((accepted["samples"], turned_in["samples"]), (1, 2))
        for row in (accepted, turned_in):
            self.assertEqual(
                row["rewards"]["guaranteed"], {"state": "unknown", "slots": []}
            )
            self.assertEqual(
                row["rewards"]["choices"], {"state": "unknown", "slots": []}
            )
        self.assertEqual(turned_in["rewards"]["xp"], {"state": "ready", "value": 123})
        self.assertEqual(
            turned_in["rewards"]["money"], {"state": "ready", "value": 456}
        )

    def test_never_evaluates_lua_or_accepts_compressed_or_executable_formats(self):
        for source in (
            b"FindAnUpgradeObservations = {}",
            b"return os.execute('bad')",
            b"loadstring('bad')()",
            b"\x1f\x8banything",
        ):
            with self.subTest(source=source), self.assertRaises(ValueError):
                O.load(source)

    def test_unknown_privacy_fields_are_rejected_at_every_boundary(self):
        for path in (
            (),
            ("records", 0),
            ("records", 0, "context"),
            ("records", 0, "source"),
            ("records", 0, "client"),
            ("records", 0, "location"),
            ("records", 0, "rewards"),
            ("records", 0, "rewards", "guaranteed"),
            ("records", 0, "rewards", "guaranteed", "slots", 0),
        ):
            data = copy.deepcopy(self.data)
            target = data
            for part in path:
                target = target[part]
            target["playerGUID"] = "Player-private"
            self.reject(data)

    def test_duplicate_keys_bool_numbers_nonfinite_and_foreign_schemas_fail(self):
        with self.assertRaises(ValueError):
            O.load(self.payload.replace(b'"schema":1', b'"schema":1,"schema":1'))
        for path, value in (
            (["schema"], True),
            (["schema"], 2),
            (["dropped"], -1),
            (["records", 0, "questID"], True),
            (["records", 0, "questID"], 0),
            (["records", 0, "client", "interface"], 120001),
            (["records", 0, "client", "build"], 1.5),
            (["records", 0, "samples"], 1000001),
            (["records", 0, "title"], "\ud800"),
            (["records", 0, "title"], "|Hplayer:private|h"),
            (["records", 0, "title"], "x\nprivate"),
        ):
            data = copy.deepcopy(self.data)
            target = data
            for part in path[:-1]:
                target = target[part]
            target[path[-1]] = value
            self.reject(data)
        for number in (b"NaN", b"Infinity", b"-Infinity", b"1e999"):
            with self.assertRaises(ValueError):
                O.load(self.payload.replace(b'"dropped":0', b'"dropped":' + number))

    def test_incomplete_lists_false_empty_quantities_and_choice_counts_cannot_pass(
        self,
    ):
        for mutate in (
            lambda r: r["guaranteed"].update(state="unknown"),
            lambda r: r["guaranteed"].update(expected=0),
            lambda r: r["choices"].update(choose=2),
            lambda r: r["choices"]["slots"][1].update(slot=1),
            lambda r: r["guaranteed"]["slots"][0].update(quantity=0),
            lambda r: r["guaranteed"]["slots"][0].update(state="unknown"),
            lambda r: r["guaranteed"].update(state="partial"),
            lambda r: r.update(otherRewards="none"),
        ):
            data = copy.deepcopy(self.data)
            mutate(data["records"][0]["rewards"])
            self.reject(data)

    def test_unknown_missing_slot_is_valid_but_cannot_be_reported_ready(self):
        rewards = self.row["rewards"]
        rewards["choices"]["slots"][1] = {"slot": 2, "state": "unknown"}
        rewards["choices"]["state"] = "partial"
        O.load(json.dumps(self.data).encode())
        rewards["choices"]["state"] = "ready"
        self.reject(self.data)

    def test_observer_map_coordinates_never_become_npc_positions(self):
        self.row["location"].update(uiMapID=1429, x=0, y=1)
        O.load(json.dumps(self.data).encode())
        for mutation in (
            {"kind": "npc"},
            {"x": True},
            {"x": -1},
            {"x": float("inf")},
            {"x": None},
        ):
            data = copy.deepcopy(self.data)
            data["records"][0]["location"].update(mutation)
            self.reject(data)

    def test_limits_before_decoding_and_per_quest_variants_and_duplicates(self):
        for source in (b" " * (O.MAX_BYTES + 1), b"[" * 13 + b"]" * 13):
            with self.assertRaises(ValueError):
                O.load(source)
        self.data["records"] *= 2
        self.reject(self.data)
        self.data["records"] = []
        for index in range(13):
            row = copy.deepcopy(self.row)
            row["title"] = f"Variant {index}"
            self.data["records"].append(row)
        self.reject(self.data)

    def test_comparison_preserves_slots_quantities_and_published_player_scope(self):
        catalog = {
            "targetBuild": "1.60.1.70374",
            "quests": [
                {
                    "id": 6,
                    "title": self.row["title"],
                    "itemState": "published",
                    "items": [
                        {
                            "group": "guaranteed",
                            "slot": 1,
                            "itemID": 90001,
                            "quantity": 3,
                        },
                        {"group": "choice", "slot": 1, "itemID": 90001, "quantity": 3},
                    ],
                }
            ],
        }
        original = copy.deepcopy(catalog)
        report = O.compare(self.data, catalog)
        self.assertEqual(report["records"][0]["notes"], [])
        self.row["rewards"]["guaranteed"]["slots"][0]["quantity"] = 2
        report = O.compare(self.data, catalog)
        self.assertIn("player-visible", report["records"][0]["notes"][0])
        self.assertFalse(report["productionEligible"])
        self.assertEqual(catalog, original)

    def test_cli_reads_only_bounded_input_and_reports_digest_without_mutation(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as temporary:
            file = Path(temporary) / "submission.json"
            file.write_bytes(self.payload)
            output = io.StringIO()
            with contextlib.redirect_stdout(output), patch("subprocess.run") as process:
                O.main([str(file)])
                process.assert_not_called()
            self.assertFalse(json.loads(output.getvalue())["productionEligible"])
            self.assertEqual(file.read_bytes(), self.payload)
            file.write_bytes(b"{}")
            with (
                contextlib.redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit) as failure,
            ):
                O.main([str(file)])
            self.assertEqual(failure.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
