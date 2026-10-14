"""Import reviewed ATT Forever authoring facts without executing upstream Lua.

Only exact q(...,{groups={i(...)}}) associations and selected literal fields
are included. Objective providers, starter items, nested vendors and loot are
not rewards. See docs/SEARCH-DATABASE-PLAN.md for scope and source boundaries.
"""
from pathlib import Path
import argparse, hashlib, json, re

ROOT = Path(__file__).resolve().parents[1]
PIN = "d75383ccdbff1208b87cf4024fa425c0825a7ad6"
PREFIX = ".contrib/.db/forever/"
TOKEN = re.compile(r"--\[\[.*?\]\]|--[^\n]*|\[\[.*?\]\]|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'|[A-Za-z_][\w.]*|-?\d+(?:\.\d+)?|[^\s]", re.S)

def preprocess(text):
    """Only the conditions present in this pinned Forever source are supported."""
    states = []; output = []
    tags={"ANYCLASSIC", "FOREVER", "CAMELOT", "CLASSIC", "CRIEVE", "EXPLORATION", "OBJECTIVES", "NOSIMPLIFY"}
    milestones={"TBC":2,"WRATH":3,"CATA":4,"MOP":5,"WOD":6,"LEGION":7,"BFA":8,"TWW":11}
    def condition(value):
        if value.startswith("NOT "): return not condition(value[4:])
        if value in tags: return True
        if value=="SEASON_OF_DISCOVERY": return False
        match=re.fullmatch(r"(BEFORE|AFTER) ([A-Z]+|\d[\d.]*)",value)
        if not match: raise ValueError("Unknown source condition: "+value)
        comparison,version=match.groups()
        if version in milestones: target=(milestones[version],0,0,0)
        else:
            if not re.fullmatch(r"\d[\d.]*",version): raise ValueError("Unknown source version: "+version)
            parts=[int(v) for v in version.rstrip(".").split(".")]; target=tuple((parts+[0]*4)[:4])
        current=(1,60,1,69893)
        return current<target if comparison=="BEFORE" else current>=target
    for line in text.splitlines(keepends=True):
        directive = re.match(r"\s*--\s*#(if|elseif|else|endif)\s*(.*?)\s*$", line, re.I)
        if directive:
            action,value=directive.groups(); action=action.lower()
            if action == "if":
                active=condition(value); states.append([active,active])
            elif action=="elseif":
                assert states; active=not states[-1][1] and condition(value); states[-1]=[active,states[-1][1] or active]
            elif action == "else":
                assert states; states[-1]=[not states[-1][1],True]
            else: assert states; states.pop()
            output.append("\n")
        else: output.append(line if all(state[0] for state in states) else "\n")
    assert not states, "Unclosed source condition"
    return "".join(output)

def tokenize(text):
    result=[]; line=1; position=0
    for match in TOKEN.finditer(text):
        line+=text.count("\n",position,match.start()); word=match.group()
        if not word.startswith("--"): result.append((word,line))
        line+=word.count("\n"); position=match.end()
    return result

def bounds(tokens):
    stack = []; ends = {}; opener = {"}": "{", ")": "(", "]": "["}
    for index, (word, _) in enumerate(tokens):
        if word in ("{", "(", "["): stack.append((word, index))
        elif word in opener:
            assert stack and stack[-1][0] == opener[word], "Unbalanced source delimiters"
            _, start = stack.pop(); ends[start] = index
    assert not stack, "Unclosed source delimiters"
    return ends

def entries(tokens, ends, start):
    index = start + 1; stop = ends[start]; result = []
    while index < stop:
        if tokens[index][0] in (",", ";"): index += 1; continue
        begin = index
        while index < stop and tokens[index][0] not in (",", ";"):
            index = ends[index] + 1 if index in ends else index + 1
        result.append((begin, index))
    return result

def fields(tokens, ends, start):
    out = {}
    for begin, finish in entries(tokens, ends, start):
        if begin+1 < finish and tokens[begin+1][0] == "=":
            assert tokens[begin][0] not in out, "Duplicate selected source field"
            out[tokens[begin][0]] = (begin+2, finish)
        elif begin+3 < finish and tokens[begin][0] == "[" and tokens[begin+2][0] == "]" and tokens[begin+3][0] == "=":
            key=tokens[begin+1][0]
            if re.fullmatch(r'"[A-Za-z_][A-Za-z_0-9]*"',key):
                key=json.loads(key); assert key not in out, "Duplicate selected source field"
                out[key]=(begin+4,finish)
    return out

