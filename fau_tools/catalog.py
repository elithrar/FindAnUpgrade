"""Canonical catalog reconciliation, validation, and deterministic Lua projection."""

import argparse
import hashlib
import json
import re
from collections import Counter

from fau_tools.context import ROOT

# Complete catalog.

FIELDS = (
    "items",
    "title",
    "level",
    "minimum",
    "xp",
    "money",
    "reputation",
    "currencies",
    "givers",
    "coordinates",
)
METADATA = (
    "title",
    "minimum",
    "maximum",
    "faction",
    "classTokens",
    "races",
    "eligibilityUnknown",
    "prerequisites",
    "prerequisiteCount",
    "locations",
    "locationConflict",
    "questKind",
)
# The pinned Forever provider explicitly withholds legacy position projections
# in these changed frames (Areas 44/139/215/1519). Direct quest/current-primary
# points are separate evidence; a global historical NPC point cannot replace it.
UNCERTAIN_GLOBAL_MAPS = {1433, 1423, 1412, 1453}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def read_inputs(root):
    provenance = json.loads((root / "data/catalog-complete-sources.json").read_bytes())
    if provenance["schemaVersion"] != 2 or provenance["targetBuild"] != "1.60.1.70374":
        raise ValueError("Unsupported comprehensive catalog target")
    inputs = {}
    for key, receipt in provenance["inputs"].items():
        path = (root / receipt["path"]).resolve()
        if not path.is_relative_to((root / "data").resolve()):
            raise ValueError("Input outside owned data directory")
        raw = path.read_bytes()
        if digest(raw) != receipt["sha256"]:
            raise ValueError("Frozen catalog input changed: " + receipt["path"])
        inputs[key] = json.loads(raw)
    return provenance, inputs


def pairs(items):
    return sorted((item["group"], item["itemID"], item["quantity"]) for item in items)


def entity(location):
    return next(
        (
            (key, location[key])
            for key in ("npcID", "objectID", "itemID")
            if key in location
        ),
        None,
    )


def location_scope_matches(location, incoming):
    return entity(location) == entity(incoming) and (
        location.get("faction") == incoming.get("faction")
        or location.get("faction") is None
    )


def enrich_locations(row, compiled, disagreements):
    existing = [dict(location) for location in row.get("locations", [])]
    originals = [dict(location) for location in existing]
    qualified = {
        entity(location)
        for location in compiled.get("locations", [])
        if location.get("faction")
    }
    for key in qualified:
        incoming = [
            location for location in compiled["locations"] if entity(location) == key
        ]
        if any(not location.get("faction") for location in incoming):
            continue
        scopes = sorted({location["faction"] for location in incoming})
        existing = [
            dict(location, faction=faction)
            for location in existing
            for faction in (
                scopes
                if entity(location) == key and not location.get("faction")
                else [location.get("faction")]
            )
        ]
        for location in existing:
            if location.get("faction") is None:
                location.pop("faction", None)
    originals = [dict(location) for location in existing]
    recorded_entities = {entity(location) for location in existing}
    incoming_entities = {entity(location) for location in compiled.get("locations", [])}
    conflicting = {
        (entity(incoming), incoming.get("faction"))
        for incoming in compiled.get("locations", [])
        if not any(
            entity(old) == entity(incoming)
            and (
                not old.get("faction")
                or not incoming.get("faction")
                or old["faction"] == incoming["faction"]
            )
            for old in originals
        )
        and any(
            entity(old)[0] == entity(incoming)[0]
            and (
                not old.get("faction")
                or not incoming.get("faction")
                or old["faction"] == incoming["faction"]
            )
            for old in originals
        )
    }
    if conflicting:
        disagreements.append(
            {
                "id": row["id"],
                "field": "starters",
                "authoring": sorted(recorded_entities),
                "compiled": sorted(incoming_entities),
            }
        )
    for incoming in compiled.get("locations", []):
        key = entity(incoming)
        # Missing authoring can be expanded from the compiled exact q record.
        # A different source giver is diagnostic, never a guessed extra NPC.
        if (key, incoming.get("faction")) in conflicting:
            continue
        matching = [
            location
            for location in existing
            if location_scope_matches(location, incoming)
        ]
        if "mapID" not in incoming:
            if not matching:
                existing.append(dict(incoming))
            continue
        coordinate = {name: incoming[name] for name in ("mapID", "x", "y")}
        mapped = [
            location
            for location in originals
            if location_scope_matches(location, incoming) and "mapID" in location
        ]
        if mapped:
            if not any(
                all(location[name] == coordinate[name] for name in coordinate)
                for location in mapped
            ):
                row["locationConflict"] = True
                disagreements.append(
                    {
                        "id": row["id"],
                        "field": "coordinates",
                        "entity": list(key),
                        "compiled": coordinate,
                        "authoring": [
                            {name: location[name] for name in coordinate}
                            for location in mapped
                        ],
                    }
                )
            continue
        bare = (
            matching[0]
            if matching
            else next(
                (
                    location
                    for location in originals
                    if location_scope_matches(location, incoming)
                ),
                {},
            )
        )
        existing = [
            location
            for location in existing
            if not (
                location_scope_matches(location, incoming) and "mapID" not in location
            )
        ]
        enriched = dict(bare, **incoming)
        if enriched not in existing:
            existing.append(enriched)
    if existing:
        row["locations"] = existing


