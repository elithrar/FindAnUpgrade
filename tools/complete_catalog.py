"""Canonical multi-source quest facts and explicit per-ID coverage accounting."""
from pathlib import Path
from collections import Counter
import hashlib
import json

FIELDS = ("items", "title", "level", "minimum", "xp", "money", "reputation", "currencies", "givers", "coordinates")
METADATA = ("title", "minimum", "maximum", "faction", "classTokens", "races", "eligibilityUnknown", "prerequisites", "prerequisiteCount", "locations", "locationConflict")


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read_inputs(root):
    provenance = json.loads((root/"data/catalog-complete-sources.json").read_bytes())
    if provenance["schemaVersion"] != 2 or provenance["targetBuild"] != "1.60.1.70374":
        raise ValueError("Unsupported comprehensive catalog target")
    inputs = {}
    for key, receipt in provenance["inputs"].items():
        path = (root/receipt["path"]).resolve()
        if not path.is_relative_to((root/"data").resolve()):
            raise ValueError("Input outside owned data directory")
        raw = path.read_bytes()
        if digest(raw) != receipt["sha256"]:
            raise ValueError("Frozen catalog input changed: "+receipt["path"])
        inputs[key] = json.loads(raw)
    return provenance, inputs


def pairs(items):
    return sorted((item["group"], item["itemID"], item["quantity"]) for item in items)