def literal(tokens, ends, span):
    if not span: return None
    begin, finish = span; words = [word for word, _ in tokens[begin:finish]]
    if len(words) == 1:
        if re.fullmatch(r"-?\d+(?:\.\d+)?", words[0]):
            value = float(words[0]); return int(value) if value.is_integer() else value
        if re.fullmatch(r"[A-Z][A-Z_0-9]*|MAP\.[A-Z_0-9]+", words[0]): return words[0]
    if words and words[0] == "{" and ends[begin] == finish-1:
        values = [literal(tokens, ends, entry) for entry in entries(tokens, ends, begin)]
        return values if all(value is not None for value in values) else None
    return None

def label(lines, line):
    if "--" not in lines[line-1]: return None
    text = lines[line-1].split("--", 1)[1].strip()
    if " / " in text or text.startswith("["): return None
    text = re.sub(r"\s*\[[^\]]*\]|\s*<[^>]*>", "", text).strip()
    text = re.sub(r"\s*\(\d+/\d+\)\s*$", "", text)
    text = re.sub(r"\s*\([A-Z !]+\)\s*$", "", text)
    return text if text and len(text) <= 100 and not any(c in text for c in "<>{}=|") else None

def parse(text, path, maps, race_constants=None):
    text = preprocess(text); lines = text.splitlines(); tokens = tokenize(text); ends = bounds(tokens)
    records = []; omissions = []
    for index, (word, line) in enumerate(tokens):
        if word != "q" or index+4 >= len(tokens): continue
        if tokens[index+1][0] != "(" or not tokens[index+2][0].isdigit() or tokens[index+3][0] != "," or tokens[index+4][0] != "{": continue
        quest = int(tokens[index+2][0]); props = fields(tokens, ends, index+4)
        groups = props.get("groups")
        if not groups or tokens[groups[0]][0] != "{": continue
        items = []
        for begin, finish in entries(tokens, ends, groups[0]):
            words = [w for w, _ in tokens[begin:finish]]
            if len(words) >= 4 and words[0:2] == ["i", "("] and words[2].isdigit() and ends.get(begin+1) == finish-1:
                if words[3] not in (")", ","): continue
                item = {"itemID": int(words[2])}; name = label(lines, tokens[begin][1])
                if name: item["name"] = name
                items.append(item)
        if not items: continue
        unsupported=[]
        for key in ("lvl", "races", "classes", "sourceQuest", "sourceQuests", "sourceQuestNumRequired", "qg", "qgs", "coord", "coords"):
            if key in props and literal(tokens, ends, props[key]) is None:
                unsupported.append(key)
                omissions.append({"id":quest,"path":path,"line":line,"field":key,"reason":("record" if key in ("classes","races") else "field")+" omitted: unsupported selected expression"})
        if any(key in ("classes","races") for key in unsupported): continue
        for key in unsupported: props.pop(key)
        row = {"id": quest, "items": sorted({i["itemID"]: i for i in items}.values(), key=lambda i: i["itemID"]),
               "sources": [{"path": path, "line": line}]}
        if unsupported: row["eligibilityUnknown"]=True
        name = label(lines, line)
        if name: row["title"] = name
        get = lambda key: literal(tokens, ends, props.get(key))
        minimum = get("lvl")
        if type(minimum) is int and 1 <= minimum <= 200: row["minimum"] = minimum
        elif isinstance(minimum, list) and len(minimum) == 2 and all(type(v) is int and 1 <= v <= 200 for v in minimum) and minimum[0] <= minimum[1]: row["minimum"], row["maximum"] = minimum
        races = get("races")
        if races in ("ALLIANCE_ONLY", "HORDE_ONLY"): row["faction"] = "Alliance" if races == "ALLIANCE_ONLY" else "Horde"
        elif isinstance(races, list) and all(isinstance(v, (str, int)) for v in races):
            resolved = [(race_constants or {}).get(v) if isinstance(v, str) else v for v in races]
            if resolved and all(type(v) is int and v > 0 for v in resolved): row["races"] = sorted(set(resolved))
            else: row["eligibilityUnknown"] = True
        elif races is not None: row["eligibilityUnknown"] = True
        classes = get("classes")
        if isinstance(classes, list) and all(isinstance(v, str) and re.fullmatch(r"WARRIOR|PALADIN|HUNTER|ROGUE|PRIEST|SHAMAN|MAGE|WARLOCK|DRUID", v) for v in classes): row["classTokens"] = sorted(set(classes))
        elif "classes" in props: row["eligibilityUnknown"] = True
        prerequisite = get("sourceQuest"); prerequisites = get("sourceQuests")
        values = [prerequisite] if prerequisite is not None else prerequisites
        if isinstance(values, list) and values and all(type(v) is int and v > 0 and v != quest for v in values):
            row["prerequisites"] = sorted(set(values))
            threshold = get("sourceQuestNumRequired")
            if threshold is not None:
                if type(threshold) is int and 1 <= threshold <= len(row["prerequisites"]): row["prerequisiteCount"] = threshold
                else: row.pop("prerequisites"); row["eligibilityUnknown"] = True
        elif values is not None:
            row["eligibilityUnknown"] = True; omissions.append({"id": quest, "path": path, "line": line, "field": "prerequisites", "reason": "invalid, unsupported or self-referential"})
        giver = get("qg"); givers = get("qgs")
        npc_ids = [giver] if type(giver) is int and giver > 0 else givers
        if isinstance(npc_ids, list) and all(type(v) is int and v > 0 for v in npc_ids):
            row["locations"] = [{"npcID": npc} for npc in sorted(set(npc_ids))]
            if len(row["locations"]) == 1 and "qg" in props:
                npc_name = label(lines, tokens[props["qg"][0]][1])
                if npc_name: row["locations"][0]["name"] = npc_name
                coords = get("coord"); multiple = get("coords")
                points = [coords] if coords else multiple
                if isinstance(points, list):
                    places = []
                    for point in points:
                        if isinstance(point, list) and len(point) == 3 and all(type(v) in (int, float) and 0 <= v <= 100 for v in point[:2]):
                            map_id = maps.get(point[2]) if isinstance(point[2], str) else point[2]
                            if type(map_id) is int and map_id > 0:
                                places.append(dict(row["locations"][0], mapID=map_id, x=point[0]/100, y=point[1]/100))
                    if places: row["locations"] = places
        # Conditions, race restrictions and source snapshots never prove availability.
        if any(key in props for key in ("minReputation", "maxReputation", "requireSkill", "isDaily", "isWeekly", "timeline", "altQuests")): row["eligibilityUnknown"] = True
        records.append(row)
    return records, omissions