def merge_supplemental(row, incoming, disagreements):
    """Add proved missing metadata without relaxing another source's limits."""
    if (
        not incoming
        or row.get("confirmation") != "published"
        or row.get("questKind") == "hidden-trigger"
    ):
        return
    for key, value in incoming.get("constraints", {}).items():
        if (
            key not in ("classTokens", "races")
            or not isinstance(value, list)
            or not value
        ):
            raise ValueError("Unsupported supplemental constraint")
        if key in row and set(row[key]) != set(value):
            disagreements.append(
                {
                    "id": row["id"],
                    "field": key,
                    "supplemental": value,
                    "other": row[key],
                }
            )
            common = set(value) & set(row[key])
            if not common:
                row["eligibilityConflict"] = True
            else:
                row[key] = sorted(common)
        else:
            row[key] = list(value)
    existing = {entity(point) for point in row.get("locations", [])}
    locations = incoming.get("locations", [])
    if existing:
        different = [point for point in locations if entity(point) not in existing]
        if different:
            disagreements.append(
                {
                    "id": row["id"],
                    "field": "supplemental-starters",
                    "rejected": different,
                    "rule": "Preserve existing exact starter associations",
                }
            )
        locations = [point for point in locations if entity(point) in existing]
    enrich_locations(row, {"locations": locations}, disagreements)


