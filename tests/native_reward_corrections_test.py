"""Native reward authority, exact provenance and non-destructive overlay checks."""

import copy
import hashlib
import json
import unittest
from pathlib import Path

from fau_tools.catalog import apply_reviewed_update, reviewed_updates
from fau_tools.native_rewards import (
    SOURCE_SCOPE,
    overlay,
    reviewed_native_rewards,
    verify_native_source,
)

ROOT = Path(__file__).resolve().parents[1]


def item(identity, name, group="guaranteed", slot=1, quantity=1):
    return {
        "itemID": identity,
        "name": name,
        "quantity": quantity,
        "group": group,
        "slot": slot,
    }


def fixture():
    first = item(501, "Recorded shield")
    choice = item(502, "Observed helm", "choice")
    record = {
        "id": 101,
        "name": "Exact quest",
        "sourceBuild": 70862,
        "observedAt": "2026-11-09T03:59:29+00:00",
        "payloadSha256": "a" * 64,
        "guaranteed": [{"id": 501, "name": "Recorded shield", "quantity": 1}],
        "choice": [{"id": 502, "name": "Observed helm", "quantity": 1}],
        "unknownSourceField": {"preserved": True},
    }
    raw = json.dumps(
        {"schemaVersion": 1, "rewardScope": SOURCE_SCOPE, "quests": [record]}
    ).encode()
    update = {
        "id": 101,
        "title": "Exact quest",
        "expected": {
            "items": [first],
            "itemState": "published",
            "itemGroupStates": None,
        },
        "changes": {
            "items": [first, choice],
            "itemState": "published",
            "itemGroupStates": {"guaranteed": "published", "choice": "published"},
        },
        "evidence": ["native"],
        "reason": "Literal additional native choice slot.",
        "nativeObservation": {
            "source": "native",
            "build": 70862,
            "observedAt": record["observedAt"],
            "payloadSha256": record["payloadSha256"],
        },
        "nativeRecord": record,
        "replacements": [],
        "priorSource": None,
    }
    document = {
        "sources": {
            "native": {
                "url": "https://quests.questionable.services/native-quests.json",
                "sha256": hashlib.sha256(raw).hexdigest(),
                "bytes": len(raw),
                "collectedAt": "2026-11-11T04:01:00+00:00",
            }
        },
        "nativeRewardUpdates": [update],
    }
    public = {
        "records": [
            {
                "id": 101,
                "source": {
                    "url": "https://www.forevervsclassic.com/quests/101",
                    "sha256": "b" * 64,
                    "bytes": 123,
                },
                "items": [first],
            }
        ]
    }
    return document, public, raw


def snapshot_fixture(metadata=False):
    document, public, _ = fixture()
    update = document["nativeRewardUpdates"][0]
    record = update["nativeRecord"]
    record.pop("observedAt")
    snapshot = {
        "schemaVersion": 1,
        "build": 70888,
        "observedAt": "2026-11-12T04:06:50+00:00",
        "rewardScope": SOURCE_SCOPE,
    }
    update["nativeSnapshot"] = snapshot
    update["nativeObservation"]["observedAt"] = snapshot["observedAt"]
    if metadata:
        record.update(level=60, requiredLevel=57)
        update["expected"] = {"title": None, "level": None, "minimum": None}
        update["changes"] = {"title": "Exact quest", "level": 60, "minimum": 57}
        update.pop("replacements")
        update.pop("priorSource")
        document.update(
            schemaVersion=1,
            revision="quest-website-2026-11-12",
            records=[update],
            nativeRewardUpdates=[],
        )
    raw = json.dumps({**snapshot, "quests": [record]}).encode()
    document["sources"]["native"].update(
        sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw)
    )
    return document, public, raw, update


