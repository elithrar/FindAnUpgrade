"""Import reviewed ATT Forever authoring facts without executing upstream Lua.

Only direct q(...,{groups={i(...)}}) candidates without acquisition/input
semantics and selected literal fields are included. Objective components,
starter items, intermediates, nested vendors and loot are not reward evidence.
See docs/SEARCH-DATABASE-PLAN.md for scope and source boundaries.
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

def literal(tokens, ends, span, aliases=None):
    if not span: return None
    begin, finish = span; words = [word for word, _ in tokens[begin:finish]]
    if len(words) == 1:
        if aliases and words[0] in aliases: return aliases[words[0]]
        if re.fullmatch(r"-?\d+(?:\.\d+)?", words[0]):
            value = float(words[0]); return int(value) if value.is_integer() else value
        if re.fullmatch(r"[A-Z][A-Z_0-9]*|MAP\.[A-Z_0-9]+", words[0]): return words[0]
    if words and words[0] == "{" and ends[begin] == finish-1:
        values = [literal(tokens, ends, entry, aliases) for entry in entries(tokens, ends, begin)]
        return values if all(value is not None for value in values) else None
    return None

def file_aliases(tokens, ends):
    """Resolve immutable literal constants in the unscoped file prefix.

    No Lua is executed. Stop accepting declarations after a block or the first
    quest, and reject names assigned more than once anywhere in the file.
    """
    aliases = {}; declarations = {}; stack = []; prefix = True
    assignments = {}
    for index, (word, _) in enumerate(tokens[:-1]):
        if tokens[index+1][0] == "=": assignments[word] = assignments.get(word, 0) + 1
    for index, (word, _) in enumerate(tokens):
        while stack and ends[stack[-1]] < index: stack.pop()
        if word in ("do", "then", "function", "repeat", "q"): prefix = False
        if prefix and not stack and word == "local" and index+3 < len(tokens):
            name = tokens[index+1][0]
            if (re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", name)
                    and assignments.get(name) == 1 and tokens[index+2][0] == "="):
                start = index+3
                if tokens[start][0] == "{":
                    finish = ends[start]+1
                    if finish < len(tokens) and tokens[finish][0] in ("+", "-", "*", "/", "^", "%", "..", "[", "("): continue
                    value = literal(tokens, ends, (start, finish), aliases)
                    if isinstance(value, list) and value: aliases[name] = value; declarations[name] = index+1
                elif start+1 < len(tokens) and tokens[start+1][0] == ";":
                    value = literal(tokens, ends, (start, start+1), aliases)
                    if type(value) is int and value > 0: aliases[name] = value; declarations[name] = index+1
        if word in ("{", "(", "["): stack.append(index)
    # Permit references only in the selected data fields or typed item tuples.
    # Reject shadow declarations/parameters, indexing, mutation calls and alias
    # escape through another variable; these need full Lua scope interpretation.
    selected = {"lvl", "races", "classes", "sourceQuest", "sourceQuests", "sourceQuestNumRequired", "qg", "qgs", "coord", "coords", "provider", "providers", "cost", "qi", "qis", "qs", "qss"}
    for name in list(aliases):
        for index, (word, _) in enumerate(tokens):
            if word != name or index == declarations[name]: continue
            key = tokens[index-2][0] if index >= 2 and tokens[index-1][0] == "=" else None
            if index >= 4 and key == "]" and tokens[index-4][0] == "[":
                key = tokens[index-3][0].strip('"\'')
            selected_field = key in selected
            typed_item = index >= 2 and tokens[index-1][0] == "," and tokens[index-2][0] in ('"i"', "'i'")
            scalar_item = type(aliases[name]) is int and index >= 2 and tokens[index-1][0] == "(" and tokens[index-2][0] == "i"
            terminal = index+1 == len(tokens) or tokens[index+1][0] in (",", ";", "}", ")")
            if not (selected_field or typed_item or scalar_item) or not terminal:
                aliases.pop(name); break
    return aliases

def item_references(tokens, ends, span, aliases):
    """Read only exact {\"i\", positive-ID, ...} references in selected fields."""
    begin, finish = span; found = set(); unknown = False
    for index in range(begin, finish):
        if tokens[index][0] != "{": continue
        values = entries(tokens, ends, index)
        if len(values) < 2: continue
        first, second = values[0], values[1]
        if first[1] != first[0]+1 or tokens[first[0]][0] not in ('"i"', "'i'"): continue
        item = literal(tokens, ends, second, aliases)
        if type(item) is int and item > 0: found.add(item)
        else: unknown = True
    return found, unknown

def reward_inputs(tokens, ends, start, aliases):
    """Collect objective, issued-item and transitive acquisition components."""
    found = set(); unknown = False
    for index in range(start, ends[start]+1):
        if tokens[index][0] != "{": continue
        props = fields(tokens, ends, index)
        for key in ("provider", "providers", "cost"):
            if key in props:
                items, unresolved = item_references(tokens, ends, props[key], aliases)
                found.update(items); unknown = unknown or unresolved
        for key in ("qi", "qis", "qs", "qss"):
            if key not in props: continue
            value = literal(tokens, ends, props[key], aliases)
            values = value if isinstance(value, list) else [value]
            for item in values:
                if type(item) is int and item > 0: found.add(item)
                else: unknown = True
    return found, unknown

def unresolved_restrictions(tokens, ends, props, aliases, race_constants):
    """Check every exact quest occurrence, including helpers without rewards."""
    invalid = {}
    for key in ("classes", "races"):
        if key not in props: continue
        value = literal(tokens, ends, props[key], aliases)
        if key == "classes":
            valid = isinstance(value, list) and bool(value) and all(isinstance(v, str) and re.fullmatch(r"WARRIOR|PALADIN|HUNTER|ROGUE|PRIEST|SHAMAN|MAGE|WARLOCK|DRUID", v) for v in value)
        else:
            valid = value in ("ALLIANCE_ONLY", "HORDE_ONLY")
            if isinstance(value, str): valid = valid or type(race_constants.get(value)) is int and race_constants[value] > 0
            elif isinstance(value, list):
                resolved = [race_constants.get(v) if isinstance(v, str) else v for v in value]
                valid = bool(resolved) and all(type(v) is int and v > 0 for v in resolved)
        if not valid:
            invalid[key] = "record omitted: unsupported selected expression" if value is None else "record omitted: invalid or unresolved "+("class" if key == "classes" else "race")+" constraint"
    return invalid

def label(lines, line):
    if "--" not in lines[line-1]: return None
    text = lines[line-1].split("--", 1)[1].strip()
    if " / " in text or text.startswith("["): return None
    text = re.sub(r"\s*\[[^\]]*\]|\s*<[^>]*>", "", text).strip()
    text = re.sub(r"\s*\(\d+/\d+\)\s*$", "", text)
    text = re.sub(r"\s*\([A-Z !]+\)\s*$", "", text)
    return text if text and len(text) <= 100 and not any(c in text for c in "<>{}=|") else None

def quest_starters(tokens, ends, props, lines):
    """Only explicit top-level typed quest providers, never nested objectives."""
    result, unresolved = [], False
    for key in ("provider", "providers"):
        span = props.get(key)
        if not span: continue
        begin, finish = span
        if tokens[begin][0] != "{" or ends.get(begin) != finish-1:
            unresolved = True; continue
        groups = [span] if key == "provider" else entries(tokens, ends, begin)
        for start, stop in groups:
            if tokens[start][0] != "{" or ends.get(start) != stop-1:
                unresolved = True; continue
            parts = entries(tokens, ends, start)
            if len(parts) not in (2, 3):
                unresolved = True; continue
            kind_start, kind_stop = parts[0]
            id_start, id_stop = parts[1]
            kind_token = tokens[kind_start][0]
            kind = kind_token.strip("\"'")
            if kind_stop != kind_start+1 or kind_token not in ('"n"', '"o"', '"i"', "'n'", "'o'", "'i'") or id_stop != id_start+1 or not tokens[id_start][0].isdigit() or int(tokens[id_start][0]) <= 0:
                unresolved = True; continue
            field = {"n":"npcID", "o":"objectID", "i":"itemID"}[kind]
            row = {field: int(tokens[id_start][0])}
            name = label(lines, tokens[id_start][1])
            if name: row["name"] = name
            if not any(existing.get(field) == row[field] for existing in result): result.append(row)
    return result, unresolved

def parse(text, path, maps, race_constants=None, include_empty=False):
    text = preprocess(text); lines = text.splitlines(); tokens = tokenize(text); ends = bounds(tokens)
    aliases = file_aliases(tokens, ends)
    records = []; omissions = []
    for index, (word, line) in enumerate(tokens):
        if word != "q" or index+4 >= len(tokens): continue
        if tokens[index+1][0] != "(" or not tokens[index+2][0].isdigit() or tokens[index+3][0] != "," or tokens[index+4][0] != "{": continue
        quest = int(tokens[index+2][0]); props = fields(tokens, ends, index+4)
        invalid_restrictions = unresolved_restrictions(tokens, ends, props, aliases, race_constants or {})
        for key, reason in invalid_restrictions.items():
            omissions.append({"id":quest,"path":path,"line":line,"field":key,"reason":reason})
        groups = props.get("groups")
        if not groups or tokens[groups[0]][0] != "{":
            if not include_empty: continue
            groups = None
        inputs, unknown_inputs = reward_inputs(tokens, ends, index+4, aliases)
        items = []; item_lines = {}
        for begin, finish in entries(tokens, ends, groups[0]) if groups else ():
            words = [w for w, _ in tokens[begin:finish]]
            if len(words) >= 4 and words[0:2] == ["i", "("] and words[2].isdigit() and ends.get(begin+1) == finish-1:
                if words[3] not in (")", ","): continue
                item_id = int(words[2]); item_props = {}
                if words[3] == ",":
                    if len(words) <= 5 or words[4] != "{":
                        omissions.append({"id":quest,"itemID":item_id,"path":path,"line":tokens[begin][1],"reason":"reward pair omitted: unsupported item expression"})
                        continue
                    item_props = fields(tokens, ends, begin+4)
                acquisition = set(item_props) & {"provider", "providers", "cost", "cr", "crs", "coord", "coords", "sourceQuest", "sourceQuests", "requireSkill"}
                reason = None
                if item_id in inputs: reason = "objective, issued-item or acquisition component"
                elif acquisition: reason = "item acquisition fields: " + ", ".join(sorted(acquisition))
                elif unknown_inputs: reason = "unresolved quest item component expression"
                if reason:
                    omissions.append({"id":quest,"itemID":item_id,"path":path,"line":tokens[begin][1],"reason":"reward pair omitted: "+reason})
                    continue
                item = {"itemID": item_id}; name = label(lines, tokens[begin][1])
                if name: item["name"] = name
                items.append(item); item_lines[item_id] = tokens[begin][1]
        if not items and not include_empty: continue
        def omit_restricted_pairs(field):
            for item in items:
                omissions.append({"id":quest,"itemID":item["itemID"],"path":path,"line":item_lines[item["itemID"]],"reason":"reward pair omitted: unresolved quest "+field+" restriction"})
        if invalid_restrictions:
            for key in invalid_restrictions: omit_restricted_pairs(key)
            if not include_empty: continue
            # Metadata-only callers may retain independent literal giver facts.
            # They must resolve these restrictions separately before use.
            unresolved = sorted(invalid_restrictions)
            props = {key: value for key, value in props.items() if key not in invalid_restrictions}
            items = []
        else:
            unresolved = []
        unsupported=[]
        for key in ("lvl", "races", "classes", "sourceQuest", "sourceQuests", "sourceQuestNumRequired", "qg", "qgs", "coord", "coords"):
            if key in props and literal(tokens, ends, props[key], aliases) is None:
                unsupported.append(key)
                omissions.append({"id":quest,"path":path,"line":line,"field":key,"reason":("record" if key in ("classes","races") else "field")+" omitted: unsupported selected expression"})
        invalid_restrictions = [key for key in ("classes","races") if key in unsupported]
        if invalid_restrictions:
            for key in invalid_restrictions: omit_restricted_pairs(key)
            continue
        for key in unsupported: props.pop(key)
        row = {"id": quest, "items": sorted({i["itemID"]: i for i in items}.values(), key=lambda i: i["itemID"]),
               "sources": [{"path": path, "line": line}]}
        if unresolved: row["unresolvedRestrictions"] = unresolved
        if unsupported: row["eligibilityUnknown"]=True
        name = label(lines, line)
        if name: row["title"] = name
        get = lambda key: literal(tokens, ends, props.get(key), aliases)
        minimum = get("lvl")
        if type(minimum) is int and 1 <= minimum <= 200: row["minimum"] = minimum
        elif isinstance(minimum, list) and len(minimum) == 2 and all(type(v) is int and 1 <= v <= 200 for v in minimum) and minimum[0] <= minimum[1]: row["minimum"], row["maximum"] = minimum
        elif "lvl" in props:
            row["eligibilityUnknown"] = True
            omissions.append({"id":quest,"path":path,"line":line,"field":"lvl","reason":"field omitted: invalid level constraint"})
        races = get("races")
        if races in ("ALLIANCE_ONLY", "HORDE_ONLY"): row["faction"] = "Alliance" if races == "ALLIANCE_ONLY" else "Horde"
        # ATT's pinned compiled 93963 row normalizes SKYBORNE_ALLIANCE to {95}.
        # Resolve only declared numeric race constants; unknown names fail closed.
        elif isinstance(races, str) and type((race_constants or {}).get(races)) is int and (race_constants or {})[races] > 0:
            row["races"] = [(race_constants or {})[races]]
        elif isinstance(races, list) and all(isinstance(v, (str, int)) for v in races):
            resolved = [(race_constants or {}).get(v) if isinstance(v, str) else v for v in races]
            if resolved and all(type(v) is int and v > 0 for v in resolved): row["races"] = sorted(set(resolved))
            else:
                omissions.append({"id":quest,"path":path,"line":line,"field":"races","reason":"record omitted: invalid or unresolved race constraint"}); omit_restricted_pairs("races"); continue
        elif "races" in props:
            omissions.append({"id":quest,"path":path,"line":line,"field":"races","reason":"record omitted: invalid or unresolved race constraint"}); omit_restricted_pairs("races"); continue
        classes = get("classes")
        if isinstance(classes, list) and classes and all(isinstance(v, str) and re.fullmatch(r"WARRIOR|PALADIN|HUNTER|ROGUE|PRIEST|SHAMAN|MAGE|WARLOCK|DRUID", v) for v in classes): row["classTokens"] = sorted(set(classes))
        elif "classes" in props:
            omissions.append({"id":quest,"path":path,"line":line,"field":"classes","reason":"record omitted: invalid or unresolved class constraint"}); omit_restricted_pairs("classes"); continue
        prerequisite = get("sourceQuest"); prerequisites = get("sourceQuests")
        values = [prerequisite] if prerequisite is not None else prerequisites
        if "sourceQuestNumRequired" in unsupported:
            omissions.append({"id":quest,"path":path,"line":line,"field":"prerequisites","reason":"group omitted: prerequisite threshold is unresolved"})
        elif isinstance(values, list) and values and all(type(v) is int and v > 0 and v != quest for v in values):
            row["prerequisites"] = sorted(set(values))
            threshold = get("sourceQuestNumRequired")
            if threshold is not None:
                if type(threshold) is int and 1 <= threshold <= len(row["prerequisites"]): row["prerequisiteCount"] = threshold
                else:
                    row.pop("prerequisites"); row["eligibilityUnknown"] = True
                    omissions.append({"id":quest,"path":path,"line":line,"field":"prerequisites","reason":"group omitted: invalid prerequisite threshold"})
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
        if include_empty:
            starters, unknown = quest_starters(tokens, ends, props, lines)
            for starter in starters:
                if not any(any(key in starter and starter[key] == existing.get(key) for key in ("npcID", "objectID", "itemID")) for existing in row.get("locations", [])):
                    row.setdefault("locations", []).append(starter)
            if unknown:
                omissions.append({"id":quest,"path":path,"line":line,"field":"providers","reason":"field omitted: unsupported typed quest starter"})
        # Conditions, race restrictions and source snapshots never prove availability.
        if any(key in props for key in ("minReputation", "maxReputation", "requireSkill", "isDaily", "isWeekly", "isMonthly", "isYearly", "repeatable", "timeline", "altQuests", "lockCriteria", "isBreadcrumb")): row["eligibilityUnknown"] = True
        # Source links can be breadcrumbs, alternatives or character-specific.
        # An imported ID list alone never establishes a server requirement.
        if "prerequisites" in row: row["eligibilityUnknown"] = True
        records.append(row)
    return records, omissions

def merge(a,b):
    """Compatible absence enriches; conflicting known eligibility is rejected."""
    for key in ("minimum","maximum","faction","classTokens","races","prerequisites","prerequisiteCount"):
        if key in a and key in b and a[key]!=b[key]: raise ValueError("Conflicting quest constraint: "+str(a["id"])+" "+key)
    result=dict(a); result.update({k:v for k,v in b.items() if k not in result})
    result["sources"]=a["sources"]+b["sources"]
    result["eligibilityUnknown"]=a.get("eligibilityUnknown",False) or b.get("eligibilityUnknown",False)
    unresolved = sorted(set(a.get("unresolvedRestrictions", [])) | set(b.get("unresolvedRestrictions", [])))
    if unresolved: result["unresolvedRestrictions"] = unresolved
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
    merged = {}; sources = []; omitted = []; rejected=set(); pair_omissions=0; parsed = []
    for source in sorted(acquisition["files"], key=lambda s: s["path"]):
        path = source["path"]; raw = (args.source_root / path).read_bytes()
        assert hashlib.sha256(raw).hexdigest() == source["sha256"]
        if not path.startswith(PREFIX) or not path.endswith(".lua") or "/.config/" in path or path.endswith(".main.lua") or path.endswith(".metadata.lua"): continue
        rows, skips = parse(raw.decode("utf-8"), path, maps, races); omitted.extend(skips)
        if rows or skips: sources.append(source)
        # Eligibility belongs to the quest ID, not to its individual item pairs.
        # Read all occurrences before aggregation so source/file order cannot
        # leave another occurrence's distinct items unrestricted.
        rejected.update(skip["id"] for skip in skips if skip.get("field") in ("classes", "races") and skip["reason"].startswith("record omitted:"))
        parsed.append((path, rows))
    for path, rows in parsed:
        for row in rows:
            for item in row["items"]:
                if (row["id"],item["itemID"]) not in allowed:
                    omitted.append({"id":row["id"],"itemID":item["itemID"],"path":path,"line":row["sources"][0]["line"],"reason":"reward pair omitted: absent from pinned compiled membership"})
            row["items"]=[item for item in row["items"] if (row["id"],item["itemID"]) in allowed]
            if not row["items"]: pair_omissions+=1; continue
            if row["id"] in rejected: continue
            constraint=constraints.get(row["id"],{})
            if constraint.get("c"):
                if not all(value in class_names for value in constraint["c"]):
                    omitted.append({"id":row["id"],"path":path,"reason":"record omitted: unsupported compiled class constraint"}); rejected.add(row["id"]); continue
                else:
                    tokens=sorted(class_names[value] for value in constraint["c"])
                    if row.get("classTokens") and not set(tokens).issubset(row["classTokens"]):
                        omitted.append({"id":row["id"],"path":path,"reason":"record omitted: conflicting compiled class constraint"}); rejected.add(row["id"]); continue
                    row["classTokens"]=tokens
            if constraint.get("r") in (1,2):
                faction="Horde" if constraint["r"]==1 else "Alliance"
                if row.get("faction") and row["faction"]!=faction:
                    omitted.append({"id":row["id"],"path":path,"reason":"record omitted: conflicting compiled faction constraint"}); rejected.add(row["id"]); continue
                row["faction"]=faction
            previous = merged.get(row["id"])
            if previous:
                try: merged[row["id"]]=merge(previous,row)
                except ValueError as error:
                    omitted.append({"id":row["id"],"path":path,"reason":str(error)}); rejected.add(row["id"]); merged.pop(row["id"],None)
            else: merged[row["id"]] = row
    diagnosed = {(row["id"],row["itemID"]) for row in omitted if "itemID" in row}
    for path, rows in parsed:
        for row in rows:
            if row["id"] not in rejected: continue
            merged.pop(row["id"], None)
            for item in row["items"]:
                pair = (row["id"],item["itemID"])
                if pair in diagnosed: continue
                omitted.append({"id":row["id"],"itemID":item["itemID"],"path":path,"line":row["sources"][0]["line"],"reason":"reward pair omitted: quest-wide unresolved or conflicting eligibility restriction"})
                diagnosed.add(pair)
    # A repeated source occurrence must not reintroduce a pair already carrying
    # input/acquisition semantics elsewhere in this same pinned quest record.
    excluded = {(row["id"],row["itemID"]) for row in omitted if "itemID" in row}
    for quest, row in list(merged.items()):
        row["items"] = [item for item in row["items"] if (quest,item["itemID"]) not in excluded]
        if not row["items"]: merged.pop(quest)
    snapshot = {"schemaVersion": 1, "source": {"repository": acquisition["repository"], "revision": PIN, "license": "MIT", "clientBuild": "1.60.1.69893"}, "quests": sorted(merged.values(), key=lambda r: r["id"])}
    (ROOT / "data/catalog-source.json").write_bytes((json.dumps(snapshot, indent=2, ensure_ascii=False)+"\n").encode())
    sources.extend(s for s in acquisition["files"] if s["path"] in (maps_path, races_path, "LICENSE", PREFIX+".config/forever.config"))
    provenance = {"revision": PIN, "sourceBuild": "1.60.1.69893", "targetBuild": "1.60.1.70374", "files": sorted(sources, key=lambda s: s["path"]), "omissions": omitted,
                  "membershipSha256":hashlib.sha256((ROOT/"data/catalog-compiled-membership.json").read_bytes()).hexdigest(),"questsAbsentCompiledMembership":pair_omissions,
                  "excludedRewardPairCount":len(excluded),
                  "rule": "Direct authored q groups i() candidates excluding objective/issued-item/acquisition components and acquisition-bearing item nodes, intersected with pinned compiled Forever output. Each excluded pair is diagnosed. Source prerequisite links remain unconfirmed. No assumed quantity or guaranteed/choice membership. lvl is recorded minimum level; displayed quest levels hydrate natively."}
    (ROOT / "data/catalog-sources.json").write_bytes((json.dumps(provenance, indent=2)+"\n").encode())
    print(f"Imported {len(merged)} exact quests from {len(sources)} pinned inputs; {len(omitted)} diagnostics; {len(excluded)} excluded exact pairs")

if __name__ == "__main__": main()
