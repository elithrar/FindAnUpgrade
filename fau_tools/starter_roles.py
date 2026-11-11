"""Receipted starter-role authority; generic providers remain related facts.

The original provider/recipient observations stay in owned source inputs. Only
reviewed typed, reciprocal starter proofs may activate ambiguous item providers.
Corrections fail closed if another import changes their expected relationships.
"""

import copy
import json
import math
import re
from collections import Counter

from fau_tools import questie

ENTITY_KEYS = {"Npc": "npcID", "Object": "objectID", "Item": "itemID"}
ROLES = {"finisher", "provided", "unknown"}


def entity(location):
    keys = [key for key in ENTITY_KEYS.values() if key in location]
    if len(keys) != 1:
        raise ValueError("Starter role needs exactly one typed entity")
    key = keys[0]
    identity = location[key]
    if type(identity) is not int or not 0 < identity < 2**31:
        raise ValueError("Invalid starter role entity ID")
    return key, identity


def location_facts(location, related=False):
    if not isinstance(location, dict):
        raise ValueError("Invalid starter role location")
    entity(location)
    if related and location.get("role") not in ROLES:
        raise ValueError("Invalid related provider role")
    if not related and "role" in location:
        raise ValueError("Starter must not carry an unrelated role")
    if "name" in location and (
        not isinstance(location["name"], str)
        or not 0 < len(location["name"]) <= 150
        or any(ord(char) < 32 for char in location["name"])
    ):
        raise ValueError("Invalid starter role label")
    if any(key in location for key in ("mapID", "x", "y")) and (
        type(location.get("mapID")) is not int
        or location["mapID"] <= 0
        or not all(
            type(location.get(key)) in (int, float)
            and math.isfinite(location[key])
            and 0 <= location[key] <= 1
            for key in ("x", "y")
        )
    ):
        raise ValueError("Invalid starter role coordinates")


def evidence(entry, sources):
    keys = entry.get("evidence")
    if not isinstance(keys, list) or not keys or set(keys) - sources.keys():
        raise ValueError("Starter role proof needs retained source receipts")


def reciprocal(entry, location):
    proof = entry.get("proof", {})
    key, identity = entity(location)
    kind = next(kind for kind, value in ENTITY_KEYS.items() if value == key)
    pairs = questie.grouped_starters(proof.get("startedBy"))
    if not pairs or (kind, identity) not in pairs:
        raise ValueError("Starter proof lacks exact typed quest-side association")
    reverse = (
        type(proof.get("reverseStartQuest")) is int
        and proof["reverseStartQuest"] == entry["id"]
        if kind == "Item"
        else isinstance(proof.get("reverseStarts"), list)
        and all(
            type(value) is int and 0 < value < 2**31 for value in proof["reverseStarts"]
        )
        and entry["id"] in proof["reverseStarts"]
    )
    if not reverse:
        raise ValueError("Starter proof lacks exact reciprocal entity association")


def related_proof(entry, location):
    proof = entry.get("proof", {})
    key, identity = entity(location)
    kind = next(kind for kind, value in ENTITY_KEYS.items() if value == key)
    starts = questie.grouped_starters(proof.get("startedBy"))
    ends = questie.grouped_starters(proof.get("finishedBy"))
    role = location["role"]
    if role == "finisher":
        if (
            starts is None
            or (kind, identity) in starts
            or not ends
            or (kind, identity) not in ends
        ):
            raise ValueError("Finisher role lacks explicit nonstarter/finisher proof")
        return
    if kind != "Item":
        raise ValueError("Unknown/supplied provider proof must be item-typed")
    reverse = [
        row.get("questID")
        for row in proof.get("itemStartQuest", [])
        if row.get("itemID") == identity
    ]
    if len(reverse) != 1:
        raise ValueError("Item role lacks exact reverse starter observation")
    if starts and (kind, identity) in starts and reverse[0] == entry["id"]:
        raise ValueError("Proved starter cannot be moved to an unrelated role")
    if role == "provided" and (
        type(proof.get("sourceItemId")) is not int or proof["sourceItemId"] != identity
    ):
        raise ValueError("Provided role differs from explicit sourceItemId")


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def reviewed(document):
    if document is None:
        return None
    if document.get("schemaVersion") != 1:
        raise ValueError("Unsupported starter role authority schema")
    sources = document.get("sources", {})
    if not isinstance(sources, dict) or not sources:
        raise ValueError("Starter role authority lacks source receipts")
    prefixes = (
        "https://github.com/ATTWoWAddon/AllTheThings/blob/"
        "d75383ccdbff1208b87cf4024fa425c0825a7ad6/",
        "https://github.com/Questie/QuestieDB/blob/" + questie.REVISION + "/",
        "https://github.com/Questie/QuestieDB/releases/download/v1.0.6/",
    )
    prior_url = "https://github.com/elithrar/FindAnUpgrade/blob/v0.1.20/data/catalog-complete-source.json"
    for receipt in sources.values():
        if (
            not (
                receipt.get("url", "").startswith(prefixes)
                or receipt.get("url") == prior_url
            )
            or not re.fullmatch(r"[a-f0-9]{64}", receipt.get("sha256", ""))
            or type(receipt.get("bytes")) is not int
            or receipt["bytes"] <= 0
        ):
            raise ValueError("Unpinned or incomplete starter role source receipt")
    toc = sources.get("questieToc", {})
    if (
        toc.get("revision") != questie.REVISION
        or toc.get("archiveSha256") != questie.ARCHIVE_SHA256
        or toc.get("member") != "QuestieDB/" + questie.TOC
    ):
        raise ValueError("Starter proof must retain exact pinned native table identity")
    approved = set()
    for entry in document.get("verifiedItemStarters", []):
        location = {"itemID": entry["itemID"]}
        location_facts(location)
        if type(entry.get("id")) is not int or not 0 < entry["id"] < 2**31:
            raise ValueError("Invalid starter proof quest ID")
        pair = (entry["id"], entry["itemID"])
        if pair in approved:
            raise ValueError("Repeated verified item starter proof")
        evidence(entry, sources)
        reciprocal(entry, location)
        approved.add(pair)
    records = {}
    for entry in document.get("records", []):
        identity = entry.get("id")
        if (
            type(identity) is not int
            or not 0 < identity < 2**31
            or identity in records
            or not entry.get("reason")
        ):
            raise ValueError("Invalid or repeated starter role correction")
        evidence(entry, sources)
        expected, starters, related = (
            entry.get("expectedLocations"),
            entry.get("locations"),
            entry.get("relatedLocations"),
        )
        if not all(isinstance(value, list) for value in (expected, starters, related)):
            raise ValueError("Starter correction needs exact before/after lists")
        for location in expected + starters:
            location_facts(location)
        for location in related:
            location_facts(location, related=True)
            related_proof(entry, location)
        additions = []
        for addition in entry.get("starterProofs", []):
            evidence(addition, sources)
            location = addition["location"]
            location_facts(location)
            if set(location) - {*ENTITY_KEYS.values(), "name"}:
                raise ValueError("New starter proof cannot supply inferred positions")
            reciprocal(dict(addition, id=identity), location)
            if "name" in location and addition["proof"].get("name") != location["name"]:
                raise ValueError("New starter label differs from recorded native label")
            additions.append(location)
            if "itemID" in location:
                approved.add((identity, location["itemID"]))
        original = Counter(map(canonical, expected + additions))
        after = Counter(
            map(
                canonical,
                starters
                + [
                    {key: value for key, value in row.items() if key != "role"}
                    for row in related
                ],
            )
        )
        if original != after or not related:
            raise ValueError(
                "Starter correction must preserve every original relationship"
            )
        records[identity] = entry
    return {"records": records, "approvedItems": approved, "document": document}