class NativeRewardCorrectionsTests(unittest.TestCase):
    def test_absent_row_time_uses_only_the_bound_source_snapshot(self):
        document, public, raw, update = snapshot_fixture()
        self.assertNotIn("observedAt", update["nativeRecord"])
        self.assertIn(101, reviewed_native_rewards(document, public))
        verify_native_source(document, "native", raw)
        changed = copy.deepcopy(document)
        changed["nativeRewardUpdates"][0].pop("nativeSnapshot")
        with self.assertRaises(ValueError):
            reviewed_native_rewards(changed, public)
        for value in (None, "", "bad-time", "2026-11-08T00:00:00+00:00"):
            changed = copy.deepcopy(document)
            changed["nativeRewardUpdates"][0]["nativeRecord"]["observedAt"] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                reviewed_native_rewards(changed, public)
        existing, _, _ = fixture()
        existing["nativeRewardUpdates"][0]["nativeSnapshot"] = copy.deepcopy(
            update["nativeSnapshot"]
        )
        with self.assertRaises(ValueError):
            reviewed_native_rewards(existing, public)

    def test_snapshot_envelope_forgery_is_rejected_against_original_bytes(self):
        document, public, raw, _ = snapshot_fixture()
        for key, value in (
            ("build", 70999),
            ("observedAt", "2026-11-13T00:00:00+00:00"),
            ("schemaVersion", 2),
            ("rewardScope", "A different reward contract"),
        ):
            changed = copy.deepcopy(document)
            update = changed["nativeRewardUpdates"][0]
            update["nativeSnapshot"][key] = value
            if key == "observedAt":
                update["nativeObservation"]["observedAt"] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_native_source(changed, "native", raw)
        for key, value in (
            ("build", 0),
            ("schemaVersion", True),
            ("rewardScope", "Different contract"),
        ):
            changed = copy.deepcopy(document)
            changed["nativeRewardUpdates"][0]["nativeSnapshot"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                reviewed_native_rewards(changed, public)

    def test_metadata_rows_share_full_record_and_snapshot_acquisition_binding(self):
        document, _, raw, update = snapshot_fixture(metadata=True)
        verify_native_source(document, "native", raw)
        self.assertIn(101, reviewed_updates(document))
        for mutation in ("name", "level", "requiredLevel", "unknownSourceField"):
            changed = copy.deepcopy(document)
            row = changed["records"][0]["nativeRecord"]
            row[mutation] = (
                {}
                if mutation == "unknownSourceField"
                else "Different"
                if mutation == "name"
                else 58
            )
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                verify_native_source(changed, "native", raw)
        changed = copy.deepcopy(document)
        changed["records"][0]["nativeSnapshot"]["build"] += 1
        with self.assertRaises(ValueError):
            verify_native_source(changed, "native", raw)
        changed = copy.deepcopy(document)
        changed["records"][0]["changes"]["minimum"] = 58
        with self.assertRaises(ValueError):
            reviewed_updates(changed)
        renamed = copy.deepcopy(document)
        renamed["records"][0]["expected"] = {"title": "Old exact quest name"}
        renamed["records"][0]["changes"] = {"title": "Exact quest"}
        renamed["records"][0]["title"] = "Old exact quest name"
        self.assertIn(101, reviewed_updates(renamed))

    def test_positive_groups_preserve_unknown_source_fields_and_other_facts(self):
        document, public, raw = fixture()
        verify_native_source(document, "native", raw)
        updates = reviewed_native_rewards(document, public)
        row = {
            "id": 101,
            "title": "Exact quest",
            **copy.deepcopy(document["nativeRewardUpdates"][0]["expected"]),
            "confirmation": "unconfirmed",
            "moneyCost": 500000,
            "faction": "Horde",
            "locations": [{"npcID": 123}],
        }
        apply_reviewed_update(row, updates[101])
        self.assertEqual([x["itemID"] for x in row["items"]], [501, 502])
        self.assertEqual(row["confirmation"], "unconfirmed")
        self.assertEqual(row["moneyCost"], 500000)
        self.assertEqual(row["faction"], "Horde")
        self.assertEqual(row["locations"], [{"npcID": 123}])
        self.assertEqual(
            updates[101]["nativeRecord"]["unknownSourceField"], {"preserved": True}
        )
        apply_reviewed_update(row, updates[101])
        self.assertEqual(len(row["items"]), 2)

    def test_nonempty_native_group_does_not_delete_scripted_or_other_group_rewards(
        self,
    ):
        document, _, _ = fixture()
        update = document["nativeRewardUpdates"][0]
        old = {
            "items": [
                item(900, "Separately recorded rune"),
                item(501, "Recorded shield", slot=2),
                item(502, "Observed helm", "choice"),
            ],
            "itemState": "published",
            "itemGroupStates": None,
        }
        record = copy.deepcopy(update["nativeRecord"])
        record["choice"] = []
        result = overlay(old, record, [])
        self.assertEqual(
            [(x["itemID"], x["group"]) for x in result["items"]],
            [(501, "guaranteed"), (900, "guaranteed"), (502, "choice")],
        )

    def test_positive_choice_moves_identity_without_asserting_empty_guaranteed(self):
        old = {
            "items": [item(501, "Recorded shield")],
            "itemState": "published",
            "itemGroupStates": None,
        }
        record = {
            "guaranteed": [],
            "choice": [
                {"id": 501, "name": "Recorded shield", "quantity": 1},
                {"id": 502, "name": "Observed helm", "quantity": 1},
            ],
        }
        result = overlay(old, record, [])
        self.assertEqual(
            result["items"],
            [
                item(501, "Recorded shield", "choice"),
                item(502, "Observed helm", "choice", 2),
            ],
        )
        self.assertEqual(
            result["itemGroupStates"], {"guaranteed": "unknown", "choice": "published"}
        )

    def test_literal_replacement_requires_prior_receipt_and_exact_observed_slot(self):
        document, public, _ = fixture()
        update = document["nativeRewardUpdates"][0]
        update["nativeRecord"]["guaranteed"][0] = {
            "id": 601,
            "name": "New potion",
            "quantity": 1,
        }
        observed = item(601, "New potion")
        update["replacements"] = [
            {"expected": item(501, "Recorded shield"), "observed": observed}
        ]
        update["priorSource"] = copy.deepcopy(public["records"][0]["source"])
        update["changes"]["items"][0] = observed
        self.assertIn(101, reviewed_native_rewards(document, public))
        for mutate in [
            lambda u: u.update(priorSource=None),
            lambda u: u["priorSource"].update(sha256="c" * 64),
            lambda u: u["replacements"][0]["observed"].update(slot=2),
            lambda u: u["replacements"][0]["expected"].update(itemID=999),
        ]:
            with self.subTest(mutate=mutate):
                changed = copy.deepcopy(document)
                mutate(changed["nativeRewardUpdates"][0])
                with self.assertRaises(ValueError):
                    reviewed_native_rewards(changed, public)

        adopted = copy.deepcopy(public)
        adopted["records"][0].update(
            items=copy.deepcopy(update["changes"]["items"]),
            itemState="published",
            source={
                "url": public["records"][0]["source"]["url"],
                "sha256": "c" * 64,
                "bytes": 456,
            },
        )
        self.assertIn(101, reviewed_native_rewards(document, adopted))
        adopted["records"][0]["items"][0]["quantity"] = 2
        with self.assertRaises(ValueError):
            reviewed_native_rewards(document, adopted)

    def test_quantity_change_is_explicit_and_cannot_hide_unrelated_removal(self):
        old = {
            "items": [item(501, "Recorded shield", quantity=200)],
            "itemState": "published",
            "itemGroupStates": None,
        }
        record = {
            "guaranteed": [{"id": 501, "name": "Recorded shield", "quantity": 1}],
            "choice": [],
        }
        with self.assertRaises(ValueError):
            overlay(old, record, [])
        replacement = {
            "expected": old["items"][0],
            "observed": item(501, "Recorded shield"),
        }
        self.assertEqual(
            overlay(old, record, [replacement])["items"], [item(501, "Recorded shield")]
        )
        document, public, _ = fixture()
        document["nativeRewardUpdates"][0]["changes"]["items"] = [
            item(502, "Observed helm", "choice")
        ]
        with self.assertRaises(ValueError):
            reviewed_native_rewards(document, public)

    def test_rejects_wrong_payload_identity_receipt_duplicates_and_extra_authority(
        self,
    ):
        document, public, _ = fixture()
        mutations = [
            lambda u: u["nativeRecord"].update(id=102),
            lambda u: u["nativeRecord"].update(name="Different quest"),
            lambda u: u["nativeRecord"].update(payloadSha256="c" * 64),
            lambda u: u["nativeObservation"].update(build=70888),
            lambda u: u["nativeObservation"].update(source="unreceipted"),
            lambda u: u["nativeRecord"]["choice"].append(
                {"id": 501, "name": "Repeated identity", "quantity": 1}
            ),
            lambda u: u["changes"].update(moneyCost=0),
            lambda u: u["changes"]["items"][0].update(slot=2),
            lambda u: u["changes"]["items"].append(
                item(999, "Inferred reward", "choice", 2)
            ),
        ]
        for mutate in mutations:
            changed = copy.deepcopy(document)
            mutate(changed["nativeRewardUpdates"][0])
            with self.subTest(mutate=mutate), self.assertRaises(ValueError):
                reviewed_native_rewards(changed, public)
        changed = copy.deepcopy(document)
        changed["nativeRewardUpdates"].append(
            copy.deepcopy(changed["nativeRewardUpdates"][0])
        )
        with self.assertRaises(ValueError):
            reviewed_native_rewards(changed, public)
        for key, value in [
            ("url", "https://example.com/native-quests.json"),
            ("sha256", "bad"),
            ("bytes", 0),
            ("collectedAt", "2026-11-11"),
        ]:
            changed = copy.deepcopy(document)
            changed["sources"]["native"][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                reviewed_native_rewards(changed, public)

    def test_raw_source_bytes_and_unknown_fields_are_bound(self):
        document, _, raw = fixture()
        with self.assertRaises(ValueError):
            verify_native_source(document, "native", raw + b" ")
        changed = copy.deepcopy(document)
        changed["nativeRewardUpdates"][0]["nativeRecord"]["unknownSourceField"] = {}
        with self.assertRaises(ValueError):
            verify_native_source(changed, "native", raw)

    def test_source_drift_aborts_instead_of_overwriting(self):
        document, public, _ = fixture()
        update = reviewed_native_rewards(document, public)[101]
        row = {"id": 101, "title": "Exact quest", **copy.deepcopy(update["expected"])}
        row["items"][0]["quantity"] = 2
        with self.assertRaises(ValueError):
            apply_reviewed_update(row, update)

    def test_owned_corrections_have_the_expected_observed_facts(self):
        document = json.loads(
            (ROOT / "data/catalog-reviewed-updates.json").read_bytes()
        )
        public = json.loads((ROOT / "data/catalog-public-records.json").read_bytes())
        updates = reviewed_native_rewards(document, public)
        self.assertEqual(
            updates[17]["changes"]["items"],
            [item(250947, "Greater Mender's Potion", quantity=5)],
        )
        self.assertEqual(
            updates[2202]["changes"]["items"],
            [item(250947, "Greater Mender's Potion", quantity=5)],
        )
        self.assertEqual(
            updates[8249]["changes"]["items"], [item(20086, "Dusksteel Throwing Knife")]
        )
        self.assertEqual(
            updates[2846]["changes"]["items"],
            [
                item(9527, "Spellshifter Rod"),
                item(9531, "Gemshale Pauldrons", "choice"),
                item(270098, "Dank Shoulderpads", "choice", 2),
            ],
        )
        self.assertEqual(
            {
                x["itemID"]
                for x in updates[79442]["changes"]["items"]
                if x["group"] == "guaranteed"
            },
            {213086, 280696},
        )
        self.assertEqual(
            updates[5282]["changes"]["items"][0]["name"], "Testament of Hope"
        )
        self.assertEqual(
            updates[8224]["changes"]["items"][0]["name"],
            "High Test Eternium Fishing Line",
        )
        self.assertNotIn(78307, updates)
        self.assertNotIn(78699, updates)


if __name__ == "__main__":
    unittest.main()
