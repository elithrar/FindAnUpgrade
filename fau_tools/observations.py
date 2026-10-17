"""Validate untrusted, data-only encounter exports; compare without ingesting facts."""

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

from fau_tools.context import ROOT

MAX_BYTES = 262144
MAX_RECORDS = 250
STAGES = {
    "listed",
    "listed_active",
    "offered",
    "progress",
    "completion",
    "accepted",
    "turned_in",
}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def obj(value, required, optional=()):
    require(type(value) is dict, "Expected an object")
    require(
        set(required) <= value.keys() <= set(required) | set(optional),
        "Missing or unknown fields",
    )
    return value


def integer(value, low=1, high=2147483647):
    require(type(value) is int and low <= value <= high, "Invalid integer")


def text(value, limit):
    require(type(value) is str, "Expected text")
    try:
        size = len(value.encode("utf-8"))
    except UnicodeError as error:
        raise ValueError("Invalid Unicode") from error
    require(
        0 < size <= limit
        and all(ord(c) >= 32 and ord(c) != 127 and c != "|" for c in value),
        "Invalid text",
    )


def field(value):
    obj(value, {"state"}, {"value"})
    require(value["state"] in ("ready", "unknown"), "Invalid field state")
    if value["state"] == "ready":
        require("value" in value, "Ready field missing value")
        integer(value["value"], 0)
    else:
        require("value" not in value, "Unknown field contains a value")


def group(value, choice):
    obj(value, {"state", "slots"}, {"expected", "choose"} if choice else {"expected"})
    require(type(value["slots"]) is list, "Slots must be an array")
    require(value["state"] in ("ready", "unknown", "partial"), "Invalid reward state")
    if value["state"] == "unknown":
        require(
            set(value) == {"state", "slots"} and not value["slots"],
            "Unknown rewards cannot imply a count",
        )
        return
    integer(value.get("expected"), 0, 32)
    expected = value["expected"]
    require(len(value["slots"]) == expected, "Incomplete slot inventory")
    if choice:
        integer(value.get("choose"), 0, 1)
        require(value["choose"] == int(expected > 0), "Invalid choose-one count")
    partial = False
    for index, slot in enumerate(value["slots"], 1):
        obj(slot, {"slot", "state"}, {"kind", "id", "quantity", "contextFlags"})
        integer(slot["slot"], 1, 32)
        require(slot["slot"] == index, "Duplicate, reordered or missing slot")
        require(slot["state"] in ("ready", "unknown"), "Invalid slot state")
        if slot["state"] == "unknown":
            require(
                set(slot) == {"slot", "state"}, "Unknown slot contains reward facts"
            )
            partial = True
        else:
            require(
                {"kind", "id", "quantity"} <= slot.keys(), "Ready slot missing facts"
            )
            require(
                slot["kind"] in (("item", "currency") if choice else ("item",)),
                "Invalid reward kind",
            )
            integer(slot["id"])
            integer(slot["quantity"])
            if "contextFlags" in slot:
                integer(slot["contextFlags"], 0)
    require(
        (value["state"] == "partial") == partial, "Reward readiness contradicts slots"
    )


def record(row):
    obj(
        row,
        {
            "questID",
            "stage",
            "client",
            "titleState",
            "context",
            "source",
            "location",
            "questLevel",
            "rewards",
            "samples",
        },
        {"title"},
    )
    integer(row["questID"])
    require(row["stage"] in STAGES, "Unknown encounter stage")
    integer(row["samples"], 1, 1000000)
    client = obj(row["client"], {"version", "build", "interface", "locale"})
    text(client["version"], 32)
    require(
        re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", client["version"]) is not None,
        "Invalid client version",
    )
    integer(client["build"])
    integer(client["interface"])
    require(client["interface"] == 16001, "Unsupported client interface")
    text(client["locale"], 8)
    require(
        re.fullmatch(r"[a-z]{2}[A-Z]{2}", client["locale"]) is not None,
        "Invalid locale",
    )
    require(
        row["titleState"] in ("ready", "redacted", "unknown"), "Invalid title state"
    )
    require(
        (row["titleState"] == "unknown") == ("title" not in row),
        "Title state contradicts value",
    )
    if "title" in row:
        text(row["title"], 256)
    context = obj(row["context"], set(), {"faction", "classID", "raceID", "level"})
    if "faction" in context:
        require(
            context["faction"] in ("Alliance", "Horde", "Neutral"), "Unknown faction"
        )
    for name, high in (("classID", 64), ("raceID", 256), ("level", 200)):
        if name in context:
            integer(context[name], 1, high)
    source = obj(row["source"], {"kind", "role"}, {"id"})
    require(
        source["kind"] in ("npc", "item", "object", "unknown"), "Invalid source kind"
    )
    require(source["role"] in ("starter", "ender", "unknown"), "Invalid source role")
    if source["kind"] == "unknown":
        require(
            source["role"] == "unknown" and "id" not in source,
            "Unknown source contains an association",
        )
    else:
        integer(source.get("id"))
    location = obj(row["location"], {"kind"}, {"uiMapID", "x", "y"})
    require(location["kind"] == "observer", "Positions must identify the observer")
    if "uiMapID" in location:
        integer(location["uiMapID"])
    if "x" in location or "y" in location:
        require(
            {"uiMapID", "x", "y"} <= location.keys(), "Incomplete observer position"
        )
        for name in ("x", "y"):
            value = location[name]
            require(
                type(value) in (int, float)
                and math.isfinite(value)
                and 0 <= value <= 1,
                "Invalid coordinate",
            )
    field(row["questLevel"])
    rewards = obj(
        row["rewards"],
        {"scope", "otherRewards", "guaranteed", "choices", "xp", "money"},
    )
    require(
        rewards["scope"] == "dialog-items-and-choice-currencies"
        and rewards["otherRewards"] == "unknown",
        "Unsupported reward scope",
    )
    group(rewards["guaranteed"], False)
    group(rewards["choices"], True)
    field(rewards["xp"])
    field(rewards["money"])


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key")
        result[key] = value
    return result


