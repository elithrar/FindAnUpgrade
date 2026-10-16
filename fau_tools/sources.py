"""Pinned ATT acquisition and receipted public Forever collection."""

import argparse
import hashlib
import json
import math
import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import UTC, datetime
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote, urlencode, urlsplit
from urllib.request import Request, urlopen
from urllib.robotparser import RobotFileParser

from fau_tools.att import PIN, PREFIX
from fau_tools.context import ROOT
from fau_tools.html import quest_index, quest_index_fingerprints, quest_index_titles

# Acquire catalog sources.

REPO = "ATTWoWAddon/AllTheThings"
ATT_AGENT = "FindAnUpgrade-source-sync/1 (public pinned factual inputs)"


def fetch(url):
    with urlopen(
        Request(
            url,
            headers={"User-Agent": ATT_AGENT, "Accept": "application/vnd.github+json"},
        ),
        timeout=45,
    ) as response:
        if response.url.split("/")[2] not in (
            "api.github.com",
            "raw.githubusercontent.com",
        ):
            raise ValueError("Unexpected source redirect")
        return response.read()


def subtree(path, revision):
    parent, name = path.rsplit("/", 1)
    listing = json.loads(
        fetch(
            "https://api.github.com/repos/"
            + REPO
            + "/contents/"
            + quote(parent, safe="/")
            + "?ref="
            + revision
        )
    )
    selected = [row for row in listing if row["name"] == name and row["type"] == "dir"]
    if len(selected) != 1:
        raise ValueError("Source directory identity missing: " + path)
    tree = json.loads(
        fetch(
            "https://api.github.com/repos/"
            + REPO
            + "/git/trees/"
            + selected[0]["sha"]
            + "?recursive=1"
        )
    )
    if tree.get("truncated") or "tree" not in tree:
        raise ValueError("Incomplete upstream tree: " + path)
    return [
        {**row, "path": path + "/" + row["path"]}
        for row in tree["tree"]
        if row["type"] == "blob"
    ]


def receipt(path, raw, blob=None):
    actual = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
    if blob and actual != blob:
        raise ValueError("Upstream Git blob mismatch: " + path)
    return {
        "path": path,
        "gitBlob": actual,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "bytes": len(raw),
        "url": "https://github.com/"
        + REPO
        + "/blob/"
        + PIN
        + "/"
        + quote(path, safe="/"),
    }


def acquire(destination, selected):
    old = {}
    manifest = destination / "ACQUISITION.json"
    if manifest.exists():
        previous = json.loads(manifest.read_bytes())
        if previous["commit"] != PIN:
            raise ValueError(
                "Cache belongs to a different source pin; use a separate cache directory"
            )
        old = {row["path"]: row for row in previous["files"]}
    rows = []
    downloaded = 0
    for source in sorted(selected, key=lambda row: row["path"]):
        relative = Path(source["path"])
        target = (destination / relative).resolve()
        if not target.is_relative_to(destination.resolve()):
            raise ValueError("Source path escaped cache")
        raw = target.read_bytes() if target.is_file() else None
        expected = source.get("sha") or old.get(source["path"], {}).get("gitBlob")
        if (
            raw is None
            or not expected
            or hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
            != expected
        ):
            raw = fetch(
                "https://raw.githubusercontent.com/"
                + REPO
                + "/"
                + PIN
                + "/"
                + quote(source["path"], safe="/")
            )
            target.parent.mkdir(parents=True, exist_ok=True)
            verified = receipt(source["path"], raw, expected)
            target.write_bytes(raw)
            downloaded += 1
        else:
            verified = receipt(source["path"], raw, expected)
        rows.append(verified)
    destination.mkdir(parents=True, exist_ok=True)
    manifest.write_bytes(
        (
            json.dumps(
                {
                    "repository": REPO,
                    "commit": PIN,
                    "purpose": "Read-only pinned source inputs; raw files excluded from distributions",
                    "files": rows,
                },
                indent=2,
            )
            + "\n"
        ).encode()
    )
    return {
        "files": len(rows),
        "downloaded": downloaded,
        "reused": len(rows) - downloaded,
    }


