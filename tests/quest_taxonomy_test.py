import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import quest_taxonomy as taxonomy  # noqa: E402 - local tools require the repository path above


class TaxonomyTest(unittest.TestCase):
    def setUp(self):
        (ROOT / ".work").mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.cache = Path(self.temp.name)
        self.primary = {"sources": []}

    def tearDown(self):
        self.temp.cleanup()

    def page(self, identity, tag=None, extra="", domain=16):
        record = {"id": identity, "name": "Dungeon in a title is no evidence"}
        if tag is not None:
            record["type"] = tag
        raw = (
            "WH.Gatherer.addData(5, "
            + str(domain)
            + ', {"'
            + str(identity)
            + '":{}});\n'
            "$.extend(g_quests["
            + str(identity)
            + "], "
            + json.dumps(record)
            + ");"
            + extra
        ).encode()
        (self.cache / (str(identity) + ".html")).write_bytes(raw)
        receipt = {
            "id": identity,
            "url": "https://www.wowhead.com/forever/quest=" + str(identity),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "bytes": len(raw),
        }
        self.primary["sources"] = [
            row for row in self.primary["sources"] if row["id"] != identity
        ] + [receipt]
        return receipt

    def test_owned_exact_tags_and_receipts(self):
        document = taxonomy.load(ROOT)
        self.assertEqual(len(document["records"]), 36)
        self.assertEqual(
            [row["id"] for row in document["records"] if row["tagID"] == 81],
            [6922, 8908, 8920, 8940, 8958, 9009, 9022],
        )
        self.assertEqual(len({row["id"] for row in document["records"]}), 36)

    def test_missing_is_unknown_and_dungeon_names_are_ignored(self):
        self.page(1)
        self.page(2, 81)
        result = taxonomy.acquire(self.cache, self.primary)
        self.assertEqual([(r["id"], r["tagID"]) for r in result["records"]], [(2, 81)])

    def test_group_and_raid_do_not_become_dungeon(self):
        for identity, tag in [(1, 1), (2, 62), (3, 81)]:
            self.page(identity, tag)
        self.assertEqual(
            [r["tagID"] for r in taxonomy.acquire(self.cache, self.primary)["records"]],
            [1, 62, 81],
        )

    def test_partial_cache_preserves_all_prior_ids(self):
        self.page(1, 81)
        previous = taxonomy.acquire(self.cache, self.primary)
        (self.cache / "1.html").unlink()
        self.page(2, 1)
        self.assertEqual(
            [
                r["id"]
                for r in taxonomy.acquire(self.cache, self.primary, previous)["records"]
            ],
            [1, 2],
        )

    def test_empty_cache_reparse_is_idempotent(self):
        self.page(1, 81)
        previous = taxonomy.acquire(self.cache, self.primary)
        (self.cache / "1.html").unlink()
        self.assertEqual(taxonomy.acquire(self.cache, self.primary, previous), previous)

    def test_changed_receipt_same_explicit_fact_can_be_reconfirmed(self):
        self.page(1, 81)
        previous = taxonomy.acquire(self.cache, self.primary)
        receipt = self.page(1, 81, "\n<!-- changed page chrome -->")
        result = taxonomy.acquire(self.cache, self.primary, previous)
        self.assertEqual(result["records"][0]["source"], receipt)

    def test_conflict_and_disappeared_explicit_type_require_review(self):
        self.page(1, 81)
        previous = taxonomy.acquire(self.cache, self.primary)
        for tag in [62, None]:
            self.page(1, tag)
            with self.assertRaises(ValueError):
                taxonomy.acquire(self.cache, self.primary, previous)

    def test_unread_stale_receipt_or_missing_owned_source_cannot_survive(self):
        self.page(1, 81)
        previous = taxonomy.acquire(self.cache, self.primary)
        (self.cache / "1.html").unlink()
        self.primary["sources"][0]["sha256"] = "0" * 64
        with self.assertRaises(ValueError):
            taxonomy.acquire(self.cache, self.primary, previous)

    def test_wrong_environment_mismatched_hash_and_unsupported_types_reject(self):
        for tag, domain in [(81, 4), (True, 16), ("81", 16), (0, 16), (999, 16)]:
            self.page(1, tag, domain=domain)
            with self.assertRaises(ValueError):
                taxonomy.acquire(self.cache, self.primary)
        self.page(1, 81)
        (self.cache / "1.html").write_bytes(b"tampered")
        with self.assertRaises(ValueError):
            taxonomy.acquire(self.cache, self.primary)

    def test_duplicate_object_and_duplicate_fact_reject(self):
        self.page(1, 81, '$.extend(g_quests[1], {"id":1,"type":81});')
        with self.assertRaises(ValueError):
            taxonomy.acquire(self.cache, self.primary)
        self.page(1, 81)
        document = taxonomy.acquire(self.cache, self.primary)
        document["records"].append(copy.deepcopy(document["records"][0]))
        with self.assertRaises(ValueError):
            taxonomy.validate(document, self.primary)

    def test_generator_emits_only_separate_exact_type_lookup(self):
        self.page(1, 81)
        output = taxonomy.render(taxonomy.acquire(self.cache, self.primary))
        self.assertEqual(output, "N.QuestTags = {\n    [1] = 81,\n}\n")
        self.assertNotIn("status", output)

    def test_schema_boolean_and_duplicate_primary_receipt_reject(self):
        self.page(1, 81)
        document = taxonomy.acquire(self.cache, self.primary)
        document["schemaVersion"] = True
        with self.assertRaises(ValueError):
            taxonomy.validate(document, self.primary)
        document["schemaVersion"] = 1
        self.primary["sources"].append(copy.deepcopy(self.primary["sources"][0]))
        with self.assertRaises(ValueError):
            taxonomy.validate(document, self.primary)


if __name__ == "__main__":
    unittest.main()