def build_complete(root, include_supplemental=True, include_chains=True):
    provenance, inputs = read_inputs(root)
    public = {row["id"]: row for row in inputs["public"]["records"]}
    if len(public) != inputs["public"]["expected"]:
        raise ValueError("Public index was truncated or deduplicated incorrectly")
    metadata = {row["id"]: row for row in inputs["metadata"]["records"]}
    primary = {row["id"]: row for row in inputs["primary"]["records"]}
    supplemental = (
        {row["id"]: row for row in inputs.get("supplemental", {}).get("records", [])}
        if include_supplemental
        else {}
    )
    chains = (
        {row["id"]: row for row in inputs.get("chains", {}).get("records", [])}
        if include_chains
        else {}
    )
    legacy = {row["id"]: row for row in inputs["legacy"]["quests"]}
    compiled, native = (
        set(inputs["compiled"]["questIDs"]),
        set(inputs["client"]["questIDs"]),
    )
    constraints = {row["id"]: row for row in inputs["compiled"].get("constraints", [])}
    compiled_metadata = {
        row["id"]: row for row in inputs["compiled"].get("metadata", [])
    }
    hidden_triggers = set(inputs["compiled"].get("hiddenTriggerIDs", []))
    npc_positions = {
        row["npcID"]: row for row in inputs["compiled"].get("npcPositions", [])
    }
    rejected_metadata = set(inputs["metadata"].get("rejectedIDs", []))
    classification = {
        row["id"]
        for row in json.loads((root / "data/primary-statuses.json").read_bytes())[
            "quests"
        ]
    }
    history = set(inputs.get("history", {}).get("questIDs", []))
    if len(history) != len(inputs.get("history", {}).get("questIDs", [])) or any(
        type(quest) is not int or not 0 < quest < 2**31 for quest in history
    ):
        raise ValueError("Invalid monotonic identity history")
    universe = set(public) | compiled | native | classification | set(legacy) | history
    rows, gaps, disagreements, withheld_positions = [], [], [], []
    added_pairs, removed_pairs = [], []
    for quest in sorted(universe):
        authored, published, checked = (
            metadata.get(quest, {}),
            public.get(quest),
            primary.get(quest),
        )
        row = {key: authored[key] for key in METADATA if key in authored}
        row.update(
            {
                "id": quest,
                "items": [],
                "itemState": "unknown",
                "confirmation": "historical" if quest in compiled else "unconfirmed",
            }
        )
        if quest in chains:
            row["chain"] = chains[quest]["chain"]
        if quest in hidden_triggers:
            row["questKind"] = "hidden-trigger"
        if published:
            for key in (
                "title",
                "level",
                "minimum",
                "faction",
                "items",
                "itemState",
                "confirmation",
                "moneyCost",
            ):
                if key in published:
                    row[key] = published[key]
            if row.get("faction") == "Both":
                row.pop("faction")
            values = {
                key: published[key]
                for key in ("xp", "money", "reputation")
                if key in published
            }
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
                disagreements.append(
                    {"id": quest, "field": key, "compiled": value, "other": row[key]}
                )
                if key in ("classTokens", "races"):
                    value = sorted(set(value) & set(row[key]))
                if key == "faction" or not value:
                    row["eligibilityConflict"] = True
            row[key] = value
        if quest in rejected_metadata and not constraint:
            row["eligibilityConflict"] = True
        for unresolved in authored.get("unresolvedRestrictions", []):
            if {"classes": "classTokens", "races": "races"}[
                unresolved
            ] not in constraint:
                row["eligibilityConflict"] = True
        enrich_locations(row, compiled_metadata.get(quest, {}), disagreements)
        # A retained current primary page challenges every corresponding exact
        # source group, rather than replacing an unexplained discrepancy.
        if checked:
            if not published or pairs(checked["items"]) != pairs(published["items"]):
                raise ValueError("Primary/public reward group conflict: " + str(quest))
            for key in ("xp", "money", "level", "minimum"):
                if (
                    key in checked
                    and key in published
                    and checked[key] != published[key]
                ):
                    disagreements.append(
                        {
                            "id": quest,
                            "field": key,
                            "primary": checked[key],
                            "public": published[key],
                        }
                    )
            for key in ("xp", "money"):
                if key not in row.get("rewardValues", {}) and key in checked:
                    row.setdefault("rewardValues", {})[key] = checked[key]
            # AreaTable coordinates in primary Mapper are not native UI maps.
            # Preserve ATT's explicit UI-map locations, enriching exact NPC names.
            if checked.get("locations"):
                existing = [dict(location) for location in row.get("locations", [])]
                for giver in checked["locations"]:
                    matches = [
                        location
                        for location in existing
                        if entity(location) == entity(giver)
                    ]
                    if matches:
                        for location in matches:
                            if giver.get("name"):
                                location["name"] = giver["name"]
                    else:
                        existing.append(giver)
                row["locations"] = existing
                # Attached primary positions are independently proved exact
                # marker coordinates, not merely giver labels. Preserve them
                # through cache-free supplemental refreshes as well.
                points = []
                for giver in checked["locations"]:
                    scopes = [
                        old for old in existing if entity(old) == entity(giver)
                    ] or [{}]
                    for old in scopes:
                        if (
                            old.get("faction")
                            and giver.get("faction")
                            and old["faction"] != giver["faction"]
                        ):
                            continue
                        point = dict(giver)
                        if old.get("faction") and not point.get("faction"):
                            point["faction"] = old["faction"]
                        if point not in points:
                            points.append(point)
                enrich_locations(row, {"locations": points}, disagreements)
            # Matching order and equal amounts cannot prove faction identity.
            # Retain the public name/amount without guessing a primary ID.
        merge_supplemental(row, supplemental.get(quest), disagreements)
        # Run after all proven starter associations, including primary markers.
        # A position enriches an exact NPC starter; it never creates one.
        known_npcs = {
            (location["npcID"], location.get("faction"))
            for location in row.get("locations", [])
            if "npcID" in location
        }
        for npc, faction in sorted(known_npcs, key=str):
            if any(
                location.get("npcID") == npc
                and location.get("faction") == faction
                and "mapID" in location
                for location in row["locations"]
            ):
                continue
            positions = []
            for point in npc_positions.get(npc, {}).get("locations", []):
                if point["mapID"] in UNCERTAIN_GLOBAL_MAPS:
                    withheld_positions.append(
                        {
                            "id": quest,
                            "npcID": npc,
                            "mapID": point["mapID"],
                            "reason": "Legacy global position is not verified in the changed Forever coordinate frame",
                        }
                    )
                else:
                    positions.append(
                        {
                            "npcID": npc,
                            **({"faction": faction} if faction else {}),
                            **point,
                        }
                    )
            if positions:
                enrich_locations(row, {"locations": positions}, disagreements)
        if quest in native:
            row["clientIdentityRecorded"] = True
        if "level" in row and not (
            type(row["level"]) is int and 1 <= row["level"] <= 200
        ):
            row.pop("level")  # Level 0/scaled/unsupported does not become level 1.
        if "minimum" in row and not (
            type(row["minimum"]) is int and 1 <= row["minimum"] <= 200
        ):
            row.pop("minimum")
        # Historical availability constraints are retained as recorded facts;
        # a source row never claims that the quest is currently offered.
        row["eligibilityUnknown"] = True
        states = {field: "unknown" for field in FIELDS}
        states["items"] = row["itemState"]
        if row.get("title"):
            states["title"] = (
                "published" if published and published.get("title") else "recorded"
            )
        if "level" in row:
            states["level"] = "published"
        if "minimum" in row:
            states["minimum"] = (
                "published" if published and "minimum" in published else "recorded"
            )
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
            if published and published.get("reason"):
                gap["reason"] = published["reason"]
            gaps.append(gap)
        row["fieldStates"] = states
        old = {item["itemID"] for item in legacy.get(quest, {}).get("items", [])}
        new = {item["itemID"] for item in row["items"]}
        if quest in legacy and row["itemState"] != "unknown":
            added_pairs.extend([quest, item] for item in sorted(new - old))
            removed_pairs.extend([quest, item] for item in sorted(old - new))
        rows.append(row)
    source = {
        "schemaVersion": 2,
        "targetBuild": provenance["targetBuild"],
        "sourceRevision": "public-forever-" + inputs["public"]["collectedAt"][:10],
        "quests": rows,
    }
    state_counts = Counter(row["itemState"] for row in rows)
    report = {
        "schemaVersion": 2,
        "targetBuild": provenance["targetBuild"],
        "scope": "Every exact quest ID in the complete public index, historical compiled Forever catalog, current official quest cache, approved classifications and previous catalog. Identity is separate from current availability.",
        "counts": {
            "quests": len(rows),
            "publicIndex": len(public),
            "compiledIdentity": len(compiled),
            "currentClientCache": len(native),
            "classificationIds": len(classification),
            "publishedItemRewards": state_counts["published"],
            "publishedEmptyItems": state_counts["published-empty"],
            "unknownItems": state_counts["unknown"],
            "itemAssociations": sum(len(row["items"]) for row in rows),
            "distinctItems": len(
                {item["itemID"] for row in rows for item in row["items"]}
            ),
            "rowsWithGivers": sum(bool(row.get("locations")) for row in rows),
            "rowsWithCoordinates": sum(
                any("mapID" in location for location in row.get("locations", []))
                for row in rows
            ),
            "addedLegacyPairs": len(added_pairs),
            "removedLegacyPairs": len(removed_pairs),
        },
        "publicIdsAbsentOutput": sorted(set(public) - universe),
        "compiledOnlyIds": sorted(compiled - set(public)),
        "authoringOnlyCandidates": sorted(set(metadata) - universe),
        "missingFields": gaps,
        "fieldCoverage": {
            field: dict(Counter(row["fieldStates"][field] for row in rows))
            for field in FIELDS
        },
        "legacyCorrection": {
            "addedPairs": added_pairs,
            "removedPairs": removed_pairs,
            "unknownLegacyRows": sorted(
                quest for quest in legacy if quest not in public
            ),
        },
        "sourceDisagreements": disagreements,
        "metadataConflicts": inputs["metadata"]["conflicts"],
        "nativeDataLimits": {
            "questV2FileDataID": 1139443,
            "questV2": "Encrypted BLTE frame rejected by local-only reader; no keys or partial invented rows",
            "emptyCurrentTables": [
                "QuestV2CliTask",
                "QuestPackageItem",
                "QuestObjective",
                "QuestHub",
            ],
            "cachedQuestRewardLayoutVerified": False,
        },
        "acquisitionLimits": {
            "wowhead": "No new requests: GPTBot disallowed and verification challenge observed; 135 retained exact primary pages reused",
            "givers": "Public quest reward columns do not encode starter identity. Explicit authored qg/qgs and retained primary start markers only; missing givers are listed per ID.",
            "currencies": "No complete explicit currency list is exposed by the acquired public source; absence remains unknown",
        },
    }
    corrected = {pair[0] for pair in added_pairs + removed_pairs}
    report["counts"].update(
        {
            "rowsWithNpcGivers": sum(
                any("npcID" in location for location in row.get("locations", []))
                for row in rows
            ),
            "rowsWithObjectStarters": sum(
                any("objectID" in location for location in row.get("locations", []))
                for row in rows
            ),
            "rowsWithItemStarters": sum(
                any("itemID" in location for location in row.get("locations", []))
                for row in rows
            ),
            "correctedLegacyQuests": len(corrected),
            "primaryCorroboratedCorrections": len(corrected & set(primary)),
        }
    )
    report["legacyCorrection"]["primaryCheckedQuestIDs"] = sorted(
        corrected & set(primary)
    )
    report["publicUnconfirmedIDs"] = sorted(
        quest for quest, row in public.items() if row["confirmation"] == "unconfirmed"
    )
    report["eligibilityConflictIDs"] = [
        row["id"] for row in rows if row.get("eligibilityConflict")
    ]
    report["metadataOmissions"] = inputs["metadata"]["omissions"]
    report["supplementalMetadata"] = (
        inputs.get("supplemental", {}) if include_supplemental else {}
    )
    if include_chains and "chains" in inputs:
        report["chainCoverage"] = inputs["chains"]["coverage"]
    report["withheldGlobalPositions"] = withheld_positions
    recovery = inputs["metadata"].get("coordinateRecovery", {})
    if recovery:
        report["coordinateOwnershipAudit"] = recovery
        precedence = [
            "recovered-explicit-coordinate-alias-ownership",
            "unassigned-literal-coordinate-list",
            "unassigned-faction-branch",
            "no-direct-coordinate-field",
            "helper-shadow-or-mutation",
        ]
        cause_by_id = {
            row["id"]: min(
                (
                    entry["cause"]
                    for entry in recovery["audit"]
                    if entry["id"] == row["id"]
                ),
                key=lambda cause: precedence.index(cause),
                default="no-materialized-occurrence",
            )
            for row in recovery["quests"]
        }
        report["coordinateOwnershipAuditCounts"] = dict(Counter(cause_by_id.values()))
    evidence = {row["id"]: row for row in inputs.get("gaps", {}).get("records", [])}
    report["gapEvidence"] = inputs.get("gaps", {})
    report["retainedHistoryOnlyIDs"] = sorted(
        history - (set(public) | compiled | native | classification | set(legacy))
    )
    unsupported_starters = {
        entry.get("id")
        for entry in inputs["metadata"]["omissions"]
        if entry.get("field") in ("providers", "qg", "qgs")
    }
    by_id = {row["id"]: row for row in rows}
    for gap in gaps:
        row = by_id[gap["id"]]
        causes = {}
        for field in gap["missing"]:
            if field == "items":
                cause = evidence.get(row["id"], {}).get(
                    "cause", "no-current-public-reward-record"
                )
            elif field == "currencies":
                cause = "complete-currency-list-not-exposed"
            elif field in ("givers", "coordinates"):
                if row.get("questKind") == "hidden-trigger":
                    cause = "declared-hidden-trigger"
                elif row["id"] in inputs.get("gaps", {}).get(
                    "unprovenHeaderContextIDs", []
                ):
                    cause = "parent-header-context-does-not-prove-child-starter"
                elif row.get("confirmation") == "unconfirmed":
                    cause = "unconfirmed-forever-identity"
                elif not row.get("locations"):
                    cause = (
                        "unsupported-starter-expression"
                        if row["id"] in unsupported_starters
                        else "starter-fields-absent-in-inspected-sources"
                    )
                elif any(point["id"] == row["id"] for point in withheld_positions):
                    cause = "legacy-coordinate-frame-not-verified-for-Forever"
                elif all("itemID" in location for location in row["locations"]):
                    cause = "item-start-has-no-fixed-activation-point"
                elif len({entity(location) for location in row["locations"]}) > 1:
                    cause = "multiple-or-mixed-starters-without-owned-point"
                else:
                    cause = "starter-position-absent-in-inspected-sources"
            elif field == "money" and "moneyCost" in row:
                cause = "published-payment-cost-is-not-a-reward"
            elif field in ("level", "minimum") and field in public.get(row["id"], {}):
                cause = "unsupported-published-level-value"
            else:
                cause = "field-not-explicitly-published"
            causes[field] = cause
        gap["causes"] = causes
    report["gapCauseCounts"] = {
        field: dict(
            Counter(gap["causes"][field] for gap in gaps if field in gap["causes"])
        )
        for field in FIELDS
    }
    report["inventoryConfirmation"] = {
        "published": sum(row["confirmation"] == "published" for row in rows),
        "historicalOrUnconfirmed": sum(
            row["confirmation"] != "published" for row in rows
        ),
        "finderRule": "Historical/unconfirmed candidates and declared hidden triggers are excluded unless current native offer/log/map evidence proves availability. Cached rewards or titles alone are not availability proof.",
    }
    report["compiledConstraintConflicts"] = inputs["compiled"]["constraintConflicts"]
    report["repeatedRewardSlots"] = []
    report["publishedMoneyCosts"] = [
        {"id": row["id"], "copper": row["moneyCost"]}
        for row in rows
        if "moneyCost" in row
    ]
    report["ambiguousPublishedReputation"] = []
    for row in rows:
        entries = row.get("rewardValues", {}).get("reputation", [])
        names = Counter(entry["name"] for entry in entries if "name" in entry)
        for name, occurrences in sorted(names.items()):
            if occurrences > 1:
                report["ambiguousPublishedReputation"].append(
                    {
                        "id": row["id"],
                        "name": name,
                        "amounts": [
                            entry["amount"]
                            for entry in entries
                            if entry.get("name") == name
                        ],
                        "runtime": "Withheld until native faction reward evidence; source slots do not prove an effective award.",
                    }
                )
    for row in rows:
        for group, item in sorted(
            {(item["group"], item["itemID"]) for item in row["items"]}
        ):
            repeated = [
                entry
                for entry in row["items"]
                if entry["group"] == group and entry["itemID"] == item
            ]
            if len(repeated) > 1:
                report["repeatedRewardSlots"].append(
                    {
                        "id": row["id"],
                        "group": group,
                        "itemID": item,
                        "slots": [
                            {"slot": entry["slot"], "quantity": entry["quantity"]}
                            for entry in repeated
                        ],
                    }
                )
    report["acquisitionLimits"]["givers"] = (
        "Public reward columns do not encode starters. Explicit authored/compiled exact quest starters, qs/qss starting items, faction-qualified resolver branches and retained primary start markers are recorded. Independently recorded NPC positions enrich only already proven NPC starters. Nested objectives, parent-header context and item acquisition points are not promoted to starter proof."
    )
    return source, report


