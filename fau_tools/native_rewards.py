"""Exact, receipted native reward observations with guarded partial overlays."""

import copy
import hashlib
import json
import re
from datetime import datetime

GROUPS = ("guaranteed", "choice")
FIELDS = {"items", "itemState", "itemGroupStates"}
ITEM_FIELDS = {"itemID", "name", "quantity", "group", "slot"}
SOURCE_URL = "https://quests.questionable.services/native-quests.json"
SOURCE_SCOPE = (
    "Direct native reward slots only. Empty groups do not rule out scripted/spell "
    "rewards. Faction and playability are not inferred."
)


def positive(value):
    return type(value) is int and 0 < value < 2**31


def text(value, limit=200):
    return (
        isinstance(value, str)
        and 0 < len(value) <= limit
        and not any(ord(char) < 32 for char in value)
    )


def sha(value):
    return isinstance(value, str) and re.fullmatch(r"[a-f0-9]{64}", value) is not None


def timestamp(value):
    try:
        return (
            isinstance(value, str)
            and datetime.fromisoformat(value).utcoffset() is not None
        )
    except ValueError:
        return False


def checked_items(items):
    if not isinstance(items, list) or len(items) > 128:
        raise ValueError("Invalid native correction item list")
    slots = set()
    for item in items:
        if (
            not isinstance(item, dict)
            or set(item) != ITEM_FIELDS
            or item["group"] not in GROUPS
            or not all(positive(item[key]) for key in ("itemID", "quantity", "slot"))
            or not text(item["name"], 100)
            or (item["group"], item["slot"]) in slots
        ):
            raise ValueError("Invalid native correction reward slot")
        slots.add((item["group"], item["slot"]))
    return items


def observed_items(record):
    """Copy only literal nonempty slots; an empty group supplies no absence proof."""
    items = []
    for group in GROUPS:
        source = record.get(group)
        if not isinstance(source, list) or len(source) > 128:
            raise ValueError("Invalid native observed reward group")
        for slot, item in enumerate(source, 1):
            if (
                not isinstance(item, dict)
                or not positive(item.get("id"))
                or not positive(item.get("quantity"))
                or not text(item.get("name"), 100)
            ):
                raise ValueError("Invalid native observed reward item")
            items.append(
                {
                    "itemID": item["id"],
                    "name": item["name"],
                    "quantity": item["quantity"],
                    "group": group,
                    "slot": slot,
                }
            )
    checked_items(items)
    # Duplicate identities across groups/slots cannot prove an unambiguous move.
    ids = [item["itemID"] for item in items]
    if not items or len(ids) != len(set(ids)):
        raise ValueError("Ambiguous or empty native reward observation")
    return items


def overlay(expected, record, replacements):
    """Retain unobserved facts; move positive IDs and apply reviewed replacements."""
    old = copy.deepcopy(checked_items(expected["items"]))
    observed = observed_items(record)
    if not isinstance(replacements, list) or len(replacements) > len(old):
        raise ValueError("Invalid native reward replacements")
    for replacement in replacements:
        if not isinstance(replacement, dict) or set(replacement) != {
            "expected",
            "observed",
        }:
            raise ValueError("Invalid explicit native reward replacement")
        before, after = replacement["expected"], replacement["observed"]
        checked_items([before])
        checked_items([after])
        if (
            before not in old
            or after not in observed
            or before["group"] != after["group"]
            or before["slot"] != after["slot"]
            or (before["itemID"], before["quantity"])
            == (after["itemID"], after["quantity"])
            or before["itemID"] != after["itemID"]
            and before["quantity"] != after["quantity"]
        ):
            raise ValueError("Replacement lacks an exact observed slot/quantity")
        old.remove(before)
    known = {item["itemID"]: item for item in old}
    if len(known) != len(old):
        raise ValueError("Ambiguous prior reward identity")
    for item in observed:
        previous = known.get(item["itemID"])
        if previous and previous["quantity"] != item["quantity"]:
            raise ValueError("Quantity correction requires an explicit replacement")
    target = []
    for group in GROUPS:
        group_observed = [
            copy.deepcopy(item) for item in observed if item["group"] == group
        ]
        group_ids = {item["itemID"] for item in observed}
        # Native IDs are positive role facts; unrelated old rewards survive.
        retained = [
            copy.deepcopy(item)
            for item in old
            if item["group"] == group and item["itemID"] not in group_ids
        ]
        rows = group_observed + retained
        for slot, item in enumerate(rows, 1):
            item["slot"] = slot
        target.extend(rows)
    checked_items(target)
    return {
        "items": target,
        "itemState": "published",
        "itemGroupStates": {
            group: "published"
            if any(item["group"] == group for item in target)
            else "unknown"
            for group in GROUPS
        },
    }


