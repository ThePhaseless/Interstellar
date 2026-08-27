"""Search every movie/series one at a time, refusing to advance while any
Prowlarr indexer is in failure backoff."""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

PROWLARR = os.environ["PROWLARR_URL"].rstrip("/")
PROWLARR_KEY = os.environ["PROWLARR_API_KEY"]
APP = os.environ.get("APP", "radarr")
APP_URL = os.environ["APP_URL"].rstrip("/")
APP_KEY = os.environ["APP_API_KEY"]
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() != "false"
MAX_WAIT = int(os.environ.get("MAX_BACKOFF_WAIT_SECONDS", "3600"))
ITEM_DELAY = float(os.environ.get("ITEM_DELAY_SECONDS", "5"))
ONLY_IDS = [int(x) for x in os.environ.get("ONLY_IDS", "").replace(",", " ").split()]

APPS = {
    "radarr": ("movie", lambda i: {"name": "MoviesSearch", "movieIds": [i]}),
    "sonarr": ("series", lambda i: {"name": "SeriesSearch", "seriesId": i}),
}
ENTITY, SEARCH_PAYLOAD = APPS[APP]

# Sonarr's interactive-search endpoint needs a season or episode, so there is no
# series-wide equivalent of Radarr's non-grabbing release lookup.
if DRY_RUN and APP != "radarr":
    sys.exit(f"DRY_RUN is only supported for radarr, not {APP}; set DRY_RUN=false")

_status_shape_logged = False


def log(msg):
    print(f"{datetime.now(timezone.utc):%H:%M:%S} | {msg}", flush=True)


def api(base, key, path, method="GET", body=None, timeout=600):
    url = f"{base}/{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("X-Api-Key", key)
    if data:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
    return json.loads(raw) if raw else None


def failing_indexers():
    """Prowlarr records a status row on the first failure, so a non-empty list
    means at least one indexer is currently backed off."""
    global _status_shape_logged
    rows = api(PROWLARR, PROWLARR_KEY, "api/v1/indexerstatus", timeout=30) or []
    if rows and not _status_shape_logged:
        log(f"indexerstatus record shape: {json.dumps(rows[0])}")
        _status_shape_logged = True
    return rows


def backoff_deadline(rows):
    stamps = []
    for r in rows:
        till = r.get("disabledTill")
        if not till:
            continue
        stamps.append(datetime.fromisoformat(till.replace("Z", "+00:00")))
    return max(stamps) if stamps else None


def wait_for_healthy():
    """Returns False when the backoff outlasts MAX_WAIT, leaving the caller to
    record incomplete coverage rather than stall the whole run."""
    while True:
        rows = failing_indexers()
        if not rows:
            return True
        deadline = backoff_deadline(rows)
        if deadline is None:
            log("  indexers failing with no disabledTill; waiting 60s")
            time.sleep(60)
            continue
        seconds = (deadline - datetime.now(timezone.utc)).total_seconds()
        if seconds <= 0:
            time.sleep(5)
            continue
        ids = sorted({r.get("indexerId") for r in rows})
        if seconds > MAX_WAIT:
            log(f"  indexers {ids} backed off {seconds:.0f}s (> {MAX_WAIT}s cap)")
            return False
        log(f"  indexers {ids} backed off; waiting {seconds:.0f}s")
        time.sleep(seconds + 5)


def await_command(command_id):
    while True:
        cmd = api(APP_URL, APP_KEY, f"api/v3/command/{command_id}", timeout=60)
        if cmd["status"] in ("completed", "failed", "aborted"):
            return cmd["status"]
        time.sleep(3)


def search(item_id):
    if DRY_RUN:
        params = urllib.parse.urlencode({"movieId": item_id})
        releases = api(APP_URL, APP_KEY, f"api/v3/release?{params}") or []
        approved = [r for r in releases if not r.get("rejected")]
        best = max(approved, key=lambda r: r.get("customFormatScore", 0), default=None)
        detail = f"{len(releases)} releases, {len(approved)} approved"
        if best:
            detail += f", best {best.get('customFormatScore')} {best.get('title', '')[:60]}"
        return detail
    cmd = api(APP_URL, APP_KEY, "api/v3/command", "POST", SEARCH_PAYLOAD(item_id))
    return f"command {await_command(cmd['id'])}"


def main():
    items = api(APP_URL, APP_KEY, f"api/v3/{ENTITY}")
    if ONLY_IDS:
        items = [i for i in items if i["id"] in ONLY_IDS]
    items.sort(key=lambda i: i.get("sortTitle") or i.get("title", ""))
    log(f"{APP}: {len(items)} items | dry_run={DRY_RUN} | backoff cap={MAX_WAIT}s")

    covered, incomplete = [], []
    for n, item in enumerate(items, 1):
        title = item.get("title", "?")[:55]
        while True:
            if not wait_for_healthy():
                incomplete.append(title)
                log(f"[{n}/{len(items)}] SKIPPED (backoff over cap): {title}")
                break
            try:
                detail = search(item["id"])
            except (urllib.error.URLError, TimeoutError) as exc:
                log(f"[{n}/{len(items)}] search error, retrying: {title} ({exc})")
                time.sleep(30)
                continue
            if failing_indexers():
                log(f"[{n}/{len(items)}] indexer failed mid-search, retrying: {title}")
                continue
            covered.append(title)
            log(f"[{n}/{len(items)}] ok: {title} | {detail}")
            break
        time.sleep(ITEM_DELAY)

    log(f"done | full coverage: {len(covered)} | incomplete: {len(incomplete)}")
    for t in incomplete:
        log(f"  incomplete: {t}")
    return 1 if incomplete else 0


if __name__ == "__main__":
    sys.exit(main())
