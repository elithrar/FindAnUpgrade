"""Guarded GitHub preparation and exact-once CurseForge publication."""

import json
import os
import subprocess
import tempfile
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from fau_tools import release as release
from fau_tools.context import ROOT

# GitHub release preparation and finalization.


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()


def require_repository():
    if os.environ.get("GH_REPO") != "elithrar/FindAnUpgrade":
        raise ValueError("Publishing is configured only for elithrar/FindAnUpgrade")


def existing(tag):
    # API/read errors fail closed, never mean that creating a release is safe.
    pages = json.loads(
        gh("api", "--paginate", "--slurp", "repos/{owner}/{repo}/releases")
    )
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
    expected = dict(
        data["assets"], **{"release.json": release.sha(root / "dist/release.json")}
    )
    allowed = set(expected) | {
        "curseforge-upload-pending.json",
        "curseforge-receipt.json",
    }
    if set(names) - allowed:
        raise ValueError("Unexpected GitHub release assets")
    missing = []
    for name, digest in expected.items():
        if name not in names:
            missing.append(name)
        elif (
            release.hashlib.sha256(download(data["tag"], name, root)).hexdigest()
            != digest
        ):
            raise ValueError(
                "Existing release asset has different bytes; use a new version"
            )
    if missing and (not current["draft"] or current.get("immutable")):
        raise ValueError(
            "Published release is incomplete; do not replace published assets"
        )
    return missing


def upload_identity(data, project):
    return {
        "tag": data["tag"],
        "commit": data["commit"],
        "project_id": project,
        "sha256": data["assets"][data["archive"]],
        "game_version": "1.60.1",
        "game_version_type": 88568,
        "release_type": "release",
    }


def verify_upload_records(data, current, project, root=ROOT):
    names = {a["name"] for a in current["assets"]}
    if "curseforge-receipt.json" not in names:
        if "curseforge-upload-pending.json" in names:
            raise ValueError("Unresolved CurseForge upload intent blocks publication")
        return False
    if type(project) is not int or project <= 0:
        raise ValueError(
            "CF_PROJECT_ID is required to validate an existing upload receipt"
        )
    receipt = json.loads(download(data["tag"], "curseforge-receipt.json", root))
    expected = upload_identity(data, project)
    if (
        not isinstance(receipt, dict)
        or any(receipt.get(k) != v for k, v in expected.items())
        or type(receipt.get("file_id")) is not int
        or receipt["file_id"] <= 0
        or type(receipt.get("game_version_id")) is not int
        or receipt["game_version_id"] <= 0
        or receipt.get("status")
        != "upload accepted; moderation/public visibility unverified"
        or set(receipt) != set(expected) | {"file_id", "game_version_id", "status"}
    ):
        raise ValueError(
            "Existing CurseForge receipt does not match this release/project"
        )
    if "curseforge-upload-pending.json" in names:
        intent = json.loads(
            download(data["tag"], "curseforge-upload-pending.json", root)
        )
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
        gh(
            "release",
            "create",
            data["tag"],
            *files,
            "--verify-tag",
            "--draft",
            "--title",
            "FindAnUpgrade " + data["tag"],
            "--notes-file",
            str(release.release_notes(data, root)),
        )
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


# Publish curseforge.

BASE = "https://wow.curseforge.com"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected CurseForge redirect; upload was not retried")


def request(path, token, body=None, content_type=None):
    headers = {
        "X-Api-Token": token,
        "Accept": "application/json",
        "User-Agent": "FindAnUpgrade-release/1",
    }
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(BASE + path, data=body, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(
            req, timeout=60
        ) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(
            f"CurseForge HTTP {error.code}; inspect the author dashboard before retrying"
        ) from None
    except urllib.error.URLError, TimeoutError, ValueError:
        # Never print response bodies/headers or token-bearing exception detail.
        raise RuntimeError(
            "CurseForge request outcome uncertain; inspect the author dashboard before retrying"
        ) from None


def exact_version(versions, data):
    if not isinstance(versions, list):
        raise ValueError("Unexpected CurseForge version response")
    matches = [
        v
        for v in versions
        if isinstance(v, dict)
        and v.get("name") == data["game_version"]
        and v.get("gameVersionTypeID") == data["game_version_type"]
    ]
    if (
        len(matches) != 1
        or type(matches[0].get("id")) is not int
        or matches[0]["id"] <= 0
    ):
        raise ValueError(
            "Expected exactly one Forever 1.60.1 version; refusing another flavor/patch"
        )
    return matches[0]["id"]


def multipart(metadata, archive):
    boundary = "FindAnUpgrade-" + uuid.uuid4().hex
    first = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
        "Content-Type: application/json\r\n\r\n"
    ).encode() + json.dumps(metadata).encode()
    second = (
        f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
        "Content-Type: application/zip\r\n\r\n"
    ).encode() + archive.read_bytes()
    return (
        first + second + f"\r\n--{boundary}--\r\n".encode(),
        "multipart/form-data; boundary=" + boundary,
    )


