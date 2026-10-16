"""Reproduce the numeric compiled-membership cross-check without executing Lua."""

import argparse
import collections
import hashlib
import json
from pathlib import Path

from fau_tools.att import PIN, bounds, entries, fields, literal, tokenize
from fau_tools.context import ROOT


def extract(text):
    tokens = tokenize(text)
    ends = bounds(tokens)
    pairs = set()
    constraints = collections.defaultdict(list)
    for index, (word, _) in enumerate(tokens):
        if word != "q" or index + 4 >= len(tokens):
            continue
        if (
            tokens[index + 1][0] != "("
            or not tokens[index + 2][0].isdigit()
            or tokens[index + 3][0] != ","
            or tokens[index + 4][0] != "{"
        ):
            continue
        quest = int(tokens[index + 2][0])
        props = fields(tokens, ends, index + 4)
        group = props.get("g")
        if not group or tokens[group[0]][0] != "{":
            continue
        items = []
        for begin, finish in entries(tokens, ends, group[0]):
            words = [v for v, _ in tokens[begin:finish]]
            if len(words) < 4 or words[1] != "(" or ends.get(begin + 1) != finish - 1:
                continue
            if words[0] == "i" and words[2].isdigit():
                items.append(int(words[2]))
            elif (
                words[0] == "s"
                and len(words) > 5
                and words[2].isdigit()
                and words[3] == ","
                and words[4].isdigit()
            ):
                items.append(int(words[4]))
            elif words[0] == "toy" and words[2].isdigit():
                items.append(int(words[2]))
            elif (
                words[0] in ("r", "mnt", "p", "toy")
                and len(words) > 5
                and words[2].isdigit()
                and words[3] == ","
                and words[4] == "{"
            ):
                value = literal(
                    tokens, ends, fields(tokens, ends, begin + 4).get("itemID")
                )
                if type(value) is int and value > 0:
                    items.append(value)
        if items:
            pairs.update((quest, item) for item in items)
            constraints[quest].append(
                {key: literal(tokens, ends, props.get(key)) for key in ("c", "r")}
            )
    return pairs, constraints


def check(source_root, membership):
    if not (
        membership["source"]["revision"] == PIN
        and membership["source"]["generatedBuildStamp"] is None
    ):
        raise AssertionError()
    pairs = set()
    constraints = collections.defaultdict(list)
    for source in membership["sources"]:
        path = (source_root / source["path"]).resolve()
        if not (path.is_relative_to(source_root.resolve())):
            raise AssertionError()
        raw = path.read_bytes()
        if not (hashlib.sha256(raw).hexdigest() == source["sha256"]):
            raise AssertionError()
        if not (
            hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
            == source["gitBlob"]
        ):
            raise AssertionError()
        if (
            source["path"].startswith("db/Camelot/Categories/")
            and path.suffix == ".lua"
        ):
            text = raw.decode("utf-8")
            if not ("_.CreateQuest" in text or "q(" not in text):
                raise AssertionError()
            found, rows = extract(text)
            pairs.update(found)
            for quest, values in rows.items():
                constraints[quest].extend(values)
    result = []
    conflicts = []
    for quest, rows in sorted(constraints.items()):
        row = {"id": quest}
        for key in ("c", "r"):
            values = {
                json.dumps(value[key], sort_keys=True)
                for value in rows
                if value[key] is not None
            }
            if len(values) > 1:
                conflicts.append({"id": quest, "field": key})
                continue
            if values:
                row[key] = json.loads(next(iter(values)))
        if len(row) > 1:
            result.append(row)
    expected = sorted([list(pair) for pair in pairs])
    if not (expected == membership["pairs"]):
        raise AssertionError("Compiled membership changed")
    if not (
        result == membership["constraints"]
        and conflicts == membership["constraintConflicts"]
    ):
        raise AssertionError()
    if not (
        hashlib.sha256(json.dumps(expected, separators=(",", ":")).encode()).hexdigest()
        == membership["pairsSHA256"]
    ):
        raise AssertionError()
    print(
        f"Verified {len(expected)} compiled exact pairs and {len(result)} consistent constraints; no upstream execution"
    )


def main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(
        prog=prog,
        description="Verify exact compiled ATT membership without upstream execution",
    )
    parser.add_argument("--source-root", type=Path, required=True)
    args = parser.parse_args(argv)
    check(
        args.source_root,
        json.loads((ROOT / "data/catalog-compiled-membership.json").read_bytes()),
    )