def att_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog)
    parser.add_argument(
        "--source-root", type=Path, default=ROOT / ".work/catalog-cache/att-source"
    )
    parser.add_argument(
        "--compiled-root", type=Path, default=ROOT / ".work/catalog-cache/att-generated"
    )
    parser.add_argument("--revision", default=PIN)
    parser.add_argument("--plan-only", action="store_true")
    args = parser.parse_args(argv)
    if args.revision != PIN:
        raise ValueError(
            "A new ATT revision requires reviewed parser/build contracts and a pin update"
        )
    authored_tree = subtree(PREFIX.rstrip("/"), PIN)
    compiled_tree = subtree("db/Camelot", PIN)
    authored = [
        row
        for row in authored_tree
        if row["path"].endswith(".lua") or row["path"].endswith("forever.config")
    ]
    support = [
        "LICENSE",
        ".contrib/.db/shared/constants/raceIDs.lua",
        ".contrib/.db/shared/constants/classIDs.lua",
        ".contrib/.db/shared/constants/lvl.lua",
        ".contrib/.db/shared/functions/Shortcuts.lua",
        ".contrib/.db/shared/.config/root.config",
        ".contrib/.db/shared/.main.lua",
        ".contrib/.db/build - forever.bat",
        ".contrib/.db/standard/.config/retail/retail.config",
        "src/Classes/Quests.lua",
        "src/Classes/base.lua",
        "src/base.lua",
    ]
    authored.extend({"path": path} for path in support)
    compiled = [
        row
        for row in compiled_tree
        if row["path"].endswith(".lua") or row["path"].endswith("Database.xml")
    ]
    compiled.extend(
        {"path": path}
        for path in (
            "LICENSE",
            ".contrib/.db/forever/.config/forever.config",
            ".contrib/.db/shared/.config/root.config",
            ".contrib/.db/build - forever.bat",
            ".contrib/.db/standard/.config/retail/retail.config",
        )
    )
    if args.plan_only:
        print(
            json.dumps(
                {
                    "revision": PIN,
                    "authoringPaths": [row["path"] for row in authored],
                    "compiledPaths": [row["path"] for row in compiled],
                },
                indent=2,
            )
        )
        return
    print(
        json.dumps(
            {
                "revision": PIN,
                "authoring": acquire(args.source_root, authored),
                "compiled": acquire(args.compiled_root, compiled),
            },
            indent=2,
        )
    )


# Collect catalog sources.

ORIGIN = "https://www.forevervsclassic.com"
PUBLIC_AGENT = "GPTBot (FindAnUpgrade public factual data collector)"


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


