"""Reconcile exact Forever variants; ordinary checks need only owned frozen data.

Use --website-root once to import a completed website evidence snapshot read-only.
Without it, regenerate from data/classification-source.json and the preserved
baseline. Never expand a title-group label into per-ID classifications.
"""

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATUSES = ("Unchanged", "Updated", "New")
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
        max((r["status"] for r in variants), key=STATUSES.index)
        for variants in grouped.values()
    )
    return {
        "questIdCount": len(rows),
        "exactIdStatuses": {s: exact[s] for s in STATUSES},
        "titleGroupCount": len(grouped),
        "titleGroupStatuses": {s: titles[s] for s in STATUSES},
    }


def import_website(website):
    provenance = website / "quests/provenance"
    names = (
        "forever-confirmed-chart-data.json",
        "forever-confirmed-change-ledger.json",
    )
    raws = {name: (provenance / name).read_bytes() for name in names}
    chart, ledger = (json.loads(raws[name]) for name in names)
    assert chart["schemaVersion"] == 3
    assert ledger["revision"] == chart["datasetRevision"]
    assert ledger["after"] == chart["verification"]
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
                    assert BUCKETS[group["primaryStatus"]] == bucket
                    variants = group["variants"]
                    assert group["ids"] == [v["id"] for v in variants]
                    assert group["name"] == variants[0]["name"]
                    assert group["primaryStatus"] == max(
                        (v["primaryStatus"] for v in variants), key=STATUSES.index
                    )
                    for variant in variants:
                        assert variant["name"] == group["name"]
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
    assert source["schemaVersion"] == 1 and baseline["schemaVersion"] == 1
    receipts = source["receipts"]
    assert isinstance(receipts, list) and len(receipts) == 2, (
        "Expected two distinct classification source receipts"
    )
    assert all(isinstance(r, dict) and isinstance(r.get("file"), str) for r in receipts)
    assert {r["file"] for r in receipts} == RECEIPT_FILES, (
        "Expected one chart and one exclusion-ledger receipt"
    )
    assert all(
        isinstance(r.get("sha256"), str)
        and re.fullmatch(r"[a-fA-F0-9]{64}", r["sha256"])
        and type(r.get("bytes")) is int
        and r["bytes"] > 0
        for r in receipts
    ), "Invalid classification source receipt hash or byte length"
    by_id, category_reports, mixed, projected = {}, [], [], {}
    assert len({c["name"] for c in source["categories"]}) == len(source["categories"])
    for category in source["categories"]:
        rows = category["variants"]
        for row in rows:
            assert type(row["id"]) is int and row["id"] > 0
            assert row["status"] in STATUSES and row["faction"] in FACTIONS["All"]
            assert row["id"] not in by_id, "An exact ID has multiple primary categories"
            assert re.match(
                r"https://www\.wowhead\.com/forever/quest="
                + str(row["id"])
                + r"(?:/|$)",
                row["primaryUrl"],
            )
            assert row["sourceListUrl"].startswith(
                (
                    "https://www.wowhead.com/forever/quests",
                    "https://www.wowhead.com/forever/zone=",
                )
            )
            by_id[row["id"]] = {
                **row,
                "zone": category["name"],
                "zoneId": category["zoneId"],
                "section": category["section"],
                "websiteDisplay": True,
            }
        all_counts = counts(rows)
        assert all_counts["questIdCount"] == category["sourceQuestIdCount"]
        assert all_counts["titleGroupCount"] == category["sourceTitleCounts"]["total"]
        assert all(
            all_counts["titleGroupStatuses"][s]
            == category["sourceTitleCounts"][BUCKETS[s]]
            for s in STATUSES
        )
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
                            (v["status"] for v in variants), key=STATUSES.index
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
                key: {s: sum(v[key][s] for v in values) for s in STATUSES}
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
        assert len(rows) == verified["zoneCount"]
        assert (
            sum(c["projections"]["All"]["questIdCount"] for c in rows)
            == verified["questIds"]
        )
        for status in STATUSES:
            assert (
                sum(c["projections"]["All"]["titleGroupStatuses"][status] for c in rows)
                == verified["titleGroups"][BUCKETS[status]]
            )
    old = {r["id"]: r for r in baseline["quests"]}
    assert len(old) == baseline["questIdCount"] == len(baseline["quests"])
    exclusions = {r["id"]: r for r in source["excludedVariants"]}
    assert len(exclusions) == len(source["excludedVariants"])
    assert not exclusions.keys() & by_id.keys(), (
        "Excluded website variants cannot re-enter website totals"
    )
    shared = old.keys() & by_id.keys()
    assert all(old[q]["status"] == by_id[q]["status"] for q in shared), (
        "Conflicting exact-ID statuses need explicit source resolution"
    )
    retained = []
    for quest in sorted(old.keys() - by_id.keys()):
        exclusion = exclusions[quest]
        assert old[quest]["status"] == exclusion["status"]
        reasons = exclusion["reasons"]
        assert exclusion["faction"] == "Unknown"
        assert (
            isinstance(reasons, list)
            and reasons
            and all(
                isinstance(reason, str) and "Side: None" in reason for reason in reasons
            )
        ), "Retained exclusion requires nonempty exact Side: None evidence"
        assert old[quest]["zone"] == exclusion["zone"]
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
        "statusCounts": {s: status_counts[s] for s in STATUSES},
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--website-root",
        type=Path,
        help="Read-only completed site checkout, needed only for explicit snapshot replacement",
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
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
            assert path.read_bytes() == raw, "Stale classification output: " + path.name
        else:
            path.write_bytes(raw)
    print(
        f"{primary['questIdCount']} classified exact IDs; {primary['websiteQuestIdCount']} website IDs; "
        f"{primary['retainedExcludedQuestIdCount']} retained exclusions; {len(report['categories'])} primary categories"
    )


if __name__ == "__main__":
    main()
