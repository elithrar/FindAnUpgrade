"""Offline adversarial release tests; never invoke a real publishing command."""

import ast
import json
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from fau_tools import publishing as cf
from fau_tools import publishing as github
from fau_tools import release as release

ROOT = Path(__file__).resolve().parents[1]
PUBLIC_NOTES = """Find quests with upgrades: based on item level, empty slots, class and/or level range and zone. Track down quest givers with waypoints and shortlist the quest with the items you need.

FindAnUpgrade is designed to make it easier to chase down the quests that give you that missing weapon, trinket, ring or shoulder item that you need the most when levelling in WoW: Forever. New and modified quests and their rewards are built right in.

Open it with /fau or click the FindAnUpgrade button on your minimap."""


def artifact_fixture(destination, source=ROOT):
    """Create an isolated fixed-version fixture, independent of real releases."""
    from fau_tools import packaging as package

    for file in package.source_files(source):
        target = destination / file.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(file, target)
    toc_path = destination / "FindAnUpgrade/FindAnUpgrade.toc"
    toc = toc_path.read_text()
    version = release.re.search(r"^## Version: (.+)$", toc, release.re.M)[1]
    toc_path.write_text(toc.replace("## Version: " + version, "## Version: 0.1.0"))
    core = destination / "FindAnUpgrade/Core.lua"
    core.write_text(
        core.read_text().replace('version = "' + version + '"', 'version = "0.1.0"')
    )
    notes = destination / "CHANGELOG.md"
    notes.parent.mkdir(parents=True, exist_ok=True)
    notes.write_text("# Changelog\n\n## 0.1.0\n\nOffline fixture release notes.\n")
    package.build(destination)
    data = release.metadata("v0.1.0", toc_path.read_text())
    data.update(commit="a" * 40, tag_object="b" * 40, notes_sha256=release.sha(notes))
    data["assets"] = {
        n: release.sha(destination / "dist" / n)
        for n in [
            data["archive"],
            data["source_archive"],
            "SHA256SUMS",
            "package-receipt.json",
        ]
    }
    (destination / "dist/release.json").write_text(json.dumps(data))
    release.verify_artifacts(destination)
    return data


