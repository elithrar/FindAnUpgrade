"""Canonical multi-source quest facts and explicit per-ID coverage accounting."""
from pathlib import Path
from collections import Counter
import hashlib
import json

FIELDS = ("items", "title", "level", "minimum", "xp", "money", "reputation", "currencies", "givers", "coordinates")
METADATA = ("title", "minimum", "maximum", "faction", "classTokens", "races", "eligibilityUnknown", "prerequisites", "prerequisiteCount", "locations", "locationConflict", "questKind")


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


def entity(location):
    return next(((key, location[key]) for key in ("npcID", "objectID", "itemID") if key in location), None)


def location_scope_matches(location, incoming):
    return entity(location) == entity(incoming) and (location.get("faction") == incoming.get("faction") or location.get("faction") is None)


def enrich_locations(row, compiled, disagreements):
    existing = [dict(location) for location in row.get("locations", [])]
    originals = [dict(location) for location in existing]
    qualified={entity(location) for location in compiled.get("locations",[]) if location.get("faction")}
    for key in qualified:
        incoming=[location for location in compiled["locations"] if entity(location)==key]
        if any(not location.get("faction") for location in incoming):continue
        scopes=sorted({location["faction"] for location in incoming})
        existing=[dict(location,faction=faction) for location in existing for faction in (scopes if entity(location)==key and not location.get("faction") else [location.get("faction")])]
        for location in existing:
            if location.get("faction") is None:location.pop("faction",None)
    originals=[dict(location) for location in existing]
    recorded_entities = {entity(location) for location in existing}
    incoming_entities = {entity(location) for location in compiled.get("locations", [])}
    conflicting = {(entity(incoming),incoming.get("faction")) for incoming in compiled.get("locations",[]) if not any(entity(old)==entity(incoming) and (not old.get("faction") or not incoming.get("faction") or old["faction"]==incoming["faction"]) for old in originals) and any(entity(old)[0]==entity(incoming)[0] and (not old.get("faction") or not incoming.get("faction") or old["faction"]==incoming["faction"]) for old in originals)}
    if conflicting:
        disagreements.append({"id": row["id"], "field": "starters", "authoring": sorted(recorded_entities), "compiled": sorted(incoming_entities)})
    for incoming in compiled.get("locations", []):
        key = entity(incoming)
        # Missing authoring can be expanded from the compiled exact q record.
        # A different source giver is diagnostic, never a guessed extra NPC.
        if (key,incoming.get("faction")) in conflicting:
            continue
        matching = [location for location in existing if location_scope_matches(location,incoming)]
        if "mapID" not in incoming:
            if not matching: existing.append(dict(incoming))
            continue
        coordinate = {name: incoming[name] for name in ("mapID", "x", "y")}
        mapped = [location for location in originals if location_scope_matches(location,incoming) and "mapID" in location]
        if mapped:
            if not any(all(location[name] == coordinate[name] for name in coordinate) for location in mapped):
                row["locationConflict"] = True
                disagreements.append({"id":row["id"],"field":"coordinates","entity":list(key),"compiled":coordinate,"authoring":[{name:location[name] for name in coordinate} for location in mapped]})
            continue
        bare = matching[0] if matching else next((location for location in originals if location_scope_matches(location,incoming)),{})
        existing = [location for location in existing if not (location_scope_matches(location,incoming) and "mapID" not in location)]
        enriched = dict(bare, **incoming)
        if enriched not in existing: existing.append(enriched)
    if existing: row["locations"] = existing


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
    compiled_metadata = {row["id"]: row for row in inputs["compiled"].get("metadata", [])}
    hidden_triggers=set(inputs["compiled"].get("hiddenTriggerIDs",[]))
    npc_positions = {row["npcID"]: row for row in inputs["compiled"].get("npcPositions", [])}
    rejected_metadata = set(inputs["metadata"].get("rejectedIDs", []))
    classification = {row["id"] for row in json.loads((root/"data/primary-statuses.json").read_bytes())["quests"]}
    history=set(inputs.get("history",{}).get("questIDs",[]))
    if len(history)!=len(inputs.get("history",{}).get("questIDs",[])) or any(type(quest) is not int or not 0<quest<2**31 for quest in history):raise ValueError("Invalid monotonic identity history")
    universe = set(public) | compiled | native | classification | set(legacy) | history
    rows, gaps, disagreements = [], [], []
    added_pairs, removed_pairs = [], []
    for quest in sorted(universe):
        authored, published, checked = metadata.get(quest, {}), public.get(quest), primary.get(quest)
        row = {key: authored[key] for key in METADATA if key in authored}
        row.update({"id": quest, "items": [], "itemState": "unknown", "confirmation": "historical" if quest in compiled else "unconfirmed"})
        if quest in hidden_triggers:row["questKind"]="hidden-trigger"
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
        enrich_locations(row, compiled_metadata.get(quest, {}), disagreements)
        # A separately recorded NPC position can enrich an already established
        # starter ID. It cannot create a new NPC-to-quest association.
        known_npcs = {(location["npcID"],location.get("faction")) for location in row.get("locations", []) if "npcID" in location}
        for npc, faction in sorted(known_npcs,key=str):
            if any(location.get("npcID") == npc and location.get("faction") == faction and "mapID" in location for location in row["locations"]): continue
            positions = [{"npcID":npc,**({"faction":faction} if faction else {}),**point} for point in npc_positions.get(npc, {}).get("locations", [])]
            if positions:
                enrich_locations(row,{"locations":positions},disagreements)
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
                    matches = [location for location in existing if entity(location) == entity(giver)]
                    if matches:
                        for location in matches:
                            if giver.get("name"): location["name"] = giver["name"]
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
    recovery=inputs["metadata"].get("coordinateRecovery",{})
    if recovery:
        report["coordinateOwnershipAudit"]=recovery
        precedence=["recovered-explicit-coordinate-alias-ownership","unassigned-literal-coordinate-list","unassigned-faction-branch","no-direct-coordinate-field","helper-shadow-or-mutation"]
        cause_by_id={row["id"]:min((entry["cause"] for entry in recovery["audit"] if entry["id"]==row["id"]),key=lambda cause:precedence.index(cause),default="no-materialized-occurrence") for row in recovery["quests"]}
        report["coordinateOwnershipAuditCounts"]=dict(Counter(cause_by_id.values()))
    evidence={row["id"]:row for row in inputs.get("gaps",{}).get("records",[])}
    report["gapEvidence"]=inputs.get("gaps",{})
    report["retainedHistoryOnlyIDs"]=sorted(history-(set(public)|compiled|native|classification|set(legacy)))
    unsupported_starters={entry.get("id") for entry in inputs["metadata"]["omissions"] if entry.get("field") in ("providers","qg","qgs")}
    by_id={row["id"]:row for row in rows}
    for gap in gaps:
        row=by_id[gap["id"]]
        causes={}
        for field in gap["missing"]:
            if field=="items":cause=evidence.get(row["id"],{}).get("cause","no-current-public-reward-record")
            elif field=="currencies":cause="complete-currency-list-not-exposed"
            elif field in ("givers","coordinates"):
                if row.get("questKind")=="hidden-trigger":cause="declared-hidden-trigger"
                elif row["id"] in inputs.get("gaps",{}).get("unprovenHeaderContextIDs",[]):cause="parent-header-context-does-not-prove-child-starter"
                elif row.get("confirmation")=="unconfirmed":cause="unconfirmed-forever-identity"
                elif not row.get("locations"):cause="unsupported-starter-expression" if row["id"] in unsupported_starters else "starter-fields-absent-in-inspected-sources"
                elif all("itemID" in location for location in row["locations"]):cause="item-start-has-no-fixed-activation-point"
                elif len({entity(location) for location in row["locations"]})>1:cause="multiple-or-mixed-starters-without-owned-point"
                else:cause="starter-position-absent-in-inspected-sources"
            elif field in ("level","minimum") and field in public.get(row["id"],{}):cause="unsupported-published-level-value"
            else:cause="field-not-explicitly-published"
            causes[field]=cause
        gap["causes"]=causes
    report["gapCauseCounts"]={field:dict(Counter(gap["causes"][field] for gap in gaps if field in gap["causes"])) for field in FIELDS}
    report["inventoryConfirmation"]={"published":sum(row["confirmation"]=="published" for row in rows),"historicalOrUnconfirmed":sum(row["confirmation"]!="published" for row in rows),"finderRule":"Historical/unconfirmed candidates and declared hidden triggers are excluded unless current native offer/log/map evidence proves availability. Cached rewards or titles alone are not availability proof."}
    report["compiledConstraintConflicts"] = inputs["compiled"]["constraintConflicts"]
    report["repeatedRewardSlots"] = []
    for row in rows:
        for group, item in sorted({(item["group"], item["itemID"]) for item in row["items"]}):
            repeated = [entry for entry in row["items"] if entry["group"] == group and entry["itemID"] == item]
            if len(repeated) > 1:
                report["repeatedRewardSlots"].append({"id":row["id"],"group":group,"itemID":item,"slots":[{"slot":entry["slot"],"quantity":entry["quantity"]} for entry in repeated]})
    report["acquisitionLimits"]["givers"] = "Public reward columns do not encode starters. Explicit authored/compiled exact quest starters, qs/qss starting items, faction-qualified resolver branches and retained primary start markers are recorded. Independently recorded NPC positions enrich only already proven NPC starters. Nested objectives, parent-header context and item acquisition points are not promoted to starter proof."
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
