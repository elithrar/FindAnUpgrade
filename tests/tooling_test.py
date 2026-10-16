"""Exercise verifier process failures and evidence without running publishers."""

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("verify", ROOT / "tools/verify.py")
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


class VerificationTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".work").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def execute(self, commands):
        with (
            patch.object(verify, "ROOT", self.root),
            patch.object(verify, "COMMANDS", commands),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            verify.main()

    def report(self):
        return json.loads((self.root / "dist/validation-evidence.json").read_bytes())

    def test_success_executes_real_children_and_records_the_active_python(self):
        self.execute(
            (
                ("-c", "import sys; print(sys.version.split()[0])"),
                ("-c", "import sys; print('diagnostic', file=sys.stderr)"),
            )
        )
        report = self.report()
        self.assertTrue(report["success"])
        self.assertEqual(report["pythonVersion"], sys.version.split()[0])
        self.assertEqual(
            report["commands"][0]["stdout"].strip(), report["pythonVersion"]
        )
        self.assertEqual(report["commands"][1]["stderr"], "diagnostic\n")

    def test_failed_child_stops_before_following_build_or_write(self):
        with self.assertRaises(SystemExit):
            self.execute(
                (
                    ("-c", "raise SystemExit(8)"),
                    ("-c", "from pathlib import Path; Path('should-not-run').touch()"),
                )
            )
        report = self.report()
        self.assertFalse(report["success"])
        self.assertEqual(len(report["commands"]), 1)
        self.assertEqual(report["commands"][0]["exitCode"], 8)
        self.assertFalse((self.root / "should-not-run").exists())

    def test_source_whitespace_failure_preserves_the_original_bytes(self):
        source = self.root / "tools/source.py"
        source.parent.mkdir()
        original = b"answer = 42  \n"
        source.write_bytes(original)
        with self.assertRaises(SystemExit):
            self.execute(())
        report = self.report()
        self.assertFalse(report["success"])
        self.assertEqual(report["trailingWhitespace"], ["tools/source.py:1"])
        self.assertEqual(source.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