def apply(row, authority, reviewed_starter=None):
    """Reconcile exact old facts and quarantine unproved new item providers."""
    if authority is None:
        return
    if "relatedLocations" in row:
        row["relatedLocations"] = copy.deepcopy(row["relatedLocations"])
    entry = authority["records"].get(row["id"])
    if entry:
        if row.get("locations", []) not in (
            entry["expectedLocations"],
            entry["locations"],
        ):
            raise ValueError("Starter role source conflict: " + str(row["id"]))
        for relation in row.get("relatedLocations", []):
            retained_starter = relation.get("role") == "unknown" and any(
                all(
                    old.get(key) == value
                    for key, value in relation.items()
                    if key != "role"
                )
                for old in entry["locations"]
            )
            if not retained_starter and not any(
                all(
                    old.get(key) == value
                    for key, value in relation.items()
                    if key != "role"
                )
                and relation.get("role") in ("unknown", old["role"])
                for old in entry["relatedLocations"]
            ):
                raise ValueError("Related provider source conflict: " + str(row["id"]))
        row["locations"] = copy.deepcopy(entry["locations"])
        row["relatedLocations"] = copy.deepcopy(entry["relatedLocations"])
        for addition in entry.get("starterProofs", []):
            retained = addition["proof"].get("retainedConstraints", {})
            current = {
                key: row[key]
                for key in ("classTokens", "races", "faction")
                if key in row
            }
            if retained != current or row.get("eligibilityConflict"):
                raise ValueError("New starter retained eligibility changed")
            for key, values in addition["proof"].get("restrictions", {}).items():
                if key in current and not set(current[key]) & set(values):
                    raise ValueError("New starter conflicts with retained eligibility")
    website = {
        location["itemID"]
        for location in (reviewed_starter or {}).get("locations", [])
        if "itemID" in location
    }
    locations = []
    related_entities = {
        entity(location) for location in row.get("relatedLocations", [])
    }
    for location in row.get("locations", []):
        item = location.get("itemID")
        approved = item and (
            (row["id"], item) in authority["approvedItems"] or item in website
        )
        if approved:
            if any(
                entity(related) == entity(location) and related["role"] == "finisher"
                for related in row.get("relatedLocations", [])
            ):
                raise ValueError(
                    "Verified item starter contradicts an explicit nonstarter role"
                )
            row["relatedLocations"] = [
                related
                for related in row.get("relatedLocations", [])
                if entity(related) != entity(location) or related["role"] != "unknown"
            ]
            if not row["relatedLocations"]:
                row.pop("relatedLocations")
        if not approved and (entity(location) in related_entities or item):
            related = dict(location, role="unknown")
            if entity(
                location
            ) not in related_entities and related not in row.setdefault(
                "relatedLocations", []
            ):
                row["relatedLocations"].append(related)
        else:
            locations.append(location)
    if locations:
        row["locations"] = locations
    else:
        row.pop("locations", None)
