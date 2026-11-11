"""Independent failures for role attribution and future source refreshes."""

import copy
import json
import unittest
from pathlib import Path

from fau_tools import starter_roles
from fau_tools.att import merge, parse

ROOT = Path(__file__).resolve().parents[1]


class StarterRolesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.document = json.loads(
            (ROOT / "data/catalog-starter-roles.json").read_bytes()
        )

    def authority(self):
        return starter_roles.reviewed(copy.deepcopy(self.document))

    def test_recipient_becomes_related_fact_without_losing_coordinates(self):
        authority = self.authority()
        entry = authority["records"][96294]
        row = {"id": 96294, "locations": copy.deepcopy(entry["expectedLocations"])}
        starter_roles.apply(row, authority)
        self.assertEqual(
            row["locations"],
            [{"itemID": 273658, "name": "Bloody Parchment (quest starter)"}],
        )
        recipient = row["relatedLocations"][0]
        self.assertEqual(
            (recipient["npcID"], recipient["role"], recipient["mapID"]),
            (259118, "finisher", 1412),
        )
        once = copy.deepcopy(row)
        starter_roles.apply(row, authority)
        self.assertEqual(row, once)

    def test_all_nine_replacement_starters_preserve_eligibility(self):
        authority = self.authority()
        additions = [
            entry
            for entry in authority["records"].values()
            if entry.get("starterProofs")
        ]
        self.assertEqual(len(additions), 9)
        for entry in additions:
            retained = entry["starterProofs"][0]["proof"]["retainedConstraints"]
            row = dict(
                copy.deepcopy(retained),
                id=entry["id"],
                locations=copy.deepcopy(entry["expectedLocations"]),
            )
            starter_roles.apply(row, authority)
            self.assertEqual(row["locations"], entry["locations"])
            self.assertEqual({key: row[key] for key in retained}, retained)
            self.assertFalse(any("mapID" in point for point in row["locations"]))
            changed = dict(row, faction="contradictory")
            with self.assertRaisesRegex(ValueError, "eligibility changed"):
                starter_roles.apply(changed, authority)

    def test_changed_locations_abort_instead_of_overwriting_source_drift(self):
        authority = self.authority()
        locations = copy.deepcopy(authority["records"][96294]["expectedLocations"])
        locations[0]["x"] = 0.75
        with self.assertRaisesRegex(ValueError, "source conflict"):
            starter_roles.apply({"id": 96294, "locations": locations}, authority)

    def test_forged_finisher_and_provided_roles_fail(self):
        for role in ("finisher", "provided"):
            doc = copy.deepcopy(self.document)
            entry = next(
                entry
                for entry in doc["records"]
                if any(p["role"] == role for p in entry["relatedLocations"])
            )
            if role == "finisher":
                entry["proof"]["finishedBy"] = []
            else:
                entry["proof"]["sourceItemId"] = None
            with self.assertRaises(ValueError):
                starter_roles.reviewed(doc)

    def test_verified_item_requires_both_typed_directions(self):
        for key, value in [("startedBy", [[123]]), ("reverseStartQuest", 123)]:
            doc = copy.deepcopy(self.document)
            doc["verifiedItemStarters"][0]["proof"][key] = value
            with self.assertRaises(ValueError):
                starter_roles.reviewed(doc)

    def test_new_unreviewed_item_provider_is_retained_but_not_a_starter(self):
        row = {
            "id": 990001,
            "locations": [
                {
                    "itemID": 999999,
                    "name": "Associated item",
                    "unfamiliarFact": "preserved",
                }
            ],
        }
        starter_roles.apply(row, self.authority())
        self.assertNotIn("locations", row)
        self.assertEqual(
            row["relatedLocations"],
            [
                {
                    "itemID": 999999,
                    "name": "Associated item",
                    "unfamiliarFact": "preserved",
                    "role": "unknown",
                }
            ],
        )

    def test_explicit_reviewed_website_item_starter_remains(self):
        location = {"itemID": 270301, "name": "Ve'han's Research Notes"}
        row = {"id": 93521, "locations": [location]}
        starter_roles.apply(row, self.authority(), {"locations": [location]})
        self.assertEqual(row["locations"], [location])
        self.assertNotIn("relatedLocations", row)

    def test_future_explicit_recipient_and_generic_npc_provider_do_not_start(self):
        text = """q(990001,{
            qg=123, -- Actual NPC (quest recipient)
            coord={20,30,MAP.ZONE},
            providers={{"n",456},{"i",789}},
        })"""
        rows, _ = parse(text, "fixture", {"MAP.ZONE": 1412}, include_empty=True)
        row = rows[0]
        self.assertTrue(
            any(
                p.get("npcID") == 123 and p["role"] == "finisher"
                for p in row["relatedLocations"]
            )
        )
        starter_roles.apply(row, self.authority())
        self.assertNotIn("locations", row)
        self.assertEqual(
            {starter_roles.entity(p) for p in row["relatedLocations"]},
            {("npcID", 123), ("npcID", 456), ("itemID", 789)},
        )

    def test_normal_declared_qg_is_not_demoted_by_generic_duplicate(self):
        rows, _ = parse(
            'q(990001,{qg=123,provider={"n",123}})', "fixture", {}, include_empty=True
        )
        starter_roles.apply(rows[0], self.authority())
        self.assertEqual(rows[0]["locations"], [{"npcID": 123}])
        self.assertNotIn("relatedLocations", rows[0])

    def test_same_pinned_recipient_and_provider_reparse_reconciles_idempotently(self):
        raw = """q(96294, { -- A Darker Truth
            provider = { "i", 273658 }, -- Bloody Parchment (quest starter)
            qg = 259118, -- Muln Earthfury (quest recipient)
            coord = { 33.4, 22.4, MAP.MULGORE },
            races = HORDE_ONLY,
            lvl = 23,
        })"""
        rows, _ = parse(raw, "fixture", {"MAP.MULGORE": 1412}, include_empty=True)
        row = next(row for row in rows if row["id"] == 96294)
        authority = self.authority()
        self.assertEqual(len(row["relatedLocations"]), 2)
        starter_roles.apply(row, authority)
        entry = authority["records"][96294]
        self.assertEqual(row["locations"], entry["locations"])
        self.assertEqual(row["relatedLocations"], entry["relatedLocations"])

    def test_related_facts_survive_exact_id_source_merge(self):
        a = {
            "id": 9,
            "items": [],
            "sources": [],
            "relatedLocations": [{"itemID": 123, "role": "unknown"}],
        }
        b = {
            "id": 9,
            "items": [],
            "sources": [],
            "relatedLocations": [{"npcID": 456, "role": "finisher"}],
        }
        self.assertEqual(len(merge(a, b)["relatedLocations"]), 2)

    def test_supplied_midsummer_items_with_reciprocal_proof_remain_starters(self):
        authority = self.authority()
        for identity, item, name in [
            (9324, 23179, "Flame of Orgrimmar"),
            (9325, 23180, "Flame of Thunder Bluff"),
            (9326, 23181, "Flame of the Undercity"),
            (9330, 23182, "Flame of Stormwind"),
            (9331, 23183, "Flame of Ironforge"),
            (9332, 23184, "Flame of Darnassus"),
        ]:
            raw = f'q({identity},{{\nprovider={{"i",{item}}}, -- {name} (Provided)\n}})'
            rows, _ = parse(raw, "fixture", {}, include_empty=True)
            row = rows[0]
            self.assertEqual(row["relatedLocations"][0]["role"], "provided")
            starter_roles.apply(row, authority)
            self.assertEqual(row["locations"][0]["itemID"], item)
            self.assertEqual(row["relatedLocations"][0]["role"], "provided")
