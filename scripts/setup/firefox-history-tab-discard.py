#!/usr/bin/env python3
"""Recommend Auto Tab Discard policy from Firefox history.

The default output is intentionally hostname-only. It reads Firefox's
places.sqlite database read-only, aggregates visits by hostname, and emits a
reviewable policy fragment rather than modifying dotfiles automatically.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sqlite3
import sys
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


AUTO_TAB_DISCARD_ID = "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}"
FIREFOX_EPOCH_FACTOR = 1_000_000

WORK_APP_RULES: dict[str, tuple[str, ...]] = {
    "github.com": ("*://github.com/*", "*://*.github.com/*"),
    "gitlab.com": ("*://gitlab.com/*", "*://*.gitlab.com/*"),
    "bitbucket.org": ("*://bitbucket.org/*", "*://*.bitbucket.org/*"),
    "atlassian.net": ("*://*.atlassian.net/*",),
    "slack.com": ("*://app.slack.com/*", "*://*.slack.com/*"),
    "teams.microsoft.com": ("*://teams.microsoft.com/*",),
    "meet.google.com": ("*://meet.google.com/*",),
    "zoom.us": ("*://*.zoom.us/*",),
    "linear.app": ("*://linear.app/*", "*://*.linear.app/*"),
    "notion.so": ("*://notion.so/*", "*://*.notion.so/*"),
    "figma.com": ("*://figma.com/*", "*://*.figma.com/*"),
    "miro.com": ("*://miro.com/*", "*://*.miro.com/*"),
    "docs.google.com": ("*://docs.google.com/*",),
    "calendar.google.com": ("*://calendar.google.com/*",),
    "mail.google.com": ("*://mail.google.com/*",),
    "console.aws.amazon.com": ("*://console.aws.amazon.com/*",),
    "signin.aws.amazon.com": ("*://signin.aws.amazon.com/*",),
    "awsapps.com": ("*://*.awsapps.com/*",),
}

BASE_POLICY: dict[str, object] = {
    "period": 3600,
    "number": 8,
    "audio": True,
    "pinned": True,
    "form": True,
    "online": True,
    "mode": "time-based",
    "memory-enabled": False,
    "simultaneous-jobs": 1,
    "trash.enabled": False,
    "startup-unpinned": False,
    "startup-pinned": False,
}

DEFAULT_POLICY_JSON = Path(__file__).resolve().parent / "firefox/policies.json"


@dataclass
class HostStats:
    visits: int = 0
    urls: int = 0
    frecency: int = 0
    last_visit: int = 0


def resolve_profile_path(firefox_root: Path, profile_ref: str) -> Path:
    profile_path = Path(profile_ref)
    if profile_path.is_absolute():
        return profile_path
    return firefox_root / profile_path


def find_default_profile(firefox_root: Path) -> Path:
    profiles_ini = firefox_root / "profiles.ini"
    if not profiles_ini.is_file():
        raise FileNotFoundError(f"Firefox profiles.ini not found: {profiles_ini}")

    section = ""
    path = ""
    is_relative = "1"
    is_default = "0"
    install_default = ""
    profile_default: tuple[str, str] | None = None
    first_profile: tuple[str, str] | None = None

    def commit_profile_section() -> None:
        nonlocal first_profile, profile_default
        if not section.startswith("Profile") or not path:
            return
        if first_profile is None:
            first_profile = (path, is_relative)
        if is_default == "1":
            profile_default = (path, is_relative)

    with profiles_ini.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n").rstrip("\r")
            if not line or line.startswith(("#", ";")):
                continue
            if line.startswith("[") and line.endswith("]"):
                commit_profile_section()
                section = line[1:-1]
                path = ""
                is_relative = "1"
                is_default = "0"
                continue

            key, sep, value = line.partition("=")
            if not sep:
                continue
            if section.startswith("Install") and key == "Default":
                install_default = value
            elif section.startswith("Profile"):
                if key == "Path":
                    path = value
                elif key == "IsRelative":
                    is_relative = value
                elif key == "Default" and value == "1":
                    is_default = "1"

    commit_profile_section()

    if install_default:
        return resolve_profile_path(firefox_root, install_default)
    if profile_default:
        path, relative = profile_default
        return resolve_profile_path(firefox_root, path) if relative == "1" else Path(path)
    if first_profile:
        path, relative = first_profile
        return resolve_profile_path(firefox_root, path) if relative == "1" else Path(path)

    raise FileNotFoundError(f"No Firefox profiles found in {profiles_ini}")


def normalize_hostname(url: str) -> str:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        return ""
    hostname = parsed.hostname.lower().strip(".")
    if hostname.startswith("www."):
        hostname = hostname[4:]
    return hostname


def copy_history_database(places: Path) -> Path:
    tmp_dir = Path(tempfile.mkdtemp(prefix="firefox-history-"))
    tmp_places = tmp_dir / "places.sqlite"
    shutil.copy2(places, tmp_places)
    return tmp_places


def read_history(profile: Path, days: int) -> dict[str, HostStats]:
    places = profile / "places.sqlite"
    if not places.is_file():
        raise FileNotFoundError(f"Firefox history database not found: {places}")

    tmp_places = copy_history_database(places)
    try:
        cutoff = int((time.time() - days * 24 * 60 * 60) * FIREFOX_EPOCH_FACTOR)
        stats: dict[str, HostStats] = {}
        with sqlite3.connect(f"file:{tmp_places}?mode=ro", uri=True) as conn:
            rows = conn.execute(
                """
                SELECT url, visit_count, frecency, COALESCE(last_visit_date, 0)
                FROM moz_places
                WHERE last_visit_date >= ?
                  AND (url LIKE 'http://%' OR url LIKE 'https://%')
                """,
                (cutoff,),
            )
            for url, visit_count, frecency, last_visit in rows:
                hostname = normalize_hostname(str(url))
                if not hostname:
                    continue
                current = stats.setdefault(hostname, HostStats())
                current.visits += int(visit_count or 0)
                current.urls += 1
                current.frecency += int(frecency or 0)
                current.last_visit = max(current.last_visit, int(last_visit or 0))
        return stats
    finally:
        shutil.rmtree(tmp_places.parent)


def matching_work_rules(hostname: str) -> tuple[str, ...]:
    matches: list[str] = []
    for suffix, rules in WORK_APP_RULES.items():
        if hostname == suffix or hostname.endswith(f".{suffix}"):
            matches.extend(rules)
    return tuple(matches)


def recommend_whitelist(stats: dict[str, HostStats], min_visits: int) -> list[str]:
    rules: list[str] = []
    seen: set[str] = set()
    ranked_hosts = sorted(
        stats.items(),
        key=lambda item: (item[1].visits, item[1].frecency, item[1].last_visit),
        reverse=True,
    )
    for hostname, host_stats in ranked_hosts:
        if host_stats.visits < min_visits:
            continue
        for rule in matching_work_rules(hostname):
            if rule not in seen:
                rules.append(rule)
                seen.add(rule)
    return rules


def recommended_period(stats: dict[str, HostStats]) -> int:
    active_hosts = sum(1 for host in stats.values() if host.visits >= 5)
    if active_hosts >= 80:
        return 1800
    if active_hosts <= 20:
        return 5400
    return 3600


def build_recommendation(args: argparse.Namespace) -> dict[str, object]:
    firefox_root = Path(args.firefox_root).expanduser()
    profile = Path(args.profile).expanduser() if args.profile else find_default_profile(firefox_root)
    stats = read_history(profile, args.days)
    whitelist = recommend_whitelist(stats, args.min_visits)
    policy = dict(BASE_POLICY)
    policy["period"] = recommended_period(stats)
    policy["whitelist-url"] = whitelist

    top_work_hosts = [
        {"hostname": hostname, "visits": host_stats.visits, "urls": host_stats.urls}
        for hostname, host_stats in sorted(
            stats.items(),
            key=lambda item: (item[1].visits, item[1].frecency, item[1].last_visit),
            reverse=True,
        )
        if matching_work_rules(hostname)
    ][: args.top]

    return {
        "profile": str(profile),
        "historyDays": args.days,
        "privacy": "hostnames-only; full URLs are not emitted",
        "hostnamesSeen": len(stats),
        "recommendedPolicyFragment": {
            "policies": {
                "3rdparty": {
                    "Extensions": {
                        AUTO_TAB_DISCARD_ID: policy,
                    }
                }
            }
        },
        "matchedWorkHosts": top_work_hosts,
    }


def write_text_atomically(path: Path, text: str) -> None:
    tmp_path = path.with_name(f".{path.name}.tmp")
    try:
        tmp_path.write_text(text, encoding="utf-8")
        tmp_path.replace(path)
    finally:
        if tmp_path.exists():
            tmp_path.unlink()


def apply_recommendation(recommendation: dict[str, object], policy_json: Path) -> None:
    existing = json.loads(policy_json.read_text(encoding="utf-8"))
    policy = existing.setdefault("policies", {})
    third_party = policy.setdefault("3rdparty", {})
    extensions = third_party.setdefault("Extensions", {})
    fragment = recommendation["recommendedPolicyFragment"]
    assert isinstance(fragment, dict)
    recommended_policy = fragment["policies"]["3rdparty"]["Extensions"][AUTO_TAB_DISCARD_ID]
    extensions[AUTO_TAB_DISCARD_ID] = recommended_policy
    write_text_atomically(policy_json, json.dumps(existing, indent=2, sort_keys=False) + "\n")


def self_test() -> int:
    tmp = Path(tempfile.mkdtemp())
    try:
        firefox_root = tmp / "Firefox"
        profile = firefox_root / "Profiles/test.default"
        profile.mkdir(parents=True)
        (firefox_root / "profiles.ini").write_text(
            "\n".join(
                [
                    "[Install123]",
                    "Default=Profiles/test.default",
                    "[Profile0]",
                    "Name=default",
                    "IsRelative=1",
                    "Path=Profiles/test.default",
                    "Default=1",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        places = profile / "places.sqlite"
        policy_json = tmp / "policies.json"
        now = int(time.time() * FIREFOX_EPOCH_FACTOR)
        with sqlite3.connect(places) as conn:
            conn.execute(
                "CREATE TABLE moz_places (url TEXT, visit_count INTEGER, frecency INTEGER, last_visit_date INTEGER)"
            )
            conn.executemany(
                "INSERT INTO moz_places VALUES (?, ?, ?, ?)",
                [
                    ("https://github.com/org/repo", 12, 100, now),
                    ("https://example.com/private/path", 50, 500, now),
                    ("https://tenant.atlassian.net/browse/ABC", 8, 80, now),
                    ("file:///Users/example/secret", 99, 999, now),
                ],
            )
        args = argparse.Namespace(
            firefox_root=str(firefox_root),
            profile="",
            days=90,
            min_visits=5,
            top=10,
            apply=False,
            policy_json=str(policy_json),
        )
        result = build_recommendation(args)
        text = json.dumps(result)
        assert "github.com" in text
        assert "atlassian.net" in text
        assert "example.com/private" not in text
        assert "file://" not in text
        policy_json.write_text(
            json.dumps(
                {"policies": {"ExtensionSettings": {AUTO_TAB_DISCARD_ID: {"installation_mode": "force_installed"}}}}
            ),
            encoding="utf-8",
        )
        apply_recommendation(result, policy_json)
        applied = json.loads(policy_json.read_text(encoding="utf-8"))
        assert applied["policies"]["ExtensionSettings"][AUTO_TAB_DISCARD_ID]["installation_mode"] == "force_installed"
        assert "whitelist-url" in applied["policies"]["3rdparty"]["Extensions"][AUTO_TAB_DISCARD_ID]
        return 0
    finally:
        shutil.rmtree(tmp)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--firefox-root",
        default=str(Path.home() / "Library/Application Support/Firefox"),
        help="Firefox profile root containing profiles.ini",
    )
    parser.add_argument("--profile", default="", help="Firefox profile directory to read")
    parser.add_argument("--days", type=int, default=90, help="history lookback window")
    parser.add_argument("--min-visits", type=int, default=5, help="minimum hostname visits before recommending a rule")
    parser.add_argument("--top", type=int, default=15, help="number of matched hostnames to include")
    parser.add_argument(
        "--apply", action="store_true", help="merge the recommendation into the dotfiles Firefox policies.json"
    )
    parser.add_argument(
        "--policy-json",
        default=str(DEFAULT_POLICY_JSON),
        help="Firefox policies.json to update when --apply is used",
    )
    parser.add_argument("--self-test", action="store_true", help="run synthetic history recommendation tests")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.self_test:
        return self_test()
    recommendation = build_recommendation(args)
    if args.apply:
        apply_recommendation(recommendation, Path(args.policy_json).expanduser())
        print(f"Updated {Path(args.policy_json).expanduser()}")
    else:
        print(json.dumps(recommendation, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