def build_complete(root):
    provenance, inputs = read_inputs(root)
    public = {row["id"]: row for row in inputs["public"]["records"]}
    if len(public) != inputs["public"]["expected"]:
        raise ValueError("Public index was truncated or deduplicated incorrectly")
    metadata = {row["id"]: row for row in inputs["metadata"]["records"]}
    primary = {row["id"]: row for row in inputs["primary"]["records"]}
    legacy = {row["id"]: row for row in inputs["legacy"]["quests"]}
    compiled, native = set(inputs["compiled"]["questIDs"]), set(inputs["client"]["questIDs"])
    constraints = {row["id"]: row for row in inputs["compiled"].get("constraints", [])}
    rejected_metadata = set(inputs["metadata"].get("rejectedIDs", []))
    classification = {row["id"] for row in json.loads((root/"data/primary-statuses.json").read_bytes())["quests"]}
    universe = set(public) | compiled | native | classification | set(legacy)
    rows, gaps, disagreements = [], [], []
    added_pairs, removed_pairs = [], []
    for quest in sorted(universe):
        authored, published, checked = metadata.get(quest, {}), public.get(quest), primary.get(quest)
        row = {key: authored[key] for key in METADATA if key in authored}
        row.update({"id": quest, "items": [], "itemState": "unknown", "confirmation": "historical" if quest in compiled else "unconfirmed"})
        if published:
            for key in ("title", "level", "minimum", "faction", "items", "itemState", "confirmation"):
                if key in published:
                    row[key] = published[key]
            if row.get("faction") == "Both":
                row.pop("faction")
            values = {key: published[key] for key in ("xp", "money", "reputation") if key in published}
            if values:
                row["rewardValues"] = values
        # Compiled restrictions apply independently of successful authoring
        # metadata. Quest 792's authored exclude() expression is unsupported,
        # but its compiled class list still explicitly excludes warlocks.
        constraint = constraints.get(quest, {})
        if constraint.get("eligibilityConflict"):
            row["eligibilityConflict"] = True
        for key in ("classTokens", "faction", "races"):
            if key not in constraint:
                continue
            value = constraint[key]
            if key in row and row[key] != value:
                disagreements.append({"id": quest, "field": key, "compiled": value, "other": row[key]})
                if key in ("classTokens", "races"):
                    value = sorted(set(value) & set(row[key]))
                if key == "faction" or not value:
                    row["eligibilityConflict"] = True
            row[key] = value
        if quest in rejected_metadata and not constraint:
            row["eligibilityConflict"] = True
        for unresolved in authored.get("unresolvedRestrictions", []):
            if {"classes": "classTokens", "races": "races"}[unresolved] not in constraint:
                row["eligibilityConflict"] = True
        # A retained current primary page challenges every corresponding exact
        # source group, rather than replacing an unexplained discrepancy.
        if checked:
            if not published or pairs(checked["items"]) != pairs(published["items"]):
                raise ValueError("Primary/public reward group conflict: "+str(quest))
            for key in ("xp", "money", "level", "minimum"):
                if key in checked and key in published and checked[key] != published[key]:
                    disagreements.append({"id": quest, "field": key, "primary": checked[key], "public": published[key]})
            # AreaTable coordinates in primary Mapper are not native UI maps.
            # Preserve ATT's explicit UI-map locations, enriching exact NPC names.
            if checked.get("locations"):
                existing = [dict(location) for location in row.get("locations", [])]
                for giver in checked["locations"]:
                    matches = [location for location in existing if location.get("npcID") == giver["npcID"]]
                    if matches:
                        for location in matches:
                            location["name"] = giver["name"]
                    else:
                        existing.append(giver)
                row["locations"] = existing
            # Matching order and equal amounts cannot prove faction identity.
            # Retain the public name/amount without guessing a primary ID.
        if quest in native:
            row["clientIdentityRecorded"] = True
        if "level" in row and not (type(row["level"]) is int and 1 <= row["level"] <= 200):
            row.pop("level")  # Level 0/scaled/unsupported does not become level 1.
        if "minimum" in row and not (type(row["minimum"]) is int and 1 <= row["minimum"] <= 200):
            row.pop("minimum")
        # Historical availability constraints are retained as recorded facts;
        # a source row never claims that the quest is currently offered.
        row["eligibilityUnknown"] = True
        states = {field: "unknown" for field in FIELDS}
        states["items"] = row["itemState"]
        if row.get("title"):
            states["title"] = "published" if published and published.get("title") else "recorded"
        if "level" in row:
            states["level"] = "published"
        if "minimum" in row:
            states["minimum"] = "published" if published and "minimum" in published else "recorded"
        for key in ("xp", "money", "reputation"):
            if key in row.get("rewardValues", {}):
                states[key] = "published"
        if row.get("locations"):
            states["givers"] = "recorded"
        if any("mapID" in location for location in row.get("locations", [])):
            states["coordinates"] = "recorded"
        missing = [key for key, state in states.items() if state == "unknown"]
        if missing:
            gap = {"id": quest, "missing": missing, "confirmation": row["confirmation"]}
            if published and published.get("reason"): gap["reason"] = published["reason"]
            gaps.append(gap)
        row["fieldStates"] = states
        old = {item["itemID"] for item in legacy.get(quest, {}).get("items", [])}
        new = {item["itemID"] for item in row["items"]}
        if quest in legacy and row["itemState"] != "unknown":
            added_pairs.extend([quest, item] for item in sorted(new-old))
            removed_pairs.extend([quest, item] for item in sorted(old-new))
        rows.append(row)
    source = {"schemaVersion": 2, "targetBuild": provenance["targetBuild"], "sourceRevision": "public-forever-"+inputs["public"]["collectedAt"][:10], "quests": rows}
    state_counts = Counter(row["itemState"] for row in rows)
    report = {"schemaVersion": 2, "targetBuild": provenance["targetBuild"], "scope": "Every exact quest ID in the complete public index, historical compiled Forever catalog, current official quest cache, approved classifications and previous catalog. Identity is separate from current availability.", "counts": {"quests": len(rows), "publicIndex": len(public), "compiledIdentity": len(compiled), "currentClientCache": len(native), "classificationIds": len(classification), "publishedItemRewards": state_counts["published"], "publishedEmptyItems": state_counts["published-empty"], "unknownItems": state_counts["unknown"], "itemAssociations": sum(len(row["items"]) for row in rows), "distinctItems": len({item["itemID"] for row in rows for item in row["items"]}), "rowsWithGivers": sum(bool(row.get("locations")) for row in rows), "rowsWithCoordinates": sum(any("mapID" in location for location in row.get("locations", [])) for row in rows), "addedLegacyPairs": len(added_pairs), "removedLegacyPairs": len(removed_pairs)}, "publicIdsAbsentOutput": sorted(set(public)-universe), "compiledOnlyIds": sorted(compiled-set(public)), "authoringOnlyCandidates": sorted(set(metadata)-universe), "missingFields": gaps, "fieldCoverage": {field: dict(Counter(row["fieldStates"][field] for row in rows)) for field in FIELDS}, "legacyCorrection": {"addedPairs": added_pairs, "removedPairs": removed_pairs, "unknownLegacyRows": sorted(quest for quest in legacy if quest not in public)}, "sourceDisagreements": disagreements, "metadataConflicts": inputs["metadata"]["conflicts"], "nativeDataLimits": {"questV2FileDataID": 1139443, "questV2": "Encrypted BLTE frame rejected by local-only reader; no keys or partial invented rows", "emptyCurrentTables": ["QuestV2CliTask", "QuestPackageItem", "QuestObjective", "QuestHub"], "cachedQuestRewardLayoutVerified": False}, "acquisitionLimits": {"wowhead": "No new requests: GPTBot disallowed and verification challenge observed; 135 retained exact primary pages reused", "givers": "Public quest reward columns do not encode starter identity. Explicit authored qg/qgs and retained primary start markers only; missing givers are listed per ID.", "currencies": "No complete explicit currency list is exposed by the acquired public source; absence remains unknown"}}
    corrected = {pair[0] for pair in added_pairs+removed_pairs}
    report["counts"].update({
        "rowsWithNpcGivers": sum(any("npcID" in location for location in row.get("locations", [])) for row in rows),
        "rowsWithObjectStarters": sum(any("objectID" in location for location in row.get("locations", [])) for row in rows),
        "rowsWithItemStarters": sum(any("itemID" in location for location in row.get("locations", [])) for row in rows),
        "correctedLegacyQuests": len(corrected),
        "primaryCorroboratedCorrections": len(corrected & set(primary)),
    })
    report["legacyCorrection"]["primaryCheckedQuestIDs"] = sorted(corrected & set(primary))
    report["publicUnconfirmedIDs"] = sorted(quest for quest, row in public.items() if row["confirmation"] == "unconfirmed")
    report["eligibilityConflictIDs"] = [row["id"] for row in rows if row.get("eligibilityConflict")]
    report["metadataOmissions"] = inputs["metadata"]["omissions"]
    report["compiledConstraintConflicts"] = inputs["compiled"]["constraintConflicts"]
    report["repeatedRewardSlots"] = []
    for row in rows:
        for group, item in sorted({(item["group"], item["itemID"]) for item in row["items"]}):
            repeated = [entry for entry in row["items"] if entry["group"] == group and entry["itemID"] == item]
            if len(repeated) > 1:
                report["repeatedRewardSlots"].append({"id":row["id"],"group":group,"itemID":item,"slots":[{"slot":entry["slot"],"quantity":entry["quantity"]} for entry in repeated]})
    report["acquisitionLimits"]["givers"] = "Public reward columns do not encode starters. Explicit authored qg/qgs and top-level typed NPC/object/item providers plus retained primary start markers are recorded; nested objectives and item-source coordinates are not promoted to giver proof. Missing givers remain listed per ID."
    return source, report