def validate_complete(source, provenance, root):
    expected, report = build_complete(root)
    if source != expected:
        raise ValueError(
            "Comprehensive catalog does not reproduce its frozen input reconciliation"
        )
    if provenance != json.loads(
        (root / "data/catalog-complete-sources.json").read_bytes()
    ):
        raise ValueError("Comprehensive provenance mismatch")
    ids = set()
    for row in source["quests"]:
        quest = row["id"]
        if type(quest) is not int or not 0 < quest < 2**31 or quest in ids:
            raise ValueError("Invalid or duplicate comprehensive quest ID")
        ids.add(quest)
        seen = set()
        for item in row["items"]:
            if set(item) - {"itemID", "name", "quantity", "group", "slot"}:
                raise ValueError("Unexpected published item field")
            key = (item["group"], item["slot"])
            if (
                key in seen
                or key[0] not in ("guaranteed", "choice")
                or type(key[1]) is not int
                or key[1] <= 0
                or type(item["itemID"]) is not int
                or item["itemID"] <= 0
                or type(item["quantity"]) is not int
                or item["quantity"] <= 0
            ):
                raise ValueError("Invalid published reward group/quantity")
            seen.add(key)
        if (
            row["itemState"] == "published-empty"
            and row["items"]
            or row["itemState"] == "unknown"
            and row["items"]
        ):
            raise ValueError(
                "Empty/unknown source rewards cannot contain invented items"
            )
    return report


