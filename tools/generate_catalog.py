"""Validate and deterministically generate QuestBrief's owned reward catalogue."""
from pathlib import Path
import argparse, hashlib, json, re, sys

ROOT = Path(__file__).resolve().parents[1]
PIN = "d75383ccdbff1208b87cf4024fa425c0825a7ad6"
sys.path.insert(0, str(ROOT / "tools"))

def load_inputs(root=ROOT):
    complete = root / "data/catalog-complete-source.json"
    if complete.exists():
        return json.loads(complete.read_bytes()), json.loads((root / "data/catalog-complete-sources.json").read_bytes())
    return json.loads((root / "data/catalog-source.json").read_bytes()), json.loads((root / "data/catalog-sources.json").read_bytes())

def positive(value):
    assert type(value) is int and 0 < value < 2**31, "Invalid exact ID"

def text(value):
    assert isinstance(value, str) and 0 < len(value) <= 100 and all(ord(c) >= 32 for c in value), "Invalid identification label"

def validate(source, provenance):
    if source.get("schemaVersion") == 2:
        from complete_catalog import validate_complete
        validate_complete(source, provenance, ROOT)
        return
    assert source["schemaVersion"] == 1
    assert source["source"] == {"repository": "ATTWoWAddon/AllTheThings", "revision": PIN, "license": "MIT", "clientBuild": "1.60.1.69893"}
    assert provenance["revision"] == PIN and provenance["targetBuild"] == "1.60.1.70374"
    membership=json.loads((ROOT/"data/catalog-compiled-membership.json").read_bytes())
    assert membership["source"]["revision"]==PIN and membership["schemaVersion"]==1
    assert provenance["membershipSha256"]==hashlib.sha256((ROOT/"data/catalog-compiled-membership.json").read_bytes()).hexdigest()
    allowed={tuple(pair) for pair in membership["pairs"]}
    assert len(allowed)==len(membership["pairs"]) and all(len(pair)==2 and all(type(v) is int and v>0 for v in pair) for pair in allowed)
    paths = {row["path"] for row in provenance["files"]}
    assert "LICENSE" in paths
    for row in provenance["files"]:
        assert re.fullmatch(r"[a-f0-9]{64}", row["sha256"]) and re.fullmatch(r"[a-f0-9]{40}", row["gitBlob"])
        assert row["url"].startswith("https://github.com/ATTWoWAddon/AllTheThings/blob/"+PIN+"/")
    excluded = set()
    for omission in provenance["omissions"]:
        assert omission["path"] in paths and isinstance(omission["reason"], str)
        if "itemID" in omission:
            positive(omission["id"]); positive(omission["itemID"])
            assert type(omission["line"]) is int and omission["line"] > 0
            excluded.add((omission["id"], omission["itemID"]))
    assert provenance["excludedRewardPairCount"] == len(excluded)
    ids = set()
    for row in source["quests"]:
        assert set(row) <= {"id", "title", "minimum", "maximum", "faction", "classTokens", "races", "eligibilityUnknown", "prerequisites", "prerequisiteCount", "items", "locations", "locationConflict", "sources"}, "Unexpected quest field"
        positive(row["id"]); assert row["id"] not in ids; ids.add(row["id"])
        if "title" in row: text(row["title"])
        for key in ("minimum", "maximum"):
            if key in row: assert type(row[key]) is int and 1 <= row[key] <= 200
        if "minimum" in row and "maximum" in row: assert row["minimum"] <= row["maximum"], "Inverted level constraint"
        if "faction" in row: assert row["faction"] in ("Alliance", "Horde")
        if "classTokens" in row:
            assert isinstance(row["classTokens"], list) and row["classTokens"] and all(isinstance(c, str) and c in ("WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID") for c in row["classTokens"])
            assert len(set(row["classTokens"])) == len(row["classTokens"]), "Duplicate class constraint"
        if "eligibilityUnknown" in row: assert type(row["eligibilityUnknown"]) is bool
        if "locationConflict" in row: assert type(row["locationConflict"]) is bool
        for key in ("prerequisites", "races"):
            if key in row: assert isinstance(row[key], list) and row[key], "Invalid constraint array"
            for value in row.get(key, []): positive(value); assert key != "prerequisites" or value != row["id"]
            assert len(set(row.get(key, []))) == len(row.get(key, [])), "Duplicate constraint ID"
        if "prerequisiteCount" in row: assert type(row["prerequisiteCount"]) is int and 1 <= row["prerequisiteCount"] <= len(row["prerequisites"])
        assert row["sources"] and all(s["path"] in paths and type(s["line"]) is int and s["line"] > 0 for s in row["sources"])
        assert row["items"] and len(row["items"]) <= 512; item_ids = set()
        for item in row["items"]:
            assert set(item) <= {"itemID", "name", "quantity", "group"}
            positive(item["itemID"]); assert item["itemID"] not in item_ids; item_ids.add(item["itemID"])
            assert (row["id"],item["itemID"]) in allowed, "Association absent from pinned compiled cross-check"
            assert (row["id"],item["itemID"]) not in excluded, "Excluded input/acquisition pair reintroduced"
            if "name" in item: text(item["name"])
            if "quantity" in item: positive(item["quantity"])
            if "group" in item: assert item["group"] in ("guaranteed", "choice")
            # This source only establishes associations. A future observed source
            # needs a schema/provenance update before counts/groups are accepted.
            assert "quantity" not in item and "group" not in item
        for location in row.get("locations", []):
            assert set(location) <= {"npcID", "name", "mapID", "x", "y"}
            positive(location["npcID"])
            if "name" in location: text(location["name"])
            if "mapID" in location:
                positive(location["mapID"])
                assert all(type(location[k]) in (int, float) and 0 <= location[k] <= 1 for k in ("x", "y"))
            else: assert "x" not in location and "y" not in location