def validate_complete(source, provenance, root):
    expected, report = build_complete(root)
    if source != expected:
        raise ValueError("Comprehensive catalog does not reproduce its frozen input reconciliation")
    if provenance != json.loads((root/"data/catalog-complete-sources.json").read_bytes()):
        raise ValueError("Comprehensive provenance mismatch")
    ids = set()
    for row in source["quests"]:
        quest = row["id"]
        if type(quest) is not int or not 0 < quest < 2**31 or quest in ids:
            raise ValueError("Invalid or duplicate comprehensive quest ID")
        ids.add(quest)
        seen = set()
        for item in row["items"]:
            if set(item)-{"itemID", "name", "quantity", "group", "slot"}:
                raise ValueError("Unexpected published item field")
            key = (item["group"], item["slot"])
            if key in seen or key[0] not in ("guaranteed", "choice") or type(key[1]) is not int or key[1] <= 0 or type(item["itemID"]) is not int or item["itemID"] <= 0 or type(item["quantity"]) is not int or item["quantity"] <= 0:
                raise ValueError("Invalid published reward group/quantity")
            seen.add(key)
        if row["itemState"] == "published-empty" and row["items"] or row["itemState"] == "unknown" and row["items"]:
            raise ValueError("Empty/unknown source rewards cannot contain invented items")
    return report