class MetadataTests(unittest.TestCase):
    def test_checked_in_release_notes_match_the_actual_manifest(self):
        toc = (ROOT / "FindAnUpgrade/FindAnUpgrade.toc").read_text(encoding="utf-8")
        version = release.re.search(r"^## Version: (.+)$", toc, release.re.M)[1]
        data = release.metadata("v" + version, toc)
        data["notes_sha256"] = release.sha(ROOT / "CHANGELOG.md")
        body = release.release_notes_body(data, ROOT)
        self.assertTrue(body.strip())
        self.assertNotIn("## ", body)

    def test_public_notes_extract_only_exact_paragraphs_and_bind_source_hash(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            path = root / "CHANGELOG.md"
            source = "# Changelog\n\n## 0.1.0\n\n" + PUBLIC_NOTES + "\n"
            for newline in ("\n", "\r\n"):
                path.write_bytes(source.replace("\n", newline).encode("utf-8"))
                data = {"version": "0.1.0", "notes_sha256": release.sha(path)}
                self.assertEqual(release.release_notes_body(data, root), PUBLIC_NOTES)
                self.assertEqual(len(PUBLIC_NOTES.split("\n\n")), 3)
            path.write_bytes((source + "Changed after verification.\n").encode("utf-8"))
            with self.assertRaisesRegex(ValueError, "source changed"):
                release.release_notes_body(data, root)

    def test_public_notes_reject_empty_bodies_and_embedded_headings(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            path = root / "CHANGELOG.md"
            for body in ("", "# More notes", "Paragraph\n\n## Details\n\nMore text"):
                path.write_bytes(("# Changelog\n\n## 0.1.0\n\n" + body).encode("utf-8"))
                data = {"version": "0.1.0", "notes_sha256": release.sha(path)}
                with self.assertRaises(ValueError):
                    release.release_notes_body(data, root)

    def test_changelog_requires_exact_current_then_unique_descending_history(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            data = {"version": "0.1.0"}
            with self.assertRaisesRegex(ValueError, "notes missing"):
                release.release_notes(data, root)
            path = root / "CHANGELOG.md"
            for content in [
                "No version",
                "## 0.2.0",
                "## 0.1.0\n## 0.2.0",
                "## 0.1.0\n## 0.1.0",
                "## 0.1.0\n## 0.0.8\n## 0.0.9",
                "## 0.1.0\n## 0.0.09",
                "## 0.2.0-rc\n## 0.1.0",
            ]:
                path.write_text(content)
                with self.assertRaisesRegex(ValueError, "exact current release"):
                    release.release_notes(data, root)
            path.write_text("# Changelog\n\n## 0.1.0\n\nCurrent notes\n")
            self.assertEqual(release.release_notes(data, root), path)

    def test_current_public_notes_exclude_history_and_bind_even_historical_bytes(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            path = root / "CHANGELOG.md"
            source = (
                "# Changelog\n\n## 0.1.0\n\n"
                + PUBLIC_NOTES
                + "\n\n## 0.0.9\n\nOlder release text.\n"
            )
            for newline in ("\n", "\r\n"):
                path.write_bytes(source.replace("\n", newline).encode("utf-8"))
                data = {"version": "0.1.0", "notes_sha256": release.sha(path)}
                self.assertEqual(release.release_notes_body(data, root), PUBLIC_NOTES)
            path.write_bytes(
                source.replace(
                    "Older release text.", "Changed historical text."
                ).encode("utf-8")
            )
            with self.assertRaisesRegex(ValueError, "source changed"):
                release.release_notes_body(data, root)

    def test_release_commands_route_only_the_explicit_payload_root(self):
        from fau_tools import cli

        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory).resolve()
            with patch.object(release, "main") as run:
                cli.main(["release", "--verify", "--root", str(root)])
            run.assert_called_once_with(["--verify"], root=root)
            for arguments, method in (([], "prepare"), (["--finalize"], "finalize")):
                with patch.object(github, method) as run:
                    cli.main(["publish-github", *arguments, "--root", str(root)])
                run.assert_called_once_with(root=root)
            with patch.object(cf, "upload") as run:
                cli.main(["publish-curseforge", "--root", str(root)])
            run.assert_called_once_with(root=root)

    def test_explicit_root_verification_never_uses_the_tooling_checkout(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as directory:
            root = Path(directory)
            data = {"tag": "v0.1.0", "commit": "a" * 40}
            with (
                patch.dict(os.environ, {"GITHUB_OUTPUT": str(root / "verify-output")}),
                patch.object(release, "verify_artifacts", return_value=data) as verify,
                patch.object(release, "verify_remote") as remote,
            ):
                release.main(["--verify"], root=root)
            verify.assert_called_once_with(root)
            remote.assert_called_once_with(data, root)
            with (
                patch.dict(
                    os.environ,
                    {
                        "RELEASE_TAG": "v0.1.0",
                        "GITHUB_OUTPUT": str(root / "prepare-output"),
                    },
                ),
                patch.object(release, "prepare", return_value=data) as prepare,
                patch.object(release, "refresh_refs") as refresh,
            ):
                release.main([], root=root)
            prepare.assert_called_once_with("v0.1.0", root)
            refresh.assert_called_once_with("v0.1.0", root)
            self.assertEqual(
                (root / "prepare-output").read_text(), "commit=" + data["commit"] + "\n"
            )

    def test_duplicate_release_roots_and_flags_reject_before_side_effects(self):
        from contextlib import redirect_stderr
        from io import StringIO

        from fau_tools import cli

        for arguments in (
            ["release", "--verify", "--verify"],
            ["release", "--root", "one", "--root", "two"],
            ["publish-github", "--root", "one", "--root", "two"],
            ["publish-curseforge", "--root", "one", "--root", "two"],
        ):
            with (
                self.subTest(arguments=arguments),
                patch.object(release, "main") as run,
                patch.object(github, "prepare") as prepare,
                patch.object(github, "finalize") as finalize,
                patch.object(cf, "upload") as upload,
                redirect_stderr(StringIO()),
                self.assertRaises(SystemExit),
            ):
                cli.main(arguments)
            for operation in (run, prepare, finalize, upload):
                operation.assert_not_called()

    def toc(self, version="0.1.0"):
        return f"## Interface: 16001\n## Version: {version}\n"

    def test_only_exact_stable_tag_and_forever(self):
        self.assertEqual(
            release.metadata("v0.1.0", self.toc())["game_version_type"], 88568
        )
        for invalid in [
            "0.1.0",
            "v01.1.0",
            "v0.1.0-alpha.1",
            "v0.1.0;echo unsafe",
            "--help",
            "refs/tags/v0.1.0",
        ]:
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                release.metadata(invalid, self.toc())
        for toc in [
            self.toc("0.2.0"),
            self.toc().replace("16001", "120001"),
            self.toc() + "## Interface-Classic: 11507\n",
            self.toc() + "## Version: 0.1.0\n",
        ]:
            with self.subTest(toc=toc), self.assertRaises(ValueError):
                release.metadata("v0.1.0", toc)

    def test_exact_forever_version_never_falls_back(self):
        data = release.metadata("v0.1.0", self.toc())
        wrong = [
            {"id": 1, "name": "1.60.1", "gameVersionTypeID": 517},
            {"id": 2, "name": "1.60.0", "gameVersionTypeID": 88568},
        ]
        with self.assertRaises(ValueError):
            cf.exact_version(wrong, data)
        exact = {"id": 3, "name": "1.60.1", "gameVersionTypeID": 88568}
        self.assertEqual(cf.exact_version(wrong + [exact], data), 3)
        for values in [
            wrong + [exact, exact],
            [{**exact, "id": True}],
            [{**exact, "id": 0}],
            {"error": "bad"},
        ]:
            with self.assertRaises(ValueError):
                cf.exact_version(values, data)

    def test_settings_missing_skip_and_invalid_id_reject(self):
        for settings in [{}, {"CF_API_KEY": "fixture"}, {"CF_PROJECT_ID": "42"}]:
            self.assertIsNone(cf.settings(settings))
        self.assertEqual(
            cf.settings({"CF_API_KEY": "fixture", "CF_PROJECT_ID": "42"}),
            ("fixture", 42),
        )
        for value in ["0", "-1", "01", "42;echo bad", " 42", "https://example.invalid"]:
            with self.assertRaises(ValueError):
                cf.settings({"CF_API_KEY": "fixture", "CF_PROJECT_ID": value})

    def test_git_annotation_ancestry_head_and_tag_move(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as folder:
            root = Path(folder)

            def git(*args):
                return release.git(*args, root=root)

            git("init", "-b", "main")
            git("config", "commit.gpgsign", "false")
            git("config", "tag.gpgsign", "false")
            git("config", "user.name", "Offline test")
            git("config", "user.email", "test@example.invalid")
            (root / "file").write_text("one")
            git("add", "file")
            git("commit", "-m", "base")
            git("update-ref", "refs/remotes/origin/main", "HEAD")
            git("tag", "-a", "v0.1.0", "-m", "First version")
            commit = release.check_tag("v0.1.0", root)
            data = {
                "tag": "v0.1.0",
                "commit": commit,
                "tag_object": git("rev-parse", "refs/tags/v0.1.0"),
            }
            git("tag", "v0.1.1")
            with self.assertRaises(ValueError):
                release.check_tag("v0.1.1", root)
            git("checkout", "-b", "unmerged")
            (root / "file").write_text("two")
            git("commit", "-am", "off-main")
            git("tag", "-a", "v0.1.2", "-m", "Off-main")
            with self.assertRaises(ValueError):
                release.check_tag("v0.1.2", root)
            with self.assertRaises(ValueError):
                release.check_tag("v0.1.0", root)
            git("checkout", "main")
            git("tag", "-f", "-a", "v0.1.0", "-m", "Changed annotation")
            with self.assertRaisesRegex(ValueError, "moved"):
                release.verify_tag(data, root)

    def test_dirty_or_untracked_source_after_tag_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as folder:
            root = Path(folder)

            def git(*args):
                return release.git(*args, root=root)

            git("init", "-b", "main")
            git("config", "commit.gpgsign", "false")
            git("config", "tag.gpgsign", "false")
            git("config", "user.name", "Offline test")
            git("config", "user.email", "test@example.invalid")
            source = root / "file"
            source.write_text("one")
            git("add", "file")
            git("commit", "-m", "base")
            git("update-ref", "refs/remotes/origin/main", "HEAD")
            git("tag", "-a", "v0.1.0", "-m", "Release")
            release.check_tag("v0.1.0", root)
            source.write_text("one plus uncommitted change")
            with self.assertRaisesRegex(ValueError, "clean"):
                release.check_tag("v0.1.0", root)
            git("checkout", "--", "file")
            (root / "untracked.lua").write_text("unreviewed")
            with self.assertRaisesRegex(ValueError, "clean"):
                release.check_tag("v0.1.0", root)

    def test_multipart_preserves_binary_zip_and_headers(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as folder:
            path = Path(folder) / "FindAnUpgrade-0.1.0.zip"
            path.write_bytes(b"PK\x00\xff\x01")
            metadata = {"gameVersions": [99], "releaseType": "release"}
            body, kind = cf.multipart(metadata, path)
            self.assertIn(path.read_bytes(), body)
            self.assertIn(json.dumps(metadata).encode(), body)
            self.assertIn(b'name="file"; filename="FindAnUpgrade-0.1.0.zip"', body)
            self.assertTrue(
                kind.startswith("multipart/form-data; boundary=FindAnUpgrade-")
            )

    def test_remote_tag_moved_after_checkout_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / ".work") as folder:
            remote, root = Path(folder) / "remote", Path(folder) / "checkout"
            remote.mkdir()

            def git(*args):
                return release.git(*args, root=remote)

            git("init", "-b", "main")
            git("config", "commit.gpgsign", "false")
            git("config", "tag.gpgsign", "false")
            git("config", "user.name", "Offline test")
            git("config", "user.email", "test@example.invalid")
            (remote / "file").write_text("one")
            git("add", "file")
            git("commit", "-m", "first")
            git("tag", "-a", "v0.1.0", "-m", "First tag")
            shutil.copytree(remote, root)
            release.git("remote", "add", "origin", str(remote), root=root)
            data = {
                "tag": "v0.1.0",
                "commit": git("rev-parse", "HEAD"),
                "tag_object": git("rev-parse", "refs/tags/v0.1.0"),
            }

            # Simulate transport only. Actual objects, refs, annotation and HEAD
            # checks run through Git in two disposable repositories.
            def read_remote(tag, target):
                for source in (remote / ".git/objects").rglob("*"):
                    destination = (
                        target
                        / ".git/objects"
                        / source.relative_to(remote / ".git/objects")
                    )
                    if source.is_file() and not destination.exists():
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copyfile(source, destination)
                release.git(
                    "update-ref",
                    "refs/remotes/origin/main",
                    git("rev-parse", "HEAD"),
                    root=target,
                )
                release.git(
                    "update-ref",
                    "refs/tags/" + tag,
                    git("rev-parse", "refs/tags/" + tag),
                    root=target,
                )

            with (
                patch.object(
                    release, "refresh_refs", side_effect=read_remote
                ) as refresh,
                patch.object(release, "check_source_tree"),
            ):
                release.verify_remote(data, root)
                git(
                    "tag", "-f", "-a", "v0.1.0", "-m", "Same commit, changed tag object"
                )
                with self.assertRaisesRegex(ValueError, "moved"):
                    release.verify_remote(data, root)
                (remote / "file").write_text("two")
                git("commit", "-am", "second")
                git("tag", "-f", "-a", "v0.1.0", "-m", "Moved to another commit")
                with self.assertRaisesRegex(ValueError, "tagged commit"):
                    release.verify_remote(data, root)
                self.assertEqual(refresh.call_count, 3)

    def test_private_ref_auth_is_ephemeral_and_diagnostics_are_sanitized(self):
        token = "offline-auth-fixture"
        with (
            patch.dict(os.environ, {"GH_TOKEN": token}),
            patch.object(subprocess, "run") as command,
        ):
            command.return_value.returncode = 0
            release.refresh_refs("v0.1.0")
            args, kwargs = command.call_args
            self.assertNotIn(token, " ".join(args[0]))
            self.assertEqual(kwargs["env"]["GIT_CONFIG_COUNT"], "1")
            self.assertEqual(
                kwargs["env"]["GIT_CONFIG_KEY_0"],
                "http.https://github.com/.extraheader",
            )
            self.assertTrue(kwargs["capture_output"])
            self.assertNotIn("GIT_CONFIG_VALUE_0", os.environ)
            command.return_value.returncode = 1
            with self.assertRaisesRegex(RuntimeError, "Could not refresh") as error:
                release.refresh_refs("v0.1.0")
            self.assertNotIn(token, str(error.exception))


class ArtifactTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from fau_tools import packaging as package

        cls.package = package
        cls.temp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        cls.template = Path(cls.temp.name) / "template"
        artifact_fixture(cls.template)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.temp_instance = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(self.temp_instance.cleanup)
        self.root = Path(self.temp_instance.name) / "root"
        shutil.copytree(self.template, self.root)

    def resign(self, filename):
        # Adversary can change checksum metadata; exact repository payload still wins.
        directory = self.root / "dist"
        data = json.loads((directory / "release.json").read_text())
        receipt = json.loads((directory / "package-receipt.json").read_text())
        receipt["archives"][filename] = release.sha(directory / filename)
        (directory / "SHA256SUMS").write_text(
            "".join(f"{sha}  {name}\n" for name, sha in receipt["archives"].items())
        )
        (directory / "package-receipt.json").write_text(json.dumps(receipt))
        data["assets"] = {n: release.sha(directory / n) for n in data["assets"]}
        (directory / "release.json").write_text(json.dumps(data))

    def test_exact_payload_passes(self):
        data = release.verify_artifacts(self.root)
        self.assertEqual(data["archive"], "FindAnUpgrade-0.1.0.zip")
        payload = {
            p["path"]
            for p in json.loads((self.root / "dist/package-receipt.json").read_text())[
                "payload"
            ]
        }
        for name in [
            "FindAnUpgrade/LICENSE",
            "FindAnUpgrade/Data/Catalog.lua",
            "FindAnUpgrade/Data/ATT-LICENSE.txt",
        ]:
            self.assertIn(name, payload)

    def test_catalog_license_cannot_be_replaced_by_rewriting_provenance(self):
        path = self.root / "FindAnUpgrade/Data/ATT-LICENSE.txt"
        path.write_bytes(b"MIT label without the required grant or disclaimer")
        provenance = self.root / "data/catalog-sources.json"
        data = json.loads(provenance.read_bytes())
        for row in data["files"]:
            if row["path"] == "LICENSE":
                row["sha256"] = release.sha(path)
        provenance.write_text(json.dumps(data))
        with self.assertRaisesRegex(ValueError, "MIT permission"):
            release.verify_artifacts(self.root)

    def test_real_notes_and_version_bump_do_not_break_fixed_fixture(self):
        toc = self.root / "FindAnUpgrade/FindAnUpgrade.toc"
        toc.write_text(
            toc.read_text().replace("## Version: 0.1.0", "## Version: 0.2.0")
        )
        core = self.root / "FindAnUpgrade/Core.lua"
        core.write_text(
            core.read_text().replace('version = "0.1.0"', 'version = "0.2.0"')
        )
        future_notes = "# Changelog\n\n## 0.2.0\n\nFuture real release notes.\n"
        (self.root / "CHANGELOG.md").write_text(future_notes)
        destination = Path(self.temp_instance.name) / "normalized-fixture"
        data = artifact_fixture(destination, self.root)
        self.assertEqual(data["version"], "0.1.0")
        self.assertIn("## 0.1.0", (destination / "CHANGELOG.md").read_text())
        self.assertEqual((self.root / "CHANGELOG.md").read_text(), future_notes)

    def test_altered_archive_is_rejected(self):
        archive = self.root / "dist/FindAnUpgrade-0.1.0.zip"
        archive.write_bytes(archive.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "checksums"):
            release.verify_artifacts(self.root)

    def test_extra_zip_asset_is_rejected(self):
        (self.root / "dist/FindAnUpgrade-old.zip").write_bytes(b"old build")
        with self.assertRaisesRegex(ValueError, "Unexpected release ZIP"):
            release.verify_artifacts(self.root)

    def test_ignored_private_files_are_excluded_and_untracked_sources_are_rejected(
        self,
    ):
        def git(*args):
            return release.git(*args, root=self.root)

        # Preserve literal bytes so this probe isolates ignored payload members.
        for file in self.package.source_files(self.root):
            if file.suffix in [".md", ".lua", ".py", ".toc", ".json", ".yml"]:
                file.write_bytes(file.read_bytes().replace(b"\r\n", b"\n"))
        git("init", "-b", "main")
        git("config", "commit.gpgsign", "false")
        git("config", "tag.gpgsign", "false")
        git("config", "user.name", "Offline test")
        git("config", "user.email", "test@example.invalid")
        git("add", ".")
        git("commit", "-m", "source")
        git("update-ref", "refs/remotes/origin/main", "HEAD")
        git("tag", "-a", "v0.1.0", "-m", "Version")
        commit = release.check_tag("v0.1.0", self.root)
        release.check_source_tree(commit, self.root)
        ignored = self.root / "fau_tools/.work/untracked-fixture.env"
        ignored.parent.mkdir()
        ignored.write_bytes(b"private fixture must not ship")
        self.assertEqual(git("status", "--porcelain"), "")
        self.assertNotIn(ignored, self.package.source_files(self.root))
        release.check_source_tree(commit, self.root)
        # A source-shaped ignored file is excluded from release sources too.
        unknown = self.root / "data/untracked-fixture.json"
        unknown.write_bytes(b"unreviewed source")
        exclusion = self.root / ".git/info/exclude"
        with exclusion.open("ab") as output:
            output.write(b"\ndata/untracked-fixture.json\n")
        self.assertEqual(git("status", "--porcelain"), "")
        self.assertNotIn(unknown, self.package.source_files(self.root))
        release.check_source_tree(commit, self.root)

    def test_forged_checksums_do_not_allow_extra_payload(self):
        archive = self.root / "dist/FindAnUpgrade-0.1.0.zip"
        with zipfile.ZipFile(archive, "a") as payload:
            payload.writestr("FindAnUpgrade/unreviewed.lua", "bad")
        self.resign(archive.name)
        with self.assertRaisesRegex(ValueError, "manifest"):
            release.verify_artifacts(self.root)

    def test_forged_source_zip_is_rejected(self):
        archive = self.root / "dist/FindAnUpgrade-0.1.0-source.zip"
        with zipfile.ZipFile(archive, "a") as payload:
            payload.writestr("secrets.env", "fixture")
        self.resign(archive.name)
        with self.assertRaisesRegex(ValueError, "manifest"):
            release.verify_artifacts(self.root)

    def test_duplicate_or_missing_checksums_rejected(self):
        path = self.root / "dist/SHA256SUMS"
        original = path.read_text()
        for value in [
            original + original.splitlines()[0] + "\n",
            original.splitlines()[0] + "\n",
            "not a digest",
        ]:
            path.write_text(value)
            with self.assertRaises(ValueError):
                release.verify_artifacts(self.root)

    def test_receipt_and_notes_changes_rejected(self):
        path = self.root / "dist/package-receipt.json"
        original = path.read_bytes()
        receipt = json.loads(original)
        receipt["published"] = True
        path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(ValueError, "receipt"):
            release.verify_artifacts(self.root)
        path.write_bytes(original)
        (self.root / "CHANGELOG.md").write_text("Different notes")
        with self.assertRaises(ValueError):
            release.verify_artifacts(self.root)


class PublishTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / ".work")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "dist").mkdir()
        notes = self.root / "CHANGELOG.md"
        notes.write_bytes(
            ("# Changelog\n\n## 0.1.0\n\n" + PUBLIC_NOTES + "\n").encode("utf-8")
        )
        self.data = release.metadata("v0.1.0", MetadataTests().toc())
        self.data.update(
            commit="a" * 40, tag_object="b" * 40, notes_sha256=release.sha(notes)
        )
        self.assets = {}
        for name in [
            self.data["archive"],
            self.data["source_archive"],
            "SHA256SUMS",
            "package-receipt.json",
        ]:
            (self.root / "dist" / name).write_bytes(("fixture " + name).encode())
        self.data["assets"] = {
            n: release.sha(self.root / "dist" / n)
            for n in [
                self.data["archive"],
                self.data["source_archive"],
                "SHA256SUMS",
                "package-receipt.json",
            ]
        }
        (self.root / "dist/release.json").write_text(json.dumps(self.data))
        self.assets = {
            n: (self.root / "dist" / n).read_bytes()
            for n in [*self.data["assets"], "release.json"]
        }
        self.current = {
            "tag_name": "v0.1.0",
            "assets": [],
            "draft": True,
            "immutable": False,
            "body": PUBLIC_NOTES,
            "html_url": "https://example.invalid/release",
        }
        self.calls = []

        def existing(tag):
            self.current["assets"] = [{"name": n} for n in self.assets]
            return self.current

        def gh(*args):
            self.calls.append(("gh", args))
            if args[:2] == ("release", "upload"):
                path = Path(args[-1])
                self.assets[path.name] = path.read_bytes()
            elif args[:2] == ("release", "edit"):
                self.current["draft"] = False
            elif args[:2] == ("release", "create"):
                notes_file = Path(args[args.index("--notes-file") + 1])
                self.current["body"] = notes_file.read_text(encoding="utf-8")
            return ""

        def request(path, token, body=None, content_type=None):
            self.calls.append(("request", path))
            if body is None:
                return [{"id": 33, "name": "1.60.1", "gameVersionTypeID": 88568}]
            return {"id": 12345}

        contexts = [
            patch.object(release, "verify_artifacts", return_value=self.data),
            patch.object(release, "verify_remote"),
            patch.object(github, "existing", side_effect=existing),
            patch.object(github, "gh", side_effect=gh),
            patch.object(
                github,
                "download",
                side_effect=lambda tag, name, root: self.assets[name],
            ),
            patch.object(cf, "request", side_effect=request),
            patch("builtins.print"),
            patch.dict(
                os.environ,
                {
                    "GH_REPO": "elithrar/FindAnUpgrade",
                    "CF_API_KEY": "offline-fixture-only",
                    "CF_PROJECT_ID": "42",
                    "GITHUB_STEP_SUMMARY": "",
                },
            ),
        ]
        for context in contexts:
            context.start()
            self.addCleanup(context.stop)

    def receipt(self):
        return {
            "tag": self.data["tag"],
            "commit": self.data["commit"],
            "project_id": 42,
            "sha256": self.data["assets"][self.data["archive"]],
            "game_version": "1.60.1",
            "game_version_type": 88568,
            "release_type": "release",
            "file_id": 12345,
            "game_version_id": 33,
            "status": "upload accepted; moderation/public visibility unverified",
        }

    def test_success_records_confirmed_intent_before_one_post_and_receipt_after(self):
        self.assertTrue(cf.upload(self.root))
        post = next(
            i
            for i, c in enumerate(self.calls)
            if c[0] == "request" and c[1].endswith("upload-file")
        )
        intent = next(
            i
            for i, c in enumerate(self.calls)
            if c[0] == "gh" and c[1][-1].endswith("curseforge-upload-pending.json")
        )
        self.assertLess(intent, post)
        self.assertIn("curseforge-upload-pending.json", self.assets)
        self.assertIn("curseforge-receipt.json", self.assets)
        self.assertEqual(
            json.loads(self.assets["curseforge-receipt.json"])["file_id"], 12345
        )
        self.assertEqual(
            sum(c[0] == "request" and c[1].endswith("upload-file") for c in self.calls),
            1,
        )

    def test_github_and_curseforge_use_the_same_exact_three_paragraphs(self):
        self.current["assets"] = [{"name": name} for name in self.assets]
        with patch.object(github, "existing", side_effect=[None, self.current]):
            github.prepare(self.root)
        create = next(
            args
            for kind, args in self.calls
            if kind == "gh" and args[:2] == ("release", "create")
        )
        notes_file = Path(create[create.index("--notes-file") + 1])
        self.assertEqual(notes_file, self.root / "dist/release-notes.md")
        self.assertEqual(notes_file.read_bytes(), PUBLIC_NOTES.encode("utf-8"))
        self.assertEqual(self.current["body"], PUBLIC_NOTES)
        with patch.object(cf, "multipart", wraps=cf.multipart) as multipart:
            self.assertTrue(cf.upload(self.root))
        metadata = multipart.call_args.args[0]
        self.assertEqual(metadata["changelog"], PUBLIC_NOTES)
        posted_metadata = json.loads(
            cf.request.call_args.args[2].split(b"\r\n\r\n", 1)[1].split(b"\r\n--", 1)[0]
        )
        self.assertEqual(posted_metadata["changelog"], PUBLIC_NOTES)
        self.assertEqual(metadata["changelog"], notes_file.read_text(encoding="utf-8"))
        self.assertEqual(len(metadata["changelog"].split("\n\n")), 3)
        self.assertNotIn("#", metadata["changelog"])
        self.assertEqual(
            release.sha(self.root / "CHANGELOG.md"), self.data["notes_sha256"]
        )

    def test_conflicting_existing_notes_fail_without_edit_or_upload(self):
        self.current["body"] = "Different notes, possibly already published."
        for draft in (True, False):
            self.current["draft"] = draft
            for operation in (github.prepare, github.finalize, cf.upload):
                with (
                    self.subTest(draft=draft, operation=operation.__name__),
                    self.assertRaisesRegex(ValueError, "release notes differ"),
                ):
                    operation(self.root)
        self.assertEqual(self.calls, [])

    def test_receipt_validated_before_duplicate_upload_is_skipped(self):
        self.assets["curseforge-receipt.json"] = json.dumps(self.receipt()).encode()
        self.assertTrue(cf.upload(self.root))
        self.assertEqual(cf.request.call_count, 0)
        for key, value in [
            ("sha256", "bad"),
            ("project_id", 99),
            ("file_id", True),
            ("game_version_type", 517),
        ]:
            self.assets["curseforge-receipt.json"] = json.dumps(
                {**self.receipt(), key: value}
            ).encode()
            with self.assertRaises(ValueError):
                cf.upload(self.root)
        self.assertEqual(cf.request.call_count, 0)

    def test_pending_and_immutable_block_post(self):
        self.assets["curseforge-upload-pending.json"] = b"intent"
        with self.assertRaisesRegex(ValueError, "unresolved"):
            cf.upload(self.root)
        del self.assets["curseforge-upload-pending.json"]
        self.current["immutable"] = True
        with self.assertRaisesRegex(ValueError, "Immutable"):
            cf.upload(self.root)
        self.assertEqual(cf.request.call_count, 0)

    def test_timeout_is_never_retried(self):
        original = cf.request.side_effect

        def failure(path, *args):
            if path.endswith("upload-file"):
                raise TimeoutError("offline fixture")
            return original(path, *args)

        cf.request.side_effect = failure
        with self.assertRaises(TimeoutError):
            cf.upload(self.root)
        self.assertEqual(cf.request.call_count, 2)
        self.assertIn("curseforge-upload-pending.json", self.assets)
        self.assertNotIn("curseforge-receipt.json", self.assets)

    def test_missing_settings_skip_without_network(self):
        with patch.dict(os.environ, {"CF_API_KEY": ""}):
            self.assertFalse(cf.upload(self.root))
        with patch.dict(os.environ, {"CF_PROJECT_ID": ""}):
            self.assertFalse(cf.upload(self.root))
        self.assertEqual(cf.request.call_count, 0)
        self.assertEqual(self.calls, [])

    def test_changed_github_asset_or_missing_published_asset_rejected(self):
        self.assets["SHA256SUMS"] = b"changed"
        with self.assertRaisesRegex(ValueError, "different bytes"):
            github.prepare(self.root)
        self.assets["SHA256SUMS"] = (self.root / "dist/SHA256SUMS").read_bytes()
        del self.assets["package-receipt.json"]
        self.current["draft"] = False
        with self.assertRaisesRegex(ValueError, "incomplete"):
            github.prepare(self.root)
        self.assertEqual(self.calls, [])

    def test_unverified_extra_release_assets_are_rejected(self):
        for name in ["unverified-extra.zip", "surprise.exe", "foreign-receipt.json"]:
            self.assets[name] = b"unverified"
            with self.assertRaisesRegex(ValueError, "Unexpected"):
                github.prepare(self.root)
            del self.assets[name]
        self.assertEqual(self.calls, [])

    def test_github_finalize_confirms_publication_and_never_edits_published_release(
        self,
    ):
        github.finalize(self.root)
        self.assertFalse(self.current["draft"])
        self.assertEqual(len(self.calls), 1)
        self.calls.clear()
        github.finalize(self.root)
        self.assertEqual(self.calls, [])

    def test_unresolved_upload_blocks_github_finalize_when_settings_removed(self):
        self.assets["curseforge-upload-pending.json"] = b"intent"
        with patch.dict(os.environ, {"CF_API_KEY": ""}):
            self.assertFalse(cf.upload(self.root))
            with self.assertRaisesRegex(ValueError, "Unresolved"):
                github.finalize(self.root)
        self.assertEqual(self.calls, [])

    def test_finalize_cannot_trust_malformed_or_foreign_receipt_with_missing_token(
        self,
    ):
        self.assets["curseforge-upload-pending.json"] = json.dumps(
            github.upload_identity(self.data, 42)
        ).encode()
        for receipt in [
            {},
            {**self.receipt(), "project_id": 99},
            {**self.receipt(), "file_id": True},
        ]:
            self.assets["curseforge-receipt.json"] = json.dumps(receipt).encode()
            with patch.dict(os.environ, {"CF_API_KEY": ""}):
                self.assertFalse(cf.upload(self.root))
                with self.assertRaises(ValueError):
                    github.finalize(self.root)
        self.assets["curseforge-receipt.json"] = json.dumps(self.receipt()).encode()
        with (
            patch.dict(os.environ, {"CF_PROJECT_ID": ""}),
            self.assertRaises(ValueError),
        ):
            github.finalize(self.root)
        self.assertEqual(self.calls, [])

    def test_uncertain_intent_write_stops_before_post(self):
        github.gh.side_effect = lambda *args: ""
        with self.assertRaisesRegex(ValueError, "intent was not confirmed"):
            cf.upload(self.root)
        self.assertEqual(cf.request.call_count, 1)  # version GET only

    def test_read_failure_and_wrong_repository_fail_closed(self):
        github.existing.side_effect = RuntimeError("offline read failure")
        with self.assertRaises(RuntimeError):
            github.prepare(self.root)
        self.assertEqual(self.calls, [])
        with (
            patch.dict(os.environ, {"GH_REPO": "other/fork"}),
            self.assertRaises(ValueError),
        ):
            cf.upload(self.root)
        self.assertEqual(cf.request.call_count, 0)


class WorkflowTests(unittest.TestCase):
    def test_recovery_tools_are_pinned_separately_from_the_unchanged_tagged_payload(
        self,
    ):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        validation, publish = workflow.split("  publish:\n", 1)
        for job, command_count in ((validation, 1), (publish, 4)):
            steps = release.re.split(r"(?m)^      - ", job)[1:]
            tools = [step for step in steps if "path: .work/release-tools" in step]
            self.assertEqual(len(tools), 1)
            self.assertIn("ref: ${{ github.workflow_sha }}", tools[0])
            commands = [
                step
                for step in steps
                if release.re.search(r"python -m fau_tools (?:release|publish-)", step)
            ]
            self.assertEqual(len(commands), command_count)
            for step in commands:
                self.assertIn("working-directory: .work/release-tools", step)
                self.assertIn('--root "$GITHUB_WORKSPACE"', step)
        self.assertIn("ref: ${{ inputs.tag || github.ref }}", validation)
        self.assertIn("ref: ${{ needs.validate.outputs.commit }}", publish)
        self.assertNotIn("python -m fau_tools check --root", workflow)

    def test_recovery_dispatch_and_credentials_use_reviewed_presynced_tools(self):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        self.assertIn(
            "(github.event_name != 'workflow_dispatch' || github.ref == 'refs/heads/main')",
            workflow,
        )
        validation, publish = workflow.split("  publish:\n", 1)
        for job in (validation, publish):
            header, *steps = release.re.split(r"(?m)^      - ", job)
            self.assertIn(
                "UV_PROJECT_ENVIRONMENT: ${{ github.workspace }}/.work/release-venv",
                header,
            )
            sync = next(
                index
                for index, step in enumerate(steps)
                if "name: Sync locked release tooling dependencies" in step
            )
            self.assertIn("working-directory: .work/release-tools", steps[sync])
            self.assertIn("run: uv sync --locked", steps[sync])
            self.assertNotIn("GH_TOKEN:", steps[sync])
            self.assertNotIn("secrets.", steps[sync])
            for index, step in enumerate(steps):
                if "GH_TOKEN:" in step or "secrets." in step:
                    self.assertGreater(index, sync)
                    self.assertIn("uv run --locked --no-sync python -m fau_tools", step)
                    self.assertNotIn("UV_PROJECT_ENVIRONMENT:", step)
        self.assertLess(
            validation.index("python -m fau_tools check"),
            validation.index("name: Check out release tooling"),
        )
        for step in release.re.split(r"(?m)^      - ", validation)[1:]:
            if (
                "name: Sync locked payload dependencies" in step
                or "name: Test and package" in step
            ):
                self.assertIn(
                    "UV_PROJECT_ENVIRONMENT: ${{ github.workspace }}/.work/venv", step
                )

    def test_renamed_repository_and_supplied_secret_are_the_release_contract(self):
        with patch.dict(os.environ, {"GH_REPO": "elithrar/FindAnUpgrade"}):
            github.require_repository()
        for repository in ["elithrar/QuestBrief", "other/FindAnUpgrade", ""]:
            with (
                patch.dict(os.environ, {"GH_REPO": repository}),
                self.assertRaises(ValueError),
            ):
                github.require_repository()
        self.assertIsNone(
            cf.settings({"CF_API_TOKEN": "offline-obsolete", "CF_PROJECT_ID": "42"})
        )
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        self.assertIn("if: github.repository == 'elithrar/FindAnUpgrade'", workflow)
        self.assertNotIn("elithrar/QuestBrief", workflow)
        self.assertNotIn("secrets.CF_API_TOKEN", workflow)
        triggers = workflow.split("permissions:\n", 1)[0]
        self.assertIn("tags: ['v*']", triggers)
        self.assertIn("workflow_dispatch:", triggers)
        self.assertNotIn("branches:", triggers)
        self.assertNotIn("pull_request", triggers)

    def test_all_validation_workflows_supply_the_executed_native_contracts(self):
        runner = ast.parse((ROOT / "tests/run.py").read_text())
        required = next(
            ast.literal_eval(node.value)
            for node in runner.body
            if isinstance(node, ast.Assign)
            and any(
                isinstance(target, ast.Name) and target.id == "CURRENT_PATHS"
                for target in node.targets
            )
        )
        revision = json.loads((ROOT / "tests/native-source-fixtures.json").read_text())[
            "currentSnapshot"
        ]["revision"]
        for name in ["check.yml", "release.yml"]:
            text = (ROOT / ".github/workflows" / name).read_text()
            step = next(
                part
                for part in release.re.split(r"(?m)^      - ", text)
                if "path: .work/current-api" in part
            )
            with self.subTest(workflow=name):
                self.assertIn("ref: " + revision, step)
                supplied = set(release.re.findall(r"(?m)^            /(.+)$", step))
                self.assertEqual(set(required), supplied)

    def test_workflows_pin_actions_and_keep_credentials_in_publish_steps(self):
        for name in ["check.yml", "release.yml"]:
            text = (ROOT / ".github/workflows" / name).read_text()
            uses = release.re.findall(r"uses: (\S+)", text)
            self.assertTrue(uses)
            self.assertTrue(
                all(
                    release.re.fullmatch(
                        r"(?:actions/[a-z-]+|astral-sh/setup-uv)@[0-9a-f]{40}", u
                    )
                    for u in uses
                )
            )
            self.assertNotIn("pull_request_target", text)
            self.assertEqual(
                text.count("persist-credentials: false"),
                text.count("uses: actions/checkout@"),
            )
            self.assertIn("uv run --locked python -m fau_tools check", text)
            self.assertIn("uv sync --locked", text)
            for step in release.re.split(r"(?m)^      - ", text)[1:]:
                self.assertTrue(
                    "uses:" in step or "run:" in step,
                    "GitHub step lacks an action or command",
                )
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        validation, publish = workflow.split("  publish:\n", 1)
        self.assertNotIn("secrets.", validation)
        self.assertNotIn("contents: write", validation)
        self.assertIn("needs: validate", publish)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertIn("CF_API_KEY: ${{ secrets.CF_API_KEY }}", publish)
        self.assertIn("CF_PROJECT_ID: ${{ vars.CF_PROJECT_ID }}", publish)
        final_step = publish.split("- name: Publish completed GitHub release", 1)[1]
        self.assertIn("CF_PROJECT_ID: ${{ vars.CF_PROJECT_ID }}", final_step)
        self.assertLess(
            publish.index("python -m fau_tools release --verify"),
            publish.index("python -m fau_tools publish-github"),
        )
        self.assertLess(
            publish.index("python -m fau_tools publish-curseforge"),
            publish.index("python -m fau_tools publish-github --finalize"),
        )
        self.assertNotIn("git fetch origin", workflow)


if __name__ == "__main__":
    (ROOT / ".work").mkdir(exist_ok=True)
    unittest.main()
