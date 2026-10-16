"""Reward evidence regressions: explicit amounts versus absent source fields."""

import json
import tempfile
import unittest
from pathlib import Path

from fau_tools.html import primary_reward_values, quest_detail, reward_amount_line
from fau_tools.importer import primary_records

ROOT = Path(__file__).resolve().parents[1]


def page(body, before="", after=""):
    return (
        '<html><body><a href="https://www.wowhead.com/forever/quest=9">Quest</a>'
        + before
        + '<section><div class="label">Forever</div><div class="wow-tt"><div class="font-semibold">Exact variant</div>'
        + body
        + "</div></section>"
        + after
        + "</body></html>"
    )


def amounts(*lines, heading="You will also receive:"):
    return (
        "<div><div>"
        + heading
        + "</div>"
        + "".join("<div>" + line + "</div>" for line in lines)
        + "</div>"
    )


class RewardAmountRecoveryTests(unittest.TestCase):
    def test_retained_primary_import_keeps_missing_rep_unknown_and_requires_variant(
        self,
    ):
        (ROOT / ".work").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as tmp:
            path = Path(tmp) / "9.html"
            source = {"id": 9, "name": "Exact variant", "xp": 0, "money": 0}

            def write():
                path.write_text(
                    "WH.Gatherer.addData(5, 16, {}); $.extend(g_quests[9], "
                    + json.dumps(source)
                    + ");",
                    encoding="utf-8",
                )

            write()
            row = primary_records(Path(tmp))["records"][0]
            self.assertNotIn("reputation", row)
            self.assertEqual((row["xp"], row["money"]), (0, 0))
            source["reprewards"] = []
            write()
            self.assertEqual(primary_records(Path(tmp))["records"][0]["reputation"], [])
            source["id"] = 10
            write()
            with self.assertRaisesRegex(ValueError, "variant mismatch"):
                primary_records(Path(tmp))

    def test_primary_absence_is_not_zero_or_empty_reputation(self):
        self.assertEqual(primary_reward_values({}), {})
        self.assertEqual(
            primary_reward_values({"xp": 0, "money": 0, "reprewards": []}),
            {"xp": 0, "money": 0, "reputation": []},
        )
        self.assertEqual(
            primary_reward_values({"reprewards": [[72, 150], [87, -500]]}),
            {
                "reputation": [
                    {"factionID": 72, "amount": 150},
                    {"factionID": 87, "amount": -500},
                ]
            },
        )

    def test_primary_corrupt_values_fail_before_source_freeze(self):
        for row in (
            {"xp": True},
            {"xp": 1.5},
            {"money": -1},
            {"money": "100"},
            {"money": 2**53},
            {"reprewards": None},
            {"reprewards": {}},
            {"reprewards": [[72, True]]},
            {"reprewards": [[0, 100]]},
            {"reprewards": [[72, 100, 1]]},
            {"reprewards": [[72, 100], [72, 100]]},
        ):
            with self.subTest(row=row), self.assertRaises(ValueError):
                primary_reward_values(row)

    def test_explicit_display_units_keep_zero_negative_rep_and_copper(self):
        row = quest_detail(
            page(
                amounts(
                    "0 experience",
                    "1g<span>2s</span><span>3c</span>",
                    "+150 reputation with Argent Dawn",
                    "-500 reputation with Bloodsail Buccaneers",
                )
            ),
            9,
        )
        self.assertEqual(row["xp"], 0)
        self.assertEqual(row["money"], 10203)
        self.assertEqual(
            row["reputation"],
            [
                {"name": "Argent Dawn", "amount": 150},
                {"name": "Bloodsail Buccaneers", "amount": -500},
            ],
        )
        self.assertEqual(reward_amount_line("1,234g 5s"), ("money", 12340500))
        self.assertEqual(reward_amount_line("0c"), ("money", 0))
        self.assertEqual(
            reward_amount_line("0 reputation with Gelkis Clan Centaur"),
            ("reputation", {"name": "Gelkis Clan Centaur", "amount": 0}),
        )
        self.assertEqual(reward_amount_line("-1g -3s"), ("moneyCost", 10300))

    def test_negative_money_is_explicit_cost_without_a_zero_reward_claim(self):
        row = quest_detail(page(amounts("-1g -3s")), 9)
        self.assertEqual(row["moneyCost"], 10300)
        self.assertNotIn("money", row)
        self.assertEqual(row["fieldStates"]["money"], "unknown")

    def test_repeated_faction_observations_remain_separate_without_a_sum(self):
        row = quest_detail(
            page(
                amounts(
                    "+200 reputation with Thorium Brotherhood",
                    "+200 reputation with Thorium Brotherhood",
                )
            ),
            9,
        )
        self.assertEqual(
            row["reputation"], [{"name": "Thorium Brotherhood", "amount": 200}] * 2
        )

    def test_blank_or_unlabelled_amounts_remain_unknown(self):
        for body in (
            "",
            amounts(""),
            amounts("100"),
            amounts("No cash amount recorded"),
        ):
            row = quest_detail(page(body), 9)
            for key in ("xp", "money", "reputation", "currencies"):
                self.assertNotIn(key, row)
                self.assertEqual(row["fieldStates"][key], "unknown")

    def test_other_environment_change_summary_and_objectives_cannot_supply_amounts(
        self,
    ):
        classic = (
            '<section><div class="label">Classic Era</div><div class="wow-tt">'
            + amounts("9,999 experience", "1g", "+100 reputation with Stormwind")
            + "</div></section>"
        )
        body = amounts(
            "9,999 experience",
            "1g",
            "+100 reputation with Stormwind",
            heading="Changes in Forever",
        )
        body += amounts(
            "9,999 experience",
            "1g",
            "+100 reputation with Stormwind",
            heading="Objectives",
        )
        script = "<script>const xp=9999; const money=10000;</script>"
        row = quest_detail(page(body, before=classic, after=script), 9)
        self.assertNotIn("xp", row)
        self.assertNotIn("money", row)
        self.assertNotIn("reputation", row)

    def test_malformed_and_duplicate_source_values_do_not_silently_change_amounts(self):
        bad = (
            "1,,000 experience",
            "01 experience",
            "-5 experience",
            "1,20 experience",
            "1.5 experience",
            "9007199254740992 experience",
            "+1,,000 reputation with Stormwind",
            "150 reputation with Stormwind",
            "+150 reputation with ",
            "+2147483648 reputation with Stormwind",
            "1g 2g",
            "1s 2g",
            "-1g 3s",
            "1.5g",
            "1,20g",
            "9007199254741000c",
        )
        for text in bad:
            with self.subTest(text=text), self.assertRaises(ValueError):
                quest_detail(page(amounts(text)), 9)
        for lines in (("100 experience", "200 experience"), ("1g", "2s")):
            with self.subTest(lines=lines), self.assertRaises(ValueError):
                quest_detail(page(amounts(*lines)), 9)

    def test_incomplete_or_ambiguous_forever_identity_cannot_supply_amounts(self):
        html = page(amounts("100 experience", "1g", "+100 reputation with Stormwind"))
        for invalid in (
            html[:-7],
            html.replace("quest=9", "quest=10"),
            html.replace(">Forever</div>", ">Classic Era</div>"),
        ):
            row = quest_detail(invalid, 9)
            self.assertEqual(row["confirmation"], "unconfirmed")
            self.assertNotIn("xp", row)
            self.assertNotIn("money", row)
            self.assertNotIn("reputation", row)

    def test_unbalanced_panel_tags_cannot_manufacture_a_complete_empty_list(self):
        html = page(amounts("100 experience"))
        invalid = (
            html.replace("Exact variant</div>", "Exact variant"),
            html.replace("100 experience</div>", "100 experience"),
            html.replace("</div></section>", "</section>"),
            html.replace("100 experience", "<span>100 experience"),
            html.replace("100 experience", "100 experience</span>"),
        )
        for body in invalid:
            with (
                self.subTest(body=body),
                self.assertRaisesRegex(ValueError, "Malformed Forever reward panel"),
            ):
                quest_detail(body, 9)
        self.assertEqual(quest_detail(page(""), 9)["itemState"], "published-empty")
        row = quest_detail(
            page(
                amounts("<span>100</span> experience")
                + "<hr/><div>Details<br/>continued</div>"
            ),
            9,
        )
        self.assertEqual(row["xp"], 100)


if __name__ == "__main__":
    unittest.main()
