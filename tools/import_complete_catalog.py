"""Freeze and reconcile complete public Forever coverage with owned source facts.

Raw HTML/client files stay outside distributions. The emitted numeric facts,
short identification labels, source receipts and unknown-field inventory are
the reproducible build inputs; upstream Lua and website scripts never execute.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import struct

from catalog_html import quest_detail
from import_catalog import PIN, PREFIX, parse, merge, tokenize, bounds, fields, literal

ROOT = Path(__file__).resolve().parents[1]
BUILD = "1.60.1.70374"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def write(path, value):
    raw = (json.dumps(value, indent=2, ensure_ascii=False)+"\n").encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": digest(raw)}


def native_ids(path):
    raw = path.read_bytes()
    if raw[:4] != b"TSQW" or len(raw) < 32 or struct.unpack_from("<I", raw, 4)[0] != 70374:
        raise ValueError("Expected official 70374 quest cache framing")
    offset, records, terminated = 24, [], False
    while offset+8 <= len(raw):
        quest, size = struct.unpack_from("<II", raw, offset)
        offset += 8
        if quest == 0:
            if size != 0 or offset != len(raw):
                raise ValueError("Unexpected quest-cache terminator")
            terminated = True
            break
        if quest >= 2**31 or size < 4 or offset+size > len(raw) or struct.unpack_from("<I", raw, offset)[0] != quest:
            raise ValueError("Invalid exact quest-cache record framing")
        records.append(quest)
        offset += size
    if not terminated or offset != len(raw) or len(records) != len(set(records)):
        raise ValueError("Partial or duplicate quest-cache records")
    return {"build": BUILD, "sha256": digest(raw), "bytes": len(raw), "questIDs": sorted(records), "verifiedFields": ["exact quest identity", "client build", "record framing"], "rewardLayoutVerified": False}


def authoring_metadata(source_root):
    acquisition = json.loads((source_root/"ACQUISITION.json").read_bytes())
    if acquisition["commit"] != PIN:
        raise ValueError("Unexpected ATT source revision")
    receipts = {row["path"]: row for row in acquisition["files"]}
    dependencies = [PREFIX+".config/constants/maps.lua", ".contrib/.db/shared/constants/raceIDs.lua"]
    for path in dependencies:
        if path not in receipts or digest((source_root/path).read_bytes()) != receipts[path]["sha256"]:
            raise ValueError("Metadata dependency changed: "+path)
    raw = (source_root/dependencies[0]).read_text(encoding="utf-8")
    maps = {"MAP."+key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*[,;]", raw, re.M)}
    raw = (source_root/dependencies[1]).read_text(encoding="utf-8")
    races = {key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*;", raw, re.M)}
    records, sources, omissions, conflicts, rejected = {}, [receipts[path] for path in dependencies], [], [], set()
    for source in sorted(acquisition["files"], key=lambda row: row["path"]):
        path = source["path"]
        if not path.startswith(PREFIX) or not path.endswith(".lua") or "/.config/" in path or path.endswith((".main.lua", ".metadata.lua")):
            continue
        raw = (source_root/path).read_bytes()
        if digest(raw) != source["sha256"]:
            raise ValueError("Authoring input hash changed: "+path)
        rows, skipped = parse(raw.decode("utf-8"), path, maps, races, include_empty=True)
        sources.append(source)
        omissions.extend(skipped)
        for row in rows:
            # This layer establishes metadata, not a second reward parser.
            row.pop("items")
            if row["id"] in rejected:
                continue
            previous = records.get(row["id"])
            if not previous:
                records[row["id"]] = row
                continue
            try:
                joined = merge(dict(previous, items=[]), dict(row, items=[]))
                joined.pop("items")
                records[row["id"]] = joined
            except ValueError as error:
                conflicts.append({"id": row["id"], "reason": str(error), "sources": previous["sources"]+row["sources"]})
                # Sticky across later occurrences: file order cannot restore a
                # restriction after contradictory exact-ID metadata was found.
                rejected.add(row["id"])
                records.pop(row["id"], None)
    for quest in rejected:
        records.pop(quest, None)
    return {"sourceRevision": PIN, "sourceBuild": "1.60.1.69893", "records": sorted(records.values(), key=lambda row: row["id"]), "sources": sources, "omissions": omissions, "conflicts": conflicts, "rejectedIDs": sorted(rejected)}


def compiled_ids(source_root):
    acquisition = json.loads((source_root/"ACQUISITION.json").read_bytes())
    if acquisition["commit"] != PIN:
        raise ValueError("Unexpected compiled-source revision")
    sources, ids, categories, occurrences = [], set(), {}, {}
    for source in acquisition["files"]:
        path = source["path"]
        if not path.startswith("db/Camelot/Categories/") or not path.endswith(".lua"):
            continue
        raw = (source_root/path).read_bytes()
        if digest(raw) != source["sha256"]:
            raise ValueError("Compiled source changed: "+path)
        tokens, found = tokenize(raw.decode("utf-8")), set()
        ends = bounds(tokens)
        for index, (word, _) in enumerate(tokens[:-4]):
            if word == "q" and tokens[index+1][0] == "(" and tokens[index+2][0].isdigit() and tokens[index+3][0] == ",":
                quest = int(tokens[index+2][0])
                found.add(quest)
                if tokens[index+4][0] == "{":
                    props = fields(tokens, ends, index+4)
                    occurrence = {key: literal(tokens, ends, props[key]) for key in ("c", "r", "races") if key in props}
                    occurrences.setdefault(quest, []).append(occurrence)
        categories[Path(path).stem] = sorted(found)
        ids.update(found)
        sources.append(source)
    constraints, conflicts = [], []
    class_names = {1:"WARRIOR",2:"PALADIN",3:"HUNTER",4:"ROGUE",5:"PRIEST",7:"SHAMAN",8:"MAGE",9:"WARLOCK",11:"DRUID"}
    for quest, variants in sorted(occurrences.items()):
        row = {"id": quest}
        for key, target in (("c", "classTokens"), ("r", "faction"), ("races", "races")):
            values = {json.dumps(value[key], sort_keys=True) for value in variants if key in value}
            if not values:
                continue
            if len(values) != 1:
                conflicts.append({"id": quest, "field": key, "values": sorted(values)})
                row["eligibilityConflict"] = True
                continue
            value = json.loads(next(iter(values)))
            if key == "c" and isinstance(value, list) and value and all(type(v) is int and v in class_names for v in value):
                row[target] = sorted({class_names[v] for v in value})
            elif key == "r" and type(value) is int and value in (1, 2):
                row[target] = "Horde" if value == 1 else "Alliance"
            elif key == "races" and isinstance(value, list) and value and all(type(v) is int and v > 0 for v in value):
                row[target] = sorted(set(value))
            else:
                conflicts.append({"id": quest, "field": key, "reason": "Unsupported compiled restriction", "value": value})
                row["eligibilityConflict"] = True
        if len(row) > 1:
            constraints.append(row)
    return {"sourceRevision": PIN, "sourceConfigBuild": "1.60.1.69893", "questIDs": sorted(ids), "categories": categories, "constraints": constraints, "constraintConflicts": conflicts, "sources": sources, "semantics": "Historical compiled identity is not current availability or reward proof"}


def primary_records(cache):
    records, sources = [], []
    decoder = json.JSONDecoder()
    for path in sorted(cache.glob("*.html"), key=lambda path: int(path.stem)):
        quest = int(path.stem)
        raw = path.read_bytes()
        html = raw.decode("utf-8")
        match = re.search(r"\$\.extend\(g_quests\["+str(quest)+r"\],\s*", html)
        if not match or "WH.Gatherer.addData(5, 16" not in html:
            raise ValueError("Cached primary exact Forever record missing: "+str(quest))
        row, _ = decoder.raw_decode(html[match.end():])
        if row.get("id") != quest:
            raise ValueError("Cached primary quest variant mismatch")
        record = {"id": quest, "title": row["name"], "items": [], "itemState": "published" if row.get("itemrewards") or row.get("itemchoices") else "published-empty", "sourceUrl": "https://www.wowhead.com/forever/quest="+str(quest), "sha256": digest(raw)}
        for field, group in (("itemrewards", "guaranteed"), ("itemchoices", "choice")):
            for item, count, *rest in row.get(field, []):
                if type(item) is not int or type(count) is not int or item <= 0 or count <= 0:
                    raise ValueError("Invalid primary item pair")
                record["items"].append({"itemID": item, "quantity": count, "group": group})
        for field, target in (("level", "level"), ("reqlevel", "minimum"), ("xp", "xp"), ("money", "money")):
            if field in row:
                record[target] = row[field]
        record["reputation"] = [{"factionID": faction, "amount": amount} for faction, amount in row.get("reprewards", [])]
        mapper = re.search(r"new Mapper\(", html)
        if mapper:
            data, _ = decoder.raw_decode(html[mapper.end():])
            starters = {}
            for area in data.get("objectives", {}).values():
                for level in area.get("levels", []):
                    for entity in level:
                        if entity.get("point") == "start" and entity.get("type") == 1 and type(entity.get("id")) is int:
                            starters[entity["id"]] = {"npcID": entity["id"], "name": entity.get("name", "NPC "+str(entity["id"]))}
            if starters:
                record["locations"] = sorted(starters.values(), key=lambda row: row["npcID"])
        sources.append({"id": quest, "url": record["sourceUrl"], "sha256": record["sha256"], "bytes": len(raw)})
        records.append(record)
    return {"records": records, "sources": sources, "method": "Retained primary HTML only; no new Wowhead requests, JavaScript execution, or area-ID-to-UI-map guesses"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--att-source-root", type=Path, required=True)
    parser.add_argument("--compiled-root", type=Path, required=True)
    parser.add_argument("--primary-cache", type=Path, required=True)
    parser.add_argument("--client-cache", type=Path, required=True)
    args = parser.parse_args()
    index = json.loads((args.source_root/"index-manifest.json").read_bytes())
    manifest = json.loads((args.source_root/"quest-manifest.json").read_bytes())
    if not index["complete"] or not manifest["complete"]:
        raise ValueError("Complete reconciled public index and detail acquisition required")
    if len(set(index["questIDs"])) != index["expected"] or {row["key"] for row in manifest["sources"]} != set(index["questIDs"]):
        raise ValueError("Public source membership mismatch")
    rows = []
    for source in manifest["sources"]:
        raw = (args.source_root/source["file"]).read_bytes()
        if digest(raw) != source["sha256"]:
            raise ValueError("Detail hash changed: "+source["file"])
        row = quest_detail(raw.decode("utf-8"), source["key"])
        row["source"] = {key: source[key] for key in ("url", "sha256", "bytes")}
        rows.append(row)
        if len(rows) % 500 == 0:
            print(json.dumps({"parsedPublicRecords": len(rows), "expected": index["expected"]}), flush=True)
    public = {"schemaVersion": 1, "collectedAt": manifest["collectedAt"], "source": index["source"], "expected": index["expected"], "indexSources": index["sources"], "paginationRepairs": index["paginationRepairs"], "records": sorted(rows, key=lambda row: row["id"])}
    inputs = {}
    for key, name, value in (("public", "catalog-public-records.json", public), ("metadata", "catalog-metadata-records.json", authoring_metadata(args.att_source_root)), ("compiled", "catalog-compiled-quests.json", compiled_ids(args.compiled_root)), ("primary", "catalog-primary-records.json", primary_records(args.primary_cache)), ("client", "catalog-client-evidence.json", native_ids(args.client_cache))):
        inputs[key] = write(ROOT/"data"/name, value)
    inputs["legacy"] = {"path": "data/catalog-source.json", "sha256": digest((ROOT/"data/catalog-source.json").read_bytes())}
    write(ROOT/"data/catalog-complete-sources.json", {"schemaVersion": 2, "targetBuild": BUILD, "inputs": inputs, "classificationAuthority": "data/primary-statuses.json", "rule": "Union of exact public, compiled, current-cache and approved-classification IDs. Current public item groups supersede historical associations. Retained primary pages independently challenge matching public rows. Missing fields stay unknown. Native cache identity is not decoded reward proof."})
    from complete_catalog import build_complete
    source, report = build_complete(ROOT)
    write(ROOT/"data/catalog-complete-source.json", source)
    write(ROOT/"data/catalog-reconciliation.json", report)
    print(json.dumps(report["counts"], indent=2))


if __name__ == "__main__":
    main()