def load(payload):
    """Bound bytes and structural depth before invoking the JSON decoder."""
    require(
        type(payload) is bytes and len(payload) <= MAX_BYTES,
        "Export exceeds byte limit",
    )
    try:
        source = payload.decode("utf-8")
    except UnicodeError as error:
        raise ValueError("Export is not UTF-8") from error
    depth, quoted, escaped = 0, False, False
    for char in source:
        if quoted:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif char in "[{":
            depth += 1
            require(depth <= 12, "Export nesting limit exceeded")
        elif char in "]}":
            depth -= 1
    try:
        data = json.loads(
            source,
            object_pairs_hook=unique_object,
            parse_constant=lambda _: require(False, "Nonfinite JSON number"),
        )
        obj(data, {"format", "schema", "addonVersion", "dropped", "records"})
        require(
            data["format"] == "FindAnUpgrade.quest-observations",
            "Unknown export format",
        )
        integer(data["schema"])
        require(data["schema"] == 1, "Unsupported observation schema")
        text(data["addonVersion"], 32)
        integer(data["dropped"], 0, 1000000)
        require(
            type(data["records"]) is list and len(data["records"]) <= MAX_RECORDS,
            "Invalid record count",
        )
        variants, seen = {}, set()
        for row in data["records"]:
            record(row)
            identity = json.dumps(
                {k: v for k, v in row.items() if k != "samples"},
                sort_keys=True,
                ensure_ascii=True,
            )
            require(identity not in seen, "Duplicate observation")
            seen.add(identity)
            key = (row["questID"], row["stage"])
            variants[key] = variants.get(key, 0) + 1
            require(variants[key] <= 12, "Observation variant limit exceeded")
    except (TypeError, KeyError, OverflowError, RecursionError) as error:
        raise ValueError("Malformed observation structure") from error
    return data


def compare(data, catalog):
    """Report candidates with their native context; never synthesize canonical records."""
    baseline = {row["id"]: row for row in catalog["quests"]}
    rows = []
    for observation in data["records"]:
        current = baseline.get(observation["questID"])
        notes = []
        if current is None:
            notes.append("ID absent from bundled catalog")
        else:
            if (
                observation["titleState"] == "ready"
                and current.get("title") != observation["title"]
            ):
                notes.append("Title differs from bundled catalog")
            if observation["context"].get("faction") and current.get("faction") not in (
                None,
                "Both",
                observation["context"]["faction"],
            ):
                notes.append(
                    "Observer faction differs from published restriction; review availability"
                )
            for name, kind in (("guaranteed", "guaranteed"), ("choices", "choice")):
                group_data = observation["rewards"][name]
                if group_data["state"] != "ready":
                    notes.append(f"{name}: native enumeration incomplete")
                    continue
                native = sorted(
                    (slot["slot"], slot["id"], slot["quantity"])
                    for slot in group_data["slots"]
                    if slot["kind"] == "item"
                )
                published = sorted(
                    (item.get("slot"), item["itemID"], item.get("quantity"))
                    for item in current.get("items", [])
                    if item["group"] == kind
                )
                if (
                    current.get("itemState") in ("published", "published-empty")
                    and native != published
                ):
                    notes.append(
                        f"{name}: player-visible item slots differ from published base; may be context filtering"
                    )
        rows.append(
            {
                "questID": observation["questID"],
                "stage": observation["stage"],
                "client": observation["client"],
                "context": observation["context"],
                "notes": notes,
            }
        )
    return {
        "schema": 1,
        "productionEligible": False,
        "catalogBuild": catalog.get("targetBuild"),
        "records": rows,
        "limitations": [
            "Untrusted observations require independent source review; no catalog files were changed.",
            "Observer context does not establish all faction/class/race availability or NPC spawn coordinates.",
            "Player-visible options and XP/money are not universal or published base rewards; other reward types remain unknown.",
        ],
    }


def main(argv=None, prog="python -m fau_tools observations"):
    parser = argparse.ArgumentParser(prog=prog, description=__doc__)
    parser.add_argument(
        "export",
        type=Path,
        help="Manual JSON export; SavedVariables Lua is never evaluated",
    )
    args = parser.parse_args(argv)
    with args.export.open("rb") as stream:
        payload = stream.read(MAX_BYTES + 1)
    try:
        data = load(payload)
    except ValueError as error:
        parser.exit(2, f"Invalid observation export: {error}\n")
    catalog = json.loads((ROOT / "data/catalog-complete-source.json").read_bytes())
    report = compare(data, catalog)
    report["submissionSha256"] = hashlib.sha256(payload).hexdigest()
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
