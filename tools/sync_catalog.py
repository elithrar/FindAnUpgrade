"""Standalone, incremental public acquisition and verified catalog replacement.

check is offline. reparse uses owned caches. refresh acquires ordinary public
pages and pinned ATT files. No command commits, installs, publishes or runs Lua
from upstream sources. Only a fully verified staged candidate can replace data.
"""

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import uuid
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = [
    "data/" + name
    for name in (
        "catalog-public-records.json",
        "catalog-metadata-records.json",
        "catalog-compiled-quests.json",
        "catalog-primary-records.json",
        "catalog-client-evidence.json",
        "catalog-identity-history.json",
        "catalog-chain-records.json",
        "catalog-gap-evidence.json",
        "catalog-complete-sources.json",
        "catalog-complete-source.json",
        "catalog-reconciliation.json",
        "catalog-coverage.json",
        "catalog-supplemental-metadata.json",
        "primary-statuses.json",
        "classification-reconciliation.json",
        "quest-taxonomy.json",
    )
] + ["FindAnUpgrade/Data/Catalog.lua", "FindAnUpgrade/Data/Quests.lua"]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None


def run(root, arguments):
    print("python " + " ".join(map(str, arguments)), flush=True)
    subprocess.run([sys.executable, *map(str, arguments)], cwd=root, check=True)


def compare(old, new):
    before = {row["id"]: row for row in old["quests"]}
    after = {row["id"]: row for row in new["quests"]}
    changed = []
    for quest in sorted(before.keys() & after.keys()):
        fields = sorted(
            key
            for key in before[quest].keys() | after[quest].keys()
            if before[quest].get(key) != after[quest].get(key)
        )
        if fields:
            changed.append({"id": quest, "fields": fields})
    return {
        "addedIDs": sorted(after.keys() - before.keys()),
        "removedIDs": sorted(before.keys() - after.keys()),
        "changed": changed,
    }


def apply_candidate(root, stage, baseline, input_baseline=None):
    """Check for concurrent edits, prewrite all replacements, rollback on failure."""
    if set(baseline) != set(OUTPUTS):
        raise ValueError("Unexpected replacement inventory")
    for name, expected in (input_baseline or {}).items():
        if sha(root / name) != expected:
            raise ValueError("Concurrent frozen input edit: " + name)
    for name, expected in baseline.items():
        if sha(root / name) != expected:
            raise ValueError("Concurrent catalog edit: " + name)
    originals = {
        name: (root / name).read_bytes() if (root / name).exists() else None
        for name in OUTPUTS
    }
    temporary = {}
    replaced = []
    try:
        for name in OUTPUTS:
            source = stage / name
            if not source.is_file():
                raise ValueError("Missing validated candidate: " + name)
            target = root / name
            if not target.resolve().is_relative_to(root.resolve()):
                raise ValueError("Replacement outside repository")
            path = target.with_name(target.name + ".sync-" + uuid.uuid4().hex)
            path.write_bytes(source.read_bytes())
            temporary[name] = path
        for name, expected in baseline.items():
            if sha(root / name) != expected:
                raise ValueError("Concurrent catalog edit: " + name)
        for name, expected in (input_baseline or {}).items():
            if sha(root / name) != expected:
                raise ValueError("Concurrent frozen input edit: " + name)
        for name in OUTPUTS:
            temporary[name].replace(root / name)
            replaced.append(name)
    except Exception:
        for name in replaced:
            if originals[name] is None:
                (root / name).unlink()
            else:
                (root / name).write_bytes(originals[name])
        raise
    finally:
        for path in temporary.values():
            path.unlink(missing_ok=True)


