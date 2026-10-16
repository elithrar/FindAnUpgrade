"""Failure-input checks for exact starter identity and fixed-point ownership."""

import base64
import json
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fau_tools import catalog as complete_catalog
from fau_tools import questie as source

ROOT = Path(__file__).resolve().parents[1]


def cbor(value):
    def head(major, number):
        if number < 24:
            return bytes([(major << 5) | number])
        for additional, size in ((24, 1), (25, 2), (26, 4), (27, 8)):
            if number < 1 << (size * 8):
                return bytes([(major << 5) | additional]) + number.to_bytes(size, "big")
        raise ValueError("fixture overflow")

    if value is None:
        return b"\xf6"
    if isinstance(value, bool):
        return b"\xf5" if value else b"\xf4"
    if isinstance(value, int):
        return head(0, value) if value >= 0 else head(1, -value - 1)
    if isinstance(value, float):
        return b"\xfb" + struct.pack(">d", value)
    if isinstance(value, str):
        raw = value.encode()
        return head(2, len(raw)) + raw
    if isinstance(value, list):
        return head(4, len(value)) + b"".join(map(cbor, value))
    if isinstance(value, dict):
        return head(5, len(value)) + b"".join(
            cbor(key) + cbor(row) for key, row in value.items()
        )
    raise TypeError(value)


def fixture(
    quest_fields=None,
    npc_fields=None,
    item_fields=None,
    object_fields=None,
    generated=None,
    dynamic="",
):
    lines = [
        "## Interface: 16001",
        "## X-Flavor: Forever",
        "## X-Contract-Version: 4",
        "## X-BUILD-COMMIT: " + source.REVISION,
    ]
    for entity, records in (
        ("Quest", quest_fields or {900001: {2: [[11]]}}),
        ("Npc", npc_fields or {11: {1: "Giver", 10: [900001], 7: {1: [[20.0, 30.0]]}}}),
        ("Item", item_fields or {}),
        ("Object", object_fields or {}),
    ):
        for identity, fields in records.items():
            scalar = {
                key: value
                for key, value in fields.items()
                if key not in source.TABLE_FIELDS[entity]
            }
            scalar["p"] = sum(
                1 << (key - 1) for key in fields if key in source.TABLE_FIELDS[entity]
            )
            lines.append(
                f"## X-{entity}-{identity}-S: "
                + base64.b64encode(cbor(scalar)).decode()
            )
            for key, value in fields.items():
                if key in source.TABLE_FIELDS[entity]:
                    lines.append(
                        f"## X-{entity}-{identity}-{key}: "
                        + base64.b64encode(cbor(value)).decode()
                    )
    files = {
        source.TOC: ("\n".join(lines) + "\n").encode(),
        "support/Forever/Zones/areaIdToUiMapId.lua": b"ZoneDB.private.areaIdToUiMapIdOverride = [[return {[10001]=224,}]]\nZoneDB.private.areaIdToUiMapId = [[return {\n [1] = 1426,\n [2] = 1426,\n [215] = 1412,\n}]]",
        "support/Forever/Zones/uiMapIdToAreaId.lua": b"ZoneDB.private.uiMapIdToAreaId = [[return {\n [1426] = 1,\n [1412] = 215,\n}]]",
    }
    files["src/corrections/enum/expansions.lua"] = (
        b"constants.raceMaskById = {\n [1] = 1,\n [8] = 128,\n [95] = 4294967296,\n [96] = 8589934592,\n}\nClassic = {classKeys = {\n WARRIOR = 1,\n PALADIN = 2,\n HUNTER = 4,\n ROGUE = 8,\n PRIEST = 16,\n SHAMAN = 64,\n MAGE = 128,\n WARLOCK = 256,\n DRUID = 1024,\n}\n}"
    )
    for entity in ("Quest", "Npc", "Object", "Item"):
        files[source.GENERATED + entity + ".lua"] = (
            (generated or {}).get(entity, "return {}").encode()
        )
    if dynamic:
        files["src/corrections/Forever/legacy/classicQuestFixes.lua"] = dynamic.encode()
    return {
        "files": [
            {"path": name, "sha256": source.sha(raw), "bytes": len(raw)}
            for name, raw in files.items()
        ]
    }, files


