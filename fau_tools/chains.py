"""Import exact pinned Forever chain facts without executing upstream Lua.

Final Baked fields retain their typed meaning. Only an exact, explicit Forever
authored field surviving that final composition can establish a hard relation.
Inherited facts and ATT links remain useful disclosure, never server proof."""

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path

from fau_tools import questie as provider
from fau_tools.context import ROOT

AUTHORED = "src/corrections/Forever/foreverQuestFixes.lua"
AUTHORED_BLOB = "3c7b34dfec76a30af9a1e97f010b1cd662882dda"
FIELDS = {
    "preQuestGroup": 12,
    "preQuestSingle": 13,
    "childQuests": 14,
    "inGroupWith": 15,
    "exclusiveTo": 16,
    "nextQuestInChain": 22,
    "parentQuest": 25,
    "breadcrumbForQuestId": 27,
    "breadcrumbs": 28,
    "availableUntilCompleted": 33,
    "availableStartingWith": 34,
    "disabledByQuest": 36,
}
ARRAYS = {12, 13, 14, 15, 16, 28}
RELATIONS = {
    "childQuests": "unlocks",
    "inGroupWith": "related",
    "exclusiveTo": "exclusive",
    "nextQuestInChain": "supersededBy",
    "parentQuest": "requiresActive",
    "breadcrumbForQuestId": "breadcrumb",
    "breadcrumbs": "optionalPrerequisite",
    "availableUntilCompleted": "untilCompleted",
    "availableStartingWith": "startingWith",
    "disabledByQuest": "disabledWhileActive",
}


def blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def acquire(root):
    path = root / "chain-source/foreverQuestFixes.lua"
    raw = (
        path.read_bytes()
        if path.is_file()
        else provider.fetch(
            f"https://raw.githubusercontent.com/{provider.REPOSITORY}/{provider.REVISION}/{AUTHORED}"
        )
    )
    if blob(raw) != AUTHORED_BLOB:
        raise ValueError("Pinned Forever authored chain source mismatch")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(raw)
    return raw


def ids(value, own, signed=False):
    if not isinstance(value, list) or not value or len(value) > 128:
        return None
    if any(
        type(v) is not int
        or v == 0
        or not 0 < abs(v) < 2**31
        or (v < 0 and not signed)
        or abs(v) == own
        for v in value
    ):
        return None
    if len({abs(v) for v in value}) != len(value):
        return None
    return sorted(value, key=lambda v: abs(v))


def dynamic_owners(text, selected):
    tokens = provider.tokenize(text)
    ends = provider.bounds(tokens)
    result = set()
    names = {"questKeys." + name for name in selected}
    for index, (word, _) in enumerate(tokens[:-4]):
        if (
            word == "["
            and tokens[index + 1][0].isdigit()
            and tokens[index + 2][0] == "]"
            and tokens[index + 3][0] == "="
            and tokens[index + 4][0] == "{"
        ):
            if any(token in names for token, _ in tokens[index + 4 : ends[index + 4]]):
                result.add(int(tokens[index + 1][0]))
    return result