# Generate catalog.

PIN = "d75383ccdbff1208b87cf4024fa425c0825a7ad6"


def load_inputs(root=ROOT):
    complete = root / "data/catalog-complete-source.json"
    if complete.exists():
        return json.loads(complete.read_bytes()), json.loads(
            (root / "data/catalog-complete-sources.json").read_bytes()
        )
    return json.loads((root / "data/catalog-source.json").read_bytes()), json.loads(
        (root / "data/catalog-sources.json").read_bytes()
    )


def positive(value):
    if not (type(value) is int and 0 < value < 2**31):
        raise AssertionError("Invalid exact ID")


def text(value):
    if not (
        isinstance(value, str)
        and 0 < len(value) <= 100
        and all(ord(c) >= 32 for c in value)
    ):
        raise AssertionError("Invalid identification label")


def validate(source, provenance):
    if source.get("schemaVersion") == 2:
        validate_complete(source, provenance, ROOT)
        return
    if not (source["schemaVersion"] == 1):
        raise AssertionError()
    if not (
        source["source"]
        == {
            "repository": "ATTWoWAddon/AllTheThings",
            "revision": PIN,
            "license": "MIT",
            "clientBuild": "1.60.1.69893",
        }
    ):
        raise AssertionError()
    if not (
        provenance["revision"] == PIN and provenance["targetBuild"] == "1.60.1.70374"
    ):
        raise AssertionError()
    membership = json.loads(
        (ROOT / "data/catalog-compiled-membership.json").read_bytes()
    )
    if not (
        membership["source"]["revision"] == PIN and membership["schemaVersion"] == 1
    ):
        raise AssertionError()
    if not (
        provenance["membershipSha256"]
        == hashlib.sha256(
            (ROOT / "data/catalog-compiled-membership.json").read_bytes()
        ).hexdigest()
    ):
        raise AssertionError()
    allowed = {tuple(pair) for pair in membership["pairs"]}
    if not (
        len(allowed) == len(membership["pairs"])
        and all(
            len(pair) == 2 and all(type(v) is int and v > 0 for v in pair)
            for pair in allowed
        )
    ):
        raise AssertionError()
    paths = {row["path"] for row in provenance["files"]}
    if "LICENSE" not in paths:
        raise AssertionError()
    for row in provenance["files"]:
        if not (
            re.fullmatch(r"[a-f0-9]{64}", row["sha256"])
            and re.fullmatch(r"[a-f0-9]{40}", row["gitBlob"])
        ):
            raise AssertionError()
        if not (
            row["url"].startswith(
                "https://github.com/ATTWoWAddon/AllTheThings/blob/" + PIN + "/"
            )
        ):
            raise AssertionError()
    excluded = set()
    for omission in provenance["omissions"]:
        if not (omission["path"] in paths and isinstance(omission["reason"], str)):
            raise AssertionError()
        if "itemID" in omission:
            positive(omission["id"])
            positive(omission["itemID"])
            if not (type(omission["line"]) is int and omission["line"] > 0):
                raise AssertionError()
            excluded.add((omission["id"], omission["itemID"]))
    if not (provenance["excludedRewardPairCount"] == len(excluded)):
        raise AssertionError()
    ids = set()
    for row in source["quests"]:
        if not (
            set(row)
            <= {
                "id",
                "title",
                "minimum",
                "maximum",
                "faction",
                "classTokens",
                "races",
                "eligibilityUnknown",
                "prerequisites",
                "prerequisiteCount",
                "items",
                "locations",
                "locationConflict",
                "sources",
            }
        ):
            raise AssertionError("Unexpected quest field")
        positive(row["id"])
        if not (row["id"] not in ids):
            raise AssertionError()
        ids.add(row["id"])
        if "title" in row:
            text(row["title"])
        for key in ("minimum", "maximum"):
            if key in row:
                if not (type(row[key]) is int and 1 <= row[key] <= 200):
                    raise AssertionError()
        if "minimum" in row and "maximum" in row:
            if not (row["minimum"] <= row["maximum"]):
                raise AssertionError("Inverted level constraint")
        if "faction" in row:
            if row["faction"] not in ("Alliance", "Horde"):
                raise AssertionError()
        if "classTokens" in row:
            if not (
                isinstance(row["classTokens"], list)
                and row["classTokens"]
                and all(
                    isinstance(c, str)
                    and c
                    in (
                        "WARRIOR",
                        "PALADIN",
                        "HUNTER",
                        "ROGUE",
                        "PRIEST",
                        "SHAMAN",
                        "MAGE",
                        "WARLOCK",
                        "DRUID",
                    )
                    for c in row["classTokens"]
                )
            ):
                raise AssertionError()
            if not (len(set(row["classTokens"])) == len(row["classTokens"])):
                raise AssertionError("Duplicate class constraint")
        if "eligibilityUnknown" in row:
            if type(row["eligibilityUnknown"]) is not bool:
                raise AssertionError()
        if "locationConflict" in row:
            if type(row["locationConflict"]) is not bool:
                raise AssertionError()
        for key in ("prerequisites", "races"):
            if key in row:
                if not (isinstance(row[key], list) and row[key]):
                    raise AssertionError("Invalid constraint array")
            for value in row.get(key, []):
                positive(value)
                if not (key != "prerequisites" or value != row["id"]):
                    raise AssertionError()
            if not (len(set(row.get(key, []))) == len(row.get(key, []))):
                raise AssertionError("Duplicate constraint ID")
        if "prerequisiteCount" in row:
            if not (
                type(row["prerequisiteCount"]) is int
                and 1 <= row["prerequisiteCount"] <= len(row["prerequisites"])
            ):
                raise AssertionError()
        if not (
            row["sources"]
            and all(
                s["path"] in paths and type(s["line"]) is int and s["line"] > 0
                for s in row["sources"]
            )
        ):
            raise AssertionError()
        if not (row["items"] and len(row["items"]) <= 512):
            raise AssertionError()
        item_ids = set()
        for item in row["items"]:
            if not (set(item) <= {"itemID", "name", "quantity", "group"}):
                raise AssertionError()
            positive(item["itemID"])
            if not (item["itemID"] not in item_ids):
                raise AssertionError()
            item_ids.add(item["itemID"])
            if (row["id"], item["itemID"]) not in allowed:
                raise AssertionError(
                    "Association absent from pinned compiled cross-check"
                )
            if not ((row["id"], item["itemID"]) not in excluded):
                raise AssertionError("Excluded input/acquisition pair reintroduced")
            if "name" in item:
                text(item["name"])
            if "quantity" in item:
                positive(item["quantity"])
            if "group" in item:
                if item["group"] not in ("guaranteed", "choice"):
                    raise AssertionError()
            # This source only establishes associations. A future observed source
            # needs a schema/provenance update before counts/groups are accepted.
            if not ("quantity" not in item and "group" not in item):
                raise AssertionError()
        for location in row.get("locations", []):
            if not (set(location) <= {"npcID", "name", "mapID", "x", "y"}):
                raise AssertionError()
            positive(location["npcID"])
            if "name" in location:
                text(location["name"])
            if "mapID" in location:
                positive(location["mapID"])
                if not (
                    all(
                        type(location[k]) in (int, float) and 0 <= location[k] <= 1
                        for k in ("x", "y")
                    )
                ):
                    raise AssertionError()
            else:
                if not ("x" not in location and "y" not in location):
                    raise AssertionError()


