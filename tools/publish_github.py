"""Publish verified release assets without moving tags or replacing asset bytes."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import release

ROOT = Path(__file__).resolve().parents[1]


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()


def require_repository():
    if os.environ.get("GH_REPO") != "elithrar/QuestBrief":
        raise ValueError("Publishing is configured only for elithrar/QuestBrief")


def existing(tag):
    # API/read errors fail closed, never mean that creating a release is safe.
    pages = json.loads(gh("api", "--paginate", "--slurp", "repos/{owner}/{repo}/releases"))
    matches = [r for page in pages for r in page if r["tag_name"] == tag]
    if len(matches) > 1:
        raise ValueError("Ambiguous GitHub release")
    return matches[0] if matches else None


def download(tag, name, root=ROOT):
    with tempfile.TemporaryDirectory() as folder:
        gh("release", "download", tag, "--pattern", name, "--dir", folder)
        return (Path(folder) / name).read_bytes()


def verify_existing(data, current, root=ROOT):
    assets = current["assets"]
    names = [a["name"] for a in assets]
    if len(names) != len(set(names)):
        raise ValueError("Duplicate GitHub asset names")
    expected = dict(data["assets"], **{"release.json": release.sha(root / "dist/release.json")})
    allowed = set(expected) | {"curseforge-upload-pending.json", "curseforge-receipt.json"}
    if set(names) - allowed:
        raise ValueError("Unexpected GitHub release assets")
    missing = []
    for name, digest in expected.items():
        if name not in names:
            missing.append(name)
        elif release.hashlib.sha256(download(data["tag"], name, root)).hexdigest() != digest:
            raise ValueError("Existing release asset has different bytes; use a new version")
    if missing and (not current["draft"] or current.get("immutable")):
        raise ValueError("Published release is incomplete; do not replace published assets")
    return missing


def upload_identity(data, project):
    return {"tag": data["tag"], "commit": data["commit"], "project_id": project,
            "sha256": data["assets"][data["archive"]], "game_version": "1.60.1",
            "game_version_type": 88568, "release_type": "release"}


def verify_upload_records(data, current, project, root=ROOT):
    names = {a["name"] for a in current["assets"]}
    if "curseforge-receipt.json" not in names:
        if "curseforge-upload-pending.json" in names:
            raise ValueError("Unresolved CurseForge upload intent blocks publication")
        return False
    if type(project) is not int or project <= 0:
        raise ValueError("CF_PROJECT_ID is required to validate an existing upload receipt")
    receipt = json.loads(download(data["tag"], "curseforge-receipt.json", root))
    expected = upload_identity(data, project)
    if (not isinstance(receipt, dict) or any(receipt.get(k) != v for k, v in expected.items())
            or type(receipt.get("file_id")) is not int or receipt["file_id"] <= 0
            or type(receipt.get("game_version_id")) is not int or receipt["game_version_id"] <= 0
            or receipt.get("status") != "upload accepted; moderation/public visibility unverified"
            or set(receipt) != set(expected) | {"file_id", "game_version_id", "status"}):
        raise ValueError("Existing CurseForge receipt does not match this release/project")
    if "curseforge-upload-pending.json" in names:
        intent = json.loads(download(data["tag"], "curseforge-upload-pending.json", root))
        if intent != expected:
            raise ValueError("Existing CurseForge intent does not match its receipt")
    return True


def prepare(root=ROOT):
    require_repository()
    data = release.verify_artifacts(root)
    release.verify_remote(data, root)
    current = existing(data["tag"])
    if current:
        missing = verify_existing(data, current, root)
        for name in missing:
            release.verify_remote(data, root)
            gh("release", "upload", data["tag"], str(root / "dist" / name))
    else:
        files = [str(root / "dist" / n) for n in [*data["assets"], "release.json"]]
        release.verify_remote(data, root)
        gh("release", "create", data["tag"], *files, "--verify-tag", "--draft",
           "--title", "FindAnUpgrade " + data["tag"], "--notes-file",
           str(root / "docs/releases" / (data["version"] + ".md")))
    # Confirm creation/upload before allowing the CurseForge side effect.
    current = existing(data["tag"])
    if not current or verify_existing(data, current, root):
        raise ValueError("GitHub draft assets could not be confirmed")
    return data


def finalize(root=ROOT):
    require_repository()
    data = release.verify_artifacts(root)
    release.verify_remote(data, root)
    current = existing(data["tag"])
    if not current or verify_existing(data, current, root):
        raise ValueError("GitHub release assets must be complete before publication")
    project = os.environ.get("CF_PROJECT_ID", "")
    project = int(project) if release.re.fullmatch(r"[1-9][0-9]*", project) else None
    verify_upload_records(data, current, project, root)
    if current["draft"]:
        release.verify_remote(data, root)
        gh("release", "edit", data["tag"], "--draft=false")
    current = existing(data["tag"])
    if not current or current["draft"]:
        raise ValueError("GitHub publication could not be confirmed")
    print("GitHub release: " + current["html_url"])


if __name__ == "__main__":
    if sys.argv[1:] == ["--finalize"]:
        finalize()
    elif not sys.argv[1:]:
        prepare()
    else:
        raise SystemExit("Use no arguments to prepare, or --finalize to publish")
