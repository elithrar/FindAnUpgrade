"""Regress source-boundary failures found during independent recovery review."""

import tempfile
import unittest
from pathlib import Path
from unittest import mock

from fau_tools import catalog as catalog
from fau_tools import sync as sync

ROOT = Path(__file__).resolve().parents[1]


class RecoveryIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "data").mkdir()
        (self.root / "data/primary-statuses.json").write_text(
            '{"quests": []}', encoding="utf-8"
        )
        self.public = {
            "id": 9,
            "title": "Exact quest",
            "level": 20,
            "minimum": 10,
            "confirmation": "published",
            "itemState": "published-empty",
            "items": [],
        }
        self.inputs = {
            "public": {
                "records": [self.public],
                "collectedAt": "2026-10-15",
                "expected": 1,
            },
            "metadata": {
                "records": [
                    {"id": 9, "locations": [{"npcID": 11, "faction": "Alliance"}]}
                ],
                "conflicts": [],
                "omissions": [],
            },
            "compiled": {
                "questIDs": [9],
                "metadata": [],
                "constraints": [],
                "constraintConflicts": [],
                "npcPositions": [],
            },
            "primary": {"records": []},
            "client": {"questIDs": []},
            "legacy": {"quests": []},
        }

    def build(self):
        with mock.patch.object(
            catalog,
            "read_inputs",
            return_value=({"targetBuild": "1.60.1.70374"}, self.inputs),
        ):
            return catalog.build_complete(self.root)

    def test_attached_primary_point_survives_without_supplement_and_keeps_faction(self):
        self.inputs["primary"]["records"] = [
            {
                "id": 9,
                "items": [],
                "locations": [{"npcID": 11, "mapID": 1426, "x": 0.2, "y": 0.3}],
            }
        ]
        source, _ = self.build()
        self.assertEqual(
            source["quests"][0]["locations"],
            [{"npcID": 11, "faction": "Alliance", "mapID": 1426, "x": 0.2, "y": 0.3}],
        )

    def test_supplemental_constraints_cannot_relax_known_class_or_race(self):
        row = {
            "id": 9,
            "confirmation": "published",
            "classTokens": ["PRIEST"],
            "races": [8],
            "locations": [],
        }
        catalog.merge_supplemental(
            row,
            {
                "constraints": {"classTokens": ["MAGE"], "races": [8, 2]},
                "locations": [{"npcID": 11}],
            },
            [],
        )
        self.assertTrue(row["eligibilityConflict"])
        self.assertEqual(row["classTokens"], ["PRIEST"])
        self.assertEqual(row["races"], [8])

    def test_changed_frame_global_position_is_withheld_without_deleting_starter(self):
        self.inputs["compiled"]["npcPositions"] = [
            {"npcID": 11, "locations": [{"mapID": 1412, "x": 0.2, "y": 0.3}]}
        ]
        source, report = self.build()
        row = source["quests"][0]
        self.assertEqual(row["locations"], [{"npcID": 11, "faction": "Alliance"}])
        self.assertEqual(row["fieldStates"]["coordinates"], "unknown")
        self.assertEqual(report["withheldGlobalPositions"][0]["mapID"], 1412)

    def test_explicit_quest_point_is_separate_from_uncertain_global_projection(self):
        self.inputs["metadata"]["records"][0]["locations"][0].update(
            mapID=1412, x=0.4, y=0.5
        )
        self.inputs["compiled"]["npcPositions"] = [
            {"npcID": 11, "locations": [{"mapID": 1412, "x": 0.2, "y": 0.3}]}
        ]
        source, report = self.build()
        self.assertEqual(source["quests"][0]["locations"][0]["x"], 0.4)
        self.assertFalse(report["withheldGlobalPositions"])

    def test_entity_namespaces_do_not_create_a_new_npc_starter(self):
        row = {"id": 9, "confirmation": "published", "locations": [{"objectID": 11}]}
        disagreements = []
        catalog.merge_supplemental(
            row,
            {"locations": [{"npcID": 11, "mapID": 1426, "x": 0.2, "y": 0.3}]},
            disagreements,
        )
        self.assertEqual(row["locations"], [{"objectID": 11}])
        self.assertTrue(disagreements)

    def test_money_cost_remains_separate_from_unknown_reward(self):
        self.public["moneyCost"] = 10000
        source, report = self.build()
        row = source["quests"][0]
        self.assertEqual(row["moneyCost"], 10000)
        self.assertNotIn("money", row.get("rewardValues", {}))
        self.assertEqual(row["fieldStates"]["money"], "unknown")
        self.assertEqual(
            report["missingFields"][0]["causes"]["money"],
            "published-payment-cost-is-not-a-reward",
        )

    def test_repeated_reputation_observations_are_reported_without_summing(self):
        self.public["reputation"] = [
            {"name": "Stormwind", "amount": 200},
            {"name": "Stormwind", "amount": 400},
        ]
        source, report = self.build()
        self.assertEqual(
            source["quests"][0]["rewardValues"]["reputation"], self.public["reputation"]
        )
        self.assertEqual(
            report["ambiguousPublishedReputation"][0]["amounts"], [200, 400]
        )

    def test_concurrent_frozen_input_edit_blocks_all_replacement(self):
        stage = self.root / "stage"
        baseline = {}
        for name in sync.OUTPUTS:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"before")
            candidate = stage / name
            candidate.parent.mkdir(parents=True, exist_ok=True)
            candidate.write_bytes(b"after")
            baseline[name] = sync.sha(target)
        frozen = self.root / "data/classification-source.json"
        frozen.write_bytes(b"original")
        inputs = {"data/classification-source.json": sync.sha(frozen)}
        frozen.write_bytes(b"concurrent edit")
        with self.assertRaisesRegex(ValueError, "Concurrent frozen input"):
            sync.apply_candidate(self.root, stage, baseline, inputs)
        self.assertTrue(
            all((self.root / name).read_bytes() == b"before" for name in sync.OUTPUTS)
        )


if __name__ == "__main__":
    unittest.main()
