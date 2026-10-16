"""Exercise verifier process failures and evidence without running publishers."""

import contextlib
import hashlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fau_tools import cli, sync, verify
from fau_tools.context import ROOT, source_files
from tests import run as lua_runner


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
        source = self.root / "fau_tools/source.py"
        source.parent.mkdir()
        original = b"answer = 42  \n"
        source.write_bytes(original)
        with self.assertRaises(SystemExit):
            self.execute(())
        report = self.report()
        self.assertFalse(report["success"])
        self.assertEqual(report["trailingWhitespace"], ["fau_tools/source.py:1"])
        self.assertEqual(source.read_bytes(), original)


class CommandBoundaryTests(unittest.TestCase):
    def test_help_never_runs_checks_builds_imports_or_publication(self):
        for command in (
            ["check"],
            ["build"],
            ["sync"],
            ["import"],
            ["data"],
            ["data", "classify"],
            ["data", "tags"],
            ["data", "quests"],
            ["data", "catalog"],
            ["source"],
            ["source", "att"],
            ["source", "public"],
            ["metadata"],
            ["chains"],
            ["membership"],
            ["import-att"],
            ["import-catalog"],
            ["migrate"],
            ["observations"],
            ["release"],
            ["publish-github"],
            ["publish-curseforge"],
        ):
            output = io.StringIO()
            with (
                self.subTest(command=command),
                patch("subprocess.run") as process,
                patch("urllib.request.urlopen") as network,
                contextlib.redirect_stdout(output),
            ):
                with self.assertRaises(SystemExit) as result:
                    cli.main([*command, "--help"])
                self.assertEqual(result.exception.code, 0)
                path = "sync" if command == ["import"] else " ".join(command)
                self.assertIn("usage: python -m fau_tools " + path, output.getvalue())
                process.assert_not_called()
                network.assert_not_called()

    def test_import_is_explicitly_staged_and_retains_cache_arguments(self):
        with patch.object(sync, "main") as execute:
            cli.main(["import", "--cache-root", "my caches"])
        execute.assert_called_once_with(
            ["reparse", "--stage-only", "--cache-root", "my caches"],
            prog="python -m fau_tools sync",
        )

    def test_import_help_labels_the_underlying_sync_command(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), self.assertRaises(SystemExit):
            cli.main(["import", "--help"])
        self.assertIn(
            "import is an alias for python -m fau_tools sync reparse --stage-only",
            output.getvalue(),
        )
        self.assertIn("--primary-cache", output.getvalue())
        self.assertIn("--stage-only", output.getvalue())

    def test_forwarded_options_and_program_names_keep_the_domain_owner(self):
        cases = (
            (["sync"], "sync.main"),
            (["data", "classify"], "classification.import_main"),
            (["data", "tags"], "classification.taxonomy_main"),
            (["data", "quests"], "classification.quests_main"),
            (["data", "catalog"], "catalog.generate_main"),
            (["source", "att"], "sources.att_main"),
            (["source", "public"], "sources.public_main"),
            (["metadata"], "questie.main"),
            (["chains"], "chains.main"),
            (["membership"], "membership.main"),
            (["import-att"], "att.main"),
            (["import-catalog"], "importer.main"),
            (["migrate"], "migration.main"),
        )
        for command, target in cases:
            with self.subTest(command=command), patch("fau_tools." + target) as run:
                cli.main([*command, "--domain-option", "relative path"])
                run.assert_called_once_with(
                    ["--domain-option", "relative path"],
                    prog="python -m fau_tools " + " ".join(command),
                )

    def test_invalid_options_report_the_selected_command_before_work(self):
        for command in (["check"], ["build"], ["data", "classify"]):
            error = io.StringIO()
            with (
                self.subTest(command=command),
                patch("subprocess.run") as process,
                contextlib.redirect_stderr(error),
                self.assertRaises(SystemExit) as result,
            ):
                cli.main([*command, "--unexpected"])
            self.assertEqual(result.exception.code, 2)
            self.assertIn(
                "usage: python -m fau_tools " + " ".join(command), error.getvalue()
            )
            process.assert_not_called()

    def test_classification_conflicting_flags_still_fail_before_reading_inputs(self):
        with (
            patch.object(Path, "read_bytes") as read,
            contextlib.redirect_stderr(io.StringIO()),
            self.assertRaises(SystemExit) as result,
        ):
            cli.main(["data", "classify", "--check", "--website-root", "website"])
        self.assertEqual(result.exception.code, 2)
        read.assert_not_called()

    def test_release_and_publication_flags_remain_strict(self):
        from fau_tools import publishing, release

        with patch.object(release, "main") as run:
            cli.main(["release", "--verify"])
        run.assert_called_once_with(["--verify"])
        with patch.object(publishing, "finalize") as finalize:
            cli.main(["publish-github", "--finalize"])
        finalize.assert_called_once_with()
        for command in (
            ["publish-github", "--finalize", "--finalize"],
            ["publish-curseforge", "--unexpected"],
        ):
            with (
                self.subTest(command=command),
                patch.object(publishing, "prepare") as prepare,
                patch.object(publishing, "finalize") as finalize,
                patch.object(publishing, "upload") as upload,
                contextlib.redirect_stderr(io.StringIO()),
                self.assertRaises(SystemExit) as result,
            ):
                cli.main(command)
            self.assertEqual(result.exception.code, 2)
            prepare.assert_not_called()
            finalize.assert_not_called()
            upload.assert_not_called()

    def test_source_inventory_excludes_private_environment_and_metadata(self):
        self.assertTrue(all(path.is_relative_to(ROOT) for path in source_files()))
        relative = {path.relative_to(ROOT).as_posix() for path in source_files()}
        self.assertIn("fau_tools/cli.py", relative)
        self.assertIn("pyproject.toml", relative)
        self.assertNotIn("plan.md", relative)
        self.assertFalse(
            any(
                ".work" in Path(path).parts or path.endswith(".pyc")
                for path in relative
            )
        )

    def test_source_and_stage_filter_incidental_files_without_git(self):
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        source = Path(temporary.name) / "source"
        from fau_tools.context import SOURCE_FILES

        for name in SOURCE_FILES:
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"maintained root")
        maintained = (
            "fau_tools/cli.py",
            "data/catalog-source.json",
            "tests/native-source-fixtures.json",
            "tests/model_test.lua",
            ".github/workflows/check.yml",
            "FindAnUpgrade/LICENSE",
        )
        incidental = (
            "fau_tools/scratch.py",
            "data/private.json",
            "tests/local-review.json",
            "tests/scratch_test.py",
            ".github/workflows/private.yml",
            "fau_tools/private-cache.bin",
            "fau_tools/.venv/private.env",
            "fau_tools/tooling.egg-info/PKG-INFO",
            "data/local-review.tmp",
            "data/catalog-source.json.sync-123",
            "fau_tools/__pycache__/cli.pyc",
            "tests/.private.py",
        )
        for name in maintained + incidental:
            path = source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")
        files = {path.relative_to(source).as_posix() for path in source_files(source)}
        self.assertTrue(set(maintained).issubset(files))
        self.assertFalse(set(incidental) & files)
        stage = Path(temporary.name) / "stage"
        sync.stage_sources(source, stage)
        self.assertTrue(all((stage / name).is_file() for name in maintained))
        self.assertTrue(all(not (stage / name).exists() for name in incidental))
        self.assertTrue(all((source / name).is_file() for name in incidental))

    def test_missing_declared_source_prevents_partial_stage_copy(self):
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        source = Path(temporary.name) / "source"
        maintained = source / "fau_tools/cli.py"
        maintained.parent.mkdir(parents=True)
        maintained.write_bytes(b"fixture")
        stage = Path(temporary.name) / "stage"
        with patch(
            "fau_tools.context.SOURCE_FILES", ("fau_tools/cli.py", "data/source.json")
        ):
            with self.assertRaisesRegex(
                ValueError, "Missing declared source files: data/source.json"
            ):
                sync.stage_sources(source, stage)
        self.assertFalse((stage / "fau_tools/cli.py").exists())

    def test_stage_uses_its_own_module_without_parent_checkout_imports(self):
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        stage = Path(temporary.name) / "candidate"
        # This test checks Python package precedence, not native source fixtures.
        # Avoid duplicating their deep paths inside an already staged Windows tree.
        with patch.object(sync.shutil, "copytree"):
            sync.stage_sources(ROOT, stage)
        classifier = stage / "fau_tools/classification.py"
        classifier.write_bytes(
            classifier.read_bytes()
            + b'\n\ndef quests_main(argv=None, *, prog=None):\n    print("STAGED-CANDIDATE", ROOT)\n'
        )
        process = subprocess.run(
            [sys.executable, "-m", "fau_tools", "data", "quests", "--check"],
            cwd=stage,
            text=True,
            encoding="utf-8",
            capture_output=True,
            check=True,
        )
        self.assertEqual(process.stdout.strip(), "STAGED-CANDIDATE " + str(stage))

    def test_sync_subprocess_selects_stage_module_without_path_injection(self):
        with (
            patch.object(sync.subprocess, "run") as process,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            sync.run(Path("candidate"), ["data", "quests", "--check"])
        process.assert_called_once_with(
            [sys.executable, "-m", "fau_tools", "data", "quests", "--check"],
            cwd=Path("candidate"),
            check=True,
        )


class NativeFixtureEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.raw = b"pinned native source fixture"
        self.paths = lua_runner.CURRENT_PATHS
        contracts = {
            "currentSnapshot": {
                "revision": "fixture-revision",
                "files": [
                    {"path": name, "sha256": hashlib.sha256(self.raw).hexdigest()}
                    for name in self.paths
                ],
            },
            "files": [],
        }
        document = self.root / "tests/native-source-fixtures.json"
        document.parent.mkdir(parents=True)
        document.write_text(json.dumps(contracts), encoding="utf-8")

    def fixture(self, raw):
        path = self.root / ".work/current-api" / self.paths[0]
        path.parent.mkdir(parents=True)
        path.write_bytes(raw)

    def test_absent_cache_records_missing_paths_without_claiming_integration(self):
        evidence = lua_runner.fixture_evidence(self.root)
        self.assertFalse(evidence["currentNativeSourceIntegration"])
        self.assertFalse(evidence["pinnedNativeSourceIntegration"])
        self.assertEqual(evidence["currentNativeSourceMissingFixtures"], self.paths)
        self.assertEqual(evidence["currentNativeSourceAvailableFixtures"], [])

    def test_partial_valid_cache_is_verified_without_claiming_complete_integration(
        self,
    ):
        self.fixture(self.raw)
        evidence = lua_runner.fixture_evidence(self.root)
        self.assertFalse(evidence["currentNativeSourceIntegration"])
        self.assertEqual(
            evidence["currentNativeSourceAvailableFixtures"], self.paths[:1]
        )
        self.assertEqual(evidence["currentNativeSourceMissingFixtures"], self.paths[1:])

    def test_partial_corrupt_cache_is_rejected_before_lua_execution(self):
        self.fixture(self.raw + b"changed")
        with self.assertRaisesRegex(AssertionError, "Current native source differs"):
            lua_runner.fixture_evidence(self.root)


if __name__ == "__main__":
    unittest.main()
