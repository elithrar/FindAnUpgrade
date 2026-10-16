"""Acquisition trust boundaries, incremental reuse, ownership and safe apply."""

import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest import mock
from urllib.error import HTTPError

from fau_tools import sources as acquire
from fau_tools import sources as collect
from fau_tools import sync as sync
from fau_tools.att import bounds, literal, tokenize
from fau_tools.catalog import enrich_locations
from fau_tools.coordinates import recover_file
from fau_tools.importer import (
    compiled_ids,
    compiled_locations,
    compiled_quest_variants,
    ordered_inputs,
    source_bytes,
)

ROOT = Path(__file__).resolve().parents[1]


class Response:
    def __init__(self, raw, url=collect.ORIGIN + "/quests/9", headers=None):
        self.raw, self.url, self.headers = raw, url, headers or {}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def read(self):
        return self.raw


class SyncTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".work").mkdir(exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def collector(self, **kwargs):
        with mock.patch.object(
            collect,
            "urlopen",
            return_value=Response(b"User-agent: *\nAllow: /\nDisallow: /api/\n"),
        ):
            collector = collect.Collector(self.root, **kwargs)
        collector.delay = 0
        return collector

    def seed(self, age=0):
        body = b"<html>exact source</html>"
        now = datetime.now(UTC) - timedelta(hours=age)
        row = {
            "key": 9,
            "url": collect.ORIGIN + "/quests/9",
            "file": "quests/9.html",
            "sha256": hashlib.sha256(body).hexdigest(),
            "bytes": len(body),
            "checkedAt": now.isoformat(),
            "etag": "v1",
        }
        (self.root / "quests").mkdir()
        (self.root / "quests/9.html").write_bytes(body)
        collect.save(self.root / ".receipts/quests/9.json", row)
        return body, row

    def test_warm_reuse_does_not_extend_freshness_and_tampering_fails(self):
        body, row = self.seed()
        collector = self.collector()
        with mock.patch.object(collect, "urlopen") as network:
            self.assertEqual(collector.get(9, row["url"], "quests"), body)
            network.assert_not_called()
        self.assertEqual(collector.rows["9"]["checkedAt"], row["checkedAt"])
        (self.root / row["file"]).write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "hash changed"):
            collector.get(9, row["url"], "quests")

    def test_expired_conditional_304_requires_verified_cached_body(self):
        body, row = self.seed(age=25)
        collector = self.collector()
        error = HTTPError(row["url"], 304, "Not Modified", {"ETag": "v1"}, None)
        with mock.patch.object(collect, "urlopen", side_effect=error) as network:
            self.assertEqual(collector.get(9, row["url"], "quests"), body)
            self.assertEqual(
                network.call_args.args[0].get_header("If-none-match"), "v1"
            )
        self.assertGreater(collector.rows["9"]["checkedAt"], row["checkedAt"])

    def test_changed_index_row_refreshes_a_warm_detail(self):
        _, row = self.seed()
        collector = self.collector(refresh_keys=[9])
        with mock.patch.object(
            collect, "urlopen", return_value=Response(b"<html>new body</html>")
        ) as network:
            self.assertEqual(
                collector.get(9, row["url"], "quests"), b"<html>new body</html>"
            )
            network.assert_called_once()

    def test_interrupted_refresh_does_not_clear_pending_changed_details(self):
        state = {"title": "Old", "detail": b"old detail"}
        requests = []

        def fetch(request, timeout):
            url = request.full_url
            requests.append(url)
            if url.endswith("/robots.txt"):
                return Response(b"User-agent: *\nAllow: /\n", url)
            if "/quests?" in url:
                return Response(
                    (
                        '<html><span>1 results</span><a href="/quests/9" data-wowhead="quest=9&amp;domain=forever"><div class="font-semibold">'
                        + state["title"]
                        + "</div></a></html>"
                    ).encode(),
                    url,
                )
            return Response(state["detail"], url)

        def command(mode):
            with (
                mock.patch.object(
                    sys,
                    "argv",
                    ["collect", "--source-root", str(self.root), "--mode", mode]
                    + (["--refresh"] if mode == "index" else []),
                ),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                collect.public_main()

        with mock.patch.object(collect, "urlopen", side_effect=fetch):
            command("index")
            command("quests")
            state.update(title="New", detail=b"new detail")
            command("index")
            command("index")
            requests.clear()
            command("quests")
        self.assertEqual((self.root / "quests/9.html").read_bytes(), b"new detail")
        self.assertIn(collect.ORIGIN + "/quests/9", requests)
        self.assertEqual(
            json.loads((self.root / "index-manifest.json").read_bytes())["changedIDs"],
            [],
        )

    def test_route_key_and_policy_boundaries_fail_without_requests(self):
        collector = self.collector()
        with mock.patch.object(collect, "urlopen") as network:
            for key, url in (
                ("../9", collect.ORIGIN + "/quests/9"),
                (9, collect.ORIGIN + "/api/quests"),
                (9, "https://example.com/quests/9"),
            ):
                with self.assertRaises(ValueError):
                    collector.get(key, url, "quests")
            network.assert_not_called()

    def test_challenge_and_rate_restrictions_stop_collection(self):
        collector = self.collector()
        with mock.patch.object(
            collect, "urlopen", return_value=Response(b"Just a moment...")
        ):
            with self.assertRaisesRegex(ValueError, "challenge"):
                collector.get(9, collect.ORIGIN + "/quests/9", "quests")
        self.assertTrue(collector.stop)
        with mock.patch.object(collect, "urlopen") as network:
            with self.assertRaises(RuntimeError):
                collector.get(10, collect.ORIGIN + "/quests/10", "quests")
            network.assert_not_called()

    def test_source_acquirer_rejects_partial_tree_and_wrong_git_blob(self):
        with mock.patch.object(
            acquire,
            "fetch",
            side_effect=[
                b'[{"name":"child","type":"dir","sha":"x"}]',
                b'{"truncated":true,"tree":[]}',
            ],
        ):
            with self.assertRaisesRegex(ValueError, "Incomplete"):
                acquire.subtree("parent/child", acquire.PIN)
        with mock.patch.object(acquire, "fetch", return_value=b"wrong bytes"):
            with self.assertRaisesRegex(ValueError, "blob mismatch"):
                acquire.acquire(self.root, [{"path": "file.lua", "sha": "0" * 40}])
        self.assertFalse((self.root / "file.lua").exists())

    def test_literal_quest_values_cannot_be_prefixes_of_expressions(self):
        for text in (
            "q(9,{qgs={11}} and {qgs={22}})",
            "q(9,_.ResolveQuestData({aqd={qgs={11}} and unknown(),hqd={qgs={22}}}))",
            "q(9,_.ResolveQuestData({aqd={qgs={11}},hqd={qgs={22}}}).other)",
        ):
            tokens = tokenize(text)
            self.assertEqual(compiled_quest_variants(tokens, bounds(tokens), 0), [])

    def test_resolver_branch_overrides_and_false_inherits_without_union(self):
        tokens = tokenize(
            "q(9,_.ResolveQuestData({qgs={99},c={4},aqd={qgs={11}},hqd={qgs=false}}))"
        )
        ends = bounds(tokens)
        result = [
            (
                faction,
                literal(tokens, ends, props["qgs"]),
                literal(tokens, ends, props["c"]),
            )
            for props, faction in compiled_quest_variants(tokens, ends, 0)
        ]
        self.assertEqual(result, [("Alliance", [11], [4]), ("Horde", [99], [4])])

    def test_hidden_tracker_calls_with_and_without_metadata_keep_exact_identities(self):
        path = "db/Camelot/Categories/HiddenQuestTriggers.lua"
        raw = b"hqt(9,{qgs={11}});hqt(10)"
        target = self.root / path
        target.parent.mkdir(parents=True)
        target.write_bytes(raw)
        (self.root / "ACQUISITION.json").write_text(
            json.dumps(
                {
                    "commit": acquire.PIN,
                    "files": [
                        {"path": path, "sha256": hashlib.sha256(raw).hexdigest()}
                    ],
                }
            )
        )
        compiled = compiled_ids(self.root)
        self.assertEqual(compiled["questIDs"], [9, 10])
        self.assertEqual(compiled["hiddenTriggerIDs"], [9, 10])
        self.assertEqual(compiled["metadata"], [])

    def test_multiple_starters_do_not_receive_unowned_coordinates(self):
        text = "q(9,{qgs={11,22},coords={[1411]={{20,30},{40,50}}}})"
        tokens = tokenize(text)
        ends = bounds(tokens)
        props, _ = compiled_quest_variants(tokens, ends, 0)[0]
        locations, diagnostics = compiled_locations(tokens, ends, props, [text])
        self.assertEqual(locations, [{"npcID": 11}, {"npcID": 22}])
        self.assertTrue(diagnostics)

    def test_faction_qualification_preserves_names_and_other_faction_starter(self):
        row = {"id": 9, "locations": [{"npcID": 11, "name": "Known"}]}
        enrich_locations(
            row,
            {
                "locations": [
                    {"npcID": 11, "faction": "Alliance"},
                    {"npcID": 11, "faction": "Horde"},
                ]
            },
            [],
        )
        self.assertEqual(
            row["locations"],
            [
                {"npcID": 11, "name": "Known", "faction": "Alliance"},
                {"npcID": 11, "name": "Known", "faction": "Horde"},
            ],
        )
        row = {"id": 9, "locations": [{"npcID": 11, "faction": "Alliance"}]}
        enrich_locations(row, {"locations": [{"npcID": 22, "faction": "Horde"}]}, [])
        self.assertEqual(len(row["locations"]), 2)

    def test_staged_apply_rejects_missing_files_or_concurrent_edits(self):
        stage = self.root / "stage"
        stage.mkdir()
        for name in sync.OUTPUTS:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(b"original")
        baseline = {name: sync.sha(self.root / name) for name in sync.OUTPUTS}
        with self.assertRaisesRegex(ValueError, "Missing validated"):
            sync.apply_candidate(self.root, stage, baseline)
        self.assertTrue(
            all((self.root / name).read_bytes() == b"original" for name in sync.OUTPUTS)
        )
        (self.root / sync.OUTPUTS[0]).write_bytes(b"concurrent")
        with self.assertRaisesRegex(ValueError, "Concurrent"):
            sync.apply_candidate(self.root, stage, baseline)

    def test_apply_rolls_back_a_partial_replace(self):
        stage = self.root / "stage"
        stage.mkdir()
        for name in sync.OUTPUTS:
            for root, raw in ((self.root, b"original"), (stage, b"candidate")):
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
        baseline = {name: sync.sha(self.root / name) for name in sync.OUTPUTS}
        original = Path.replace
        calls = []

        def replace(path, target):
            calls.append(target)
            if len(calls) == 2:
                raise OSError("simulated apply failure")
            return original(path, target)

        with mock.patch.object(Path, "replace", replace):
            with self.assertRaisesRegex(OSError, "simulated"):
                sync.apply_candidate(self.root, stage, baseline)
        self.assertTrue(
            all((self.root / name).read_bytes() == b"original" for name in sync.OUTPUTS)
        )
        self.assertEqual(list(self.root.rglob("*.sync-*")), [])

    def test_receipt_cannot_read_outside_the_acquisition_root(self):
        with self.assertRaisesRegex(ValueError, "outside cache"):
            source_bytes(self.root, {"file": "../private.html"})

    def test_provenance_retains_owned_order_and_sorts_new_keys(self):
        previous = {"public": {}, "metadata": {}, "supplemental": {}, "chains": {}}
        inputs = {
            "chains": {"sha256": "c"},
            "public": {"sha256": "p"},
            "supplemental": {"sha256": "s"},
            "zeta": {},
            "alpha": {},
        }
        ordered = ordered_inputs(inputs, previous)
        self.assertEqual(
            list(ordered), ["public", "supplemental", "chains", "alpha", "zeta"]
        )
        self.assertEqual(ordered, inputs)

    def test_staged_snapshot_carries_locked_tooling_without_private_environment(self):
        source = self.root / "source"
        for name in ("FindAnUpgrade", "data", "docs", "tests", "fau_tools", ".github"):
            (source / name).mkdir(parents=True)
        for name in (
            "AGENTS.md",
            "README.md",
            "LICENSE",
            ".gitignore",
            ".gitattributes",
            "pyproject.toml",
            "uv.lock",
            ".python-version",
        ):
            (source / name).write_bytes(name.encode("utf-8"))
        private = source / ".work/venv/private.txt"
        private.parent.mkdir(parents=True)
        private.write_text("private environment", encoding="utf-8")
        stage = self.root / "stage"
        sync.stage_sources(source, stage)
        for name in ("pyproject.toml", "uv.lock", ".python-version"):
            self.assertEqual((stage / name).read_bytes(), (source / name).read_bytes())
        self.assertFalse((stage / ".work/venv").exists())


class CoordinateBindingTests(unittest.TestCase):
    prefix = "local LEFT={{10,20,MAP.A}};local RIGHT={{30,40,MAP.B}};\n"
    anchors = "q(1,{qg=22,coords=LEFT});q(2,{qg=11,coords=RIGHT});\n"
    target = "q(9,{qgs={11,22},coords=appendGroups(RIGHT,appendGroups(LEFT,{}))})"
    scope = {9: {("npcID", 11), ("npcID", 22)}}
    maps = {"MAP.A": 100, "MAP.B": 101}

    def recover(self, text, scope=None):
        return recover_file(text, "fixture", self.maps, scope or self.scope)[0]

    def test_explicit_anchors_override_alias_names_and_list_order(self):
        rows = self.recover(self.prefix + self.anchors + self.target)[9]
        self.assertEqual(
            {(row["npcID"], row["mapID"], row["x"], row["y"]) for row in rows},
            {(22, 100, 0.1, 0.2), (11, 101, 0.3, 0.4)},
        )

    def test_mutated_escaped_or_nonfresh_coordinate_arrays_remain_unknown(self):
        for extra in ("LEFT[1][1]=90;", "Mutate(LEFT);", "local ESCAPE=LEFT;"):
            self.assertEqual(
                self.recover(self.prefix + self.anchors + self.target + ";" + extra), {}
            )
        for expression in (
            "appendGroups(LEFT,RIGHT)",
            "appendGroups(LEFT,appendGroups(LEFT,RIGHT))",
        ):
            self.assertEqual(
                self.recover(
                    self.prefix
                    + self.anchors
                    + "q(9,{qgs={11,22},coords="
                    + expression
                    + "})"
                ),
                {},
            )

    def test_helper_rebinding_and_expression_suffixes_cannot_borrow_contracts(self):
        for extra in (
            "_G.appendGroups=function()return {} end;",
            "function _G.appendGroups(a,b)return {} end;",
            "local appendGroups=function()return {} end;",
        ):
            self.assertEqual(
                self.recover(self.prefix + extra + self.anchors + self.target), {}
            )
        for suffix in (".other", "[1]", " and {}", " or {}"):
            self.assertEqual(
                self.recover(
                    self.prefix
                    + self.anchors
                    + "q(9,{qgs={11,22},coords=appendGroups(LEFT,{})"
                    + suffix
                    + "})"
                ),
                {},
            )

    def test_conflicting_or_missing_owners_do_not_establish_locations(self):
        self.assertEqual(self.recover(self.prefix + self.target), {})
        self.assertEqual(
            self.recover(
                self.prefix + self.anchors + "q(3,{qg=11,coords=LEFT});" + self.target
            ),
            {},
        )
        self.assertEqual(
            self.recover(
                self.prefix
                + self.anchors
                + "q(9,{qg=11,qgs={22},coords=appendGroups(RIGHT,{})})"
            ),
            {},
        )

    def test_target_identity_and_entity_namespace_must_already_match(self):
        self.assertEqual(
            self.recover(
                self.prefix
                + self.anchors
                + self.target.replace("qgs={11,22}", "qgs={22,33}")
            ),
            {},
        )
        self.assertEqual(
            self.recover(
                self.prefix + self.anchors + self.target,
                {9: {("itemID", 11), ("objectID", 22)}},
            ),
            {},
        )

    def test_equal_inline_points_and_objectives_do_not_prove_alias_ownership(self):
        self.assertEqual(
            self.recover(
                self.prefix
                + self.anchors
                + "q(9,{qgs={11,22},coords={{10,20,MAP.A},{30,40,MAP.B}}})"
            ),
            {},
        )
        self.assertEqual(
            self.recover(
                self.prefix
                + self.anchors
                + "q(9,{qgs={11,22},coord={10,20,MAP.A},coords=appendGroups(LEFT,{})})"
            ),
            {},
        )
        anchors = 'q(1,{coords=LEFT,groups={objective(1,{provider={"n",22}})}});q(2,{qg=11,coords=RIGHT});'
        self.assertEqual(self.recover(self.prefix + anchors + self.target), {})

    def test_frozen_106_audit_and_two_quest_recovery_preserve_all_starter_identities(
        self,
    ):
        metadata = json.loads(
            (ROOT / "data/catalog-metadata-records.json").read_bytes()
        )
        recovery = metadata["coordinateRecovery"]
        self.assertEqual(len(recovery["quests"]), 106)
        self.assertEqual(recovery["recoveredIDs"], [9388, 9389])
        output = {
            row["id"]: row
            for row in json.loads(
                (ROOT / "data/catalog-complete-source.json").read_bytes()
            )["quests"]
        }
        for quest in recovery["quests"]:
            expected = {
                (key, point[key])
                for point in quest["starters"]
                for key in ("npcID", "objectID", "itemID")
                if key in point
            }
            actual = {
                (key, point[key])
                for point in output[quest["id"]].get("locations", [])
                for key in ("npcID", "objectID", "itemID")
                if key in point
            }
            self.assertEqual(actual, expected)
        report = json.loads((ROOT / "data/catalog-reconciliation.json").read_bytes())
        self.assertEqual(
            report["coordinateOwnershipAuditCounts"],
            {
                "recovered-explicit-coordinate-alias-ownership": 2,
                "unassigned-literal-coordinate-list": 60,
                "unassigned-faction-branch": 6,
                "no-direct-coordinate-field": 38,
            },
        )

    def test_recovered_midsummer_points_have_exact_npc_ownership_and_provenance(self):
        metadata = json.loads(
            (ROOT / "data/catalog-metadata-records.json").read_bytes()
        )
        sources = {row["path"] for row in metadata["sources"]}
        output = {
            row["id"]: row
            for row in json.loads(
                (ROOT / "data/catalog-complete-source.json").read_bytes()
            )["quests"]
        }
        expected = {
            (16817, 1453, 38.5, 61.1),
            (16817, 1455, 63.6, 24.7),
            (16817, 1438, 56.6, 92.3),
            (16818, 1454, 46.8, 38.0),
            (16818, 1456, 21.3, 26.4),
            (16818, 1458, 67.6, 8.3),
        }
        for quest in (9388, 9389):
            points = output[quest]["locations"]
            self.assertEqual(
                {
                    (
                        point["npcID"],
                        point["mapID"],
                        round(point["x"] * 100, 1),
                        round(point["y"] * 100, 1),
                    )
                    for point in points
                },
                expected,
            )
            proof = next(
                row
                for row in metadata["coordinateRecovery"]["audit"]
                if row["id"] == quest
            )
            self.assertEqual(len(proof["proofs"]), 2)
            self.assertTrue(
                all(
                    anchor["path"] in sources and anchor["line"] > 0
                    for item in proof["proofs"]
                    for anchor in item["anchors"]
                )
            )


if __name__ == "__main__":
    unittest.main()
