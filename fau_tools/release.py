"""Validate an explicit release tag and the exact build before publication.

This module has no publishing credentials or network writes. Release conventions
follow XPIsland; its BSD notice is retained in FindAnUpgrade/XPISLAND-LICENSE.txt."""

import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import zipfile

from fau_tools.context import ROOT

VERSION = r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)"


def metadata(tag, toc):
    if not re.fullmatch("v" + VERSION, tag):
        raise ValueError("Use an existing annotated vX.Y.Z tag")
    if re.findall(r"^## Version: (.+)$", toc, re.M) != [tag[1:]]:
        raise ValueError("Tag must exactly match the TOC version")
    if re.findall(r"^## Interface[^:]*: (.+)$", toc, re.M) != ["16001"]:
        raise ValueError("Only Forever 1.60.1/interface 16001 may be released")
    return {
        "tag": tag,
        "version": tag[1:],
        "interface": 16001,
        "archive": f"FindAnUpgrade-{tag[1:]}.zip",
        "source_archive": f"FindAnUpgrade-{tag[1:]}-source.zip",
        "game_version": "1.60.1",
        "game_version_type": 88568,
        "release_type": "release",
    }


def git(*args, root=ROOT):
    return subprocess.check_output(
        ["git", *args], cwd=root, text=True, stderr=subprocess.DEVNULL
    ).strip()


