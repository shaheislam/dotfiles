#!/usr/bin/env python3
"""
dump-history.py — read Firefox places.sqlite (read-only/immutable) and
print frecency-ranked host stats. Used by `build-import.py` for the
pinning helper, and standalone when you want to refresh your YAML
seeding manually after months of usage.

Usage:
  ./dump-history.py                # human-readable table, top 50
  ./dump-history.py --json         # JSON output for piping
  ./dump-history.py --days 180     # change window
  ./dump-history.py --limit 200    # change row count

Cross-device note:
  Firefox Sync's history engine is opt-in. If you enable it
  (about:preferences#sync → History), places.sqlite on this device
  will eventually merge in remote visits — there's no separate
  per-device DB to consult. So this script's output is always
  "whatever Firefox has locally" — single-device or merged.
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import time
import urllib.parse
from collections import defaultdict
from pathlib import Path


COUNTRY_TLDS = {"uk", "jp", "au", "nz", "in", "za"}
SECOND_LEVEL_PUBLIC = {"co", "org", "ac", "gov", "net"}


def find_places_db() -> Path | None:
    base = Path.home() / "Library/Application Support/Firefox/Profiles"
    if not base.is_dir():
        return None
    for prof in sorted(base.iterdir(), key=lambda p: p.stat().st_mtime, reverse=True):
        db = prof / "places.sqlite"
        if db.is_file():
            return db
    return None


def etld_plus_one(host: str) -> str:
    parts = host.lower().split(":")[0].split(".")
    if len(parts) >= 3 and parts[-2] in SECOND_LEVEL_PUBLIC and parts[-1] in COUNTRY_TLDS:
        return ".".join(parts[-3:])
    return ".".join(parts[-2:]) if len(parts) >= 2 else host


def host_frecency(days: int = 365, limit: int = 2000) -> list[tuple[str, int]]:
    """Return [(host_etld1, max_frecency), ...] sorted desc."""
    db = find_places_db()
    if db is None:
        return []
    cutoff_us = int((time.time() - days * 86400) * 1_000_000)
    con = sqlite3.connect(f"file:{db}?mode=ro&immutable=1", uri=True)
    cur = con.cursor()
    cur.execute(
        """SELECT url, visit_count, frecency
           FROM moz_places
           WHERE hidden=0 AND url LIKE 'http%' AND last_visit_date > ?
           ORDER BY frecency DESC LIMIT ?""",
        (cutoff_us, limit),
    )
    hosts: dict[str, dict[str, int]] = defaultdict(lambda: {"visits": 0, "frecency": 0})
    for url, vc, fr in cur.fetchall():
        try:
            netloc = urllib.parse.urlparse(url).netloc
        except ValueError:
            continue
        if not netloc:
            continue
        h = etld_plus_one(netloc)
        hosts[h]["visits"] += vc or 0
        hosts[h]["frecency"] = max(hosts[h]["frecency"], fr or 0)
    return sorted(((h, d["frecency"]) for h, d in hosts.items()), key=lambda x: -x[1])


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=365)
    ap.add_argument("--limit", type=int, default=50)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    rows = host_frecency(days=args.days, limit=2000)[: args.limit]
    if not rows:
        print("no history found (places.sqlite missing?)", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps([{"host": h, "frecency": f} for h, f in rows], indent=2))
    else:
        for h, f in rows:
            print(f"  {h:<40} frecency={f}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
