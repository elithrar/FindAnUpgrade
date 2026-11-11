"""Recorded attribution roles must not turn associated items into starters."""

import copy
import json
import unittest
from pathlib import Path

from fau_tools import questie as source
from tests.starter_coordinate_recovery_test import fixture

ROOT = Path(__file__).resolve().parents[1]


def records(quests, website=(), **kwargs):
    _, files = fixture(**kwargs)
    baked = source.Baked(files[source.TOC])
    enums = source.restriction_enums(files["src/corrections/enum/expansions.lua"])
    return source.starter_role_records(quests, baked, set(website), enums)


class StarterRoleDataTests(unittest.TestCase):
    def test_reciprocal_item_starter_survives_even_when_source_item_is_the_same(self):
        quests = [{"id": 900001, "locations": [{"itemID": 42}]}]
        changes, verified = records(
            quests,
            quest_fields={900001: {2: {3: [42]}, 11: 42}},
            item_fields={42: {5: 900001}},
        )
        self.assertEqual(changes, [])
        self.assertEqual(verified[0]["itemID"], 42)
        self.assertEqual(verified[0]["proof"]["startedBy"], [None, None, [42]])

    def test_item_starting_a_different_quest_keeps_the_supplied_item_role(self):
        location = {"itemID": 42, "name": "Letter", "faction": "Alliance"}
        quests = [{"id": 900001, "locations": [location, {"npcID": 11}]}]
        original = copy.deepcopy(quests)
        changes, verified = records(
            quests,
            quest_fields={900001: {2: [[11]], 11: 42}},
            item_fields={42: {5: 900002}},
        )
        row = changes[0]
        self.assertEqual(row["locations"], [{"npcID": 11}])
        self.assertEqual(row["relatedLocations"], [dict(location, role="provided")])
        self.assertEqual(
            row["proof"]["itemStartQuest"], [{"itemID": 42, "questID": 900002}]
        )
        self.assertEqual(verified, [])
        self.assertEqual(quests, original)

    def test_finisher_coordinates_do_not_transfer_to_the_proven_item_starter(self):
        old = {"npcID": 11, "name": "Recipient", "mapID": 1426, "x": 0.2, "y": 0.3}
        changes, verified = records(
            [{"id": 900001, "locations": [old]}],
            quest_fields={900001: {2: {3: [42]}, 3: [[11]]}},
            item_fields={42: {1: "Starting letter", 5: 900001}},
        )
        row = changes[0]
        self.assertEqual(row["relatedLocations"], [dict(old, role="finisher")])
        self.assertEqual(row["locations"], [{"itemID": 42, "name": "Starting letter"}])
        self.assertNotIn("mapID", row["starterProofs"][0]["location"])
        self.assertEqual(verified[0]["itemID"], 42)

    def test_missing_source_does_not_remove_npc_or_override_explicit_website_starter(
        self,
    ):
        old = [{"npcID": 11}, {"itemID": 42}, {"itemID": 43}]
        changes, _ = records(
            [{"id": 900002, "locations": old}],
            website={(900002, 42)},
            quest_fields={900001: {2: [[11]]}},
        )
        self.assertEqual(changes[0]["locations"], old[:2])
        self.assertEqual(
            changes[0]["relatedLocations"], [{"itemID": 43, "role": "unknown"}]
        )

    def test_incompatible_constraints_prevent_new_starter_and_keep_original_facts(self):
        old = {"npcID": 11}
        quest = {"id": 900001, "classTokens": ["MAGE"], "locations": [old]}
        changes, _ = records(
            [quest],
            quest_fields={900001: {2: [[12]], 3: [[11]], 7: 1}},
            npc_fields={12: {1: "Warrior giver", 10: [900001]}},
        )
        self.assertEqual(changes[0]["locations"], [])
        self.assertEqual(changes[0]["starterProofs"], [])
        self.assertEqual(quest["classTokens"], ["MAGE"])

    def test_finisher_table_presence_is_checked_independently_of_starter(self):
        _, files = fixture(quest_fields={900001: {2: {3: [42]}, 3: [[11]]}})
        baked = source.Baked(files[source.TOC])
        self.assertEqual(baked.field("Quest", 900001, 3), [[11]])
        baked.scalars[("Quest", 900001)]["p"] = 2
        with self.assertRaisesRegex(ValueError, "presence mismatch"):
            baked.field("Quest", 900001, 3)

    def test_review_ledger_conserves_every_old_fact_and_only_adds_proved_starters(self):
        data = json.loads((ROOT / "data/catalog-starter-roles.json").read_bytes())
        for row in data["records"]:
            related = [
                {k: v for k, v in point.items() if k != "role"}
                for point in row["relatedLocations"]
            ]
            additions = [entry["location"] for entry in row["starterProofs"]]
            for old in row["expectedLocations"]:
                self.assertIn(old, row["locations"] + related, row["id"])
            for location in row["locations"]:
                self.assertIn(location, row["expectedLocations"] + additions, row["id"])
            for point in row["relatedLocations"]:
                self.assertIn(point["role"], {"provided", "finisher", "unknown"})

    def test_unreviewed_baseline_cannot_be_given_the_old_catalog_receipt(self):
        with self.assertRaisesRegex(ValueError, "baseline"):
            source.starter_role_ledger(
                Path("not-a-cache"), b'{"schemaVersion":2,"quests":[]}', {}
            )
