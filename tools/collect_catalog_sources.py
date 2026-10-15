"""Acquire allowed public HTML, preserving hashes, failures and full index scope.

No API/search endpoint, embedded JavaScript execution, challenge workaround,
proxy, private endpoint or Wowhead request is made by this collector.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlsplit, urlencode
from urllib.request import Request, urlopen
from urllib.robotparser import RobotFileParser
import argparse
import hashlib
import json
import math
import threading
import time

from catalog_html import quest_index, quest_index_titles

ORIGIN = "https://www.forevervsclassic.com"
AGENT = "GPTBot (QuestBrief public factual data collector)"


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2)+"\n", encoding="utf-8")


class Collector:
    def __init__(self, root, reuse=None):
        self.root, self.reuse = root, reuse
        self.lock, self.next_request, self.stop = threading.Lock(), 0, False
        self.rows = {}
        request = Request(ORIGIN+"/robots.txt", headers={"User-Agent": AGENT})
        with urlopen(request, timeout=30) as response:
            raw = response.read()
        self.policy = RobotFileParser(ORIGIN+"/robots.txt")
        self.policy.parse(raw.decode("utf-8").splitlines())
        save(root/"robots.json", {"url": ORIGIN+"/robots.txt", "sha256": hashlib.sha256(raw).hexdigest(), "body": raw.decode("utf-8")})
        self.delay = max(.3, self.policy.crawl_delay("GPTBot") or 0)

    def get(self, key, url, folder):
        parts = urlsplit(url)
        if parts.netloc != "www.forevervsclassic.com" or parts.scheme != "https" or not parts.path.startswith("/quests"):
            raise ValueError("URL outside reviewed public quest scope")
        if not self.policy.can_fetch("GPTBot", url):
            raise ValueError("Public robots policy denies "+url)
        destination = self.root/folder/(str(key)+".html")
        if destination.exists():
            raw, cached = destination.read_bytes(), True
        elif self.reuse and folder == "quests" and (self.reuse/(str(key)+".html")).exists():
            raw, cached = (self.reuse/(str(key)+".html")).read_bytes(), True
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
        else:
            if self.stop:
                raise RuntimeError("Collection stopped after a server access/rate restriction")
            with self.lock:
                pause = max(0, self.next_request-time.monotonic())
                self.next_request = max(self.next_request, time.monotonic())+self.delay
            if pause:
                time.sleep(pause)
            if self.stop:
                raise RuntimeError("Collection stopped after a server access/rate restriction")
            try:
                request = Request(url, headers={"User-Agent": AGENT})
                with urlopen(request, timeout=30) as response:
                    if urlsplit(response.url).netloc != parts.netloc:
                        raise ValueError("Unexpected cross-domain redirect")
                    raw = response.read()
            except HTTPError as error:
                if error.code in (401, 403, 429):
                    self.stop = True
                raise
            if any(value in raw.lower() for value in (b"verify that you're not a robot", b"just a moment...", b"cf-chl-", b"captcha")):
                self.stop = True
                raise ValueError("Verification challenge; collection stopped without bypass")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(raw)
            cached = False
        row = {"key": key, "url": url, "file": destination.relative_to(self.root).as_posix(), "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest(), "cached": cached, "state": "collected"}
        self.rows[str(key)] = row
        return raw

    def batch(self, jobs, folder):
        results, errors = {}, []
        with ThreadPoolExecutor(max_workers=4) as pool:
            pending = {pool.submit(self.get, key, url, folder): key for key, url in jobs}
            for future in as_completed(pending):
                key = pending[future]
                try:
                    results[key] = future.result()
                except Exception as error:
                    errors.append({"key": key, "state": "unavailable", "error": str(error)})
                if (len(results)+len(errors)) % 100 == 0:
                    print(json.dumps({"folder": folder, "done": len(results)+len(errors), "total": len(jobs), "errors": len(errors)}), flush=True)
        return results, errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--reuse-quest-cache", type=Path)
    parser.add_argument("--mode", choices=("index", "quests"), required=True)
    args = parser.parse_args()
    collector = Collector(args.source_root, args.reuse_quest_cache)
    if args.mode == "index":
        first = collector.get(1, ORIGIN+"/quests?status=any&all=1", "index")
        expected, ids = quest_index(first.decode("utf-8"))
        pages = math.ceil(expected/50)
        results, errors = collector.batch([(page, ORIGIN+"/quests?status=any&all=1&page="+str(page)) for page in range(2, pages+1)], "index")
        universe = set(ids)
        titles = quest_index_titles(first.decode("utf-8"))
        repeated = set()
        for page, raw in sorted(results.items()):
            count, found = quest_index(raw.decode("utf-8"))
            if count != expected:
                raise ValueError("Public index changed during collection")
            repeated.update(universe.intersection(found))
            universe.update(found)
            titles.update(quest_index_titles(raw.decode("utf-8")))
        # Equal level/title rows can straddle an unstable public pagination
        # boundary. Reconcile those names through the site's visible name filter.
        repairs = []
        for number, title in enumerate(sorted({titles[quest] for quest in repeated}), 1):
            query = {"status": "any", "all": 1, "q": title}
            url = ORIGIN+"/quests?"+urlencode(query)
            raw = collector.get("repair-"+str(number)+"-1", url, "index")
            total, found = quest_index(raw.decode("utf-8"))
            recovered = set(found)
            for page in range(2, math.ceil(total/50)+1):
                query["page"] = page
                raw = collector.get("repair-"+str(number)+"-"+str(page), ORIGIN+"/quests?"+urlencode(query), "index")
                count, found = quest_index(raw.decode("utf-8"))
                if count != total:
                    raise ValueError("Public filtered index changed during collection")
                recovered.update(found)
            repairs.append({"query": title, "expected": total, "uniqueIDs": len(recovered), "addedIDs": sorted(recovered-universe)})
            universe.update(recovered)
        report = {"schemaVersion": 1, "collectedAt": datetime.now(timezone.utc).isoformat(), "source": ORIGIN+"/quests?status=any&all=1", "scope": "All public quest results, all categories/levels/factions, including test entries; an index ID alone does not prove current Forever availability", "expected": expected, "pagesExpected": pages, "pagesCollected": len(results)+1, "distinctQuestIDs": len(universe), "paginationRepairs": repairs, "questIDs": sorted(universe), "sources": sorted(collector.rows.values(), key=lambda row: str(row["key"])), "errors": errors, "complete": not errors and len(universe) == expected}
        save(args.source_root/"index-manifest.json", report)
        print(json.dumps({key: value for key, value in report.items() if key not in ("questIDs", "sources")}, indent=2))
        if not report["complete"]:
            raise SystemExit(1)
    else:
        index = json.loads((args.source_root/"index-manifest.json").read_bytes())
        if not index["complete"]:
            raise ValueError("Complete reconciled index required before detail collection")
        results, errors = collector.batch([(quest, ORIGIN+"/quests/"+str(quest)) for quest in index["questIDs"]], "quests")
        report = {"schemaVersion": 1, "collectedAt": datetime.now(timezone.utc).isoformat(), "source": ORIGIN, "expected": len(index["questIDs"]), "collected": len(results), "sources": sorted(collector.rows.values(), key=lambda row: row["key"]), "errors": errors, "complete": not errors and len(results) == len(index["questIDs"])}
        save(args.source_root/"quest-manifest.json", report)
        print(json.dumps({key: value for key, value in report.items() if key != "sources"}, indent=2))
        if not report["complete"]:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
