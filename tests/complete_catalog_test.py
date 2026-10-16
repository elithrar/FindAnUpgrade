"""Whole-inventory reconciliation and independent failure inputs for public facts."""

import copy
import json
import struct
import tempfile
import unittest
from pathlib import Path

from fau_tools.att import merge, parse
from fau_tools.catalog import build_complete, read_inputs, validate_complete
from fau_tools.html import quest_detail, quest_index
from fau_tools.importer import native_ids

ROOT = Path(__file__).resolve().parents[1]


def page(body="", quest=9, extra="", label="Forever"):
    return (
        '<html><body><a href="https://www.wowhead.com/forever/quest='
        + str(quest)
        + '">Quest</a>'
        + extra
        + '<section><div class="label">'
        + label
        + '</div><div class="wow-tt"><div class="font-semibold">Exact quest</div><div>Level 20</div>'
        + body
        + "</div></section></body></html>"
    )


def item(group="You will receive:", domain="forever", quantity=""):
    return (
        "<div><div>"
        + group
        + '</div><div><a href="/items/123" data-wowhead="item=123&amp;domain='
        + domain
        + '"><span>Item</span><span>'
        + quantity
        + "</span></a></div></div>"
    )


class CompleteCatalogTests(unittest.TestCase):
    def test_output_reproduces_every_source_id_and_explicit_unknown(self):
        source, report = build_complete(ROOT)
        actual = json.loads((ROOT / "data/catalog-complete-source.json").read_bytes())
        self.assertEqual(source, actual)
        self.assertEqual(report["publicIdsAbsentOutput"], [])
        self.assertEqual(
            sum(report["fieldCoverage"]["items"].values()), len(source["quests"])
        )
        self.assertGreater(report["counts"]["publishedEmptyItems"], 1837)
        self.assertGreater(report["counts"]["rowsWithGivers"], 3500)
        _, inputs = read_inputs(ROOT)
        self.assertEqual(report["counts"]["publicIndex"], inputs["public"]["expected"])
        identity = set(inputs["compiled"]["questIDs"]) | set(
            inputs["client"]["questIDs"]
        )
        identity.update(row["id"] for row in inputs["public"]["records"])
        identity.update(row["id"] for row in inputs["legacy"]["quests"])
        identity.update(
            row["id"]
            for row in json.loads((ROOT / "data/primary-statuses.json").read_bytes())[
                "quests"
            ]
        )
        identity.update(inputs.get("history", {}).get("questIDs", []))
        self.assertEqual({row["id"] for row in source["quests"]}, identity)
        output = {row["id"]: row for row in source["quests"]}
        for quest in inputs["compiled"].get("hiddenTriggerIDs", []):
            self.assertEqual(output[quest]["questKind"], "hidden-trigger")
        for published in inputs["public"]["records"]:
            row = output[published["id"]]
            self.assertEqual(row["items"], published["items"])
            self.assertEqual(row["itemState"], published["itemState"])
            for field in ("xp", "money", "reputation"):
                if field in published:
                    self.assertEqual(row["rewardValues"][field], published[field])

    def test_canonical_truncation_and_changed_reward_groups_are_rejected(self):
        source, _ = build_complete(ROOT)
        provenance, _ = read_inputs(ROOT)
        changed = copy.deepcopy(source)
        changed["quests"].pop()
        with self.assertRaisesRegex(ValueError, "reconciliation"):
            validate_complete(changed, provenance, ROOT)
        changed = copy.deepcopy(source)
        row = next(row for row in changed["quests"] if row["id"] == 682)
        row["items"] = [item for item in row["items"] if item["group"] != "guaranteed"]
        with self.assertRaisesRegex(ValueError, "reconciliation"):
            validate_complete(changed, provenance, ROOT)

    def test_missing_and_truncated_panels_are_unknown_not_empty(self):
        for html in (page(label="Classic Era"), page()[:-7], page(quest=10)):
            result = quest_detail(html, 9)
            self.assertEqual(result["itemState"], "unknown")
            self.assertEqual(result["items"], [])
        self.assertEqual(quest_detail(page(), 9)["itemState"], "published-empty")

    def test_classic_rewards_and_change_summaries_do_not_become_forever_rewards(self):
        classic = (
            '<section><div class="label">Classic Era</div><div class="wow-tt">'
            + item(domain="classic")
            + "</div></section>"
        )
        changed = '<div><div>Changes in Forever</div><a href="/items/456">Historical change</a></div>'
        result = quest_detail(page(changed, extra=classic), 9)
        self.assertEqual(result["items"], [])
        self.assertEqual(result["itemState"], "published-empty")
        with self.assertRaisesRegex(ValueError, "environment"):
            quest_detail(page(item(domain="classic")), 9)

    def test_reward_groups_keep_duplicate_identity_across_groups_and_quantities(self):
        result = quest_detail(
            page(
                item(quantity="\u00d72")
                + item("You will be able to choose one of these rewards:")
            ),
            9,
        )
        self.assertEqual(
            [(i["group"], i["itemID"], i["quantity"]) for i in result["items"]],
            [("guaranteed", 123, 2), ("choice", 123, 1)],
        )
        repeated = quest_detail(
            page(item(quantity="\u00d720") + item(quantity="\u00d710")), 9
        )
        self.assertEqual(
            [(row["slot"], row["quantity"]) for row in repeated["items"]],
            [(1, 20), (2, 10)],
        )
        with self.assertRaisesRegex(ValueError, "quantity"):
            quest_detail(page(item(quantity="\u00d70")), 9)

    def test_explicit_units_and_names_are_required_for_published_amounts(self):
        body = "<div><div>You will also receive:</div><div>1,450 experience</div><div>1g 4s 2c</div><div>+50 reputation with Ironforge</div></div>"
        row = quest_detail(page(body), 9)
        self.assertEqual(
            (row["xp"], row["money"], row["reputation"]),
            (1450, 10402, [{"name": "Ironforge", "amount": 50}]),
        )
        row = quest_detail(
            page("<div><div>You will also receive:</div><div>40</div></div>"), 9
        )
        self.assertNotIn("money", row)
        self.assertNotIn("xp", row)
        self.assertEqual(row["fieldStates"]["money"], "unknown")

    def test_index_retains_unconfirmed_discovery_ids_without_changing_their_environment(
        self,
    ):
        html = '<html><span>2<!-- --> results</span><a href="/quests/9" data-wowhead="quest=9&amp;domain=forever">A</a><a href="/quests/10" data-wowhead="quest=10&amp;domain=classic">B</a></html>'
        self.assertEqual(quest_index(html), (2, [9, 10]))

    def test_metadata_does_not_require_an_item_reward_or_invent_one(self):
        text = "q(9,{qg=54,lvl=15,coord={50,60,MAP.ZONE}})"
        self.assertEqual(parse(text, "fixture", {"MAP.ZONE": 100})[0], [])
        rows, _ = parse(text, "fixture", {"MAP.ZONE": 100}, include_empty=True)
        self.assertEqual(rows[0]["items"], [])
        self.assertEqual(rows[0]["locations"][0]["npcID"], 54)

    def test_independent_giver_metadata_survives_an_unsupported_restriction_for_separate_resolution(
        self,
    ):
        rows, _ = parse(
            "q(792,{classes=exclude(WARLOCK,ALL_CLASSES),qg=3145,coord={42,68,MAP.ZONE}})",
            "fixture",
            {"MAP.ZONE": 1411},
            include_empty=True,
        )
        self.assertEqual(rows[0]["unresolvedRestrictions"], ["classes"])
        self.assertEqual(
            rows[0]["locations"][0],
            {"npcID": 3145, "mapID": 1411, "x": 0.42, "y": 0.68},
        )
        self.assertEqual(rows[0]["items"], [])

    def test_typed_object_and_item_starters_never_become_npc_associations_or_coordinates(
        self,
    ):
        text = 'q(9,{provider={"i",123},providers={{"o",456},{"n",789}},coord={20,30,MAP.ZONE},groups={objective(1,{provider={"n",999}})}})'
        rows, _ = parse(text, "fixture", {"MAP.ZONE": 1411}, include_empty=True)
        self.assertEqual(
            rows[0]["locations"], [{"itemID": 123}, {"objectID": 456}, {"npcID": 789}]
        )
        rows, omissions = parse(
            "q(9,{provider={n,123}})", "fixture", {}, include_empty=True
        )
        self.assertNotIn("locations", rows[0])
        self.assertTrue(any(row.get("field") == "providers" for row in omissions))

    def test_unresolved_restrictions_accumulate_across_exact_id_occurrences(self):
        a = {"id": 9, "items": [], "sources": [], "unresolvedRestrictions": ["classes"]}
        b = {"id": 9, "items": [], "sources": [], "unresolvedRestrictions": ["races"]}
        self.assertEqual(merge(a, b)["unresolvedRestrictions"], ["classes", "races"])

    def test_native_identity_validation_requires_current_build_and_complete_framing(
        self,
    ):
        raw = (
            b"TSQW"
            + struct.pack("<I", 70374)
            + b"\0" * 16
            + struct.pack("<III", 9, 4, 9)
            + b"\0" * 8
        )
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as tmp:
            path = Path(tmp) / "questcache.wdb"
            path.write_bytes(raw)
            row = native_ids(path)
            self.assertEqual(row["questIDs"], [9])
            self.assertFalse(row["rewardLayoutVerified"])
            for bad in (
                raw[:-1],
                raw[:-8],
                raw[:4] + struct.pack("<I", 70338) + raw[8:],
            ):
                path.write_bytes(bad)
                with self.assertRaises(ValueError):
                    native_ids(path)


if __name__ == "__main__":
    unittest.main()
