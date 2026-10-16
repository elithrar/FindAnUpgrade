"""Run style checks, behavioral tests and a local build without external writes."""

import json
import subprocess
import sys
from datetime import UTC, datetime

from fau_tools.context import ROOT

COMMANDS = (
    ("-m", "ruff", "check", "fau_tools", "tests"),
    ("-m", "ruff", "format", "--check", "fau_tools", "tests"),
    ("-m", "fau_tools", "data", "classify", "--check"),
    ("-m", "fau_tools", "data", "tags", "--check"),
    ("-m", "fau_tools", "data", "quests", "--check"),
    ("-m", "fau_tools", "data", "catalog", "--check"),
    ("-m", "tests.run"),
    ("-m", "unittest", "discover", "-s", "tests", "-p", "*_test.py"),
    ("-m", "fau_tools", "build"),
)


def trailing_whitespace(root=ROOT):
    """Report source whitespace without altering owned files or evidence."""
    trailing = []
    for name in ("FindAnUpgrade", "data", "tests", "fau_tools"):
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


def main(argv=None):
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