def check_tag(tag, root=ROOT):
    # Check before passing input to Git; never treat input as an option or refspec.
    if not re.fullmatch("v" + VERSION, tag):
        raise ValueError("Invalid release tag")
    ref = "refs/tags/" + tag
    if git("cat-file", "-t", ref, root=root) != "tag":
        raise ValueError("Release tag must be annotated")
    commit = git("rev-parse", ref + "^{commit}", root=root)
    if git("rev-parse", "HEAD", root=root) != commit:
        raise ValueError("Checkout must be the tagged commit")
    result = subprocess.run(
        ["git", "merge-base", "--is-ancestor", commit, "refs/remotes/origin/main"],
        cwd=root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if result.returncode:
        raise ValueError("Release commit must be reachable from origin/main")
    if git("status", "--porcelain", "--untracked-files=all", root=root):
        raise ValueError(
            "Release checkout must be clean and contain only committed source"
        )
    return commit


def refresh_refs(tag, root=ROOT):
    """Read remote main/tag using ephemeral auth, without persisting credentials."""
    if not re.fullmatch("v" + VERSION, tag):
        raise ValueError("Invalid release tag")
    environ = dict(os.environ)
    token = environ.get("GH_TOKEN")
    if token:
        credential = base64.b64encode(("x-access-token:" + token).encode()).decode()
        environ.update(
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="http.https://github.com/.extraheader",
            GIT_CONFIG_VALUE_0="AUTHORIZATION: basic " + credential,
        )
    ref = "refs/tags/" + tag
    result = subprocess.run(
        [
            "git",
            "fetch",
            "--force",
            "origin",
            "main:refs/remotes/origin/main",
            ref + ":" + ref,
        ],
        cwd=root,
        env=environ,
        text=True,
        capture_output=True,
    )
    if result.returncode:
        # Credential-bearing Git diagnostics must not be copied into logs.
        raise RuntimeError("Could not refresh remote main and exact release tag")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check_source_tree(commit, root=ROOT):
    """Every packaged source member must equal a tracked blob in the tag tree."""
    from fau_tools.packaging import source_files

    raw = subprocess.check_output(["git", "ls-tree", "-r", "-z", commit], cwd=root)
    tracked = {}
    for entry in raw.split(b"\0"):
        if entry:
            details, path = entry.split(b"\t", 1)
            mode, kind, digest = details.split(b" ")
            if kind == b"blob" and mode in [b"100644", b"100755"]:
                tracked[path] = digest.decode("ascii")
    for file in source_files(root):
        relative = file.relative_to(root).as_posix()
        content = file.read_bytes()
        digest = hashlib.sha1(
            b"blob " + str(len(content)).encode() + b"\0" + content
        ).hexdigest()
        if tracked.get(relative.encode("utf-8")) != digest:
            raise ValueError(
                "Packaged source differs from tagged Git blob: " + relative
            )


def verify_artifacts(root=ROOT):
    """Reject changed/extra archive bytes and manifests, including the source ZIP."""
    from fau_tools.packaging import SHIPPED, source_files, validate

    directory = root / "dist"
    data = json.loads((directory / "release.json").read_text(encoding="utf-8"))
    expected = metadata(
        data["tag"],
        (root / "FindAnUpgrade/FindAnUpgrade.toc").read_text(encoding="utf-8"),
    )
    if any(data.get(key) != value for key, value in expected.items()):
        raise ValueError("Unexpected release metadata")
    if not all(
        re.fullmatch(r"[0-9a-f]{40}", data.get(k, "")) for k in ["commit", "tag_object"]
    ):
        raise ValueError("Invalid release commit or tag object")
    if validate(root) != data["version"]:
        raise ValueError("Package version mismatch")
    names = [data["archive"], data["source_archive"]]
    if {p.name for p in directory.glob("*.zip")} != set(names):
        raise ValueError("Unexpected release ZIP assets")
    lines = (directory / "SHA256SUMS").read_text(encoding="utf-8").splitlines()
    checksums = {}
    for line in lines:
        match = re.fullmatch(
            r"([0-9a-f]{64})  (FindAnUpgrade-" + VERSION + r"(?:-source)?\.zip)", line
        )
        if not match or match[2] in checksums:
            raise ValueError("Invalid or duplicate checksum entry")
        checksums[match[2]] = match[1]
    if set(checksums) != set(names) or any(
        sha(directory / name) != checksums[name] for name in names
    ):
        raise ValueError("Archive checksums do not match the exact build")
    addon_files = [root / "FindAnUpgrade" / name for name in SHIPPED]
    targets = [
        (data["archive"], addon_files, ""),
        (
            data["source_archive"],
            source_files(root),
            f"FindAnUpgrade-{data['version']}-source/",
        ),
    ]
    for name, files, prefix in targets:
        expected_files = {prefix + p.relative_to(root).as_posix(): p for p in files}
        with zipfile.ZipFile(directory / name) as archive:
            if len(archive.namelist()) != len(expected_files) or set(
                archive.namelist()
            ) != set(expected_files):
                raise ValueError("Archive payload manifest changed")
            if archive.testzip() or any(
                archive.read(n) != p.read_bytes() for n, p in expected_files.items()
            ):
                raise ValueError("Archive payload bytes changed")
    receipt = json.loads(
        (directory / "package-receipt.json").read_text(encoding="utf-8")
    )
    payload = [
        {
            "path": p.relative_to(root).as_posix(),
            "bytes": p.stat().st_size,
            "sha256": sha(p),
        }
        for p in sorted(addon_files)
    ]
    if receipt != {
        "addon": "FindAnUpgrade",
        "version": data["version"],
        "interface": 16001,
        "candidateOnly": True,
        "published": False,
        "installed": False,
        "archives": checksums,
        "payload": payload,
    }:
        raise ValueError("Package receipt disagrees with the exact build")
    assets = names + ["SHA256SUMS", "package-receipt.json"]
    if data.get("assets") != {name: sha(directory / name) for name in assets}:
        raise ValueError("Release asset receipt changed")
    notes = root / "docs/releases" / (data["version"] + ".md")
    if (
        not notes.is_file()
        or not notes.read_text(encoding="utf-8").strip()
        or data.get("notes_sha256") != sha(notes)
    ):
        raise ValueError("Version-specific release notes missing or changed")
    return data


def prepare(tag, root=ROOT):
    data = metadata(
        tag, (root / "FindAnUpgrade/FindAnUpgrade.toc").read_text(encoding="utf-8")
    )
    data["commit"] = check_tag(tag, root)
    check_source_tree(data["commit"], root)
    data["tag_object"] = git("rev-parse", "refs/tags/" + tag, root=root)
    notes = root / "docs/releases" / (data["version"] + ".md")
    if not notes.is_file() or not notes.read_text(encoding="utf-8").strip():
        raise ValueError("Add version-specific release notes before tagging")
    data["notes_sha256"] = sha(notes)
    directory = root / "dist"
    names = [
        data["archive"],
        data["source_archive"],
        "SHA256SUMS",
        "package-receipt.json",
    ]
    data["assets"] = {name: sha(directory / name) for name in names}
    (directory / "release.json").write_text(
        json.dumps(data, indent=2) + "\n", encoding="utf-8"
    )
    verify_artifacts(root)
    return data


def verify_tag(data, root=ROOT):
    if (
        check_tag(data["tag"], root) != data["commit"]
        or git("rev-parse", "refs/tags/" + data["tag"], root=root) != data["tag_object"]
    ):
        raise ValueError("Release tag moved since validation; use a new version")


def verify_remote(data, root=ROOT):
    refresh_refs(data["tag"], root)
    verify_tag(data, root)
    check_source_tree(data["commit"], root)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv not in ([], ["--verify"]):
        raise SystemExit("release accepts only --verify")
    if argv == ["--verify"]:
        data = verify_artifacts()
        verify_remote(data)
    else:
        tag = os.environ.get("RELEASE_TAG", "")
        refresh_refs(tag)
        data = prepare(tag)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
            output.write("commit=" + data["commit"] + "\n")
    print(f"Validated {data['tag']}: Forever 1.60.1, commit {data['commit']}")