def stage_sources(root, stage):
    stage.mkdir(parents=True)
    (stage / ".work").mkdir()
    for name in ("FindAnUpgrade", "data", "docs", "tests", "tools", ".github"):
        shutil.copytree(
            root / name,
            stage / name,
            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
        )
    for name in (
        "AGENTS.md",
        "README.md",
        "plan.md",
        "LICENSE",
        ".gitignore",
        ".gitattributes",
        "pyproject.toml",
        "uv.lock",
        ".python-version",
    ):
        shutil.copyfile(root / name, stage / name)
    for name in ("blizzard", "current-api"):
        source = root / ".work" / name
        if source.is_dir():
            shutil.copytree(source, stage / ".work" / name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "reparse", "refresh"))
    parser.add_argument("--cache-root", type=Path, default=ROOT / ".work/catalog-cache")
    parser.add_argument("--public-root", type=Path)
    parser.add_argument("--authoring-root", type=Path)
    parser.add_argument("--compiled-root", type=Path)
    parser.add_argument(
        "--primary-cache",
        type=Path,
        help="Optional retained raw pages, never downloaded by this tool",
    )
    parser.add_argument(
        "--client-cache", type=Path, help="Optional read-only 70374 identity cache"
    )
    parser.add_argument(
        "--questie-root",
        type=Path,
        help="Pinned optional numeric Forever metadata cache",
    )
    parser.add_argument(
        "--refresh-details",
        action="store_true",
        help="Revalidate all detail pages rather than warm unchanged rows",
    )
    parser.add_argument("--max-age-hours", type=float, default=24)
    args = parser.parse_args()
    if args.mode == "check":
        run(ROOT, ["tools/verify.py"])
        return
    public = (args.public_root or args.cache_root / "public").resolve()
    authored = (args.authoring_root or args.cache_root / "att-source").resolve()
    compiled = (args.compiled_root or args.cache_root / "att-generated").resolve()
    questie = (args.questie_root or args.cache_root / "questie").resolve()
    if args.mode == "refresh":
        run(ROOT, ["tools/questie_metadata.py", "acquire", "--source-root", questie])
        run(ROOT, ["tools/quest_chains.py", "--source-root", questie, "--acquire"])
        run(
            ROOT,
            [
                "tools/acquire_catalog_sources.py",
                "--source-root",
                authored,
                "--compiled-root",
                compiled,
            ],
        )
        run(
            ROOT,
            [
                "tools/collect_catalog_sources.py",
                "--source-root",
                public,
                "--mode",
                "index",
                "--refresh",
            ],
        )
        command = [
            "tools/collect_catalog_sources.py",
            "--source-root",
            public,
            "--mode",
            "quests",
            "--max-age-hours",
            args.max_age_hours,
        ]
        if args.refresh_details:
            command.append("--refresh")
        run(ROOT, command)
        from complete_catalog import read_inputs
        from import_complete_catalog import compiled_ids

        _, owned = read_inputs(ROOT)
        ids = set(compiled_ids(compiled)["questIDs"])
        ids.update(owned.get("history", {}).get("questIDs", []))
        ids.update(
            row["id"] for row in owned["public"]["records"] + owned["legacy"]["quests"]
        )
        ids.update(owned["client"]["questIDs"])
        candidate_file = public / "candidate-ids.json"
        candidate_file.write_text(
            json.dumps({"questIDs": sorted(ids)}) + "\n", encoding="utf-8"
        )
        run(
            ROOT,
            [
                "tools/collect_catalog_sources.py",
                "--source-root",
                public,
                "--mode",
                "candidates",
                "--candidate-ids",
                candidate_file,
                "--refresh",
            ],
        )
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    stage = ROOT / ".work/catalog-sync" / stamp
    baseline = {name: sha(ROOT / name) for name in OUTPUTS}
    frozen = {
        path.relative_to(ROOT).as_posix(): sha(path)
        for directory in (ROOT / "data", ROOT / "tools")
        for path in directory.rglob("*")
        if path.is_file()
        and path.suffix in (".json", ".py")
        and "__pycache__" not in path.parts
        and path.relative_to(ROOT).as_posix() not in OUTPUTS
    }
    stage_sources(ROOT, stage)
    for name, expected in frozen.items():
        if sha(stage / name) != expected:
            raise ValueError("Frozen input changed during snapshot: " + name)
    # Classification/category evidence is an owned frozen input. Regeneration
    # must survive standalone reparses without another website checkout.
    run(stage, ["tools/import_classifications.py"])
    run(stage, ["tools/generate_data.py"])
    command = [
        "tools/import_complete_catalog.py",
        "--source-root",
        public,
        "--att-source-root",
        authored,
        "--compiled-root",
        compiled,
    ]
    for key, path in (
        ("--primary-cache", args.primary_cache),
        ("--client-cache", args.client_cache),
    ):
        if path:
            command.extend([key, path.resolve()])
    if args.questie_root or questie.is_dir():
        command.extend(["--questie-root", questie])
    run(stage, command)
    taxonomy = ["tools/quest_taxonomy.py"]
    if args.primary_cache:
        taxonomy.extend(["--primary-cache", args.primary_cache.resolve()])
    run(stage, taxonomy)
    run(stage, ["tools/generate_data.py"])
    run(stage, ["tools/generate_catalog.py"])
    diff = compare(
        json.loads((ROOT / "data/catalog-complete-source.json").read_bytes()),
        json.loads((stage / "data/catalog-complete-source.json").read_bytes()),
    )
    report = {
        "checkedAt": datetime.now(UTC).isoformat(),
        "stage": str(stage),
        "mode": args.mode,
        "diff": diff,
        "before": baseline,
        "frozenInputs": frozen,
        "after": {name: sha(stage / name) for name in OUTPUTS},
        "applied": False,
    }
    report_path = ROOT / "dist/catalog-sync-diff.json"
    report_path.parent.mkdir(exist_ok=True)

    def receipt():
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    receipt()
    if diff["removedIDs"]:
        raise ValueError("Exact IDs disappeared from the monotonic inventory")
    run(stage, ["tools/verify.py"])
    apply_candidate(ROOT, stage, baseline, frozen)
    report["applied"] = True
    receipt()
    print(
        json.dumps(
            {
                "applied": True,
                "addedIDs": len(diff["addedIDs"]),
                "changedIDs": len(diff["changed"]),
                "report": str(report_path),
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