def lua(value):
    if isinstance(value, bool): return "true" if value else "false"
    if isinstance(value, (int, float)): return repr(value)
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list): return "{"+",".join(lua(v) for v in value)+"}"
    if isinstance(value, dict): return "{"+",".join(k+"="+lua(value[k]) for k in sorted(value))+"}"
    raise TypeError(type(value))

def render(source, provenance):
    validate(source, provenance)
    if source["schemaVersion"] == 2:
        lines = ["-- Generated by tools/generate_catalog.py; do not edit.",
                 "-- Complete reconciled public Forever identity/reward snapshot plus attributed ATT metadata.",
                 "-- Published base values are separate from current native player rewards.",
                 "-- Unknown reward fields are not zero; item groups retain exact variants and quantities.",
                 "local _,N=...", 'N.CatalogData={schemaVersion=2,questCount='+str(len(source["quests"]))+',sourceRevision="'+source["sourceRevision"]+'",sourceBuild="1.60.1.70374",quests={']
        for row in source["quests"]:
            lines.append("    "+lua({key: value for key, value in row.items() if key != "fieldStates"})+",")
        lines.extend(["}}", ""])
        return "\n".join(lines).encode()
    lines = ["-- Generated by tools/generate_catalog.py; do not edit.",
             "-- ATT-derived numeric facts and short labels: MIT; see Data/ATT-LICENSE.txt.",
             "-- Source build 1.60.1.69893; target 70374. Not current live verification.",
             "-- Recorded associations do not establish reward counts or choice groups.",
             "local _,N=...", 'N.CatalogData={schemaVersion=1,questCount='+str(len(source["quests"]))+',sourceRevision="'+PIN+'",sourceBuild="1.60.1.69893",quests={']
    for row in sorted(source["quests"], key=lambda r: r["id"]):
        lines.append("    "+lua({k: v for k, v in row.items() if k != "sources"})+",")
    lines.extend(["}}", ""])
    return "\n".join(lines).encode()

