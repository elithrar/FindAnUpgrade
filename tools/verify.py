"""Capture offline validation and final build evidence without external writes."""
from pathlib import Path
from datetime import datetime, timezone
import json, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]

def main():
    results = []
    commands=[["tools/import_classifications.py", "--check"], ["tools/quest_taxonomy.py", "--check"], ["tests/quest_taxonomy_test.py"], ["tests/quest_chain_test.py"], ["tools/generate_data.py", "--check"], ["tests/run.py"], ["tests/data_test.py"], ["tools/generate_catalog.py", "--check"], ["tests/catalog_test.py"], ["tests/complete_catalog_test.py"], ["tests/catalog_sync_test.py"], ["tests/reward_amount_recovery_test.py"], ["tests/starter_coordinate_recovery_test.py"], ["tests/recovery_integration_test.py"], ["tests/migration_test.py"], ["tests/package_test.py"], ["tests/release_test.py"], ["tools/package.py"]]
    for command in commands:
        run = subprocess.run([sys.executable] + command, cwd=ROOT, text=True, capture_output=True)
        results.append({"command": "python " + " ".join(command), "exitCode": run.returncode, "stdout": run.stdout, "stderr": run.stderr})
        print(f'{results[-1]["command"]}: {"PASS" if run.returncode == 0 else "FAIL"}')
        if run.returncode: print(run.stdout, run.stderr); break
    trailing = []
    source_dirs = [ROOT / d for d in ["FindAnUpgrade", "data", "docs", "tests", "tools"]]
    for directory in source_dirs:
        for file in directory.rglob("*"):
            if file.is_file() and file.suffix in [".lua", ".py", ".md", ".json", ".toc"]:
                if "__pycache__" in file.parts: continue
                for line, text in enumerate(file.read_text(encoding="utf-8").splitlines(), 1):
                    if text.rstrip(" \t") != text: trailing.append(f"{file.relative_to(ROOT).as_posix()}:{line}")
    report = {"checkedAt": datetime.now(timezone.utc).isoformat(), "commands": results, "trailingWhitespace": trailing}
    report["success"] = len(results) == len(commands) and all(x["exitCode"] == 0 for x in results) and not trailing
    (ROOT / "dist").mkdir(exist_ok=True)
    (ROOT / "dist/validation-evidence.json").write_bytes((json.dumps(report, indent=2) + "\n").encode())
    print(f"Trailing whitespace: {len(trailing)}; overall: {'PASS' if report['success'] else 'FAIL'}")
    if not report["success"]: raise SystemExit(1)

if __name__ == "__main__": main()