def lua(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return "{" + ",".join(lua(v) for v in value) + "}"
    if isinstance(value, dict):
        return "{" + ",".join(k + "=" + lua(value[k]) for k in sorted(value)) + "}"
    raise TypeError(type(value))


def render(source, provenance):
    validate(source, provenance)
    if source["schemaVersion"] == 2:
        lines = [
            "-- Generated by tools/generate_catalog.py; do not edit.",
            "-- Complete reconciled public Forever identity/reward snapshot plus attributed ATT metadata.",
            "-- Published base values are separate from current native player rewards.",
            "-- Unknown reward fields are not zero; item groups retain exact variants and quantities.",
            "local _,N=...",
            "N.CatalogData={schemaVersion=2,questCount="
            + str(len(source["quests"]))
            + ',sourceRevision="'
            + source["sourceRevision"]
            + '",sourceBuild="1.60.1.70374",quests={',
        ]
        for row in source["quests"]:
            lines.append(
                "    "
                + lua(
                    {key: value for key, value in row.items() if key != "fieldStates"}
                )
                + ","
            )
        lines.extend(["}}", ""])
        return "\n".join(lines).encode()
    lines = [
        "-- Generated by tools/generate_catalog.py; do not edit.",
        "-- ATT-derived numeric facts and short labels: MIT; see Data/ATT-LICENSE.txt.",
        "-- Source build 1.60.1.69893; target 70374. Not current live verification.",
        "-- Recorded associations do not establish reward counts or choice groups.",
        "local _,N=...",
        "N.CatalogData={schemaVersion=1,questCount="
        + str(len(source["quests"]))
        + ',sourceRevision="'
        + PIN
        + '",sourceBuild="1.60.1.69893",quests={',
    ]
    for row in sorted(source["quests"], key=lambda r: r["id"]):
        lines.append(
            "    " + lua({k: v for k, v in row.items() if k != "sources"}) + ","
        )
    lines.extend(["}}", ""])
    return "\n".join(lines).encode()


def coverage(source, output, root=ROOT):
    if source["schemaVersion"] == 2:
        _, report = build_complete(root)
        rows = source["quests"]
        primary = {
            row["id"]: row["status"]
            for row in json.loads((root / "data/primary-statuses.json").read_bytes())[
                "quests"
            ]
        }
        return {
            "schemaVersion": 2,
            "targetBuild": source["targetBuild"],
            "questCount": len(rows),
            "itemCount": report["counts"]["distinctItems"],
            "associationCount": report["counts"]["itemAssociations"],
            "publicIndexCount": report["counts"]["publicIndex"],
            "publicIdsAbsentOutput": report["publicIdsAbsentOutput"],
            "itemStates": report["fieldCoverage"]["items"],
            "fieldCoverage": report["fieldCoverage"],
            "questsWithGivers": report["counts"]["rowsWithGivers"],
            "questsWithNpc": report["counts"]["rowsWithNpcGivers"],
            "questsWithCoordinates": report["counts"]["rowsWithCoordinates"],
            "knownQuantities": sum(
                "quantity" in item for row in rows for item in row["items"]
            ),
            "knownRewardGroups": sum(
                "group" in item for row in rows for item in row["items"]
            ),
            "classificationCounts": {
                key: sum(primary.get(row["id"], "Unknown") == key for row in rows)
                for key in ("New", "Updated", "Unchanged", "Unknown")
            },
            "reconciliationReport": "dist/catalog-reconciliation.json",
            "luaSha256": hashlib.sha256(output).hexdigest(),
            "sourceSha256": hashlib.sha256(
                (root / "data/catalog-complete-source.json").read_bytes()
            ).hexdigest(),
            "liveClientVerified": False,
        }
    rows = source["quests"]
    primary = json.loads((root / "data/primary-statuses.json").read_bytes())
    statuses = {q["id"]: q["status"] for q in primary["quests"]}
    return {
        "schemaVersion": 1,
        "sourceRevision": PIN,
        "sourceBuild": "1.60.1.69893",
        "targetBuild": "1.60.1.70374",
        "questCount": len(rows),
        "itemCount": len({i["itemID"] for q in rows for i in q["items"]}),
        "associationCount": sum(len(q["items"]) for q in rows),
        "questsWithNpc": sum(bool(q.get("locations")) for q in rows),
        "questsWithCoordinates": sum(
            any("mapID" in p for p in q.get("locations", [])) for q in rows
        ),
        "questsWithMinimumLevel": sum("minimum" in q for q in rows),
        "questsWithStaticDifficultyLevel": 0,
        "knownQuantities": 0,
        "knownRewardGroups": 0,
        "staticMoneyXpCurrencyReputationAmounts": 0,
        "classifiedQuests": sum(q["id"] in statuses for q in rows),
        "classifiedNewQuests": sum(statuses.get(q["id"]) == "New" for q in rows),
        "classificationCounts": {
            key: sum(statuses.get(q["id"], "Unknown") == key for q in rows)
            for key in ("New", "Updated", "Unchanged", "Unknown")
        },
        "factionCounts": {
            key: sum(q.get("faction", "Unknown") == key for q in rows)
            for key in ("Alliance", "Horde", "Unknown")
        },
        "minimumLevelBands": {
            f"{low}-{high}": sum(low <= q.get("minimum", -1) <= high for q in rows)
            for low, high in (
                (1, 10),
                (11, 20),
                (21, 30),
                (31, 40),
                (41, 50),
                (51, 60),
                (61, 200),
            )
        },
        "luaSha256": hashlib.sha256(output).hexdigest(),
        "sourceSha256": hashlib.sha256(
            (root / "data/catalog-source.json").read_bytes()
        ).hexdigest(),
        "liveClientVerified": False,
    }


def write_reports(source, output, root=ROOT, destination=None):
    """Regenerate ignored diagnostics from facts; reports never supply authority."""
    directory = destination or root / "dist"
    directory.mkdir(parents=True, exist_ok=True)
    _, reconciliation = build_complete(root)
    summary = coverage(source, output, root)
    for name, value in (
        ("catalog-reconciliation.json", reconciliation),
        ("catalog-coverage.json", summary),
    ):
        (directory / name).write_bytes(
            (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        )
    return summary


def generate_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    source, provenance = load_inputs()
    output = render(source, provenance)
    path = ROOT / "FindAnUpgrade/Data/Catalog.lua"
    if args.check:
        if path.read_bytes() != output:
            raise AssertionError(str(path) + " is stale")
    else:
        path.write_bytes(output)
    report = write_reports(source, output, ROOT)
    print(json.dumps(report, indent=2))