def coverage(source, output):
    if source["schemaVersion"] == 2:
        from complete_catalog import build_complete
        _, report = build_complete(ROOT)
        rows = source["quests"]
        primary = {row["id"]: row["status"] for row in json.loads((ROOT / "data/primary-statuses.json").read_bytes())["quests"]}
        return {"schemaVersion": 2, "targetBuild": source["targetBuild"], "questCount": len(rows), "itemCount": report["counts"]["distinctItems"], "associationCount": report["counts"]["itemAssociations"],
                "publicIndexCount": report["counts"]["publicIndex"], "publicIdsAbsentOutput": report["publicIdsAbsentOutput"],
                "itemStates": report["fieldCoverage"]["items"], "fieldCoverage": report["fieldCoverage"],
                "questsWithGivers": report["counts"]["rowsWithGivers"], "questsWithNpc": report["counts"]["rowsWithNpcGivers"], "questsWithCoordinates": report["counts"]["rowsWithCoordinates"],
                "knownQuantities": sum("quantity" in item for row in rows for item in row["items"]), "knownRewardGroups": sum("group" in item for row in rows for item in row["items"]),
                "classificationCounts": {key: sum(primary.get(row["id"], "Unknown") == key for row in rows) for key in ("New", "Updated", "Unchanged", "Unknown")},
                "reconciliationReport": "data/catalog-reconciliation.json", "luaSha256": hashlib.sha256(output).hexdigest(),
                "sourceSha256": hashlib.sha256((ROOT / "data/catalog-complete-source.json").read_bytes()).hexdigest(), "liveClientVerified": False}
    rows = source["quests"]; primary = json.loads((ROOT / "data/primary-statuses.json").read_bytes())
    statuses = {q["id"]: q["status"] for q in primary["quests"]}
    return {"schemaVersion": 1, "sourceRevision": PIN, "sourceBuild": "1.60.1.69893", "targetBuild": "1.60.1.70374",
            "questCount": len(rows), "itemCount": len({i["itemID"] for q in rows for i in q["items"]}),
            "associationCount": sum(len(q["items"]) for q in rows),
            "questsWithNpc": sum(bool(q.get("locations")) for q in rows),
            "questsWithCoordinates": sum(any("mapID" in p for p in q.get("locations", [])) for q in rows),
            "questsWithMinimumLevel": sum("minimum" in q for q in rows),
            "questsWithStaticDifficultyLevel": 0, "knownQuantities": 0, "knownRewardGroups": 0,
            "staticMoneyXpCurrencyReputationAmounts": 0,
            "classifiedQuests": sum(q["id"] in statuses for q in rows),
            "classifiedNewQuests": sum(statuses.get(q["id"]) == "New" for q in rows),
            "classificationCounts": {key: sum(statuses.get(q["id"], "Unknown") == key for q in rows) for key in ("New", "Updated", "Unchanged", "Unknown")},
            "factionCounts": {key: sum(q.get("faction", "Unknown") == key for q in rows) for key in ("Alliance", "Horde", "Unknown")},
            "minimumLevelBands": {f"{low}-{high}": sum(low <= q.get("minimum", -1) <= high for q in rows) for low, high in ((1, 10), (11, 20), (21, 30), (31, 40), (41, 50), (51, 60), (61, 200))},
            "luaSha256": hashlib.sha256(output).hexdigest(),
            "sourceSha256": hashlib.sha256((ROOT / "data/catalog-source.json").read_bytes()).hexdigest(),
            "liveClientVerified": False}

def main():
    parser = argparse.ArgumentParser(); parser.add_argument("--check", action="store_true"); args = parser.parse_args()
    source, provenance = load_inputs()
    output = render(source, provenance); report = (json.dumps(coverage(source, output), indent=2)+"\n").encode()
    for path, data in ((ROOT / "QuestBrief/Data/Catalog.lua", output), (ROOT / "data/catalog-coverage.json", report)):
        if args.check: assert path.read_bytes() == data, str(path)+" is stale"
        else: path.write_bytes(data)
    print(report.decode().strip())

if __name__ == "__main__": main()