def settings(environ=None):
    environ = os.environ if environ is None else environ
    token, project = environ.get("CF_API_KEY", ""), environ.get("CF_PROJECT_ID", "")
    if not token or not project:
        return None
    if not release.re.fullmatch(r"[1-9][0-9]*", project):
        raise ValueError(
            "CF_PROJECT_ID must be the exact positive numeric FindAnUpgrade project ID"
        )
    return token, int(project)


def summary(message):
    print(message)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(message + "\n")


def upload(root=ROOT):
    configured = settings()
    if not configured:
        summary(
            "CurseForge upload NOT attempted: add CF_API_KEY secret and CF_PROJECT_ID repository variable."
        )
        return False
    token, project = configured
    require_repository()
    data = release.verify_artifacts(root)
    release.verify_remote(data, root)
    current = existing(data["tag"])
    if not current or verify_existing(data, current, root):
        raise ValueError("Confirm exact GitHub release assets before CurseForge upload")
    names = {a["name"] for a in current["assets"]}
    expected = upload_identity(data, project)
    if "curseforge-receipt.json" in names:
        verify_upload_records(data, current, project, root)
        summary(
            "CurseForge receipt already confirms upload acceptance; no duplicate upload attempted."
        )
        return True
    if "curseforge-upload-pending.json" in names:
        raise ValueError(
            "Earlier upload outcome is unresolved. Reconcile the pending intent before retrying"
        )
    if current.get("immutable"):
        raise ValueError(
            "Immutable GitHub release cannot record upload intent; configure CurseForge before publishing a new version"
        )
    version_id = exact_version(request("/api/game/wow/versions", token), data)
    notes = release.release_notes(data, root)
    metadata = {
        "displayName": "FindAnUpgrade " + data["tag"],
        "gameVersions": [version_id],
        "releaseType": "release",
        "changelogType": "markdown",
        "changelog": notes.read_text(encoding="utf-8"),
        "isMarkedForManualRelease": False,
    }
    body, content_type = multipart(metadata, root / "dist" / data["archive"])
    pending = root / "dist/curseforge-upload-pending.json"
    pending.write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    # Upload intent is append-only and persists across runs. Never clobber it.
    release.verify_remote(data, root)
    gh("release", "upload", data["tag"], str(pending))
    current = existing(data["tag"])
    if not current or "curseforge-upload-pending.json" not in {
        a["name"] for a in current["assets"]
    }:
        raise ValueError(
            "Upload intent was not confirmed; no CurseForge POST attempted"
        )
    if download(data["tag"], pending.name, root) != pending.read_bytes():
        raise ValueError("Upload intent changed; no CurseForge POST attempted")
    release.verify_remote(data, root)
    response = request(
        f"/api/projects/{project}/upload-file", token, body, content_type
    )
    file_id = response.get("id") if isinstance(response, dict) else None
    if type(file_id) is not int or file_id <= 0:
        raise ValueError(
            "No valid upload file ID returned. Inspect CurseForge before retrying"
        )
    receipt = dict(
        expected,
        file_id=file_id,
        game_version_id=version_id,
        status="upload accepted; moderation/public visibility unverified",
    )
    path = root / "dist/curseforge-receipt.json"
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    gh("release", "upload", data["tag"], str(path))
    if download(data["tag"], path.name, root) != path.read_bytes():
        raise ValueError(
            "Upload accepted but its receipt was not confirmed; inspect CurseForge before retrying"
        )
    summary(
        f"CurseForge accepted file {file_id} as Release for Forever 1.60.1. Moderation/public visibility remains unverified."
    )
    return True