def run_import(quests=None, **kwargs):
    with patch.object(source, "owned_cache", return_value=fixture(**kwargs)):
        return source.import_metadata(
            Path("unused"), quests or [{"id": 900001, "confirmation": "published"}]
        )


class StarterCoordinateRecoveryTests(unittest.TestCase):
    def test_primary_starter_receives_exact_global_position_after_identity_merge(self):
        public = {
            "id": 900001,
            "title": "Fixture quest",
            "confirmation": "published",
            "items": [],
            "itemState": "published-empty",
        }
        primary = {
            "id": 900001,
            "items": [],
            "locations": [{"npcID": 11, "name": "Exact giver"}],
        }
        inputs = {
            "public": {"records": [public], "expected": 1, "collectedAt": "2026-10-15"},
            "primary": {"records": [primary]},
            "metadata": {"records": [], "conflicts": [], "omissions": []},
            "compiled": {
                "questIDs": [900001],
                "npcPositions": [
                    {"npcID": 11, "locations": [{"mapID": 1426, "x": 0.2, "y": 0.3}]}
                ],
                "constraintConflicts": [],
            },
            "client": {"questIDs": []},
            "legacy": {"quests": []},
        }
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            (root / "data").mkdir()
            (root / "data/primary-statuses.json").write_text('{"quests":[]}')
            with patch.object(
                complete_catalog,
                "read_inputs",
                return_value=({"targetBuild": "1.60.1.70374"}, inputs),
            ):
                catalog, _ = complete_catalog.build_complete(root)
            self.assertEqual(
                catalog["quests"][0]["locations"],
                [
                    {
                        "npcID": 11,
                        "name": "Exact giver",
                        "mapID": 1426,
                        "x": 0.2,
                        "y": 0.3,
                    }
                ],
            )
            primary["locations"] = [{"npcID": 12}]
            with patch.object(
                complete_catalog,
                "read_inputs",
                return_value=({"targetBuild": "1.60.1.70374"}, inputs),
            ):
                catalog, _ = complete_catalog.build_complete(root)
            self.assertEqual(catalog["quests"][0]["locations"], [{"npcID": 12}])

    def test_cbor_holes_signed_floats_and_duplicate_corruption(self):
        value = {2: [None, [11], [22]], 26: [[72, -250]], "p": 19, "x": 20.5}
        self.assertEqual(source.decode(base64.b64encode(cbor(value))), value)
        for raw in (b"\xa2\x01\x00\x01\x01", b"\x01\x00", b"\x9f\xff", b"\x82\x00"):
            with self.assertRaises(ValueError):
                source.decode(base64.b64encode(raw))

    def test_chunk_and_presence_corruption_fail(self):
        receipt, files = fixture()
        raw = files[source.TOC]
        reader = source.Baked(raw)
        reader.metadata["X-Quest-900001-2"] = "~2~"
        reader.metadata["X-Quest-900001-2-1"] = "gYE="
        with self.assertRaises(ValueError):
            reader.field("Quest", 900001, 2)
        reader = source.Baked(raw)
        reader.scalars[("Quest", 900001)] = {"p": 0}
        with self.assertRaises(ValueError):
            reader.field("Quest", 900001, 2)

    def test_reciprocal_source_recovers_starter_but_not_inherited_position(self):
        result = run_import()
        self.assertEqual(
            result["records"][0]["locations"], [{"npcID": 11, "name": "Giver"}]
        )
        self.assertEqual(
            result["records"][0]["evidence"][0]["basis"],
            "inherited-recorded-reciprocal-starter",
        )

    def test_forever_generated_surviving_spawn_recovers_fixed_point(self):
        result = run_import(
            generated={
                "Quest": "return {[900001]={[questKeys.startedBy]={{11}}}}",
                "Npc": "return {[11]={[npcKeys.spawns]={[1]={{20,30}}}}}",
            }
        )
        self.assertEqual(
            result["records"][0]["locations"],
            [{"npcID": 11, "name": "Giver", "mapID": 1426, "x": 0.2, "y": 0.3}],
        )
        self.assertEqual(
            result["records"][0]["evidence"][0]["basis"],
            "forever-generated-exact-starter",
        )

    def test_final_composition_challenges_generated_spawn(self):
        result = run_import(
            generated={"Npc": "return {[11]={[npcKeys.spawns]={[1]={{90,90}}}}}"}
        )
        self.assertNotIn("mapID", result["records"][0]["locations"][0])

    def test_reciprocal_identity_not_list_order_or_entity_number(self):
        result = run_import(
            quest_fields={900001: {2: [[11], [11]]}},
            npc_fields={11: {10: [900002]}},
            object_fields={11: {2: [900001]}},
        )
        self.assertEqual(result["records"][0]["locations"], [{"objectID": 11}])
        self.assertEqual(
            result["omissions"][0]["cause"], "missing-exact-reciprocal-starter-link"
        )

    def test_item_start_is_reciprocal_without_acquisition_points(self):
        result = run_import(
            quest_fields={900001: {2: [None, None, [22]]}},
            item_fields={22: {1: "Letter", 5: 900001}},
        )
        self.assertEqual(
            result["records"][0]["locations"], [{"itemID": 22, "name": "Letter"}]
        )
        result = run_import(
            quest_fields={900001: {2: [None, None, [22]]}},
            item_fields={22: {5: 900002}},
        )
        self.assertEqual(result["records"], [])

    def test_unknown_hidden_and_dynamic_records_do_not_gain_starters(self):
        for quest in (
            {"id": 900001, "confirmation": "unconfirmed"},
            {"id": 900001, "confirmation": "published", "questKind": "hidden-trigger"},
        ):
            self.assertEqual(run_import(quests=[quest])["records"], [])
        result = run_import(
            dynamic="function Provider:LoadFactionFixes() return {[900001]={[questKeys.startedBy]={{12}}}} end"
        )
        self.assertEqual(result["records"], [])
        self.assertEqual(
            result["omissions"][0]["cause"], "character-dependent-source-owner"
        )
        result = run_import(
            dynamic="function Provider:LoadFactionFixes() return {[900001]={[questKeys.requiredClasses]=16}} end"
        )
        self.assertEqual(result["records"], [])

    def test_conflicting_known_starter_and_existing_points_are_preserved(self):
        result = run_import(
            quests=[
                {
                    "id": 900001,
                    "confirmation": "published",
                    "locations": [{"npcID": 12}],
                }
            ]
        )
        self.assertEqual(result["records"], [])
        self.assertEqual(
            result["omissions"][0]["cause"], "preserve-existing-starter-association"
        )
        result = run_import(
            quests=[
                {
                    "id": 900001,
                    "confirmation": "published",
                    "locations": [{"npcID": 11, "mapID": 1426, "x": 0.8, "y": 0.8}],
                }
            ],
            generated={"Npc": "return {[11]={[npcKeys.spawns]={[1]={{20,30}}}}}"},
        )
        self.assertEqual(result["records"], [])

    def test_mobile_phase_changed_frame_and_compatibility_points_withheld(self):
        generated = {
            "Npc": "return {[11]={[npcKeys.spawns]={[1]={{20,30}},[215]={{40,50}},[10001]={{60,70}}}}}"
        }
        result = run_import(
            npc_fields={
                11: {
                    10: [900001],
                    7: {1: [[20, 30, 2]], 215: [[40, 50]], 10001: [[60, 70]]},
                }
            },
            generated=generated,
        )
        self.assertEqual(result["records"][0]["locations"], [{"npcID": 11}])
        result = run_import(
            npc_fields={
                11: {10: [900001], 7: {1: [[20, 30]]}, 8: {1: [[[20, 30], [40, 50]]]}}
            },
            generated=generated,
        )
        self.assertEqual(result["records"][0]["locations"], [{"npcID": 11}])

    def test_existing_faction_scopes_survive_coordinate_enrichment(self):
        result = run_import(
            quests=[
                {
                    "id": 900001,
                    "confirmation": "published",
                    "locations": [
                        {"npcID": 11, "faction": "Alliance"},
                        {"npcID": 11, "faction": "Horde"},
                    ],
                }
            ],
            generated={"Npc": "return {[11]={[npcKeys.spawns]={[1]={{20,30}}}}}"},
        )
        self.assertEqual(
            {point["faction"] for point in result["records"][0]["locations"]},
            {"Alliance", "Horde"},
        )

    def test_selected_lua_expression_is_never_executed(self):
        with self.assertRaises(ValueError):
            source.source_fields(
                "return {[900001]={[questKeys.startedBy]=runUnknown()}}",
                "questKeys",
                {"startedBy"},
            )
        self.assertIsNone(source.grouped_starters({1: [True]}))
        self.assertIsNone(source.grouped_starters({1: [0]}))
        self.assertEqual(
            source.grouped_starters([None, [12], [13]]), [("Item", 13), ("Object", 12)]
        )

    def test_retained_primary_exact_start_marker_owns_its_point(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            marker = {"type": 1, "point": "start", "id": 11, "coords": [[20, 30]]}
            mapper = {
                "objectives": {
                    "1": {
                        "levels": [
                            [
                                marker,
                                {
                                    "type": 1,
                                    "point": "end",
                                    "id": 12,
                                    "coords": [[90, 90]],
                                },
                                {
                                    "type": 2,
                                    "point": "start",
                                    "id": 13,
                                    "coords": [[80, 80]],
                                },
                            ]
                        ]
                    }
                }
            }
            raw = (
                'WH.Gatherer.addData(5, 16); $.extend(g_quests[900001], {"id":900001}); new Mapper('
                + json.dumps(mapper)
                + ");"
            ).encode()
            (root / "900001.html").write_bytes(raw)
            primary = {
                "records": [{"id": 900001}],
                "sources": [
                    {
                        "id": 900001,
                        "url": "https://www.wowhead.com/forever/quest=900001",
                        "sha256": source.sha(raw),
                        "bytes": len(raw),
                    }
                ],
            }
            quests = [
                {
                    "id": 900001,
                    "confirmation": "published",
                    "locations": [
                        {"npcID": 11, "faction": "Alliance"},
                        {"npcID": 12},
                        {"itemID": 13},
                        {"objectID": 13},
                    ],
                }
            ]
            records, receipts = source.primary_coordinates(
                root, primary, quests, {1: 1426}
            )
            self.assertEqual(
                records[0]["locations"],
                [
                    {
                        "npcID": 11,
                        "mapID": 1426,
                        "x": 0.2,
                        "y": 0.3,
                        "faction": "Alliance",
                    }
                ],
            )
            self.assertEqual(receipts, primary["sources"])
            self.assertEqual(
                source.primary_coordinates(root, primary, quests, {})[0], []
            )
            quests[0]["locations"][0]["mapID"] = 1426
            self.assertEqual(
                source.primary_coordinates(root, primary, quests, {1: 1426})[0], []
            )
            (root / "900001.html").write_bytes(raw + b"changed")
            with self.assertRaises(ValueError):
                source.primary_coordinates(root, primary, quests, {1: 1426})

    def test_primary_marker_rejects_boolean_entity_type_and_conflicting_representative(
        self,
    ):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            for marker in (
                {"type": True, "point": "start", "id": 11, "coords": [[20, 30]]},
                {
                    "type": 1,
                    "point": "start",
                    "id": 11,
                    "coords": [[20, 30]],
                    "coord": [90, 90],
                },
            ):
                mapper = {"objectives": {"1": {"levels": [[marker]]}}}
                raw = (
                    'WH.Gatherer.addData(5, 16); $.extend(g_quests[900001], {"id":900001}); new Mapper('
                    + json.dumps(mapper)
                    + ");"
                ).encode()
                (root / "900001.html").write_bytes(raw)
                primary = {
                    "records": [{"id": 900001}],
                    "sources": [
                        {
                            "id": 900001,
                            "url": "https://www.wowhead.com/forever/quest=900001",
                            "sha256": source.sha(raw),
                            "bytes": len(raw),
                        }
                    ],
                }
                quests = [
                    {
                        "id": 900001,
                        "confirmation": "published",
                        "locations": [{"npcID": 11}],
                    }
                ]
                self.assertEqual(
                    source.primary_coordinates(root, primary, quests, {1: 1426})[0], []
                )

    def test_direct_reciprocal_map_pairs_do_not_infer_parent_frames(self):
        _, files = fixture()
        self.assertEqual(source.canonical_maps(files), {1: 1426, 215: 1412})

    def test_new_starter_preserves_race_and_class_masks_with_skyborne_encoding(self):
        result = run_import(quest_fields={900001: {2: [[11]], 6: 4294967297, 7: 16}})
        self.assertEqual(
            result["records"][0]["constraints"],
            {"races": [1, 95], "classTokens": ["PRIEST"]},
        )
        self.assertEqual(
            result["records"][0]["constraintEvidence"],
            {"requiredRaces": 4294967297, "requiredClasses": 16},
        )
        result = run_import(quest_fields={900001: {2: [[11]], 6: 128, 7: 16}})
        self.assertEqual(
            result["records"][0]["constraints"],
            {"races": [8], "classTokens": ["PRIEST"]},
        )

    def test_unknown_restriction_bits_suppress_whole_provider_without_narrowing(self):
        for race_mask, class_mask in (
            (1 + 8192, 16),
            (1, 16 + 32),
            (1, -1),
            (True, 16),
        ):
            result = run_import(
                quest_fields={900001: {2: [[11]], 6: race_mask, 7: class_mask}}
            )
            self.assertEqual(result["records"], [])
            self.assertEqual(
                result["omissions"][0]["cause"], "unsupported-whole-race-or-class-mask"
            )
        result = run_import(quest_fields={900001: {2: [[11]], 6: 0, 7: 0}})
        self.assertEqual(result["records"][0]["constraints"], {})

    def test_repeat_import_from_fresh_base_keeps_recoveries_identical(self):
        base = [{"id": 900001, "confirmation": "published"}]
        kwargs = {
            "generated": {"Npc": "return {[11]={[npcKeys.spawns]={[1]={{20,30}}}}}"}
        }
        first = run_import(quests=base, **kwargs)
        self.assertEqual(run_import(quests=base, **kwargs), first)
        self.assertNotIn("locations", base[0])

    def test_attached_primary_points_retain_receipts_without_cache_and_repeat(self):
        receipt, files = fixture()
        page = {
            "id": 900001,
            "url": "https://www.wowhead.com/forever/quest=900001",
            "sha256": "a" * 64,
            "bytes": 100,
        }
        primary = {
            "records": [
                {
                    "id": 900001,
                    "sourceUrl": page["url"],
                    "sha256": page["sha256"],
                    "locations": [{"npcID": 11, "name": "Original"}, {"objectID": 11}],
                }
            ],
            "sources": [page],
        }
        evidence = {
            "id": 900001,
            "entity": "Npc",
            "starterID": 11,
            "basis": "retained-primary-exact-start-marker",
            "areaID": 1,
            "mapID": 1426,
            "points": [{"x": 0.2, "y": 0.3}, {"x": 0.4, "y": 0.5}],
            "sourceUrl": page["url"],
            "sha256": page["sha256"],
        }
        supplemental = {
            "source": {
                "repository": source.REPOSITORY,
                "revision": source.REVISION,
                "archiveSha256": source.ARCHIVE_SHA256,
                "files": receipt["files"],
                "canonicalMapPairs": [{"areaID": 1, "mapID": 1426}],
                "primaryCoordinateSources": [page],
            },
            "records": [
                {
                    "id": 900001,
                    "locations": [
                        {"npcID": 11, "mapID": 1426, "x": 0.2, "y": 0.3},
                        {"npcID": 11, "mapID": 1426, "x": 0.4, "y": 0.5},
                        {"npcID": 11, "mapID": 1426, "x": 0.6, "y": 0.7},
                        {"objectID": 11, "mapID": 1426, "x": 0.7, "y": 0.8},
                    ],
                    "evidence": [evidence],
                }
            ],
        }
        attached = source.attach_primary_coordinates(primary, supplemental)
        self.assertEqual(
            attached["records"][0]["locations"],
            [
                {"objectID": 11},
                {"npcID": 11, "name": "Original", "mapID": 1426, "x": 0.2, "y": 0.3},
                {"npcID": 11, "name": "Original", "mapID": 1426, "x": 0.4, "y": 0.5},
            ],
        )
        self.assertEqual(attached["records"][0]["coordinateEvidence"], [evidence])
        self.assertEqual(
            attached["coordinateMappingSources"][0]["pairs"],
            [{"areaID": 1, "mapID": 1426}],
        )
        self.assertNotIn("coordinateEvidence", primary["records"][0])
        self.assertEqual(
            source.attach_primary_coordinates(attached, supplemental), attached
        )
        self.assertEqual(
            source.attach_primary_coordinates(attached, {"records": []}), attached
        )
        supplemental["source"]["primaryCoordinateSources"] = [
            dict(page, sha256="b" * 64)
        ]
        with self.assertRaises(ValueError):
            source.attach_primary_coordinates(primary, supplemental)

    def test_attachment_requires_existing_exact_primary_npc_and_matching_map_proof(
        self,
    ):
        receipt, files = fixture()
        page = {
            "id": 900001,
            "url": "https://www.wowhead.com/forever/quest=900001",
            "sha256": "a" * 64,
            "bytes": 100,
        }
        primary = {
            "records": [
                {
                    "id": 900001,
                    "sourceUrl": page["url"],
                    "sha256": page["sha256"],
                    "locations": [{"objectID": 11}],
                }
            ],
            "sources": [page],
        }
        evidence = {
            "id": 900001,
            "entity": "Npc",
            "starterID": 11,
            "basis": "retained-primary-exact-start-marker",
            "areaID": 1,
            "mapID": 1426,
            "points": [{"x": 0.2, "y": 0.3}],
            "sourceUrl": page["url"],
            "sha256": page["sha256"],
        }
        supplemental = {
            "source": {
                "repository": source.REPOSITORY,
                "revision": source.REVISION,
                "archiveSha256": source.ARCHIVE_SHA256,
                "files": receipt["files"],
                "canonicalMapPairs": [{"areaID": 1, "mapID": 1426}],
                "primaryCoordinateSources": [page],
            },
            "records": [
                {
                    "id": 900001,
                    "locations": [{"npcID": 11, "mapID": 1426, "x": 0.2, "y": 0.3}],
                    "evidence": [evidence],
                }
            ],
        }
        self.assertEqual(
            source.attach_primary_coordinates(primary, supplemental), primary
        )
        primary["records"][0]["locations"] = [{"npcID": 11}]
        supplemental["records"][0]["locations"][0]["mapID"] = 1429
        self.assertEqual(
            source.attach_primary_coordinates(primary, supplemental), primary
        )

    def test_owned_cache_rejects_changed_hash_and_path_escape(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            (root / "data").write_bytes(b"a")
            receipt = {
                "repository": source.REPOSITORY,
                "revision": source.REVISION,
                "archiveSha256": source.ARCHIVE_SHA256,
                "files": [{"path": "data", "sha256": source.sha(b"b"), "bytes": 1}],
            }
            (root / "ACQUISITION.json").write_text(json.dumps(receipt))
            with self.assertRaises(ValueError):
                source.owned_cache(root)
            receipt["files"][0]["path"] = "../outside"
            (root / "ACQUISITION.json").write_text(json.dumps(receipt))
            with self.assertRaises(ValueError):
                source.owned_cache(root)


if __name__ == "__main__":
    unittest.main()