def merge(a,b):
    """Compatible absence enriches; conflicting known eligibility is rejected."""
    for key in ("minimum","maximum","faction","classTokens","races","prerequisites","prerequisiteCount"):
        if key in a and key in b and a[key]!=b[key]: raise ValueError("Conflicting quest constraint: "+str(a["id"])+" "+key)
    result=dict(a); result.update({k:v for k,v in b.items() if k not in result})
    result["sources"]=a["sources"]+b["sources"]
    result["eligibilityUnknown"]=a.get("eligibilityUnknown",False) or b.get("eligibilityUnknown",False)
    if "title" in a and "title" in b and a["title"]!=b["title"]: result.pop("title",None)
    items={item["itemID"]:dict(item) for item in a["items"]}
    for item in b["items"]:
        if item["itemID"] not in items: items[item["itemID"]]=dict(item)
        elif items[item["itemID"]].get("name")!=item.get("name"): items[item["itemID"]].pop("name",None)
    result["items"]=sorted(items.values(),key=lambda i:i["itemID"])
    locations={json.dumps(loc,sort_keys=True):loc for loc in a.get("locations",[])+b.get("locations",[])}
    if locations: result["locations"]=[locations[key] for key in sorted(locations)]
    if a.get("locations") and b.get("locations") and a["locations"]!=b["locations"]: result["locationConflict"]=True
    return result

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--source-root", type=Path, required=True); args = parser.parse_args()
    acquisition = json.loads((args.source_root / "ACQUISITION.json").read_bytes()); assert acquisition["commit"] == PIN
    maps_path = PREFIX + ".config/constants/maps.lua"
    maps_text = (args.source_root / maps_path).read_text(encoding="utf-8")
    maps = {"MAP."+key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*[,;]", maps_text, re.M)}
    races_path = ".contrib/.db/shared/constants/raceIDs.lua"
    race_text = (args.source_root / races_path).read_text(encoding="utf-8")
    # Only literal numeric race declarations, never conditional faction arrays.
    races = {key: int(value) for key, value in re.findall(r"^\s*([A-Z][A-Z_0-9]*)\s*=\s*(\d+)\s*;", race_text, re.M)}
    membership=json.loads((ROOT/"data/catalog-compiled-membership.json").read_bytes()); assert membership["source"]["revision"]==PIN
    allowed={tuple(pair) for pair in membership["pairs"]}
    constraints={row["id"]:row for row in membership.get("constraints",[])}
    class_names={1:"WARRIOR",2:"PALADIN",3:"HUNTER",4:"ROGUE",5:"PRIEST",7:"SHAMAN",8:"MAGE",9:"WARLOCK",11:"DRUID"}
    merged = {}; sources = []; omitted = []; rejected=set(); pair_omissions=0
    for source in sorted(acquisition["files"], key=lambda s: s["path"]):
        path = source["path"]; raw = (args.source_root / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == source["sha256"]
        if not path.startswith(PREFIX) or not path.endswith(".lua") or "/.config/" in path or path.endswith(".main.lua") or path.endswith(".metadata.lua"): continue
        rows, skips = parse(raw.decode("utf-8"), path, maps, races); omitted.extend(skips)
        if rows: sources.append(source)
        for row in rows:
            row["items"]=[item for item in row["items"] if (row["id"],item["itemID"]) in allowed]
            if not row["items"]: pair_omissions+=1; continue
            if row["id"] in rejected: continue
            constraint=constraints.get(row["id"],{})
            if constraint.get("c"):
                if not all(value in class_names for value in constraint["c"]): row["eligibilityUnknown"]=True
                else:
                    tokens=sorted(class_names[value] for value in constraint["c"])
                    if row.get("classTokens") and not set(tokens).issubset(row["classTokens"]):
                        omitted.append({"id":row["id"],"path":path,"reason":"record omitted: conflicting compiled class constraint"}); continue
                    row["classTokens"]=tokens
            if constraint.get("r") in (1,2):
                faction="Horde" if constraint["r"]==1 else "Alliance"
                if row.get("faction") and row["faction"]!=faction:
                    omitted.append({"id":row["id"],"path":path,"reason":"record omitted: conflicting compiled faction constraint"}); continue
                row["faction"]=faction
            previous = merged.get(row["id"])
            if previous:
                try: merged[row["id"]]=merge(previous,row)
                except ValueError as error:
                    omitted.append({"id":row["id"],"path":path,"reason":str(error)}); rejected.add(row["id"]); merged.pop(row["id"],None)
            else: merged[row["id"]] = row
    snapshot = {"schemaVersion": 1, "source": {"repository": acquisition["repository"], "revision": PIN, "license": "MIT", "clientBuild": "1.60.1.69893"}, "quests": sorted(merged.values(), key=lambda r: r["id"])}
    (ROOT / "data/catalog-source.json").write_bytes((json.dumps(snapshot, indent=2, ensure_ascii=False)+"\n").encode())
    sources.extend(s for s in acquisition["files"] if s["path"] in (maps_path, races_path, "LICENSE", PREFIX+".config/forever.config"))
    provenance = {"revision": PIN, "sourceBuild": "1.60.1.69893", "targetBuild": "1.60.1.70374", "files": sorted(sources, key=lambda s: s["path"]), "omissions": omitted,
                  "membershipSha256":hashlib.sha256((ROOT/"data/catalog-compiled-membership.json").read_bytes()).hexdigest(),"questsAbsentCompiledMembership":pair_omissions,
                  "rule": "Direct authored q groups i() associations intersected with pinned compiled Forever output. No assumed quantity or guaranteed/choice membership. lvl is minimum level; displayed quest levels hydrate natively."}
    (ROOT / "data/catalog-sources.json").write_bytes((json.dumps(provenance, indent=2)+"\n").encode())
    print(f"Imported {len(merged)} exact quests from {len(sources)} pinned inputs; {len(omitted)} field omissions")

if __name__ == "__main__": main()
