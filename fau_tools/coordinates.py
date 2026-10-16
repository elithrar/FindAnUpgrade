"""Recover explicit coordinate-alias ownership, without Lua execution or zipping.

Only an immutable coordinate alias used by an unambiguous singleton starter
can establish ownership. A target must reference that same alias through a
reviewed read-only appendGroups composition with a fresh destination."""

import re

from fau_tools.att import (
    bounds,
    entries,
    fields,
    file_aliases,
    literal,
    preprocess,
    quest_starters,
    tokenize,
)


def alias_leaves(tokens, ends, span):
    if not span:
        return None
    start, stop = span
    if stop == start + 1 and re.fullmatch(r"[A-Z][A-Z_0-9]*", tokens[start][0]):
        return [start]
    if (
        tokens[start][0] == "{"
        and ends.get(start) == stop - 1
        and not entries(tokens, ends, start)
    ):
        return []
    if (
        tokens[start][0] != "appendGroups"
        or start + 1 >= stop
        or tokens[start + 1][0] != "("
        or ends.get(start + 1) != stop - 1
    ):
        return None
    args = entries(tokens, ends, start + 1)
    if not args:
        return None
    # Pinned Shortcuts.lua:588-606 mutates the last argument when there are
    # multiple arguments. Never model an aliased/nonfresh destination as a read.
    if len(args) > 1:
        a, b = args[-1]
        if tokens[a][0] != "appendGroups" and not (
            tokens[a][0] == "{"
            and ends.get(a) == b - 1
            and not entries(tokens, ends, a)
        ):
            return None
    result = []
    for arg in args:
        leaves = alias_leaves(tokens, ends, arg)
        if leaves is None:
            return None
        result.extend(leaves)
    return result


def points(value, maps):
    if not isinstance(value, list) or not value:
        return None
    result = []
    for point in value:
        if (
            not isinstance(point, list)
            or len(point) != 3
            or not all(type(v) in (int, float) and 0 <= v <= 100 for v in point[:2])
        ):
            return None
        map_id = maps.get(point[2]) if isinstance(point[2], str) else point[2]
        if type(map_id) is not int or map_id <= 0:
            return None
        result.append({"mapID": map_id, "x": point[0] / 100, "y": point[1] / 100})
    return result


def recover_file(text, path, maps, scope):
    tokens = tokenize(preprocess(text))
    ends = bounds(tokens)
    calls = []
    reads = set()
    lines = text.splitlines()
    helper_changed = any(
        word in ("_G", "_G.appendGroups", "rawset", "setfenv", "getfenv")
        or word == "appendGroups"
        and (
            index == 0
            or tokens[index - 1][0] == "function"
            or index + 1 >= len(tokens)
            or tokens[index + 1][0] != "("
        )
        for index, (word, _) in enumerate(tokens)
    )
    for index, (word, line) in enumerate(tokens[:-4]):
        if (
            word != "q"
            or tokens[index + 1][0] != "("
            or not tokens[index + 2][0].isdigit()
            or tokens[index + 3][0] != ","
            or tokens[index + 4][0] != "{"
        ):
            continue
        if ends.get(index + 4) != ends.get(index + 1) - 1:
            continue
        quest = int(tokens[index + 2][0])
        props = fields(tokens, ends, index + 4)
        if not 0 < quest < 2**31:
            continue
        calls.append((quest, line, props))
        for key in ("coord", "coords"):
            leaves = alias_leaves(tokens, ends, props.get(key))
            if leaves is not None:
                reads.update(leaves)
        if "qgs" in props:
            start, stop = props["qgs"]
            if tokens[start][0] == "{" and ends.get(start) == stop - 1:
                reads.update(
                    a
                    for a, b in entries(tokens, ends, start)
                    if b == a + 1 and re.fullmatch(r"[A-Z][A-Z_0-9]*", tokens[a][0])
                )
    targets = [call for call in calls if call[0] in scope]
    if not targets:
        return {}, []
    aliases = file_aliases(tokens, ends, reads)
    owners = {}
    anchors = {}
    for quest, line, props in calls:
        span = props.get("coords")
        if not span or span[1] != span[0] + 1:
            continue
        name = tokens[span[0]][0]
        coordinates = points(aliases.get(name), maps)
        if not coordinates:
            continue
        giver = literal(tokens, ends, props.get("qg"), aliases)
        givers = literal(tokens, ends, props.get("qgs"), aliases)
        if "qg" in props and not (type(giver) is int and giver > 0):
            continue
        ids = [giver] if type(giver) is int and giver > 0 else givers
        if "qg" in props and "qgs" in props and givers != [giver]:
            continue
        starters, unknown = quest_starters(tokens, ends, props, lines, aliases)
        if (
            not isinstance(ids, list)
            or not all(type(npc) is int and npc > 0 for npc in ids)
            or len(set(ids)) != 1
            or unknown
        ):
            continue
        npc = ids[0]
        if any(
            "objectID" in starter or "npcID" in starter and starter["npcID"] != npc
            for starter in starters
        ):
            continue
        owners.setdefault(name, set()).add(npc)
        anchors.setdefault(name, []).append(
            {"questID": quest, "path": path, "line": line}
        )
    recovered = {}
    audit = []
    for quest, line, props in targets:
        span = props.get("coords")
        leaves = alias_leaves(tokens, ends, span)
        if "coord" in props and "coords" in props:
            leaves = None
        giver = literal(tokens, ends, props.get("qg"), aliases)
        declared = literal(tokens, ends, props.get("qgs"), aliases)
        target_ids = (
            {giver}
            if type(giver) is int and giver > 0
            else set(declared)
            if isinstance(declared, list)
            and all(type(npc) is int and npc > 0 for npc in declared)
            else set()
        )
        if "qg" in props and (
            not (type(giver) is int and giver > 0)
            or "qgs" in props
            and declared != [giver]
        ):
            target_ids = set()
        record = {"id": quest, "path": path, "line": line}
        if "coord" in props or "coords" in props:
            selected = props.get("coord") or props["coords"]
            record["expression"] = " ".join(
                word for word, _ in tokens[selected[0] : selected[1]]
            )
            record["cause"] = "unassigned-literal-coordinate-list"
        elif any(
            key in props
            for key in ("aqd", "hqd", "allianceQuestData", "hordeQuestData")
        ):
            record["cause"] = "unassigned-faction-branch"
        else:
            record["cause"] = "no-direct-coordinate-field"
        if helper_changed and leaves:
            record["cause"] = "helper-shadow-or-mutation"
        if (
            not helper_changed
            and leaves
            and all(
                len(owners.get(tokens[index][0], ())) == 1
                and points(aliases.get(tokens[index][0]), maps)
                for index in leaves
            )
        ):
            places = []
            proofs = []
            for index in leaves:
                name = tokens[index][0]
                npc = next(iter(owners[name]))
                if npc not in target_ids or ("npcID", npc) not in scope[quest]:
                    break
                places.extend(
                    dict(point, npcID=npc) for point in points(aliases[name], maps)
                )
                proofs.append({"alias": name, "npcID": npc, "anchors": anchors[name]})
            else:
                unique = {tuple(sorted(point.items())): point for point in places}
                recovered.setdefault(quest, []).extend(unique.values())
                record.update(
                    cause="recovered-explicit-coordinate-alias-ownership", proofs=proofs
                )
        audit.append(record)
    return recovered, audit
