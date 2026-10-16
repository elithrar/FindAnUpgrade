"""Data trust boundaries must survive Python's optimized interpreter."""

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from fau_tools.att import PIN
from fau_tools.context import ROOT


class ValidationGuardTests(unittest.TestCase):
    def setUp(self):
        (ROOT / ".work").mkdir(exist_ok=True)
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def run_python(self, code, *arguments, optimized):
        return subprocess.run(
            [sys.executable, *(["-O"] if optimized else []), "-c", code, *arguments],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )

    def snapshot(self):
        return {
            path.relative_to(self.root): path.read_bytes()
            for path in self.root.rglob("*")
            if path.is_file()
        }

    def classification_fixture(self):
        for name in (
            "classification-source.json",
            "classification-baseline.json",
            "primary-statuses.json",
        ):
            path = self.root / "data" / name
            path.parent.mkdir(exist_ok=True)
            path.write_bytes((ROOT / "data" / name).read_bytes())

    def test_classification_check_regenerates_missing_or_dirty_ignored_report(self):
        self.classification_fixture()
        before = self.snapshot()
        code = (
            "import sys; from pathlib import Path; "
            "from fau_tools import classification; "
            "classification.ROOT = Path(sys.argv[1]); "
            "classification.import_main(['--check'])"
        )
        report = self.root / "dist/classification-reconciliation.json"
        for optimized in (False, True):
            for dirty in (False, True):
                with self.subTest(optimized=optimized, dirty=dirty):
                    report.parent.mkdir(exist_ok=True)
                    report.unlink(missing_ok=True)
                    if dirty:
                        report.write_bytes(b"not an authority or valid JSON")
                    result = self.run_python(code, str(self.root), optimized=optimized)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(
                        json.loads(report.read_bytes())["union"]["questIdCount"], 2931
                    )
                    self.assertEqual(
                        {
                            name: raw
                            for name, raw in self.snapshot().items()
                            if name.parts[0] == "data"
                        },
                        before,
                    )

    def test_stale_classification_check_fails_without_writing(self):
        self.classification_fixture()
        (self.root / "data/primary-statuses.json").write_bytes(b"{}\n")
        before = self.snapshot()
        code = (
            "import sys; from pathlib import Path; "
            "from fau_tools import classification; "
            "classification.ROOT = Path(sys.argv[1]); "
            "classification.import_main(['--check'])"
        )
        for optimized in (False, True):
            with self.subTest(optimized=optimized):
                result = self.run_python(code, str(self.root), optimized=optimized)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "AssertionError: Stale classification output: primary-statuses.json",
                    result.stderr,
                )
                self.assertEqual(self.snapshot(), before)

    def test_invalid_classification_provenance_cannot_replace_owned_outputs(self):
        self.classification_fixture()
        path = self.root / "data/classification-source.json"
        source = json.loads(path.read_bytes())
        source["receipts"][0]["sha256"] = "unverified"
        path.write_text(json.dumps(source), encoding="utf-8")
        before = self.snapshot()
        code = (
            "import sys; from pathlib import Path; "
            "from fau_tools import classification; "
            "classification.ROOT = Path(sys.argv[1]); "
            "classification.import_main([])"
        )
        for optimized in (False, True):
            with self.subTest(optimized=optimized):
                result = self.run_python(code, str(self.root), optimized=optimized)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(
                    "AssertionError: Invalid classification source receipt hash or byte length",
                    result.stderr,
                )
                self.assertEqual(self.snapshot(), before)

    def test_forged_membership_receipts_fail_before_claiming_verification(self):
        path = self.root / "db/Camelot/Categories/fixture.lua"
        path.parent.mkdir(parents=True)
        raw = b"-- _.CreateQuest\nq(7,{g={i(9)}})\n"
        path.write_bytes(raw)
        membership = {
            "source": {"revision": PIN, "generatedBuildStamp": None},
            "sources": [
                {
                    "path": path.relative_to(self.root).as_posix(),
                    "sha256": hashlib.sha256(raw).hexdigest(),
                    "gitBlob": hashlib.sha1(
                        b"blob " + str(len(raw)).encode() + b"\0" + raw
                    ).hexdigest(),
                }
            ],
            "pairs": [[7, 9]],
            "constraints": [],
            "constraintConflicts": [],
            "pairsSHA256": hashlib.sha256(b"[[7,9]]").hexdigest(),
        }
        code = (
            "import json, sys; from pathlib import Path; "
            "from fau_tools.membership import check; "
            "root = Path(sys.argv[1]); "
            "check(root, json.loads((root / 'membership.json').read_bytes()))"
        )
        receipt = self.root / "membership.json"
        mutations = (
            ("source", "revision", "wrong-pin"),
            ("source", "generatedBuildStamp", "unverified"),
            ("sources", "sha256", "0" * 64),
            ("sources", "gitBlob", "0" * 40),
            (None, "pairs", [[7, 10]]),
            (None, "constraints", [{"id": 7, "c": [1]}]),
            (None, "constraintConflicts", [{"id": 7, "field": "c"}]),
            (None, "pairsSHA256", "0" * 64),
        )
        for optimized in (False, True):
            receipt.write_text(json.dumps(membership), encoding="utf-8")
            valid = self.run_python(code, str(self.root), optimized=optimized)
            self.assertEqual(valid.returncode, 0, valid.stderr)
            self.assertIn("Verified 1 compiled exact pairs", valid.stdout)
            for group, field, value in mutations:
                with self.subTest(optimized=optimized, group=group, field=field):
                    invalid = copy.deepcopy(membership)
                    target = invalid if group is None else invalid[group]
                    if group == "sources":
                        target = target[0]
                    target[field] = value
                    receipt.write_text(json.dumps(invalid), encoding="utf-8")
                    before = self.snapshot()
                    result = self.run_python(code, str(self.root), optimized=optimized)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("AssertionError", result.stderr)
                    self.assertNotIn("Verified", result.stdout)
                    self.assertEqual(self.snapshot(), before)

    def test_catalog_rejects_wrong_source_pin_under_optimization(self):
        code = (
            "import json; from fau_tools import catalog; "
            "source = json.loads((catalog.ROOT / 'data/catalog-source.json').read_bytes()); "
            "provenance = json.loads((catalog.ROOT / 'data/catalog-sources.json').read_bytes()); "
            "provenance['revision'] = 'wrong-pin'; "
            "catalog.validate(source, provenance)"
        )
        for optimized in (False, True):
            with self.subTest(optimized=optimized):
                result = self.run_python(code, optimized=optimized)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("AssertionError", result.stderr)

    def test_att_rejects_unclosed_conditions_and_duplicate_fields(self):
        cases = (
            (
                "from fau_tools.att import preprocess; "
                "preprocess('-- #if FOREVER\\nq(7,{groups={i(9)}})\\n')",
                "Unclosed source condition",
            ),
            (
                "from fau_tools.att import parse; "
                "parse('q(7,{groups={i(9)},groups={i(10)}})', 'fixture', {})",
                "Duplicate selected source field",
            ),
        )
        for optimized in (False, True):
            for code, message in cases:
                with self.subTest(optimized=optimized, message=message):
                    result = self.run_python(code, optimized=optimized)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("AssertionError: " + message, result.stderr)
