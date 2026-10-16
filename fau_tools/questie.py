"""Pinned numeric Forever metadata, without executing upstream addon Lua.

The release artifact supplies final Static/Derived values. Positive generated
fields distinguish reviewed Forever observations from inherited data. Dynamic
owners, reciprocal-link failures, uncertain points and source conflicts stay
diagnostic. This is recorded source evidence, never current availability proof."""

import argparse
import base64
import copy
import hashlib
import io
import json
import math
import re
import struct
from pathlib import Path
from urllib.request import Request, urlopen
from zipfile import ZipFile

from fau_tools.att import bounds, entries, tokenize
from fau_tools.context import ROOT

REPOSITORY = "Questie/QuestieDB"
REVISION = "36ca1ca86f6c1838de479c7c7452eb0a57d5c135"
RELEASE = "v1.0.6"
ARCHIVE = "QuestieDB-Forever.zip"
ARCHIVE_SHA256 = "d78b066c362eaf28258d9e2d041c0a7b03d6943a2dfc741dec70c6bfd8e1fc27"
TOC = "QuestieDB_Forever.toc"
GENERATED = "src/corrections/Forever/generated/foreverBase"
SOURCE_BLOBS = {
    GENERATED + "Quest.lua": "ab12cfb05caa4ca95bc91681e9ea442e76247ee0",
    GENERATED + "Npc.lua": "a0435bd31bb9f28d821b415c8bff8bb969d1d879",
    GENERATED + "Object.lua": "d19e656c69b443d896b92befd253b09a12def2b4",
    GENERATED + "Item.lua": "94dd13ba5852d8092c8b000befd805deee1f28e9",
    "docs/forever-delta-base.md": "2d6742bad244436495d74d5e45447b36020c1cb3",
}
ENTITY_KEYS = {"Npc": "npcID", "Object": "objectID", "Item": "itemID"}
TABLE_FIELDS = {
    "Quest": {2, 12, 13, 14, 15, 16, 26, 28},
    "Npc": {7, 8, 10},
    "Object": {2, 4, 7},
    "Item": set(),
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def fetch(url):
    with urlopen(
        Request(
            url,
            headers={
                "User-Agent": "FindAnUpgrade-source-sync/1 (pinned factual metadata)"
            },
        ),
        timeout=45,
    ) as response:
        return response.read()


def acquire(destination):
    """Acquire the fixed public release and source proofs into an owned cache."""
    destination = destination.resolve()
    manifest = destination / "ACQUISITION.json"
    if manifest.exists():
        previous = json.loads(manifest.read_bytes())
        if (
            previous.get("revision") != REVISION
            or previous.get("archiveSha256") != ARCHIVE_SHA256
        ):
            raise ValueError("Questie cache belongs to another reviewed pin")
    archive_path = destination / ARCHIVE
    raw = archive_path.read_bytes() if archive_path.is_file() else None
    if raw is None or sha(raw) != ARCHIVE_SHA256:
        raw = fetch(
            f"https://github.com/{REPOSITORY}/releases/download/{RELEASE}/{ARCHIVE}"
        )
    if sha(raw) != ARCHIVE_SHA256:
        raise ValueError("Pinned Questie release checksum mismatch")
    destination.mkdir(parents=True, exist_ok=True)
    archive_path.write_bytes(raw)
    files = []
    with ZipFile(io.BytesIO(raw)) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate Questie archive members")
        required = {
            TOC,
            "src/read/baked.lua",
            "src/config.lua",
            "src/corrections/enum/expansions.lua",
            "support/Forever/Zones/areaIdToUiMapId.lua",
            "support/Forever/Zones/uiMapIdToAreaId.lua",
        }
        required.update(
            "src/meta/" + entity.lower() + "Meta.lua"
            for entity in ("Quest", "Npc", "Object", "Item")
        )
        required.update(
            name[len("QuestieDB/") :]
            for name in names
            if name.startswith("QuestieDB/src/corrections/Forever/")
            and name.endswith(".lua")
        )
        for path in sorted(required):
            member = "QuestieDB/" + path
            if member not in names:
                raise ValueError("Required pinned archive input missing: " + path)
            value = archive.read(member)
            target = (destination / path).resolve()
            if not target.is_relative_to(destination):
                raise ValueError("Questie archive path escaped cache")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
            files.append(
                {
                    "path": path,
                    "sha256": sha(value),
                    "bytes": len(value),
                    "basis": "pinned-release-member",
                }
            )
    for path, expected in SOURCE_BLOBS.items():
        target = destination / path
        value = target.read_bytes() if target.is_file() else None

        def blob(data):
            return hashlib.sha1(
                b"blob " + str(len(data)).encode() + b"\0" + data
            ).hexdigest()

        if value is None or blob(value) != expected:
            value = fetch(
                f"https://raw.githubusercontent.com/{REPOSITORY}/{REVISION}/{path}"
            )
        if blob(value) != expected:
            raise ValueError("Pinned Questie source Git blob mismatch: " + path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value)
        files.append(
            {
                "path": path,
                "sha256": sha(value),
                "bytes": len(value),
                "gitBlob": expected,
                "basis": "pinned-git-source",
            }
        )
    result = {
        "schemaVersion": 1,
        "repository": REPOSITORY,
        "revision": REVISION,
        "release": RELEASE,
        "archiveSha256": ARCHIVE_SHA256,
        "files": sorted(files, key=lambda row: row["path"]),
        "rule": "Read numeric facts only. No upstream code execution or distribution.",
    }
    manifest.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result


class CBOR:
    """Bounded definite-length CBOR subset used by the pinned data artifact."""

    def __init__(self, raw):
        self.raw, self.position = raw, 0

    def take(self, size):
        if size < 0 or self.position + size > len(self.raw):
            raise ValueError("Truncated Questie CBOR")
        result = self.raw[self.position : self.position + size]
        self.position += size
        return result

    def read(self, depth=0):
        if depth > 32:
            raise ValueError("Questie CBOR nesting limit")
        head = self.take(1)[0]
        major, additional = head >> 5, head & 31
        if additional < 24:
            value = additional
        elif additional in (24, 25, 26, 27):
            value = int.from_bytes(self.take(1 << (additional - 24)), "big")
        else:
            raise ValueError("Unsupported Questie CBOR length")
        if major == 0:
            return value
        if major == 1:
            return -1 - value
        if major in (2, 3):
            return self.take(value).decode("utf-8")
        if major == 4:
            if value > 100000:
                raise ValueError("Questie CBOR array limit")
            return [self.read(depth + 1) for _ in range(value)]
        if major == 5:
            if value > 100000:
                raise ValueError("Questie CBOR map limit")
            result = {}
            for _ in range(value):
                key = self.read(depth + 1)
                if type(key) not in (str, int) or key in result:
                    raise ValueError("Invalid or duplicate Questie CBOR map key")
                result[key] = self.read(depth + 1)
            return result
        if major == 7:
            if additional == 20:
                return False
            if additional == 21:
                return True
            if additional == 22:
                return None
            if additional in (25, 26, 27):
                size = 1 << (additional - 24)
                return struct.unpack(
                    {2: ">e", 4: ">f", 8: ">d"}[size], value.to_bytes(size, "big")
                )[0]
        raise ValueError("Unsupported Questie CBOR type")


def decode(value):
    parser = CBOR(base64.b64decode(value, validate=True))
    result = parser.read()
    if parser.position != len(parser.raw):
        raise ValueError("Trailing Questie CBOR bytes")
    return result


class Baked:
    def __init__(self, raw):
        self.metadata = {}
        for line in raw.decode("utf-8").splitlines():
            match = re.fullmatch(r"## (X-(?:Quest|Npc|Object|Item)-[^:]+): (.+)", line)
            if match:
                if match[1] in self.metadata:
                    raise ValueError("Duplicate Questie TOC key")
                self.metadata[match[1]] = match[2]
        header = raw.decode("utf-8").split("## X-Quest-", 1)[0]
        if not all(
            value in header
            for value in (
                "## Interface: 16001",
                "## X-Flavor: Forever",
                "## X-Contract-Version: 4",
                "## X-BUILD-COMMIT: " + REVISION,
            )
        ):
            raise ValueError("Unexpected Questie artifact identity")
        self.scalars = {}

    def stored(self, key):
        value = self.metadata.get(key)
        if value is None:
            return None
        match = re.fullmatch(r"~([1-9]\d*)~", value)
        if match:
            count = int(match[1])
            if count > 10000:
                raise ValueError("Questie metadata chunk limit")
            try:
                value = "".join(
                    self.metadata[key + "-" + str(index)]
                    for index in range(1, count + 1)
                )
            except KeyError:
                raise ValueError("Incomplete Questie metadata chunks") from None
        return decode(value)

    def scalar(self, entity, identity):
        key = (entity, identity)
        if key not in self.scalars:
            value = self.stored(f"X-{entity}-{identity}-S")
            if isinstance(value, list):
                value = dict(enumerate(value, 1))
            if value is not None and not isinstance(value, dict):
                raise ValueError("Invalid Questie scalar row")
            self.scalars[key] = value or {}
        return self.scalars[key]

    def field(self, entity, identity, index):
        row = self.scalar(entity, identity)
        if index not in TABLE_FIELDS[entity]:
            return row.get(index)
        present = row.get("p", 0)
        if type(present) is not int or present < 0:
            raise ValueError("Invalid Questie table presence mask")
        value = self.stored(f"X-{entity}-{identity}-{index}")
        if bool(present & (1 << (index - 1))) != (value is not None):
            raise ValueError("Questie table presence mismatch")
        return value


def literal(tokens, ends, span):
    """Only numeric tables/nil holes; no symbols, calls, strings or arithmetic."""
    start, stop = span
    if stop == start + 1:
        word = tokens[start][0]
        if word == "nil":
            return None
        if re.fullmatch(r"-?\d+(?:\.\d+)?", word):
            number = float(word)
            return int(number) if number.is_integer() else number
        raise ValueError("Nonliteral Questie selected value")
    if tokens[start][0] != "{" or ends.get(start) != stop - 1:
        raise ValueError("Nonliteral Questie selected table")
    result, keyed = [], {}
    for begin, finish in entries(tokens, ends, start):
        if tokens[begin][0] == "[":
            if (
                begin + 4 >= finish
                or tokens[begin + 2][0] != "]"
                or tokens[begin + 3][0] != "="
                or not tokens[begin + 1][0].isdigit()
                or result
            ):
                raise ValueError("Invalid Questie numeric table key")
            key = int(tokens[begin + 1][0])
            if key in keyed:
                raise ValueError("Duplicate Questie selected table key")
            keyed[key] = literal(tokens, ends, (begin + 4, finish))
        else:
            if keyed:
                raise ValueError("Mixed Questie selected table")
            result.append(literal(tokens, ends, (begin, finish)))
    return keyed if keyed else result


def source_fields(text, field_prefix, selected):
    tokens = tokenize(text)
    ends = bounds(tokens)
    result = {}
    for index, (word, line) in enumerate(tokens[:-4]):
        if (
            word != "["
            or not tokens[index + 1][0].isdigit()
            or tokens[index + 2][0] != "]"
            or tokens[index + 3][0] != "="
            or tokens[index + 4][0] != "{"
        ):
            continue
        identity = int(tokens[index + 1][0])
        for start, stop in entries(tokens, ends, index + 4):
            if (
                start + 4 >= stop
                or tokens[start][0] != "["
                or tokens[start + 2][0] != "]"
                or tokens[start + 3][0] != "="
            ):
                continue
            name = tokens[start + 1][0]
            if not name.startswith(field_prefix + "."):
                continue
            name = name[len(field_prefix) + 1 :]
            if name not in selected:
                continue
            record = result.setdefault(identity, {"line": line, "fields": {}})
            if name in record["fields"]:
                raise ValueError("Repeated Questie selected field")
            record["fields"][name] = literal(tokens, ends, (start + 4, stop))
    return result


def grouped_starters(value):
    if not isinstance(value, (dict, list)):
        return None
    groups = dict(enumerate(value, 1)) if isinstance(value, list) else value
    if set(groups) - {1, 2, 3}:
        return None
    result = []
    for index, entity in ((1, "Npc"), (2, "Object"), (3, "Item")):
        ids = groups.get(index)
        if ids is None:
            continue
        if not isinstance(ids, list) or any(
            type(identity) is not int or identity <= 0 for identity in ids
        ):
            return None
        result.extend((entity, identity) for identity in ids)
    return sorted(set(result))


def restriction_enums(raw):
    """Read actual IDs and bit values; never assume raceID-1 for Forever."""
    text = raw.decode("utf-8")
    match = re.search(r"constants\.raceMaskById = \{(.*?)\n\}", text, re.S)
    classes = re.search(r"Classic = \{\s*classKeys = \{(.*?)\n\s*\}", text, re.S)
    if not match or not classes:
        raise ValueError("Pinned Questie restriction enums absent")
    races = {
        int(identity): int(mask)
        for identity, mask in re.findall(r"^\s*\[(\d+)\]\s*=\s*(\d+),", match[1], re.M)
    }
    allowed = {
        "WARRIOR",
        "PALADIN",
        "HUNTER",
        "ROGUE",
        "PRIEST",
        "SHAMAN",
        "MAGE",
        "WARLOCK",
        "DRUID",
    }
    class_bits = {
        name: int(mask)
        for name, mask in re.findall(r"^\s*([A-Z_]+)\s*=\s*(\d+),", classes[1], re.M)
        if name in allowed
    }
    if set(class_bits) != allowed or not races:
        raise ValueError("Incomplete pinned Questie restriction enums")
    for mapping in (races, class_bits):
        if len(set(mapping.values())) != len(mapping) or any(
            value <= 0 or value & (value - 1) for value in mapping.values()
        ):
            raise ValueError("Invalid pinned Questie restriction bit encoding")
    return races, class_bits


def restrictions(baked, identity, enums):
    result, evidence = {}, {}
    for index, name, key, mapping in (
        (6, "requiredRaces", "races", enums[0]),
        (7, "requiredClasses", "classTokens", enums[1]),
    ):
        mask = baked.field("Quest", identity, index)
        if mask is None:
            continue
        evidence[name] = mask
        if type(mask) is not int or not 0 <= mask < 2**53:
            return None, evidence
        if mask == 0:
            continue  # Explicit zero/absence does not erase another source's restriction.
        supported = sum(mapping.values())
        if mask & ~supported:
            return None, evidence
        result[key] = sorted(value for value, bit in mapping.items() if mask & bit)
    return result, evidence


def owned_cache(root):
    receipt = json.loads((root / "ACQUISITION.json").read_bytes())
    if (
        receipt.get("revision") != REVISION
        or receipt.get("archiveSha256") != ARCHIVE_SHA256
        or receipt.get("repository") != REPOSITORY
    ):
        raise ValueError("Unreviewed Questie cache identity")
    result = {}
    for source in receipt["files"]:
        path = (root / source["path"]).resolve()
        if not path.is_relative_to(root.resolve()) or source["path"] in result:
            raise ValueError("Unsafe or repeated Questie input path")
        raw = path.read_bytes()
        if sha(raw) != source["sha256"] or len(raw) != source["bytes"]:
            raise ValueError("Questie source receipt mismatch: " + source["path"])
        if source["path"] in SOURCE_BLOBS:
            blob = hashlib.sha1(
                b"blob " + str(len(raw)).encode() + b"\0" + raw
            ).hexdigest()
            if blob != SOURCE_BLOBS[source["path"]]:
                raise ValueError(
                    "Questie selected source differs from reviewed Git blob"
                )
        result[source["path"]] = raw
    archive_path = root / ARCHIVE
    if not archive_path.is_file() or sha(archive_path.read_bytes()) != ARCHIVE_SHA256:
        raise ValueError("Pinned Questie cache archive missing or changed")
    with ZipFile(archive_path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate pinned Questie archive members")
        for path, raw in result.items():
            if path in SOURCE_BLOBS:
                continue
            member = "QuestieDB/" + path
            if member not in names or archive.read(member) != raw:
                raise ValueError("Questie cached member differs from reviewed release")
    return receipt, result


def map_table(raw, name):
    text = raw.decode("utf-8")
    match = re.search(
        r"ZoneDB\.private\." + re.escape(name) + r" = \[\[return \{(.*?)\}\]\]",
        text,
        re.S,
    )
    if not match:
        raise ValueError("Questie primary AreaID map table absent")
    return {
        int(area): int(ui_map)
        for area, ui_map in re.findall(r"^\s*\[(\d+)\]\s*=\s*(\d+),", match[1], re.M)
    }


def numeric_points(value):
    if not isinstance(value, dict):
        return []
    result = []
    for area, rows in value.items():
        if type(area) is not int or area <= 0 or not isinstance(rows, list):
            continue
        for point in rows:
            # Phase-qualified points, instance sentinels and malformed positions
            # cannot become unconditional fixed navigation targets.
            if (
                not isinstance(point, list)
                or len(point) != 2
                or not all(
                    type(number) in (int, float)
                    and math.isfinite(number)
                    and 0 <= number <= 100
                    for number in point
                )
            ):
                continue
            result.append((area, point[0], point[1]))
    return result


def canonical_maps(files):
    forward = map_table(
        files["support/Forever/Zones/areaIdToUiMapId.lua"], "areaIdToUiMapId"
    )
    reverse = map_table(
        files["support/Forever/Zones/uiMapIdToAreaId.lua"], "uiMapIdToAreaId"
    )
    return {
        area: ui_map for area, ui_map in forward.items() if reverse.get(ui_map) == area
    }


def primary_coordinates(cache, primary, quests, maps):
    """Keep exact primary NPC start markers, using only direct native map pairs.

    Object/item acquisition versus activation remains ambiguous for mixed item
    starts, so this path deliberately selects NPC start markers only. It never
    treats objective/end markers, area membership or a parent map as a point.
    """
    by_id = {quest["id"]: quest for quest in quests}
    receipts = {row["id"]: row for row in primary["sources"]}
    records, sources = [], []
    decoder = json.JSONDecoder()
    for record in primary["records"]:
        identity = record["id"]
        quest = by_id.get(identity)
        if (
            not quest
            or quest.get("confirmation") != "published"
            or quest.get("questKind") == "hidden-trigger"
        ):
            continue
        receipt = receipts.get(identity)
        if not receipt or receipt.get(
            "url"
        ) != "https://www.wowhead.com/forever/quest=" + str(identity):
            raise ValueError("Primary coordinate receipt identity missing")
        raw = (cache / (str(identity) + ".html")).read_bytes()
        if sha(raw) != receipt["sha256"] or len(raw) != receipt["bytes"]:
            raise ValueError("Primary coordinate receipt mismatch")
        text = raw.decode("utf-8")
        match = re.search(r"\$\.extend\(g_quests\[" + str(identity) + r"\],\s*", text)
        if not match or "WH.Gatherer.addData(5, 16" not in text:
            raise ValueError("Primary exact Forever coordinate identity absent")
        detail, _ = decoder.raw_decode(text[match.end() :])
        if detail.get("id") != identity:
            raise ValueError("Primary coordinate variant mismatch")
        match = re.search(r"new Mapper\(", text)
        if not match:
            continue
        mapper, _ = decoder.raw_decode(text[match.end() :])
        if not isinstance(mapper, dict) or not isinstance(
            mapper.get("objectives", {}), dict
        ):
            raise ValueError("Unsupported primary Mapper shape")
        locations, evidence = [], []
        for area, data in mapper.get("objectives", {}).items():
            if (
                not re.fullmatch(r"[1-9]\d*", area)
                or int(area) not in maps
                or not isinstance(data, dict)
            ):
                continue
            levels = data.get("levels", [])
            if (
                not isinstance(levels, list)
                or len(levels) != 1
                or not isinstance(levels[0], list)
            ):
                continue
            for marker in levels[0]:
                if (
                    not isinstance(marker, dict)
                    or marker.get("point") != "start"
                    or type(marker.get("type")) is not int
                    or marker["type"] != 1
                    or type(marker.get("id")) is not int
                    or marker["id"] <= 0
                ):
                    continue
                matches = [
                    row
                    for row in quest.get("locations", [])
                    if row.get("npcID") == marker["id"]
                ]
                if not matches or any("mapID" in row for row in matches):
                    continue
                coordinates = marker.get(
                    "coords", [marker["coord"]] if "coord" in marker else []
                )
                points = numeric_points({int(area): coordinates})
                if not isinstance(coordinates, list) or len(points) != len(coordinates):
                    continue
                if "coord" in marker:
                    representative = numeric_points({int(area): [marker["coord"]]})
                    if len(representative) != 1 or representative[0] not in points:
                        continue
                for _, x, y in points:
                    for old in matches:
                        location = {
                            "npcID": marker["id"],
                            "mapID": maps[int(area)],
                            "x": x / 100,
                            "y": y / 100,
                        }
                        for key in ("name", "faction"):
                            if key in old:
                                location[key] = old[key]
                        if location not in locations:
                            locations.append(location)
                if points:
                    evidence.append(
                        {
                            "id": identity,
                            "entity": "Npc",
                            "starterID": marker["id"],
                            "basis": "retained-primary-exact-start-marker",
                            "areaID": int(area),
                            "mapID": maps[int(area)],
                            "points": [
                                {"x": x / 100, "y": y / 100} for _, x, y in points
                            ],
                            "sourceUrl": receipt["url"],
                            "sha256": receipt["sha256"],
                        }
                    )
        if locations:
            records.append(
                {"id": identity, "locations": locations, "evidence": evidence}
            )
            sources.append(receipt)
    return records, sources


def attach_primary_coordinates(primary, supplemental):
    """Freeze supported primary positions with their independent map receipts.

    This produces a new primary document; it never mutates either input. Only
    exact primary NPC identities and matching URL/hash proofs can receive
    coordinate facts. Questie-only records and acquisition points are ignored.
    """
    result = copy.deepcopy(primary)
    selected = [
        row
        for row in supplemental.get("records", [])
        if any(
            proof.get("basis") == "retained-primary-exact-start-marker"
            for proof in row.get("evidence", [])
        )
    ]
    if not selected:
        return result
    source = supplemental.get("source", {})
    if (
        source.get("repository") != REPOSITORY
        or source.get("revision") != REVISION
        or source.get("archiveSha256") != ARCHIVE_SHA256
    ):
        raise ValueError("Unreviewed primary coordinate map source")
    paths = {
        "support/Forever/Zones/areaIdToUiMapId.lua",
        "support/Forever/Zones/uiMapIdToAreaId.lua",
    }
    files = [row for row in source.get("files", []) if row.get("path") in paths]
    if (
        {row.get("path") for row in files} != paths
        or len(files) != 2
        or any(
            not re.fullmatch(r"[a-f0-9]{64}", row.get("sha256", ""))
            or type(row.get("bytes")) is not int
            or row["bytes"] <= 0
            for row in files
        )
    ):
        raise ValueError("Primary coordinate mapping receipts incomplete")
    mapping = {}
    for pair in source.get("canonicalMapPairs", []):
        area, ui_map = pair.get("areaID"), pair.get("mapID")
        if (
            type(area) is not int
            or area <= 0
            or type(ui_map) is not int
            or ui_map <= 0
            or area in mapping
        ):
            raise ValueError("Invalid primary canonical map proof")
        mapping[area] = ui_map
    if not mapping:
        raise ValueError("Primary canonical map proof absent")
    records = {row["id"]: row for row in result["records"]}
    receipts = {row["id"]: row for row in result["sources"]}
    incoming_receipts = {
        row["id"]: row for row in source.get("primaryCoordinateSources", [])
    }
    accepted_pairs = set()
    for incoming in selected:
        identity = incoming["id"]
        record, receipt = records.get(identity), receipts.get(identity)
        if record is None or receipt is None:
            continue
        incoming_receipt = incoming_receipts.get(identity)
        if (
            incoming_receipt is None
            or any(
                receipt.get(key) != incoming_receipt.get(key)
                for key in ("url", "sha256", "bytes")
            )
            or receipt.get("url")
            != "https://www.wowhead.com/forever/quest=" + str(identity)
            or record.get("sha256") != receipt.get("sha256")
            or record.get("sourceUrl") != receipt.get("url")
        ):
            raise ValueError(
                "Primary coordinate proof differs from exact retained page"
            )
        proofs = [
            proof
            for proof in incoming.get("evidence", [])
            if proof.get("basis") == "retained-primary-exact-start-marker"
            and proof.get("id") == identity
            and proof.get("entity") == "Npc"
            and proof.get("sourceUrl") == receipt["url"]
            and proof.get("sha256") == receipt["sha256"]
            and type(proof.get("starterID")) is int
            and proof["starterID"] > 0
            and type(proof.get("areaID")) is int
            and type(proof.get("mapID")) is int
            and mapping.get(proof["areaID"]) == proof["mapID"]
        ]
        locations = list(record.get("locations", []))
        originals = list(locations)
        for point in incoming.get("locations", []):
            npc, ui_map = point.get("npcID"), point.get("mapID")
            if (
                type(npc) is not int
                or npc <= 0
                or type(ui_map) is not int
                or ui_map <= 0
                or any(key in point for key in ("itemID", "objectID"))
            ):
                continue
            matching = [old for old in locations if old.get("npcID") == npc]
            matching_proofs = [
                proof
                for proof in proofs
                if proof["starterID"] == npc
                and proof["mapID"] == ui_map
                and isinstance(proof.get("points"), list)
                and any(
                    isinstance(recorded, dict)
                    and all(
                        type(recorded.get(key)) in (int, float)
                        and math.isfinite(recorded[key])
                        and 0 <= recorded[key] <= 1
                        and recorded[key] == point.get(key)
                        for key in ("x", "y")
                    )
                    for recorded in proof["points"]
                )
            ]
            if (
                not matching
                or not matching_proofs
                or not all(
                    type(point.get(key)) in (int, float)
                    and math.isfinite(point[key])
                    and 0 <= point[key] <= 1
                    for key in ("x", "y")
                )
            ):
                continue
            mapped = [
                old for old in originals if old.get("npcID") == npc and "mapID" in old
            ]
            if mapped and not any(
                all(old.get(key) == point[key] for key in ("mapID", "x", "y"))
                for old in mapped
            ):
                continue
            bare = [old for old in matching if "mapID" not in old]
            scopes = bare or matching
            # Preserve source-known qualification and labels; a supplemental
            # base record cannot invent a faction constraint in a primary page.
            for old in scopes:
                updated = {
                    key: value
                    for key, value in old.items()
                    if key != "mapID" and key not in ("x", "y")
                }
                updated.update({key: point[key] for key in ("mapID", "x", "y")})
                if updated not in locations:
                    locations.append(updated)
            locations = [old for old in locations if old not in bare]
            for proof in matching_proofs:
                if proof not in record.setdefault("coordinateEvidence", []):
                    record["coordinateEvidence"].append(copy.deepcopy(proof))
                accepted_pairs.add((proof["areaID"], proof["mapID"]))
        if locations:
            record["locations"] = locations
    if accepted_pairs:
        mapping_receipt = {
            "repository": REPOSITORY,
            "revision": REVISION,
            "archiveSha256": ARCHIVE_SHA256,
            "files": copy.deepcopy(sorted(files, key=lambda row: row["path"])),
            "pairs": [
                {"areaID": area, "mapID": ui_map}
                for area, ui_map in sorted(accepted_pairs)
            ],
            "rule": "Canonical reciprocal AreaID/UiMap pair only; no parent or compatibility override projection",
        }
        stored = result.setdefault("coordinateMappingSources", [])
        if mapping_receipt not in stored:
            stored.append(mapping_receipt)
    return result


def import_metadata(root, quests, primary_cache=None, primary=None):
    receipt, files = owned_cache(root)
    baked = Baked(files[TOC])
    enums = restriction_enums(files["src/corrections/enum/expansions.lua"])
    generated = {
        entity: source_fields(
            files[GENERATED + entity + ".lua"].decode("utf-8"),
            entity.lower() + "Keys",
            {
                "startedBy",
                "startedBy_add",
                "spawns",
                "spawns_add",
                "questStarts",
                "questStarts_add",
                "startQuest",
            },
        )
        for entity in ("Quest", "Npc", "Object", "Item")
    }
    maps = canonical_maps(files)
    dynamic = {entity: set() for entity in ("Quest", "Npc", "Object", "Item")}
    # Distribution strips Static provider bodies; remaining selected writes are
    # character-dependent. Never freeze their base values as universal facts.
    for path, raw in files.items():
        if (
            path.startswith("src/corrections/Forever/")
            and not path.startswith(GENERATED)
            and path.endswith(".lua")
        ):
            for entity in dynamic:
                prefix = entity.lower() + "Keys"
                tokens = tokenize(raw.decode("utf-8"))
                ends = bounds(tokens)
                for index, (word, _) in enumerate(tokens[:-4]):
                    if (
                        word != "["
                        or not tokens[index + 1][0].isdigit()
                        or tokens[index + 2][0] != "]"
                        or tokens[index + 3][0] != "="
                        or tokens[index + 4][0] != "{"
                    ):
                        continue
                    start, stop = index + 4, ends[index + 4]
                    if any(
                        token.startswith(prefix + ".")
                        and token.rsplit(".", 1)[-1].split("_", 1)[0]
                        in (
                            "startedBy",
                            "spawns",
                            "questStarts",
                            "startQuest",
                            "waypoints",
                            "requiredRaces",
                            "requiredClasses",
                        )
                        for token, _ in tokens[start:stop]
                    ):
                        dynamic[entity].add(int(tokens[index + 1][0]))
    records, audit = [], []
    for quest in sorted(quests, key=lambda row: row["id"]):
        identity = quest["id"]
        starters = grouped_starters(baked.field("Quest", identity, 2))
        if not starters:
            continue
        constraints, constraint_evidence = restrictions(baked, identity, enums)
        if constraints is None:
            audit.append(
                {
                    "id": identity,
                    "cause": "unsupported-whole-race-or-class-mask",
                    "constraintEvidence": constraint_evidence,
                }
            )
            continue
        known = {
            (entity, row[key])
            for row in quest.get("locations", [])
            for entity, key in ENTITY_KEYS.items()
            if key in row
        }
        locations, evidence = [], []
        for entity, giver in starters:
            entry = {"id": identity, "entity": entity, "starterID": giver}
            reason = None
            if quest.get("confirmation") != "published":
                reason = "quest-identity-not-currently-published"
            elif quest.get("questKind") == "hidden-trigger":
                reason = "declared-hidden-trigger"
            elif identity in dynamic["Quest"] or giver in dynamic[entity]:
                reason = "character-dependent-source-owner"
            elif known and (entity, giver) not in known:
                reason = "preserve-existing-starter-association"
            reciprocal = (
                baked.field("Item", giver, 5) == identity
                if entity == "Item"
                else identity
                in (baked.field(entity, giver, 10 if entity == "Npc" else 2) or [])
            )
            if not reason and not reciprocal:
                reason = "missing-exact-reciprocal-starter-link"
            if reason:
                audit.append(dict(entry, cause=reason))
                continue
            name = baked.field(entity, giver, 1)
            location = {ENTITY_KEYS[entity]: giver}
            if isinstance(name, str) and name and len(name) <= 150:
                location["name"] = name
            positive = []
            for field in ("startedBy", "startedBy_add"):
                value = (
                    generated["Quest"].get(identity, {}).get("fields", {}).get(field)
                )
                positive.extend(grouped_starters(value) or [])
            basis = (
                "forever-generated-exact-starter"
                if (entity, giver) in positive
                else "inherited-recorded-reciprocal-starter"
            )
            # Only explicitly generated Forever spawn facts which survive the
            # final Baked composition may supply new fixed points. Inherited
            # converted Era positions remain withheld.
            points = []
            if entity != "Item" and not baked.field(
                entity, giver, 8 if entity == "Npc" else 7
            ):
                native = numeric_points(
                    baked.field(entity, giver, 7 if entity == "Npc" else 4)
                )
                source = generated[entity].get(giver, {}).get("fields", {})
                for point in numeric_points(source.get("spawns")) + numeric_points(
                    source.get("spawns_add")
                ):
                    area, x, y = point
                    if area in (44, 139, 215, 1519) or area not in maps:
                        continue
                    if any(
                        area == a and abs(x - u) < 1e-7 and abs(y - v) < 1e-7
                        for a, u, v in native
                    ):
                        target = dict(location, mapID=maps[area], x=x / 100, y=y / 100)
                        if target not in points:
                            points.append(target)
            existing = [
                row
                for row in quest.get("locations", [])
                if row.get(ENTITY_KEYS[entity]) == giver
            ]
            if points and any("mapID" in row for row in existing):
                audit.append(dict(entry, cause="preserve-existing-starter-coordinates"))
                points = []
            if not known:
                locations.extend(points or [location])
            elif points:
                # Preserve existing faction qualification when enriching a
                # proven starter; never flatten a resolver branch.
                scopes = {row.get("faction") for row in existing}
                for point in points:
                    locations.extend(
                        dict(point, **({"faction": faction} if faction else {}))
                        for faction in sorted(scopes, key=str)
                    )
            evidence.append(
                dict(
                    entry,
                    basis=basis,
                    reciprocal=True,
                    coordinates="forever-generated-surviving-fixed-spawn"
                    if points
                    else "unknown-or-preserved",
                    questSourceLine=generated["Quest"].get(identity, {}).get("line"),
                    entitySourceLine=generated[entity].get(giver, {}).get("line"),
                )
            )
        if locations:
            unique = {json.dumps(row, sort_keys=True): row for row in locations}
            records.append(
                {
                    "id": identity,
                    "locations": [unique[key] for key in sorted(unique)],
                    "constraints": constraints,
                    "constraintEvidence": constraint_evidence,
                    "evidence": evidence,
                }
            )
    primary_sources = []
    if primary_cache is not None:
        if primary is None:
            raise ValueError("Primary coordinate input receipts required")
        extra, primary_sources = primary_coordinates(
            primary_cache, primary, quests, maps
        )
        indexed = {row["id"]: row for row in records}
        for extra_row in extra:
            row = indexed.setdefault(
                extra_row["id"],
                {"id": extra_row["id"], "locations": [], "evidence": []},
            )
            row["locations"].extend(
                location
                for location in extra_row["locations"]
                if location not in row["locations"]
            )
            row["evidence"].extend(extra_row["evidence"])
        records = [indexed[identity] for identity in sorted(indexed)]
    return {
        "schemaVersion": 1,
        "source": {
            "repository": REPOSITORY,
            "revision": REVISION,
            "release": RELEASE,
            "archiveSha256": ARCHIVE_SHA256,
            "files": receipt["files"],
            "canonicalMapPairs": [
                {"areaID": area, "mapID": ui_map}
                for area, ui_map in sorted(maps.items())
            ],
            "primaryCoordinateSources": primary_sources,
            "baselineQuestFactsSha256": sha(
                json.dumps(
                    quests, sort_keys=True, separators=(",", ":"), ensure_ascii=False
                ).encode()
            ),
        },
        "records": records,
        "omissions": audit,
        "rules": [
            "Exact reciprocal typed starters only; no objectives, drop locations, title joins or new quest identity",
            "Inherited starter relationships are historical recorded evidence, not current availability",
            "Explicit Baked race/class masks retain all known bits through pinned enum IDs; unsupported whole masks suppress provider records, zero never erases another source restriction",
            "Fixed locations require explicit generated Forever spawn facts surviving final Baked composition; inherited Era positions, phase points, mobile owners, changed-map frames and legacy override routes are withheld",
            "Optional retained primary NPC start markers require an existing exact starter and canonical reciprocal AreaID/UiMap pair; no object/item acquisition points",
            "Existing starters, faction scopes and coordinates are preserved; conflicts are diagnostic",
            "No classification, XP, money, item rewards or reputation are inferred",
        ],
    }


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("acquire", "reparse"))
    parser.add_argument(
        "--source-root", type=Path, default=ROOT / ".work/catalog-cache/questie"
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        help="Fresh canonical base WITHOUT this supplemental provider; required for reparse",
    )
    parser.add_argument("--primary-cache", type=Path)
    parser.add_argument(
        "--primary-records",
        type=Path,
        default=ROOT / "data/catalog-primary-records.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=ROOT / ".work/starter-recovery/questie-metadata.json",
    )
    args = parser.parse_args(argv)
    if args.mode == "acquire":
        result = acquire(args.source_root)
        print(json.dumps({"files": len(result["files"]), "revision": REVISION}))
        return
    if args.catalog is None:
        parser.error(
            "reparse requires --catalog built without supplemental Questie metadata"
        )
    result = import_metadata(
        args.source_root,
        json.loads(args.catalog.read_bytes())["quests"],
        args.primary_cache,
        json.loads(args.primary_records.read_bytes()) if args.primary_cache else None,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "records": len(result["records"]),
                "omissions": len(result["omissions"]),
                "output": str(args.output),
            }
        )
    )
