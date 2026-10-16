"""Exact-ID classifications, explicit taxonomy, and deterministic Lua projection."""

import argparse
import copy
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

from fau_tools.context import ROOT

# Import classifications.

PRIMARY_STATUSES = ("Unchanged", "Updated", "New")
FACTIONS = {
    "All": {"Alliance", "Horde", "Both"},
    "Alliance": {"Alliance", "Both"},
    "Horde": {"Horde", "Both"},
    "Neutral": {"Both"},
}
BUCKETS = {"Unchanged": "same", "Updated": "tweaked", "New": "new"}
OUTPUTS = ("data/primary-statuses.json", "data/classification-reconciliation.json")
RECEIPT_FILES = {
    "quests/provenance/forever-confirmed-chart-data.json",
    "quests/provenance/forever-confirmed-change-ledger.json",
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def encode(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def counts(rows):
    exact = Counter(row["status"] for row in rows)
    grouped = defaultdict(list)
    for row in rows:
        grouped[row["title"]].append(row)
    titles = Counter(
        max((r["status"] for r in variants), key=PRIMARY_STATUSES.index)
        for variants in grouped.values()
    )
    return {
        "questIdCount": len(rows),
        "exactIdStatuses": {s: exact[s] for s in PRIMARY_STATUSES},
        "titleGroupCount": len(grouped),
        "titleGroupStatuses": {s: titles[s] for s in PRIMARY_STATUSES},
    }


def import_website(website):
    provenance = website / "quests/provenance"
    names = (
        "forever-confirmed-chart-data.json",
        "forever-confirmed-change-ledger.json",
    )
    raws = {name: (provenance / name).read_bytes() for name in names}
    chart, ledger = (json.loads(raws[name]) for name in names)
    if not (chart["schemaVersion"] == 3):
        raise AssertionError()
    if not (ledger["revision"] == chart["datasetRevision"]):
        raise AssertionError()
    if not (ledger["after"] == chart["verification"]):
        raise AssertionError()
    categories = []
    for source_key, section in (("zones", "main"), ("ancillaryZones", "ancillary")):
        for zone in chart[source_key]:
            category = {
                k: zone.get(k)
                for k in (
                    "name",
                    "region",
                    "kind",
                    "parentZone",
                    "sourceUrl",
                    "coverageStatus",
                    "zoneId",
                    "zoneUrl",
                )
            }
            category.update(
                section=section,
                sourceTitleCounts=zone["counts"],
                sourceQuestIdCount=zone["questIdCount"],
                variants=[],
            )
            for bucket, groups in zone["quests"].items():
                for group in groups:
                    if not (BUCKETS[group["primaryStatus"]] == bucket):
                        raise AssertionError()
                    variants = group["variants"]
                    if not (group["ids"] == [v["id"] for v in variants]):
                        raise AssertionError()
                    if not (group["name"] == variants[0]["name"]):
                        raise AssertionError()
                    if not (
                        group["primaryStatus"]
                        == max(
                            (v["primaryStatus"] for v in variants),
                            key=PRIMARY_STATUSES.index,
                        )
                    ):
                        raise AssertionError()
                    for variant in variants:
                        if not (variant["name"] == group["name"]):
                            raise AssertionError()
                        category["variants"].append(
                            {
                                "id": variant["id"],
                                "title": variant["name"],
                                "status": variant["primaryStatus"],
                                "faction": variant["faction"],
                                "level": variant["level"],
                                "requiredLevel": variant["requiredLevel"],
                                "primaryUrl": variant["wowheadForeverUrl"],
                                "sourceListUrl": variant["sourceListUrl"],
                            }
                        )
            category["variants"].sort(key=lambda row: row["id"])
            categories.append(category)
    excluded = []
    for entry in ledger["removedVariants"]:
        record = entry["originalRecord"]
        excluded.append(
            {
                "id": entry["id"],
                "title": entry["title"],
                "zone": entry["zone"],
                "section": entry["section"],
                "status": record["primaryStatus"],
                "faction": record["faction"],
                "reasons": entry["reasons"],
                "primaryUrl": record.get("wowheadForeverUrl"),
                "sourceListUrl": record.get("sourceListUrl"),
            }
        )
    return {
        "schemaVersion": 1,
        "datasetRevision": chart["datasetRevision"],
        "collectedAt": chart["collectedAt"],
        "primarySource": chart["primarySource"],
        "scope": chart["scope"],
        "methodology": chart["methodology"],
        "receipts": [
            {
                "file": "quests/provenance/" + name,
                "sha256": sha(raws[name]),
                "bytes": len(raws[name]),
            }
            for name in names
        ],
        "sourceVerification": chart["verification"],
        "categories": categories,
        "excludedVariants": sorted(excluded, key=lambda row: row["id"]),
    }


def reconcile(source, baseline, baseline_raw):
    if not (source["schemaVersion"] == 1 and baseline["schemaVersion"] == 1):
        raise AssertionError()
    receipts = source["receipts"]
    if not (isinstance(receipts, list) and len(receipts) == 2):
        raise AssertionError("Expected two distinct classification source receipts")
    if not (
        all(isinstance(r, dict) and isinstance(r.get("file"), str) for r in receipts)
    ):
        raise AssertionError()
    if not ({r["file"] for r in receipts} == RECEIPT_FILES):
        raise AssertionError("Expected one chart and one exclusion-ledger receipt")
    if not (
        all(
            isinstance(r.get("sha256"), str)
            and re.fullmatch(r"[a-fA-F0-9]{64}", r["sha256"])
            and type(r.get("bytes")) is int
            and r["bytes"] > 0
            for r in receipts
        )
    ):
        raise AssertionError(
            "Invalid classification source receipt hash or byte length"
        )
    by_id, category_reports, mixed, projected = {}, [], [], {}
    if not (
        len({c["name"] for c in source["categories"]}) == len(source["categories"])
    ):
        raise AssertionError()
    for category in source["categories"]:
        rows = category["variants"]
        for row in rows:
            if not (type(row["id"]) is int and row["id"] > 0):
                raise AssertionError()
            if not (
                row["status"] in PRIMARY_STATUSES and row["faction"] in FACTIONS["All"]
            ):
                raise AssertionError()
            if not (row["id"] not in by_id):
                raise AssertionError("An exact ID has multiple primary categories")
            if not (
                re.match(
                    r"https://www\.wowhead\.com/forever/quest="
                    + str(row["id"])
                    + r"(?:/|$)",
                    row["primaryUrl"],
                )
            ):
                raise AssertionError()
            if not (
                row["sourceListUrl"].startswith(
                    (
                        "https://www.wowhead.com/forever/quests",
                        "https://www.wowhead.com/forever/zone=",
                    )
                )
            ):
                raise AssertionError()
            by_id[row["id"]] = {
                **row,
                "zone": category["name"],
                "zoneId": category["zoneId"],
                "section": category["section"],
                "websiteDisplay": True,
            }
        all_counts = counts(rows)
        if not (all_counts["questIdCount"] == category["sourceQuestIdCount"]):
            raise AssertionError()
        if not (
            all_counts["titleGroupCount"] == category["sourceTitleCounts"]["total"]
        ):
            raise AssertionError()
        if not (
            all(
                all_counts["titleGroupStatuses"][s]
                == category["sourceTitleCounts"][BUCKETS[s]]
                for s in PRIMARY_STATUSES
            )
        ):
            raise AssertionError()
        projections = {
            name: counts([r for r in rows if r["faction"] in factions])
            for name, factions in FACTIONS.items()
        }
        category_reports.append(
            {
                "name": category["name"],
                "section": category["section"],
                "region": category["region"],
                "kind": category["kind"],
                "zoneId": category["zoneId"],
                "sourceUrl": category["sourceUrl"],
                "projections": projections,
            }
        )
        groups = defaultdict(list)
        for row in rows:
            groups[row["title"]].append(row)
        for title, variants in groups.items():
            if len({v["status"] for v in variants}) > 1:
                mixed.append(
                    {
                        "zone": category["name"],
                        "title": title,
                        "titleGroupStatus": max(
                            (v["status"] for v in variants), key=PRIMARY_STATUSES.index
                        ),
                        "variants": [
                            {k: v[k] for k in ("id", "status", "faction")}
                            for v in variants
                        ],
                    }
                )
    for name in FACTIONS:
        values = [c["projections"][name] for c in category_reports]
        projected[name] = {
            "questIdCount": sum(v["questIdCount"] for v in values),
            "titleGroupCount": sum(v["titleGroupCount"] for v in values),
            **{
                key: {s: sum(v[key][s] for v in values) for s in PRIMARY_STATUSES}
                for key in ("exactIdStatuses", "titleGroupStatuses")
            },
        }
    for section in ("main", "ancillary", "combined"):
        rows = [
            c
            for c in category_reports
            if section == "combined" or c["section"] == section
        ]
        verified = source["sourceVerification"][section]
        if not (len(rows) == verified["zoneCount"]):
            raise AssertionError()
        if not (
            sum(c["projections"]["All"]["questIdCount"] for c in rows)
            == verified["questIds"]
        ):
            raise AssertionError()
        for status in PRIMARY_STATUSES:
            if not (
                sum(c["projections"]["All"]["titleGroupStatuses"][status] for c in rows)
                == verified["titleGroups"][BUCKETS[status]]
            ):
                raise AssertionError()
    old = {r["id"]: r for r in baseline["quests"]}
    if not (len(old) == baseline["questIdCount"] == len(baseline["quests"])):
        raise AssertionError()
    exclusions = {r["id"]: r for r in source["excludedVariants"]}
    if not (len(exclusions) == len(source["excludedVariants"])):
        raise AssertionError()
    if not (not exclusions.keys() & by_id.keys()):
        raise AssertionError("Excluded website variants cannot re-enter website totals")
    shared = old.keys() & by_id.keys()
    if not (all(old[q]["status"] == by_id[q]["status"] for q in shared)):
        raise AssertionError(
            "Conflicting exact-ID statuses need explicit source resolution"
        )
    retained = []
    for quest in sorted(old.keys() - by_id.keys()):
        exclusion = exclusions[quest]
        if not (old[quest]["status"] == exclusion["status"]):
            raise AssertionError()
        reasons = exclusion["reasons"]
        if not (exclusion["faction"] == "Unknown"):
            raise AssertionError()
        if not (
            isinstance(reasons, list)
            and reasons
            and all(
                isinstance(reason, str) and "Side: None" in reason for reason in reasons
            )
        ):
            raise AssertionError(
                "Retained exclusion requires nonempty exact Side: None evidence"
            )
        if not (old[quest]["zone"] == exclusion["zone"]):
            raise AssertionError()
        row = {
            **old[quest],
            "websiteDisplay": False,
            "faction": "Unknown",
            "exclusionReasons": exclusion["reasons"],
            "primaryUrl": exclusion["primaryUrl"],
            "sourceListUrl": exclusion["sourceListUrl"],
        }
        retained.append(row)
    union = sorted([*by_id.values(), *retained], key=lambda row: row["id"])
    status_counts = Counter(r["status"] for r in union)
    primary = {
        "schemaVersion": 2,
        "version": "2",
        "sourceFilename": "classification-source.json",
        "collectedAt": source["collectedAt"],
        "datasetRevision": source["datasetRevision"],
        "rule": "Only exact variants[].primaryStatus; New maps to verifiedNew. No title-group propagation or secondary databaseNEW. Website faction exclusions do not erase previously verified exact-ID status or establish current availability.",
        "zoneCount": len(category_reports),
        "titleGroupCount": projected["All"]["titleGroupCount"],
        "titleGroupScope": "Website display categories only; retained excluded IDs are not counted as website title groups.",
        "questIdCount": len(union),
        "websiteQuestIdCount": len(by_id),
        "retainedExcludedQuestIdCount": len(retained),
        "statusCounts": {s: status_counts[s] for s in PRIMARY_STATUSES},
        "sources": {
            "websiteReceipts": source["receipts"],
            "normalized": {
                "file": "data/classification-source.json",
                "sha256": sha(encode(source)),
            },
            "baseline": {
                "file": "data/classification-baseline.json",
                "sha256": sha(baseline_raw),
                "libraryFileId": baseline["libraryFileId"],
                "version": baseline["version"],
            },
        },
        "categories": [
            {k: c[k] for k in ("name", "section", "region", "kind", "zoneId")}
            for c in source["categories"]
        ],
        "quests": union,
    }
    report = {
        "schemaVersion": 1,
        "datasetRevision": source["datasetRevision"],
        "countingUnits": {
            "exactIds": "Each retained ID once in its primary quest category; status remains per variant.",
            "titleGroups": "Matching titles within one category, regrouped after faction filtering; New > Updated > Unchanged.",
            "zone": "Primary quest category, not a giver coordinate map or a claim of beta availability.",
        },
        "website": {
            "mainCategoryCount": sum(c["section"] == "main" for c in category_reports),
            "ancillaryCategoryCount": sum(
                c["section"] == "ancillary" for c in category_reports
            ),
            "projections": projected,
            "mixedStatusTitleGroupCount": len(mixed),
        },
        "baseline": {
            "questIdCount": len(old),
            "sharedWebsiteQuestIdCount": len(shared),
            "statusDisagreements": [],
            "newlyClassifiedWebsiteQuestIdCount": len(by_id.keys() - old.keys()),
            "retainedExcludedQuestIdCount": len(retained),
        },
        "union": {"questIdCount": len(union), "statusCounts": primary["statusCounts"]},
        "retainedWebsiteExclusions": retained,
        "categories": category_reports,
        "mixedStatusTitleGroups": mixed,
    }
    return primary, report


def import_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog, description=__doc__)
    parser.add_argument(
        "--website-root",
        type=Path,
        help="Read-only completed site checkout, needed only for explicit snapshot replacement",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if args.check and args.website_root:
        parser.error("--check uses owned inputs only; omit --website-root")
    source_path = ROOT / "data/classification-source.json"
    source = (
        import_website(args.website_root.resolve())
        if args.website_root
        else json.loads(source_path.read_bytes())
    )
    baseline_raw = (ROOT / "data/classification-baseline.json").read_bytes()
    primary, report = reconcile(source, json.loads(baseline_raw), baseline_raw)
    candidates = {source_path: encode(source)} if args.website_root else {}
    candidates.update(
        {ROOT / name: encode(value) for name, value in zip(OUTPUTS, (primary, report))}
    )
    for path, raw in candidates.items():
        if args.check:
            if not (path.read_bytes() == raw):
                raise AssertionError("Stale classification output: " + path.name)
        else:
            path.write_bytes(raw)
    print(
        f"{primary['questIdCount']} classified exact IDs; {primary['websiteQuestIdCount']} website IDs; "
        f"{primary['retainedExcludedQuestIdCount']} retained exclusions; {len(report['categories'])} primary categories"
    )


# Quest taxonomy.

PATH = "data/quest-taxonomy.json"
TAGS = {1, 41, 62, 81, 83, 85, 88, 89, 98, 102, 266, 288}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def validate_taxonomy(document, primary):
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
        validate_taxonomy(
            previous, {"sources": [row["source"] for row in previous["records"]]}
        )["records"]
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
    return validate_taxonomy(result, primary)


def load_taxonomy(root=ROOT):
    document = json.loads((root / PATH).read_bytes())
    primary = json.loads((root / "data/catalog-primary-records.json").read_bytes())
    return validate_taxonomy(document, primary)


def render_taxonomy(document):
    return (
        "N.QuestTags = {\n"
        + "".join(
            "    [" + str(row["id"]) + "] = " + str(row["tagID"]) + ",\n"
            for row in sorted(document["records"], key=lambda item: item["id"])
        )
        + "}\n"
    )


def taxonomy_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog)
    parser.add_argument("--primary-cache", type=Path)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
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
    result = load_taxonomy()
    print(
        str(len(result["records"]))
        + " exact explicit quest tags; "
        + str(sum(row["tagID"] == 81 for row in result["records"]))
        + " Dungeon"
    )


# Generate data.


LUA_STATUSES = {
    "New": "verifiedNew",
    "Updated": "verifiedUpdated",
    "Unchanged": "verifiedUnchanged",
}


def lua(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, dict):
        return "{" + ",".join(k + "=" + lua(v) for k, v in value.items()) + "}"
    raise TypeError(type(value))


def render_quests(source, taxonomy=None):
    if not (source["schemaVersion"] == 2 and source["version"] == "2"):
        raise AssertionError()
    rows = source["quests"]
    if not (len(rows) == source["questIdCount"] == len({r["id"] for r in rows})):
        raise AssertionError()
    if not (
        all(
            type(r["id"]) is int and r["id"] > 0 and r["status"] in LUA_STATUSES
            for r in rows
        )
    ):
        raise AssertionError()
    actual = Counter(row["status"] for row in rows)
    if not ({s: actual[s] for s in source["statusCounts"]} == source["statusCounts"]):
        raise AssertionError()
    included = [r for r in rows if r["websiteDisplay"]]
    excluded = [r for r in rows if not r["websiteDisplay"]]
    if not (len(included) == source["websiteQuestIdCount"]):
        raise AssertionError()
    if not (len(excluded) == source["retainedExcludedQuestIdCount"]):
        raise AssertionError()
    categories = defaultdict(list)
    metadata = {c["name"]: c for c in source["categories"]}
    if not (len(metadata) == source["zoneCount"]):
        raise AssertionError()
    for name in metadata:
        categories[name] = []
    for row in included:
        if row["zone"] not in metadata:
            raise AssertionError()
        categories[row["zone"]].append(row)
    if not (len(categories) == source["zoneCount"]):
        raise AssertionError()
    category_ids = {name: index for index, name in enumerate(sorted(categories), 1)}
    new_count = actual["New"]
    lines = [
        "-- Generated by tools/generate_data.py from per-ID primary evidence.",
        "-- Category totals count website display variants; exclusions retain status only.",
        "-- Primary quest categories are not giver maps or availability assertions.",
        "local _, N = ...",
        "N.Data = { collectedAt = "
        + lua(source["collectedAt"])
        + ", newCount = "
        + str(new_count)
        + ", questCount = "
        + str(len(rows))
        + ", statusById = {",
    ]
    for row in sorted(rows, key=lambda r: r["id"]):
        lines.append(f'    [{row["id"]}] = "{LUA_STATUSES[row["status"]]}",')
    lines.append("}, categories = {")
    total_titles = 0
    for name in sorted(categories):
        variants = categories[name]
        grouped = defaultdict(list)
        for row in variants:
            grouped[row["title"]].append(row["status"])
        rank = {"Unchanged": 0, "Updated": 1, "New": 2}
        title_counts = Counter(
            max(statuses, key=rank.get) for statuses in grouped.values()
        )
        exact_counts = Counter(r["status"] for r in variants)
        total_titles += len(grouped)
        first = metadata[name]
        summary = {
            "name": name,
            "section": first["section"],
            "region": first["region"],
            "kind": first["kind"],
            "sourceZoneID": first["zoneId"],
            "questIdCount": len(variants),
            "titleGroupCount": len(grouped),
            "exactIdStatuses": {
                s: exact_counts[s] for s in ("Unchanged", "Updated", "New")
            },
            "titleGroupStatuses": {
                s: title_counts[s] for s in ("Unchanged", "Updated", "New")
            },
        }
        lines.append("    " + lua(summary) + ",")
    if not (total_titles == source["titleGroupCount"]):
        raise AssertionError()
    lines.append("}, categoryById = {")
    for row in sorted(included, key=lambda r: r["id"]):
        lines.append(f"    [{row['id']}] = {category_ids[row['zone']]},")
    lines.append("}, websiteExcludedById = {")
    for row in sorted(excluded, key=lambda r: r["id"]):
        lines.append(
            f"    [{row['id']}] = "
            + lua({"reason": "sideNone", "zone": row["zone"]})
            + ","
        )
    lines.extend(["} }", ""])
    if taxonomy is not None:
        lines.extend(
            [
                "-- Explicit receipted quest tags are separate from classification status.",
                render_taxonomy(taxonomy),
            ]
        )
    return "\n".join(lines)


def quests_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    raw = (ROOT / "data/primary-statuses.json").read_bytes()
    source = json.loads(raw)
    output = render_quests(source, load_taxonomy(ROOT)).encode()
    path = ROOT / "FindAnUpgrade/Data/Quests.lua"
    if args.check:
        if not (path.read_bytes() == output):
            raise AssertionError("Generated classification table is stale")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(output)
    print(
        f"{source['questIdCount']} exact IDs; {source['statusCounts']['New']} verifiedNew; "
        f"{source['zoneCount']} categories; primary evidence SHA256 {hashlib.sha256(raw).hexdigest()}"
    )