class Collector:
    def __init__(
        self, root, reuse=None, refresh=False, max_age_hours=24, refresh_keys=()
    ):
        if not math.isfinite(max_age_hours) or max_age_hours < 0:
            raise ValueError("Cache age must be finite and nonnegative")
        self.root, self.reuse = root, reuse
        self.refresh, self.max_age_hours = refresh, max_age_hours
        self.refresh_keys = {str(key) for key in refresh_keys}
        self.lock, self.next_request, self.stop = threading.Lock(), 0, False
        self.rows = {}
        self.previous = {}
        for name, folder in (
            ("index-manifest.json", "index"),
            ("quest-manifest.json", "quests"),
        ):
            path = root / name
            if path.exists():
                manifest = json.loads(path.read_bytes())
                for row in manifest.get("sources", []):
                    self.previous[(folder, str(row["key"]))] = dict(
                        row, checkedAt=row.get("checkedAt", manifest.get("collectedAt"))
                    )
        request = Request(ORIGIN + "/robots.txt", headers={"User-Agent": PUBLIC_AGENT})
        with urlopen(request, timeout=30) as response:
            raw = response.read()
        self.policy = RobotFileParser(ORIGIN + "/robots.txt")
        self.policy.parse(raw.decode("utf-8").splitlines())
        save(
            root / "robots.json",
            {
                "url": ORIGIN + "/robots.txt",
                "sha256": hashlib.sha256(raw).hexdigest(),
                "body": raw.decode("utf-8"),
            },
        )
        self.delay = max(0.3, self.policy.crawl_delay("GPTBot") or 0)

    def get(self, key, url, folder):
        parts = urlsplit(url)
        if folder not in ("index", "quests") or not re.fullmatch(
            r"[A-Za-z0-9_-]+", str(key)
        ):
            raise ValueError("Unsafe cache key")
        if (
            parts.netloc != "www.forevervsclassic.com"
            or parts.scheme != "https"
            or not (
                parts.path == "/quests" or re.fullmatch(r"/quests/[1-9]\d*", parts.path)
            )
        ):
            raise ValueError("URL outside reviewed public quest scope")
        if not self.policy.can_fetch("GPTBot", url):
            raise ValueError("Public robots policy denies " + url)
        destination = self.root / folder / (str(key) + ".html")
        receipt_path = self.root / ".receipts" / folder / (str(key) + ".json")
        previous = (
            json.loads(receipt_path.read_bytes())
            if receipt_path.exists()
            else self.previous.get((folder, str(key)), {})
        )
        raw = destination.read_bytes() if destination.exists() else None
        if (
            raw is not None
            and previous
            and (
                previous.get("url") != url
                or hashlib.sha256(raw).hexdigest() != previous.get("sha256")
            )
        ):
            raise ValueError("Cached source receipt/hash changed: " + str(destination))
        checked_at = previous.get("checkedAt")
        age = None
        if checked_at:
            age = (
                datetime.now(UTC) - datetime.fromisoformat(checked_at)
            ).total_seconds() / 3600
        fresh = bool(previous and age is not None and 0 <= age <= self.max_age_hours)
        headers = {"User-Agent": PUBLIC_AGENT}
        for name, header in (
            ("etag", "If-None-Match"),
            ("lastModified", "If-Modified-Since"),
        ):
            if raw is not None and previous.get(name):
                headers[header] = previous[name]
        response_headers = {}
        force = self.refresh or str(key) in self.refresh_keys
        if raw is not None and fresh and not force:
            cached = True
        elif (
            raw is None
            and self.reuse
            and folder == "quests"
            and (self.reuse / (str(key) + ".html")).exists()
            and not force
        ):
            raw, cached = (self.reuse / (str(key) + ".html")).read_bytes(), True
            checked_at = datetime.now(UTC).isoformat()
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
        else:
            if self.stop:
                raise RuntimeError(
                    "Collection stopped after a server access/rate restriction"
                )
            with self.lock:
                pause = max(0, self.next_request - time.monotonic())
                self.next_request = (
                    max(self.next_request, time.monotonic()) + self.delay
                )
            if pause:
                time.sleep(pause)
            if self.stop:
                raise RuntimeError(
                    "Collection stopped after a server access/rate restriction"
                )
            try:
                request = Request(url, headers=headers)
                with urlopen(request, timeout=30) as response:
                    if urlsplit(response.url).netloc != parts.netloc:
                        raise ValueError("Unexpected cross-domain redirect")
                    raw = response.read()
                    response_headers = {
                        key.lower(): value for key, value in response.headers.items()
                    }
            except HTTPError as error:
                if error.code in (401, 403, 429):
                    self.stop = True
                if error.code == 304 and raw is not None and previous:
                    response_headers = {
                        key.lower(): value for key, value in error.headers.items()
                    }
                    error.close()
                else:
                    raise
            if any(
                value in raw.lower()
                for value in (
                    b"verify that you're not a robot",
                    b"just a moment...",
                    b"cf-chl-",
                    b"captcha",
                )
            ):
                self.stop = True
                raise ValueError(
                    "Verification challenge; collection stopped without bypass"
                )
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
            cached = False
            checked_at = datetime.now(UTC).isoformat()
        row = {
            "key": key,
            "url": url,
            "file": destination.relative_to(self.root).as_posix(),
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "cached": cached,
            "state": "collected",
        }
        row["checkedAt"] = checked_at
        for name, header in (("etag", "ETag"), ("lastModified", "Last-Modified")):
            value = response_headers.get(header.lower()) or previous.get(name)
            if value:
                row[name] = value
        save(receipt_path, row)
        self.rows[str(key)] = row
        return raw

    def batch(self, jobs, folder):
        results, errors = {}, []
        with ThreadPoolExecutor(max_workers=4) as pool:
            pending = {
                pool.submit(self.get, key, url, folder): key for key, url in jobs
            }
            for future in as_completed(pending):
                key = pending[future]
                try:
                    results[key] = future.result()
                except Exception as error:
                    row = {
                        "key": key,
                        "state": "unavailable",
                        "error": str(error),
                        "checkedAt": datetime.now(UTC).isoformat(),
                    }
                    if isinstance(error, HTTPError):
                        row.update(httpStatus=error.code, url=error.url)
                    errors.append(row)
                if (len(results) + len(errors)) % 100 == 0:
                    print(
                        json.dumps(
                            {
                                "folder": folder,
                                "done": len(results) + len(errors),
                                "total": len(jobs),
                                "errors": len(errors),
                            }
                        ),
                        flush=True,
                    )
        return results, errors