def import_chains(receipt, files, authored_raw, quests, att_records=None):
    """Return normalized facts and every omitted malformed relation disposition."""
    if blob(authored_raw) != AUTHORED_BLOB:
        raise ValueError("Unreviewed Forever authored chain source")
    baked = provider.Baked(files[provider.TOC])
    authored_text = authored_raw.decode("utf-8")
    if authored_text.count("function ForeverQuestFixes:LoadDynamic()") != 1:
        raise ValueError("Unsupported Forever static/dynamic boundary")
    static, dynamic_text = authored_text.split(
        "function ForeverQuestFixes:LoadDynamic()"
    )
    selected = set(FIELDS) | {key + op for key in FIELDS for op in ("_add", "_remove")}
    authored = provider.source_fields(static, "questKeys", selected)
    dynamic = dynamic_owners(dynamic_text, selected)
    # Packaged correction bodies are Dynamic; Static bodies were folded into
    # the Baked TOC. A dynamic owner cannot yield a universal hard requirement.
    for path, raw in files.items():
        if (
            path.startswith("src/corrections/Forever/")
            and not path.startswith(provider.GENERATED)
            and path.endswith(".lua")
        ):
            dynamic.update(dynamic_owners(raw.decode("utf-8"), selected))
    inventory = {q["id"]: q for q in quests}
    records, omissions = [], []
    counts = Counter()
    for quest in sorted(quests, key=lambda q: q["id"]):
        own = quest["id"]
        groups, relations, evidence = [], [], []
        values = {
            name: baked.field("Quest", own, index) for name, index in FIELDS.items()
        }

        def proof(name, value):
            observed = authored.get(own, {})
            verified = (
                observed.get("fields", {}).get(name) == value
                and name in observed.get("fields", {})
                and own not in dynamic
                and quest.get("confirmation") == "published"
            )
            evidence.append(
                {
                    "field": name,
                    "index": FIELDS[name],
                    "value": value,
                    "basis": "forever-authored-surviving-final"
                    if verified
                    else "inherited-final-forever-artifact",
                    "verified": verified,
                    "authoredLine": observed.get("line") if verified else None,
                }
            )
            return verified

        # The provider's preQuestSingle takes precedence over preQuestGroup;
        # these are alternative encodings, not two simultaneous requirements.

        name = "preQuestSingle" if values["preQuestSingle"] else "preQuestGroup"
        value = values[name]
        if value:
            selected_ids = ids(value, own, signed=name == "preQuestGroup")
            if selected_ids is None:
                omissions.append(
                    {
                        "id": own,
                        "field": name,
                        "value": value,
                        "cause": "invalid-duplicate-self-or-unsupported-prerequisites",
                    }
                )
            else:
                verified = proof(name, value) and all(
                    abs(v) in inventory for v in selected_ids
                )
                group = {
                    "kind": "any" if name == "preQuestSingle" else "all",
                    "ids": [abs(v) for v in selected_ids],
                    "verified": verified,
                }
                strict = [abs(v) for v in selected_ids if v < 0]
                if strict:
                    group["noAlternates"] = strict
                groups.append(group)
        elif quest.get("prerequisites"):
            selected_ids = ids(quest["prerequisites"], own)
            threshold = quest.get("prerequisiteCount")
            if selected_ids and (
                threshold is None
                or type(threshold) is int
                and 1 <= threshold <= len(selected_ids)
            ):
                group = {
                    "kind": "count" if threshold is not None else "all",
                    "ids": selected_ids,
                    "verified": False,
                }
                if threshold is not None:
                    group["count"] = threshold
                groups.append(group)
                evidence.append(
                    {
                        "field": "sourceQuests",
                        "basis": "att-authored-unverified-links",
                        "sources": (att_records or {}).get(own, {}).get("sources", []),
                    }
                )
        for field, kind in RELATIONS.items():
            value = values[field]
            if value in (None, 0, []):
                continue
            selected_ids = ids(value if FIELDS[field] in ARRAYS else [value], own)
            if selected_ids is None:
                omissions.append(
                    {
                        "id": own,
                        "field": field,
                        "value": value,
                        "cause": "invalid-duplicate-self-or-unsupported-relation",
                    }
                )
                continue
            verified = proof(field, value)
            for identity in selected_ids:
                relations.append(
                    {
                        "kind": kind,
                        "id": identity,
                        "verified": verified and identity in inventory,
                    }
                )
        if groups or relations:
            chain = {"groups": groups, "relations": relations}
            records.append({"id": own, "chain": chain, "evidence": evidence})
    # Explicit optional breadcrumbs override weaker ATT-only mandatory links.
    # Preserve the original group and its receipt as overridden evidence, rather
    # than displaying the same exact quest as both mandatory and optional.
    incoming_optional = {}
    for record in records:
        for relation in record["chain"]["relations"]:
            if relation["kind"] == "breadcrumb" and relation["verified"]:
                incoming_optional.setdefault(relation["id"], set()).add(record["id"])
    for record in records:
        chain = record["chain"]
        if not any(
            proof["basis"] == "att-authored-unverified-links"
            for proof in record["evidence"]
        ):
            continue
        optional = incoming_optional.get(record["id"], set()) | {
            r["id"]
            for r in chain["relations"]
            if r["kind"] == "optionalPrerequisite" and r["verified"]
        }
        retained = []
        for group in chain["groups"]:
            overridden = sorted(set(group["ids"]) & optional)
            if not overridden:
                retained.append(group)
                continue
            record["evidence"].append(
                {
                    "field": "sourceQuests",
                    "basis": "verified-optional-overrides-att-mandatory",
                    "originalGroup": group,
                    "overriddenIDs": overridden,
                    "optionalProofs": [
                        {"ownerID": identity, "field": "breadcrumbForQuestId"}
                        if identity in incoming_optional.get(record["id"], set())
                        else {"ownerID": record["id"], "field": "breadcrumbs"}
                        for identity in overridden
                    ],
                }
            )
            counts["overriddenFallbackGroups"] += 1
            for identity in overridden:
                if not any(
                    r["kind"] == "optionalPrerequisite" and r["id"] == identity
                    for r in chain["relations"]
                ):
                    chain["relations"].append(
                        {
                            "kind": "optionalPrerequisite",
                            "id": identity,
                            "verified": True,
                        }
                    )
            remaining = [
                identity for identity in group["ids"] if identity not in optional
            ]
            if remaining and group["kind"] == "all":
                retained.append(dict(group, ids=remaining))
            elif remaining:
                # An optional member invalidates a weaker any/count threshold.
                # Keep the other links without inventing a replacement count.
                chain["relations"].extend(
                    {"kind": "related", "id": identity, "verified": False}
                    for identity in remaining
                )
        chain["groups"] = retained
    for record in records:
        for group in record["chain"]["groups"]:
            counts[group["kind"] + "Groups"] += 1
            counts["verifiedGroups"] += group["verified"]
        for relation in record["chain"]["relations"]:
            counts[relation["kind"]] += 1
            counts["verifiedRelations"] += relation["verified"]
    return {
        "schemaVersion": 1,
        "source": {
            "repository": provider.REPOSITORY,
            "revision": provider.REVISION,
            "release": provider.RELEASE,
            "archiveSha256": provider.ARCHIVE_SHA256,
            "files": [
                f
                for f in receipt["files"]
                if f["path"] in (provider.TOC, "src/meta/questMeta.lua")
            ],
            "authored": {
                "path": AUTHORED,
                "url": f"https://github.com/{provider.REPOSITORY}/blob/{provider.REVISION}/{AUTHORED}",
                "gitBlob": AUTHORED_BLOB,
                "sha256": provider.sha(authored_raw),
                "bytes": len(authored_raw),
            },
        },
        "records": records,
        "omissions": omissions,
        "coverage": dict(
            counts,
            records=len(records),
            catalogQuestCount=len(quests),
            omittedFields=len(omissions),
        ),
        "rules": [
            "Typed final Forever fields; single alternatives take precedence over grouped prerequisites",
            "Exact explicit authored field must survive final Baked composition, have published identity and no Dynamic owner to hard-gate",
            "Inherited artifact and ATT links remain unverified; missing relations do not mean no prerequisites",
            "Negative group IDs mean literal completion without exclusive-path substitution; no Classic inference",
            "Breadcrumbs are optional; exclusive paths and superseding quests are distinct from prerequisite completion",
            "Verified optional breadcrumbs override weaker ATT mandatory links; original groups and source receipts remain in override evidence",
            "Only character completion facts; native log/gossip evidence takes precedence; no Questie runtime dependency",
        ],
    }


