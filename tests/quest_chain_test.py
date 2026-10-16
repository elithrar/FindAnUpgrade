"""Adversarial chain-source boundaries and exact final-composition semantics."""

import hashlib
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import quest_chains as chains  # noqa: E402 - local tools require the repository path above
import questie_metadata as provider  # noqa: E402 - local tools require the repository path above
from complete_catalog import build_complete, read_inputs  # noqa: E402 - local tools require the repository path above


def import_fixture(fields, authored="", dynamic="", quests=None, extra_files=None):
    raw = (
        "function ForeverQuestFixes:Load() return {"
        + authored
        + "} end\nfunction ForeverQuestFixes:LoadDynamic() return {"
        + dynamic
        + "} end\n"
    ).encode()

    class Baked:
        def field(self, entity, identity, index):
            return fields.get(identity, {}).get(index)

    files = {provider.TOC: b"fixture"}
    files.update(extra_files or {})
    with (
        patch.object(chains, "AUTHORED_BLOB", chains.blob(raw)),
        patch.object(provider, "Baked", return_value=Baked()),
    ):
        return chains.import_chains(
            {"files": []},
            files,
            raw,
            quests or [{"id": id, "confirmation": "published"} for id in range(1, 8)],
        )


class QuestChainTests(unittest.TestCase):
    def test_single_precedence_preserves_any_and_never_combines_unrelated_group(self):
        result = import_fixture(
            {1: {12: [2, 3], 13: [4, 5]}},
            "[1]={[questKeys.preQuestSingle]={4,5},[questKeys.preQuestGroup]={2,3}},",
        )
        self.assertEqual(
            result["records"][0]["chain"]["groups"],
            [{"kind": "any", "ids": [4, 5], "verified": True}],
        )

    def test_negative_group_ids_preserve_literal_completion_instead_of_alternates(self):
        result = import_fixture(
            {1: {12: [-2, 3]}}, "[1]={[questKeys.preQuestGroup]={-2,3}},"
        )
        self.assertEqual(
            result["records"][0]["chain"]["groups"],
            [{"kind": "all", "ids": [2, 3], "verified": True, "noAlternates": [2]}],
        )

    def test_final_mismatch_add_only_and_inherited_group_remain_unverified(self):
        for authored in (
            "[1]={[questKeys.preQuestSingle]={2}},",
            "[1]={[questKeys.preQuestSingle_add]={3}},",
            "",
        ):
            result = import_fixture({1: {13: [2, 3]}}, authored)
            self.assertFalse(result["records"][0]["chain"]["groups"][0]["verified"])

    def test_dynamic_expressions_withhold_hardness_without_executing_lua(self):
        authored = "[1]={[questKeys.preQuestSingle]={2}},"
        dynamic = (
            "[1]={[questKeys.preQuestSingle]=getCharacterDependentRequirements()},"
        )
        result = import_fixture({1: {13: [2]}}, authored, dynamic)
        self.assertFalse(result["records"][0]["chain"]["groups"][0]["verified"])
        result = import_fixture(
            {1: {13: [2]}},
            authored,
            extra_files={
                "src/corrections/Forever/legacy/classicQuestFixes.lua": b"return {[1]={[questKeys.parentQuest]=character()}}"
            },
        )
        self.assertFalse(result["records"][0]["chain"]["groups"][0]["verified"])

    def test_malformed_self_duplicate_and_unknown_id_are_not_hard_gates(self):
        for value in ([1, 2], [2, 2], [0, 2], ["2"], [-2]):
            result = import_fixture({1: {13: value}})
            self.assertEqual(result["records"], [])
            self.assertEqual(result["omissions"][0]["value"], value)
        result = import_fixture(
            {1: {13: [900]}}, "[1]={[questKeys.preQuestSingle]={900}},"
        )
        self.assertFalse(result["records"][0]["chain"]["groups"][0]["verified"])

    def test_historical_identity_and_optional_relations_retain_exact_kinds(self):
        fields = {
            1: {13: [2], 16: [3], 22: 4, 25: 5, 27: 6, 28: [7], 33: 4, 34: 5, 36: 3}
        }
        authored = "[1]={[questKeys.preQuestSingle]={2},[questKeys.exclusiveTo]={3},[questKeys.nextQuestInChain]=4,[questKeys.parentQuest]=5,[questKeys.breadcrumbForQuestId]=6,[questKeys.breadcrumbs]={7},[questKeys.availableUntilCompleted]=4,[questKeys.availableStartingWith]=5,[questKeys.disabledByQuest]=3},"
        result = import_fixture(
            fields,
            authored,
            quests=[
                {"id": i, "confirmation": "historical" if i == 1 else "published"}
                for i in range(1, 8)
            ],
        )
        row = result["records"][0]
        self.assertFalse(row["chain"]["groups"][0]["verified"])
        self.assertEqual(
            {r["kind"] for r in row["chain"]["relations"]},
            {
                "exclusive",
                "supersededBy",
                "requiresActive",
                "breadcrumb",
                "optionalPrerequisite",
                "untilCompleted",
                "startingWith",
                "disabledWhileActive",
            },
        )
        self.assertTrue(all(not r["verified"] for r in row["chain"]["relations"]))

    def test_att_thresholds_preserve_count_without_promoting_to_verified(self):
        result = import_fixture(
            {},
            quests=[
                {
                    "id": 1,
                    "confirmation": "published",
                    "prerequisites": [2, 3, 4],
                    "prerequisiteCount": 2,
                }
            ],
        )
        self.assertEqual(
            result["records"][0]["chain"]["groups"],
            [{"kind": "count", "ids": [2, 3, 4], "count": 2, "verified": False}],
        )

    def test_changed_authored_source_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unreviewed"):
            chains.import_chains({"files": []}, {}, b"not pinned", [])

    def test_verified_optional_breadcrumb_overrides_weaker_mandatory_fallback_with_receipt(
        self,
    ):
        quests = [
            {"id": 1, "confirmation": "published", "prerequisites": [2, 3]},
            {"id": 2, "confirmation": "published"},
            {"id": 3, "confirmation": "published"},
        ]
        result = import_fixture(
            {1: {28: [2]}, 2: {27: 1}},
            "[1]={[questKeys.breadcrumbs]={2}},[2]={[questKeys.breadcrumbForQuestId]=1},",
            quests=quests,
        )
        record = result["records"][0]
        self.assertEqual(
            record["chain"]["groups"], [{"kind": "all", "ids": [3], "verified": False}]
        )
        override = next(
            proof
            for proof in record["evidence"]
            if proof["basis"] == "verified-optional-overrides-att-mandatory"
        )
        self.assertEqual(override["originalGroup"]["ids"], [2, 3])
        self.assertEqual(override["overriddenIDs"], [2])
        self.assertEqual(
            override["optionalProofs"],
            [{"ownerID": 2, "field": "breadcrumbForQuestId"}],
        )
        self.assertIn(
            {"kind": "optionalPrerequisite", "id": 2, "verified": True},
            record["chain"]["relations"],
        )

    def test_optional_member_does_not_invent_adjusted_any_or_count_threshold(self):
        quests = [
            {
                "id": 1,
                "confirmation": "published",
                "prerequisites": [2, 3],
                "prerequisiteCount": 1,
            },
            {"id": 2, "confirmation": "published"},
            {"id": 3, "confirmation": "published"},
        ]
        result = import_fixture(
            {2: {27: 1}}, "[2]={[questKeys.breadcrumbForQuestId]=1},", quests=quests
        )
        record = result["records"][0]
        self.assertEqual(record["chain"]["groups"], [])
        self.assertIn(
            {"kind": "related", "id": 3, "verified": False},
            record["chain"]["relations"],
        )
        result = import_fixture({2: {27: 1}}, quests=quests)
        self.assertEqual(result["records"][0]["chain"]["groups"][0]["count"], 1)

    def test_frozen_evidence_coverage_is_exact_and_classification_rewards_unchanged(
        self,
    ):
        document = json.loads((ROOT / "data/catalog-chain-records.json").read_bytes())
        self.assertEqual(document["coverage"]["records"], len(document["records"]))
        self.assertEqual(
            document["coverage"]["verifiedGroups"],
            sum(
                g["verified"] for r in document["records"] for g in r["chain"]["groups"]
            ),
        )
        self.assertEqual(
            document["coverage"]["verifiedRelations"],
            sum(
                g["verified"]
                for r in document["records"]
                for g in r["chain"]["relations"]
            ),
        )
        self.assertEqual(
            document["source"]["authored"]["gitBlob"], chains.AUTHORED_BLOB
        )
        temple = next(r for r in document["records"] if r["id"] == 2519)
        self.assertEqual(temple["chain"]["groups"], [])
        self.assertTrue(
            any(
                p["basis"] == "verified-optional-overrides-att-mandatory"
                and p["overriddenIDs"] == [98391]
                for p in temple["evidence"]
            )
        )
        provenance, inputs = read_inputs(ROOT)
        self.assertEqual(
            provenance["inputs"]["chains"]["sha256"],
            hashlib.sha256(
                (ROOT / "data/catalog-chain-records.json").read_bytes()
            ).hexdigest(),
        )
        full, _ = build_complete(ROOT)
        base, _ = build_complete(ROOT, include_chains=False)
        self.assertEqual(
            [{k: v for k, v in r.items() if k != "chain"} for r in full["quests"]],
            base["quests"],
        )
        self.assertEqual(
            {r["id"] for r in inputs["chains"]["records"]},
            {r["id"] for r in full["quests"] if "chain" in r},
        )


if __name__ == "__main__":
    unittest.main()