def public_main(argv=None, *, prog=None):
    parser = argparse.ArgumentParser(prog=prog)
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--reuse-quest-cache", type=Path)
    parser.add_argument(
        "--mode", choices=("index", "quests", "candidates"), required=True
    )
    parser.add_argument(
        "--candidate-ids",
        type=Path,
        help="Owned JSON questIDs to check outside the current public index",
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Revalidate cached pages, using HTTP validators when supplied",
    )
    parser.add_argument("--max-age-hours", type=float, default=24)
    args = parser.parse_args(argv)
    if args.max_age_hours < 0:
        raise ValueError("Cache age must be nonnegative")
    previous_path = args.source_root / "index-manifest.json"
    previous_index = (
        json.loads(previous_path.read_bytes()) if previous_path.exists() else {}
    )
    # Migrate a receipted old cache without refetching every unchanged detail.
    if (
        args.mode == "index"
        and previous_index
        and "rowFingerprints" not in previous_index
    ):
        old = {}
        for receipt in previous_index.get("sources", []):
            path = (args.source_root / receipt["file"]).resolve()
            if not path.is_relative_to(args.source_root.resolve()):
                raise ValueError("Unsafe old index path")
            raw = path.read_bytes()
            if hashlib.sha256(raw).hexdigest() != receipt["sha256"]:
                raise ValueError("Old index cache hash changed")
            old.update(
                {
                    str(key): value
                    for key, value in quest_index_fingerprints(
                        raw.decode("utf-8")
                    ).items()
                }
            )
        previous_index["rowFingerprints"] = old
    collector = Collector(
        args.source_root,
        args.reuse_quest_cache,
        args.refresh,
        args.max_age_hours,
        previous_index.get("changedIDs", []) if args.mode == "quests" else (),
    )
    if args.mode == "index":
        first = collector.get(1, ORIGIN + "/quests?status=any&all=1", "index")
        expected, ids = quest_index(first.decode("utf-8"))
        pages = math.ceil(expected / 50)
        results, errors = collector.batch(
            [
                (page, ORIGIN + "/quests?status=any&all=1&page=" + str(page))
                for page in range(2, pages + 1)
            ],
            "index",
        )
        universe = set(ids)
        titles = quest_index_titles(first.decode("utf-8"))
        fingerprints = quest_index_fingerprints(first.decode("utf-8"))

        def track(raw):
            incoming = quest_index_fingerprints(raw.decode("utf-8"))
            for quest, fingerprint in incoming.items():
                if quest in fingerprints and fingerprints[quest] != fingerprint:
                    raise ValueError(
                        "Public row changed during collection: " + str(quest)
                    )
                fingerprints[quest] = fingerprint

        repeated = set()
        for page, raw in sorted(results.items()):
            count, found = quest_index(raw.decode("utf-8"))
            if count != expected:
                raise ValueError("Public index changed during collection")
            repeated.update(universe.intersection(found))
            universe.update(found)
            titles.update(quest_index_titles(raw.decode("utf-8")))
            track(raw)
        # Equal level/title rows can straddle an unstable public pagination
        # boundary. Reconcile those names through the site's visible name filter.
        repairs = []
        for title in sorted({titles[quest] for quest in repeated}):
            number = hashlib.sha256(title.encode()).hexdigest()[:16]
            query = {"status": "any", "all": 1, "q": title}
            url = ORIGIN + "/quests?" + urlencode(query)
            raw = collector.get("repair-" + number + "-1", url, "index")
            total, found = quest_index(raw.decode("utf-8"))
            track(raw)
            recovered = set(found)
            for page in range(2, math.ceil(total / 50) + 1):
                query["page"] = page
                raw = collector.get(
                    "repair-" + str(number) + "-" + str(page),
                    ORIGIN + "/quests?" + urlencode(query),
                    "index",
                )
                count, found = quest_index(raw.decode("utf-8"))
                track(raw)
                if count != total:
                    raise ValueError("Public filtered index changed during collection")
                recovered.update(found)
            repairs.append(
                {
                    "query": title,
                    "expected": total,
                    "uniqueIDs": len(recovered),
                    "addedIDs": sorted(recovered - universe),
                }
            )
            universe.update(recovered)
        report = {
            "schemaVersion": 1,
            "collectedAt": datetime.now(UTC).isoformat(),
            "source": ORIGIN + "/quests?status=any&all=1",
            "scope": "All public quest results, all categories/levels/factions, including test entries; an index ID alone does not prove current Forever availability",
            "expected": expected,
            "pagesExpected": pages,
            "pagesCollected": len(results) + 1,
            "distinctQuestIDs": len(universe),
            "paginationRepairs": repairs,
            "questIDs": sorted(universe),
            "sources": sorted(collector.rows.values(), key=lambda row: str(row["key"])),
            "errors": errors,
            "complete": not errors and len(universe) == expected,
        }
        old_fingerprints = previous_index.get("rowFingerprints", {})
        changed = {
            key
            for key, value in fingerprints.items()
            if old_fingerprints.get(str(key)) != value
        }
        changed.update(set(previous_index.get("changedIDs", [])) & universe)
        report.update(
            rowFingerprints={
                str(key): value for key, value in sorted(fingerprints.items())
            },
            changedIDs=sorted(changed),
            newIDs=sorted(universe - set(previous_index.get("questIDs", []))),
            removedIDs=sorted(set(previous_index.get("questIDs", [])) - universe),
        )
        save(args.source_root / "index-manifest.json", report)
        print(
            json.dumps(
                {
                    key: value
                    for key, value in report.items()
                    if key not in ("questIDs", "sources")
                },
                indent=2,
            )
        )
        if not report["complete"]:
            raise SystemExit(1)
    elif args.mode == "quests":
        index = json.loads((args.source_root / "index-manifest.json").read_bytes())
        if not index["complete"]:
            raise ValueError(
                "Complete reconciled index required before detail collection"
            )
        results, errors = collector.batch(
            [(quest, ORIGIN + "/quests/" + str(quest)) for quest in index["questIDs"]],
            "quests",
        )
        report = {
            "schemaVersion": 1,
            "collectedAt": datetime.now(UTC).isoformat(),
            "source": ORIGIN,
            "expected": len(index["questIDs"]),
            "collected": len(results),
            "sources": sorted(collector.rows.values(), key=lambda row: row["key"]),
            "errors": errors,
            "complete": not errors and len(results) == len(index["questIDs"]),
        }
        save(args.source_root / "quest-manifest.json", report)
        if report["complete"]:
            if (
                json.loads((args.source_root / "index-manifest.json").read_bytes())
                != index
            ):
                raise ValueError("Index changed concurrently with detail collection")
            index["changedIDs"] = []
            save(args.source_root / "index-manifest.json", index)
        print(
            json.dumps(
                {key: value for key, value in report.items() if key != "sources"},
                indent=2,
            )
        )
        if not report["complete"]:
            raise SystemExit(1)
    else:
        if not args.candidate_ids:
            raise ValueError("Candidate IDs file required")
        ids = json.loads(args.candidate_ids.read_bytes())["questIDs"]
        if len(ids) != len(set(ids)) or any(
            type(quest) is not int or not 0 < quest < 2**31 for quest in ids
        ):
            raise ValueError("Invalid candidate IDs")
        index = json.loads((args.source_root / "index-manifest.json").read_bytes())
        if not index["complete"]:
            raise ValueError("Complete public index required")
        ids = sorted(set(ids) - set(index["questIDs"]))
        results, errors = collector.batch(
            [(quest, ORIGIN + "/quests/" + str(quest)) for quest in ids], "quests"
        )
        complete = all(row.get("httpStatus") in (404, 410) for row in errors)
        report = {
            "collectedAt": datetime.now(UTC).isoformat(),
            "requestedIDs": ids,
            "sources": sorted(collector.rows.values(), key=lambda row: row["key"]),
            "errors": errors,
            "complete": complete,
        }
        save(args.source_root / "candidate-manifest.json", report)
        print(
            json.dumps(
                {
                    "candidates": len(ids),
                    "pages": len(results),
                    "explicitlyAbsent": len(errors),
                    "complete": complete,
                }
            )
        )
        if not complete:
            raise SystemExit(1)