def build(root, cache):
    from fau_tools.catalog import build_complete

    source, _ = build_complete(root, include_chains=False)
    receipt, files = provider.owned_cache(cache)
    path = cache / "chain-source/foreverQuestFixes.lua"
    if not path.is_file():
        raise ValueError(
            "Pinned authored chain cache missing; run quest_chains.py --acquire during refresh"
        )
    raw = path.read_bytes()
    metadata_path = root / "data/catalog-metadata-records.json"
    metadata = json.loads(metadata_path.read_bytes())
    result = import_chains(
        receipt, files, raw, source["quests"], {r["id"]: r for r in metadata["records"]}
    )
    result["source"]["attMetadata"] = {
        "path": "data/catalog-metadata-records.json",
        "sha256": provider.sha(metadata_path.read_bytes()),
    }
    return result


def main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog, description=__doc__)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument(
        "--acquire",
        action="store_true",
        help="Acquire the pinned public authored file; never implicit in offline reparse",
    )
    args = parser.parse_args(argv)
    if args.acquire:
        raw = acquire(args.source_root)
        print(json.dumps({"gitBlob": blob(raw), "bytes": len(raw)}))
        return
    result = build(ROOT, args.source_root)
    target = ROOT / "data/catalog-chain-records.json"
    target.write_bytes(
        (json.dumps(result, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    )
    provenance_path = ROOT / "data/catalog-complete-sources.json"
    provenance = json.loads(provenance_path.read_bytes())
    provenance["inputs"]["chains"] = {
        "path": "data/catalog-chain-records.json",
        "sha256": provider.sha(target.read_bytes()),
    }
    provenance_path.write_bytes(
        (json.dumps(provenance, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    )
    from fau_tools.catalog import build_complete

    source, report = build_complete(ROOT)
    for name, value in (
        ("catalog-complete-source.json", source),
        ("catalog-reconciliation.json", report),
    ):
        (ROOT / "data" / name).write_bytes(
            (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
        )
    print(json.dumps(result["coverage"], indent=2))
