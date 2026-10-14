"""Upload exact Forever bytes once, preserving intent before an uncertain POST."""
import json
import os
from pathlib import Path
import urllib.error
import urllib.request
import uuid

import publish_github as github
import release

ROOT = Path(__file__).resolve().parents[1]
BASE = "https://wow.curseforge.com"


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Unexpected CurseForge redirect; upload was not retried")


def request(path, token, body=None, content_type=None):
    headers = {"X-Api-Token": token, "Accept": "application/json",
               "User-Agent": "QuestBrief-release/1"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(BASE + path, data=body, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError(f"CurseForge HTTP {error.code}; inspect the author dashboard before retrying") from None
    except (urllib.error.URLError, TimeoutError, ValueError):
        # Never print response bodies/headers or token-bearing exception detail.
        raise RuntimeError("CurseForge request outcome uncertain; inspect the author dashboard before retrying") from None


def exact_version(versions, data):
    if not isinstance(versions, list):
        raise ValueError("Unexpected CurseForge version response")
    matches = [v for v in versions if isinstance(v, dict)
               and v.get("name") == data["game_version"]
               and v.get("gameVersionTypeID") == data["game_version_type"]]
    if len(matches) != 1 or type(matches[0].get("id")) is not int or matches[0]["id"] <= 0:
        raise ValueError("Expected exactly one Forever 1.60.1 version; refusing another flavor/patch")
    return matches[0]["id"]


def multipart(metadata, archive):
    boundary = "QuestBrief-" + uuid.uuid4().hex
    first = (f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n'
             'Content-Type: application/json\r\n\r\n').encode() + json.dumps(metadata).encode()
    second = (f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\n'
              'Content-Type: application/zip\r\n\r\n').encode() + archive.read_bytes()
    return first + second + f"\r\n--{boundary}--\r\n".encode(), "multipart/form-data; boundary=" + boundary


def settings(environ=None):
    environ = os.environ if environ is None else environ
    token, project = environ.get("CF_API_TOKEN", ""), environ.get("CF_PROJECT_ID", "")
    if not token or not project:
        return None
    if not release.re.fullmatch(r"[1-9][0-9]*", project):
        raise ValueError("CF_PROJECT_ID must be the exact positive numeric QuestBrief project ID")
    return token, int(project)


def summary(message):
    print(message)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as output:
            output.write(message + "\n")


def main(root=ROOT):
    configured = settings()
    if not configured:
        summary("CurseForge upload NOT attempted: add CF_API_TOKEN secret and CF_PROJECT_ID repository variable.")
        return False
    token, project = configured
    github.require_repository()
    data = release.verify_artifacts(root)
    release.verify_remote(data, root)
    current = github.existing(data["tag"])
    if not current or github.verify_existing(data, current, root):
        raise ValueError("Confirm exact GitHub release assets before CurseForge upload")
    names = {a["name"] for a in current["assets"]}
    expected = github.upload_identity(data, project)
    if "curseforge-receipt.json" in names:
        github.verify_upload_records(data, current, project, root)
        summary("CurseForge receipt already confirms upload acceptance; no duplicate upload attempted.")
        return True
    if "curseforge-upload-pending.json" in names:
        raise ValueError("Earlier upload outcome is unresolved. Reconcile the pending intent before retrying")
    if current.get("immutable"):
        raise ValueError("Immutable GitHub release cannot record upload intent; configure CurseForge before publishing a new version")
    version_id = exact_version(request("/api/game/wow/versions", token), data)
    notes = root / "docs/releases" / (data["version"] + ".md")
    metadata = {"displayName": "QuestBrief " + data["tag"], "gameVersions": [version_id],
                "releaseType": "release", "changelogType": "markdown",
                "changelog": notes.read_text(encoding="utf-8"), "isMarkedForManualRelease": False}
    body, content_type = multipart(metadata, root / "dist" / data["archive"])
    pending = root / "dist/curseforge-upload-pending.json"
    pending.write_text(json.dumps(expected, indent=2) + "\n", encoding="utf-8")
    # Upload intent is append-only and persists across runs. Never clobber it.
    release.verify_remote(data, root)
    github.gh("release", "upload", data["tag"], str(pending))
    current = github.existing(data["tag"])
    if not current or "curseforge-upload-pending.json" not in {a["name"] for a in current["assets"]}:
        raise ValueError("Upload intent was not confirmed; no CurseForge POST attempted")
    if github.download(data["tag"], pending.name, root) != pending.read_bytes():
        raise ValueError("Upload intent changed; no CurseForge POST attempted")
    release.verify_remote(data, root)
    response = request(f"/api/projects/{project}/upload-file", token, body, content_type)
    file_id = response.get("id") if isinstance(response, dict) else None
    if type(file_id) is not int or file_id <= 0:
        raise ValueError("No valid upload file ID returned. Inspect CurseForge before retrying")
    receipt = dict(expected, file_id=file_id, game_version_id=version_id,
                   status="upload accepted; moderation/public visibility unverified")
    path = root / "dist/curseforge-receipt.json"
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    github.gh("release", "upload", data["tag"], str(path))
    if github.download(data["tag"], path.name, root) != path.read_bytes():
        raise ValueError("Upload accepted but its receipt was not confirmed; inspect CurseForge before retrying")
    summary(f"CurseForge accepted file {file_id} as Release for Forever 1.60.1. Moderation/public visibility remains unverified.")
    return True


if __name__ == "__main__":
    main()
