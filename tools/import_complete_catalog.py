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

from catalog_html import quest_detail, quest_index_titles, primary_reward_values
from import_catalog import PIN, PREFIX, parse, merge, tokenize, bounds, fields, literal, entries, quest_starters

ROOT = Path(__file__).resolve().parents[1]
BUILD = "1.60.1.70374"


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def source_bytes(root, receipt):
    path=(root/receipt["file"]).resolve()
    if not path.is_relative_to(root.resolve()):raise ValueError("Source receipt path outside cache")
    raw=path.read_bytes()
    if digest(raw)!=receipt["sha256"] or len(raw)!=receipt["bytes"]:raise ValueError("Source hash/size changed: "+receipt["file"])
    return raw


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


def authoring_metadata(source_root, coordinate_scope=None):
    acquisition = json.loads((source_root/"ACQUISITION.json").read_bytes())
    if acquisition["commit"] != PIN:
        raise ValueError("Unexpected ATT source revision")
    receipts = {row["path"]: row for row in acquisition["files"]}
    dependencies = [PREFIX+".config/constants/maps.lua", ".contrib/.db/shared/constants/raceIDs.lua", ".contrib/.db/shared/functions/Shortcuts.lua", ".contrib/.db/shared/.config/root.config", "src/base.lua"]
    for path in dependencies:
        if path not in receipts or digest((source_root/path).read_bytes()) != receipts[path]["sha256"]:
            raise ValueError("Metadata dependency changed: "+path)
    raw = (source_root/dependencies[0]).read_text(encoding="utf-8")
    maps = {"MAP."+key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*[,;]", raw, re.M)}
    raw = (source_root/dependencies[1]).read_text(encoding="utf-8")
    races = {key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*;", raw, re.M)}
    records, sources, omissions, conflicts, rejected = {}, [receipts[path] for path in dependencies], [], [], set()
    recovery=dict(coordinate_scope or {},audit=[],recoveredIDs=[])
    scope={row["id"]:{(key,location[key]) for location in row["starters"] for key in ("npcID","objectID","itemID") if key in location} for row in recovery.get("quests",[])}
    recovered={}
    for source in sorted(acquisition["files"], key=lambda row: row["path"]):
        path = source["path"]
        if not path.startswith(PREFIX) or not path.endswith(".lua") or "/.config/" in path or path.endswith((".main.lua", ".metadata.lua")):
            continue
        raw = (source_root/path).read_bytes()
        if digest(raw) != source["sha256"]:
            raise ValueError("Authoring input hash changed: "+path)
        rows, skipped = parse(raw.decode("utf-8"), path, maps, races, include_empty=True)
        if scope:
            from coordinate_bindings import recover_file
            locations,audit=recover_file(raw.decode("utf-8"),path,maps,scope)
            recovery["audit"].extend(audit)
            for quest,places in locations.items():recovered.setdefault(quest,[]).extend(places)
        sources.append(source)
        omissions.extend(skipped)
        for row in rows:
            # This layer establishes metadata, not a second reward parser.
            row.pop("items")
            if "/.hqt/" in path: row["questKind"] = "hidden-trigger"
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
    for quest,places in recovered.items():
        if quest not in records:continue
        original=records[quest].get("locations",[])
        # Never overwrite a direct recorded point or introduce a new starter.
        if any("mapID" in point for point in original):continue
        places=list({tuple(sorted(point.items())):point for point in places}.values())
        known={(key,point[key]) for point in places for key in ("npcID","objectID","itemID") if key in point}
        records[quest]["locations"]=[point for point in original if not any((key,point.get(key)) in known for key in ("npcID","objectID","itemID"))]+places
        recovery["recoveredIDs"].append(quest)
    recovery["recoveredIDs"].sort()
    for omission in omissions:
        if omission.get("id") in recovery["recoveredIDs"] and omission.get("field") in ("coord","coords"):
            omission["resolvedBy"]="explicit-coordinate-alias-ownership"
    recovery["audit"].sort(key=lambda row:(row["id"],row["path"],row["line"]))
    return {"sourceRevision": PIN, "sourceBuild": "1.60.1.69893", "records": sorted(records.values(), key=lambda row: row["id"]), "sources": sources, "omissions": omissions, "conflicts": conflicts, "rejectedIDs": sorted(rejected),"coordinateRecovery":recovery}


def compiled_coordinates(tokens, ends, span):
    """Strict native-UI-map-keyed compiled coordinates, without source execution."""
    if not span:
        return [], False
    start, stop = span
    if tokens[start][0] != "{" or ends.get(start) != stop-1:
        return [], True
    points = []
    for begin, finish in entries(tokens, ends, start):
        if begin+5 >= finish or tokens[begin][0] != "[" or not tokens[begin+1][0].isdigit() or tokens[begin+2][0] != "]" or tokens[begin+3][0] != "=":
            return [], True
        map_id = int(tokens[begin+1][0])
        coordinates = literal(tokens, ends, (begin+4, finish))
        if map_id <= 0 or not isinstance(coordinates, list) or not coordinates:
            return [], True
        for pair in coordinates:
            if not isinstance(pair, list) or len(pair) != 2 or not all(type(value) in (int, float) and 0 <= value <= 100 for value in pair):
                return [], True
            points.append({"mapID": map_id, "x": pair[0]/100, "y": pair[1]/100})
    return points, False


def compiled_locations(tokens, ends, props, lines):
    givers = literal(tokens, ends, props.get("qgs"))
    valid_givers = isinstance(givers, list) and all(type(value) is int and value > 0 for value in givers)
    locations = [{"npcID": value} for value in sorted(set(givers))] if valid_givers else []
    providers, unresolved = quest_starters(tokens, ends, props, lines)
    points, unknown_points = compiled_coordinates(tokens, ends, props.get("coords"))
    # Explicit qgs identify coordinate ownership when there is exactly one NPC.
    # Object-only providers are also unambiguous. Mixed lists and item-source
    # coordinates must not be paired by list order or multiplied across givers.
    owner = locations[0] if len(locations) == 1 else providers[0] if not locations and len(providers) == 1 and "objectID" in providers[0] else None
    if owner and points:
        assigned = [dict(owner, **point) for point in points]
        if locations: locations = assigned
        else: providers = assigned
    for provider in providers:
        if not any(any(key in provider and provider[key] == row.get(key) for key in ("npcID", "objectID", "itemID")) for row in locations):
            locations.append(provider)
    diagnostic = []
    if unresolved: diagnostic.append("unsupported typed starter expression")
    if "qgs" in props and not valid_givers: diagnostic.append("unsupported compiled qgs")
    if unknown_points: diagnostic.append("unsupported compiled coordinate shape")
    if points and not owner: diagnostic.append("coordinate ownership not established for mixed/multiple/item starters")
    return locations, diagnostic


def compiled_quest_variants(tokens, ends, index):
    call_end=ends.get(index+1)
    if tokens[index+4][0] == "{":
        if ends.get(index+4)!=call_end-1:return []
        return [(fields(tokens,ends,index+4), None)]
    if index+6 >= len(tokens) or tokens[index+4][0] != "_.ResolveQuestData" or tokens[index+5][0] != "(" or tokens[index+6][0] != "{":
        return []
    common=fields(tokens,ends,index+6)
    # Pinned src/base.lua:49-105 selects a faction branch; branch values own
    # their fields and common values fill only absent/false/nil entries.
    if ends.get(index+5)!=call_end-1 or ends.get(index+6)!=call_end-2:return []
    if not all(key in common and tokens[common[key][0]][0] == "{" and ends.get(common[key][0])==common[key][1]-1 for key in ("aqd","hqd")):
        return []
    variants=[]
    for key,faction in (("aqd","Alliance"),("hqd","Horde")):
        props={name:value for name,value in common.items() if name not in ("aqd","hqd")}
        for name,value in fields(tokens,ends,common[key][0]).items():
            if value[1] == value[0]+1 and tokens[value[0]][0] in ("false","nil"):
                continue
            props[name]=value
        variants.append((props,faction))
    return variants


def compiled_ids(source_root):
    acquisition = json.loads((source_root/"ACQUISITION.json").read_bytes())
    if acquisition["commit"] != PIN:
        raise ValueError("Unexpected compiled-source revision")
    sources, ids, categories, occurrences, metadata, npcs, hidden = [], set(), {}, {}, {}, {}, set()
    for source in acquisition["files"]:
        path = source["path"]
        if not path.startswith("db/Camelot/Categories/") or not path.endswith(".lua"):
            continue
        raw = (source_root/path).read_bytes()
        if digest(raw) != source["sha256"]:
            raise ValueError("Compiled source changed: "+path)
        text = raw.decode("utf-8")
        lines = text.splitlines()
        tokens, found = tokenize(text), set()
        ends = bounds(tokens)
        for index, (word, _) in enumerate(tokens):
            if index+3>=len(tokens):continue
            if word=="hqt" and tokens[index+1][0]=="(" and tokens[index+2][0].isdigit() and tokens[index+3][0] in (",",")"):
                quest=int(tokens[index+2][0]);found.add(quest);hidden.add(quest)
            if index+4>=len(tokens):continue
            if word == "n" and tokens[index+1][0] == "(" and tokens[index+2][0].isdigit() and tokens[index+3][0] == "," and tokens[index+4][0] == "{":
                npc = int(tokens[index+2][0])
                props = fields(tokens, ends, index+4)
                points, unsupported = compiled_coordinates(tokens, ends, props.get("coords"))
                if npc > 0 and points and not unsupported:
                    entry = npcs.setdefault(npc,{"npcID":npc,"locations":[],"sources":[]})
                    entry["locations"].extend(point for point in points if point not in entry["locations"])
                    entry["sources"].append({"path":path,"line":tokens[index][1]})
            if word == "q" and tokens[index+1][0] == "(" and tokens[index+2][0].isdigit() and tokens[index+3][0] == ",":
                quest = int(tokens[index+2][0])
                found.add(quest)
                for props, faction in compiled_quest_variants(tokens,ends,index):
                    occurrence = {key: literal(tokens, ends, props[key]) for key in ("c", "r", "races") if key in props}
                    occurrences.setdefault(quest, []).append(occurrence)
                    locations, diagnostic = compiled_locations(tokens, ends, props, lines)
                    if faction:
                        locations=[dict(location,faction=faction) for location in locations]
                    if locations or diagnostic:
                        record = metadata.setdefault(quest, {"id": quest, "locations": [], "sources": [], "diagnostics": []})
                        record["locations"].extend(location for location in locations if location not in record["locations"])
                        record["sources"].append({"path": path, "line": tokens[index][1]})
                        record["diagnostics"].extend(diagnostic)
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
    return {"sourceRevision": PIN, "sourceConfigBuild": "1.60.1.69893", "questIDs": sorted(ids), "hiddenTriggerIDs":sorted(hidden), "categories": categories, "constraints": constraints, "constraintConflicts": conflicts, "metadata": [metadata[quest] for quest in sorted(metadata)], "npcPositions": [npcs[npc] for npc in sorted(npcs)], "sources": sources, "semantics": "Historical compiled identity and explicit metadata are not current availability or reward proof"}


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
        for field, target in (("level", "level"), ("reqlevel", "minimum")):
            if field in row:
                record[target] = row[field]
        record.update(primary_reward_values(row))
        mapper = re.search(r"new Mapper\(", html)
        if mapper:
            data, _ = decoder.raw_decode(html[mapper.end():])
            starters = {}
            for area in data.get("objectives", {}).values():
                for level in area.get("levels", []):
                    for entity in level:
                        if entity.get("point") == "start" and entity.get("type") in (1,2) and type(entity.get("id")) is int and entity["id"]>0:
                            kind = "npcID" if entity["type"] == 1 else "objectID"
                            starters[(kind,entity["id"])] = {kind: entity["id"]}
                            if entity.get("name"): starters[(kind,entity["id"])]["name"] = entity["name"]
            if starters:
                record["locations"] = [starters[key] for key in sorted(starters)]
        sources.append({"id": quest, "url": record["sourceUrl"], "sha256": record["sha256"], "bytes": len(raw)})
        records.append(record)
    return {"records": records, "sources": sources, "method": "Retained primary HTML only; no new Wowhead requests, JavaScript execution, or area-ID-to-UI-map guesses"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--att-source-root", type=Path, required=True)
    parser.add_argument("--compiled-root", type=Path, required=True)
    parser.add_argument("--primary-cache", type=Path, help="Optional retained raw primary pages; default keeps tracked normalized primary facts")
    parser.add_argument("--client-cache", type=Path, help="Optional current 70374 cache; default keeps tracked identity evidence")
    parser.add_argument("--questie-root", type=Path, help="Optional pinned numeric Forever metadata cache; omitted retains owned normalized evidence")
    args = parser.parse_args()
    from complete_catalog import read_inputs
    prior_provenance,prior_inputs=read_inputs(ROOT)
    coordinate_scope={key:value for key,value in prior_inputs["metadata"].get("coordinateRecovery",{}).items() if key not in ("audit","recoveredIDs")}
    if not coordinate_scope:
        from complete_catalog import build_complete
        prior_source,prior_report=build_complete(ROOT)
        ids={row["id"] for row in prior_report["missingFields"] if row["causes"].get("coordinates")=="multiple-or-mixed-starters-without-owned-point"}
        coordinate_scope={"baselineSourceSha256":digest((ROOT/"data/catalog-complete-source.json").read_bytes()),"baselineReportSha256":digest((ROOT/"data/catalog-reconciliation.json").read_bytes()),"rule":"Bounded audit of the 106 mixed-starter coordinate gaps from 0.1.5; explicit immutable alias ownership only, never inferred by name, point equality or list order.","quests":[{"id":row["id"],"starters":[{key:point[key] for key in ("npcID","objectID","itemID") if key in point} for point in row.get("locations",[])]} for row in prior_source["quests"] if row["id"] in ids]}
    compiled_data=compiled_ids(args.compiled_root)
    index = json.loads((args.source_root/"index-manifest.json").read_bytes())
    manifest = json.loads((args.source_root/"quest-manifest.json").read_bytes())
    if not index["complete"] or not manifest["complete"]:
        raise ValueError("Complete reconciled public index and detail acquisition required")
    if len(set(index["questIDs"])) != index["expected"] or {row["key"] for row in manifest["sources"]} != set(index["questIDs"]):
        raise ValueError("Public source membership mismatch")
    if len(manifest["sources"])!=index["expected"]:raise ValueError("Duplicate public source receipts")
    titles={}
    for receipt in index["sources"]:
        titles.update(quest_index_titles(source_bytes(args.source_root,receipt).decode("utf-8")))
    candidates_path=args.source_root/"candidate-manifest.json"
    candidates=json.loads(candidates_path.read_bytes()) if candidates_path.exists() else {"requestedIDs":[],"sources":[],"errors":[],"complete":True}
    if not candidates["complete"] or any(error.get("httpStatus") not in (404,410) for error in candidates["errors"]):raise ValueError("Unresolved candidate acquisition")
    history_path=ROOT/"data/catalog-identity-history.json"
    history_ids=set(prior_inputs.get("history",{}).get("questIDs",[]))
    history_ids.update(row["id"] for row in prior_inputs["public"]["records"]+prior_inputs["legacy"]["quests"])
    history_ids.update(prior_inputs["compiled"]["questIDs"])
    history_ids.update(prior_inputs["client"]["questIDs"])
    history_ids.update(row["id"] for row in json.loads((ROOT/"data/primary-statuses.json").read_bytes())["quests"])
    candidate_ids=set(candidates["requestedIDs"])
    if candidate_ids & set(index["questIDs"]) or not candidate_ids <= history_ids | set(compiled_data["questIDs"]):raise ValueError("Candidates outside previously established identity inventory")
    checked=[row["key"] for row in candidates["sources"]+candidates["errors"]]
    if len(checked)!=len(set(checked)) or set(checked)!=candidate_ids:raise ValueError("Incomplete or duplicate candidate disposition")
    for error in candidates["errors"]:
        if error.get("url")!="https://www.forevervsclassic.com/quests/"+str(error["key"]):raise ValueError("Candidate absence URL does not match exact quest")
    rows = []
    for source in manifest["sources"]+candidates["sources"]:
        if source["url"]!="https://www.forevervsclassic.com/quests/"+str(source["key"]):raise ValueError("Unexpected public detail URL")
        raw = source_bytes(args.source_root,source)
        row = quest_detail(raw.decode("utf-8"), source["key"])
        if row.get("reason") in ("Incomplete public HTML document","Missing or ambiguous Forever panel"):raise ValueError("Incomplete/unsupported public detail: "+str(source["key"]))
        row["source"] = {key: source[key] for key in ("url", "sha256", "bytes")}
        rows.append(row)
        if len(rows) % 500 == 0:
            print(json.dumps({"parsedPublicRecords": len(rows), "expected": index["expected"]}), flush=True)
    if len(rows)!=len({row["id"] for row in rows}):raise ValueError("Duplicate public/candidate detail identity")
    public = {"schemaVersion": 1, "collectedAt": manifest["collectedAt"], "source": index["source"], "expected": len(rows), "indexExpected":index["expected"], "indexSources": index["sources"], "paginationRepairs": index["paginationRepairs"], "records": sorted(rows, key=lambda row: row["id"])}
    inputs = {}
    primary = primary_records(args.primary_cache) if args.primary_cache else prior_inputs["primary"]
    client = native_ids(args.client_cache) if args.client_cache else prior_inputs["client"]
    if args.primary_cache and not primary["records"]: raise ValueError("Explicit primary cache contains no verified exact pages")
    for key, name, value in (("public", "catalog-public-records.json", public), ("metadata", "catalog-metadata-records.json", authoring_metadata(args.att_source_root,coordinate_scope)), ("compiled", "catalog-compiled-quests.json", compiled_data), ("primary", "catalog-primary-records.json", primary), ("client", "catalog-client-evidence.json", client)):
        inputs[key] = write(ROOT/"data"/name, value)
    inputs["legacy"] = {"path": "data/catalog-source.json", "sha256": digest((ROOT/"data/catalog-source.json").read_bytes())}
    for key in ("history", "gaps"):
        if key in prior_provenance["inputs"]: inputs[key]=prior_provenance["inputs"][key]
    def save_provenance():
        write(ROOT/"data/catalog-complete-sources.json", {"schemaVersion": 2, "targetBuild": BUILD, "inputs": inputs, "classificationAuthority": "data/primary-statuses.json", "rule": "Union of exact public, compiled, current-cache and approved-classification IDs. Public item groups own reward associations; pinned supplemental numeric facts add proved missing starters and positions without relaxing source restrictions. Primary exact pages challenge matching rows. Missing fields stay unknown; native cache identity is not decoded reward proof."})
    supplemental=prior_inputs.get("supplemental", {"schemaVersion":1,"source":{},"records":[],"omissions":[],"rules":[]})
    if args.questie_root:
        # Rebuild against the fresh base, never against prior supplemental
        # starters: otherwise the next reparse would discard its own recovery.
        save_provenance()
        from complete_catalog import build_complete
        from questie_metadata import import_metadata, attach_primary_coordinates
        base,_=build_complete(ROOT,include_supplemental=False)
        supplemental=import_metadata(args.questie_root,base["quests"],args.primary_cache,primary if args.primary_cache else None)
        if args.primary_cache:
            primary=attach_primary_coordinates(primary,supplemental)
            inputs["primary"]=write(ROOT/"data/catalog-primary-records.json",primary)
    inputs["supplemental"]=write(ROOT/"data/catalog-supplemental-metadata.json",supplemental)
    history_ids.update(row["id"] for row in rows)
    history_ids.update(compiled_data["questIDs"])
    history_ids.update(client["questIDs"])
    inputs["history"]=write(history_path,{"questIDs":sorted(history_ids),"rule":"Monotonic exact-ID inventory. A vanished public row retains its identity and unknown fields; it does not establish current availability."})
    gaps=[]
    for row in rows:
        if row["itemState"]=="unknown":
            title=titles.get(row["id"],"")
            markers=re.findall(r"<(?:UNUSED|NYI|TXT|TEST)>|\b(?:REUSE|DEPRECATED|DUMMY)\b",title,re.I)
            gaps.append({"id":row["id"],"cause":"unconfirmed-forever-identity","indexTitle":title,"explicitPlaceholderMarkers":markers,"source":row["source"]})
    for error in candidates["errors"]:
        gaps.append({"id":error["key"],"cause":"public-detail-absent","httpStatus":error["httpStatus"],"sourceUrl":error["url"],"checkedAt":error["checkedAt"]})
    old_gaps_path=ROOT/"data/catalog-gap-evidence.json"
    old_gaps=prior_inputs.get("gaps",{})
    inputs["gaps"]=write(old_gaps_path,{"records":sorted(gaps,key=lambda row:row["id"]),"candidateChecksComplete":candidates["complete"],"candidateIDs":candidates["requestedIDs"],"unprovenHeaderContextIDs":old_gaps.get("unprovenHeaderContextIDs",[]),"contextEvidence":old_gaps.get("contextEvidence",[]),"rule":"Explicit source confirmation/absence only. Placeholder labels do not establish removal from the game. Native cache supplies identity, not decoded reward fields."})
    save_provenance()
    from complete_catalog import build_complete
    source, report = build_complete(ROOT)
    write(ROOT/"data/catalog-complete-source.json", source)
    write(ROOT/"data/catalog-reconciliation.json", report)
    print(json.dumps(report["counts"], indent=2))


if __name__ == "__main__":
    main()
