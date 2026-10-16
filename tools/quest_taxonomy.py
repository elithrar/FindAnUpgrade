"""Import only explicit exact-ID quest tags from already receipted primary HTML."""

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = "data/quest-taxonomy.json"
TAGS = {1, 41, 62, 81, 83, 85, 88, 89, 98, 102, 266, 288}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def validate(document, primary):
    if (
        type(document.get("schemaVersion")) is not int
        or document["schemaVersion"] != 1
        or document.get("targetBuild") != "1.60.1.70374"
    ):
        raise ValueError("Unsupported quest taxonomy schema or client")
    owned = {row["id"]: row for row in primary["sources"]}
    if len(owned) != len(primary["sources"]):
        raise ValueError("Ambiguous owned primary source receipt")
    if (
        not isinstance(document.get("records"), list)
        or len(document["records"]) > 12000
    ):
        raise ValueError("Invalid or unbounded quest taxonomy records")
    seen = set()
    for record in document["records"]:
        identity, tag = record.get("id"), record.get("tagID")
        if type(identity) is not int or identity <= 0 or identity in seen:
            raise ValueError("Duplicate or invalid exact taxonomy ID")
        if type(tag) is not int or tag not in TAGS:
            raise ValueError("Unknown explicit quest taxonomy tag")
        source = owned.get(identity)
        if not source or record.get("source") != source:
            raise ValueError("Quest taxonomy receipt differs from owned primary input")
        if (
            source.get("url")
            != "https://www.wowhead.com/forever/quest=" + str(identity)
            or not re.fullmatch(r"[a-f0-9]{64}", source.get("sha256", ""))
            or type(source.get("bytes")) is not int
            or source["bytes"] <= 0
        ):
            raise ValueError("Invalid exact Forever taxonomy receipt")
        seen.add(identity)
    return document


def acquire(cache, primary, previous=None):
    """No network or script execution; partial caches never silently drop facts."""
    if not cache.is_dir():
        raise ValueError("Primary taxonomy cache directory is unavailable")
    # A reparse can update a page receipt without changing its explicit type.
    # Old facts remain individually receipted until that exact page is reread.
    prior = (
        validate(previous, {"sources": [row["source"] for row in previous["records"]]})[
            "records"
        ]
        if previous
        else []
    )
    records = {row["id"]: copy.deepcopy(row) for row in prior}
    sources = {row["id"]: row for row in primary["sources"]}
    for path in sorted(cache.glob("*.html"), key=lambda item: int(item.stem)):
        identity = int(path.stem)
        source = sources.get(identity)
        raw = path.read_bytes()
        if not source or source["sha256"] != digest(raw) or source["bytes"] != len(raw):
            raise ValueError(
                "Raw taxonomy page differs from owned exact primary receipt"
            )
        html = raw.decode("utf-8")
        matches = list(
            re.finditer(r"\$\.extend\(g_quests\[" + str(identity) + r"\],\s*", html)
        )
        if len(matches) != 1 or not re.search(
            r"WH\.Gatherer\.addData\(5,\s*16,\s*\{\s*\"" + str(identity) + r"\"\s*:",
            html,
        ):
            raise ValueError("Missing or ambiguous exact Forever taxonomy object")
        body = html[matches[0].end() :]
        row, end = json.JSONDecoder().raw_decode(body)
        if not body[end:].lstrip().startswith(");"):
            raise ValueError("Malformed exact primary taxonomy assignment")
        if type(row.get("id")) is not int or row["id"] != identity:
            raise ValueError("Taxonomy quest variant mismatch")
        if "type" not in row:
            if identity in records:
                raise ValueError("Previously explicit quest type is now missing")
            continue
        tag = row["type"]
        if type(tag) is not int or tag not in TAGS:
            raise ValueError("Unsupported exact primary type")
        if identity in records and records[identity]["tagID"] != tag:
            raise ValueError("Conflicting explicit quest type requires review")
        records[identity] = {
            "id": identity,
            "tagID": tag,
            "source": copy.deepcopy(source),
        }
    result = {
        "schemaVersion": 1,
        "targetBuild": "1.60.1.70374",
        "method": "Explicit type in exact Forever g_quests[id] object; absent is unknown, never normal. No title, giver, objective or instance-name inference.",
        "records": [records[key] for key in sorted(records)],
    }
    return validate(result, primary)


def load(root=ROOT):
    document = json.loads((root / PATH).read_bytes())
    primary = json.loads((root / "data/catalog-primary-records.json").read_bytes())
    return validate(document, primary)


def render(document):
    return (
        "N.QuestTags = {\n"
        + "".join(
            "    [" + str(row["id"]) + "] = " + str(row["tagID"]) + ",\n"
            for row in sorted(document["records"], key=lambda item: item["id"])
        )
        + "}\n"
    )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--primary-cache", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    path = ROOT / PATH
    if args.primary_cache:
        primary = json.loads((ROOT / "data/catalog-primary-records.json").read_bytes())
        result = acquire(
            args.primary_cache,
            primary,
            json.loads(path.read_bytes()) if path.exists() else None,
        )
        if args.check:
            if json.loads(path.read_bytes()) != result:
                raise ValueError("Owned quest taxonomy is stale")
        else:
            path.write_bytes((json.dumps(result, indent=2) + "\n").encode())
    result = load()
    print(
        str(len(result["records"]))
        + " exact explicit quest tags; "
        + str(sum(row["tagID"] == 81 for row in result["records"]))
        + " Dungeon"
    )


if __name__ == "__main__":
    main()
