"""Run style checks, behavioral tests and a local build without external writes."""

import json
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COMMANDS = (
    ("-m", "ruff", "check", "tools", "tests"),
    ("-m", "ruff", "format", "--check", "tools", "tests"),
    ("tools/import_classifications.py", "--check"),
    ("tools/quest_taxonomy.py", "--check"),
    ("tests/quest_taxonomy_test.py",),
    ("tests/quest_chain_test.py",),
    ("tools/generate_data.py", "--check"),
    ("tests/run.py",),
    ("tests/data_test.py",),
    ("tools/generate_catalog.py", "--check"),
    ("tests/catalog_test.py",),
    ("tests/complete_catalog_test.py",),
    ("tests/catalog_sync_test.py",),
    ("tests/reward_amount_recovery_test.py",),
    ("tests/starter_coordinate_recovery_test.py",),
    ("tests/recovery_integration_test.py",),
    ("tests/migration_test.py",),
    ("tests/tooling_test.py",),
    ("tests/package_test.py",),
    ("tests/release_test.py",),
    ("tools/package.py",),
)


def trailing_whitespace(root=ROOT):
    """Report source whitespace without altering owned files or evidence."""
    trailing = []
    for name in ("FindAnUpgrade", "data", "docs", "tests", "tools"):
        for file in (root / name).rglob("*"):
            if not file.is_file() or "__pycache__" in file.parts:
                continue
            if file.suffix not in {".lua", ".py", ".md", ".json", ".toc"}:
                continue
            for line, content in enumerate(
                file.read_text(encoding="utf-8").splitlines(), 1
            ):
                if content.rstrip(" \t") != content:
                    trailing.append(f"{file.relative_to(root).as_posix()}:{line}")
    return trailing


def main():
    results = []
    for command in COMMANDS:
        run = subprocess.run(
            [sys.executable, *command],
            cwd=ROOT,
            text=True,
            encoding="utf-8",
            capture_output=True,
        )
        label = "python " + " ".join(command)
        results.append(
            {
                "command": label,
                "exitCode": run.returncode,
                "stdout": run.stdout,
                "stderr": run.stderr,
            }
        )
        print(f"{label}: {'PASS' if run.returncode == 0 else 'FAIL'}", flush=True)
        if run.returncode:
            print(run.stdout, run.stderr)
            break
    trailing = trailing_whitespace(ROOT)
    success = (
        len(results) == len(COMMANDS)
        and all(result["exitCode"] == 0 for result in results)
        and not trailing
    )
    report = {
        "checkedAt": datetime.now(UTC).isoformat(),
        "pythonVersion": sys.version.split()[0],
        "commands": results,
        "trailingWhitespace": trailing,
        "success": success,
    }
    (ROOT / "dist").mkdir(exist_ok=True)
    (ROOT / "dist/validation-evidence.json").write_bytes(
        (json.dumps(report, indent=2) + "\n").encode("utf-8")
    )
    print(
        f"Trailing whitespace: {len(trailing)}; overall: {'PASS' if success else 'FAIL'}"
    )
    if not success:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