def validate_native_record(update, sources, title=None):
    """Bind an exact native row and its explicit row or snapshot observation time."""
    observation = update.get("nativeObservation")
    record = update.get("nativeRecord")
    if (
        not isinstance(observation, dict)
        or set(observation) != {"source", "build", "observedAt", "payloadSha256"}
        or not text(observation.get("source"))
    ):
        raise ValueError("Invalid native reward observation binding")
    receipt = sources.get(observation["source"], {})
    if (
        observation["source"] not in update["evidence"]
        or not isinstance(receipt, dict)
        or receipt.get("url") != SOURCE_URL
        or not sha(receipt.get("sha256"))
        or not positive(receipt.get("bytes"))
        or not timestamp(receipt.get("collectedAt"))
        or not positive(observation["build"])
        or not timestamp(observation["observedAt"])
        or not sha(observation["payloadSha256"])
        or not isinstance(record, dict)
        or not positive(record.get("id"))
        or record["id"] != update["id"]
        or record.get("name") != (update["title"] if title is None else title)
        or not positive(record.get("sourceBuild"))
        or record["sourceBuild"] != observation["build"]
        or record.get("payloadSha256") != observation["payloadSha256"]
    ):
        raise ValueError("Native reward correction does not match its receipt/record")
    if "observedAt" in record:
        if (
            record["observedAt"] != observation["observedAt"]
            or "nativeSnapshot" in update
        ):
            raise ValueError("Native row observation time changed")
    else:
        snapshot = update.get("nativeSnapshot")
        if (
            not isinstance(snapshot, dict)
            or set(snapshot) != {"schemaVersion", "build", "observedAt", "rewardScope"}
            or type(snapshot["schemaVersion"]) is not int
            or snapshot["schemaVersion"] != 1
            or not positive(snapshot["build"])
            or snapshot["build"] < record["sourceBuild"]
            or snapshot["observedAt"] != observation["observedAt"]
            or snapshot["rewardScope"] != SOURCE_SCOPE
        ):
            raise ValueError("Native row requires an exact observed snapshot envelope")


def reviewed_native_rewards(document, public):
    """Validate a separate narrow authority, leaving older receipts untouched."""
    if document is None:
        return {}
    result = {}
    public = {row["id"]: row for row in public["records"]}
    sources = document.get("sources", {})
    for update in document.get("nativeRewardUpdates", []):
        required = {
            "id",
            "title",
            "expected",
            "changes",
            "evidence",
            "reason",
            "nativeObservation",
            "nativeRecord",
            "replacements",
            "priorSource",
        }
        if (
            not isinstance(update, dict)
            or set(update) - {"nativeSnapshot"} != required
            or not positive(update["id"])
            or update["id"] in result
            or not text(update["title"])
            or not text(update["reason"], 2000)
            or not isinstance(update["evidence"], list)
            or not update["evidence"]
            or not all(text(key) for key in update["evidence"])
            or len(update["evidence"]) != len(set(update["evidence"]))
            or set(update["evidence"]) - sources.keys()
        ):
            raise ValueError("Invalid native reward correction identity/evidence")
        validate_native_record(update, sources)
        record = update["nativeRecord"]
        before, after = update["expected"], update["changes"]
        for fields in (before, after):
            if not isinstance(fields, dict) or set(fields) != FIELDS:
                raise ValueError("Native correction may change only item facts")
            checked_items(fields["items"])
            if fields["itemState"] not in (
                "published",
                "published-empty",
                "unknown",
            ) or bool(fields["items"]) != (fields["itemState"] == "published"):
                raise ValueError("Invalid native correction item state")
            states = fields["itemGroupStates"]
            if states is not None and (
                not isinstance(states, dict)
                or set(states) != set(GROUPS)
                or any(
                    value not in ("published", "unknown") for value in states.values()
                )
            ):
                raise ValueError("Invalid native correction group states")
        target = overlay(before, record, update["replacements"])
        if update["replacements"]:
            original = public.get(update["id"], {})
            prior = update["priorSource"]
            if (
                not isinstance(prior, dict)
                or set(prior) != {"url", "sha256", "bytes"}
                or prior["url"]
                != "https://www.forevervsclassic.com/quests/" + str(update["id"])
                or not sha(prior["sha256"])
                or not positive(prior["bytes"])
            ):
                raise ValueError(
                    "Reward replacement lacks the exact prior public receipt"
                )
            adopted = (
                original.get("items") == after["items"]
                and original.get("itemState") == after["itemState"]
            )
            if not adopted:
                if original.get("source") != prior:
                    raise ValueError("Reward replacement prior public receipt changed")
                for replacement in update["replacements"]:
                    if replacement.get("expected") not in original.get("items", []):
                        raise ValueError(
                            "Reward replacement does not match the prior public slot"
                        )
        elif update["priorSource"] is not None:
            raise ValueError("Unused reward replacement source")
        if before == after or target != after:
            raise ValueError(
                "Native reward correction is not the exact positive overlay"
            )
        result[update["id"]] = update
    return result


def verify_native_source(document, source_key, raw):
    """Acquisition-time binding of full recorded rows to their original bytes."""
    receipt = document["sources"][source_key]
    if (
        len(raw) != receipt["bytes"]
        or hashlib.sha256(raw).hexdigest() != receipt["sha256"]
    ):
        raise ValueError("Native reward source bytes differ from the receipt")
    source = json.loads(raw)
    if source.get("schemaVersion") != 1 or source.get("rewardScope") != SOURCE_SCOPE:
        raise ValueError("Unsupported native reward source schema")
    records = {record["id"]: record for record in source["quests"]}
    if len(records) != len(source["quests"]):
        raise ValueError("Duplicate native quest identity")
    for update in document.get("nativeRewardUpdates", []) + [
        row for row in document.get("records", []) if "nativeRecord" in row
    ]:
        if (
            update["nativeObservation"]["source"] == source_key
            and records.get(update["id"]) != update["nativeRecord"]
        ):
            raise ValueError("Native reward record differs from original source bytes")
        if (
            update["nativeObservation"]["source"] == source_key
            and "nativeSnapshot" in update
            and update["nativeSnapshot"]
            != {
                key: source.get(key)
                for key in ("schemaVersion", "build", "observedAt", "rewardScope")
            }
        ):
            raise ValueError(
                "Native snapshot envelope differs from original source bytes"
            )
