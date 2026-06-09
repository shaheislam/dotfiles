#!/usr/bin/env python3
"""Build a privacy-safe SQLite index of local skill usage.

The append-only JSONL log remains the source of truth. This script rebuilds a
derived SQLite database so monthly skill evolution can rank active, stale, and
unused skills without storing raw prompts.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


DEFAULT_LOG = "~/.local/state/agent-skills/invocations.jsonl"
DEFAULT_DB = "~/.local/state/agent-skills/skill-stats.sqlite"
DEFAULT_OPENCODE_DB = "~/.local/share/opencode/opencode.db"
SLASH_RE = re.compile(r"(?m)^\s*/([a-z0-9][a-z0-9-]{0,63})(?=\s|$)")
WORD_RE = re.compile(r"[a-z0-9][a-z0-9-]{2,}")
STOP_WORDS = {
    "about",
    "after",
    "again",
    "also",
    "because",
    "before",
    "could",
    "from",
    "have",
    "into",
    "just",
    "like",
    "make",
    "need",
    "please",
    "should",
    "that",
    "then",
    "there",
    "this",
    "with",
    "would",
}
KEEP_RARE = {
    "careful",
    "fact-checker",
    "fix",
    "freeze",
    "guard",
    "macos-cleaner",
    "security-audit",
    "unfreeze",
}


@dataclasses.dataclass(frozen=True)
class SkillInfo:
    name: str
    category: str
    path: str
    description: str


@dataclasses.dataclass(frozen=True)
class Invocation:
    ts: str
    ts_epoch: int
    harness: str
    skill: str
    source: str
    transcript_src: str | None = None
    session_id: str | None = None
    message_id: str | None = None
    jsonl_path: str | None = None
    jsonl_offset: int | None = None
    cwd: str | None = None
    prompt_hash: str | None = None
    tool_name: str | None = None


@dataclasses.dataclass(frozen=True)
class PromptSignal:
    ts_epoch: int
    skill: str | None
    prompt_hash: str
    tokens: frozenset[str]
    message_id: str | None


def expand_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def default_repo_root() -> Path:
    return expand_path(os.environ.get("DOTFILES_ROOT", "~/dotfiles"))


def iso_to_epoch(value: str | None) -> int:
    if not value:
        return 0
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return 0
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return int(parsed.timestamp())


def epoch_to_iso(value: int) -> str:
    return dt.datetime.fromtimestamp(value, tz=dt.timezone.utc).isoformat()


def ms_to_epoch(value: Any) -> int:
    try:
        numeric = int(value or 0)
    except (TypeError, ValueError):
        return 0
    if numeric > 10_000_000_000:
        return numeric // 1000
    return numeric


def prompt_hash(text: str) -> str:
    normalized = re.sub(r"\s+", " ", text.strip().lower())
    return hashlib.sha1(normalized.encode("utf-8")).hexdigest()[:16]


def json_loads(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, str):
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def cutoff_epoch(days: int | None) -> int | None:
    if days is None:
        return None
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)
    return int(cutoff.timestamp())


def within_window(epoch: int, cutoff: int | None) -> bool:
    return cutoff is None or epoch == 0 or epoch >= cutoff


def load_skill_inventory(repo_root: Path) -> dict[str, SkillInfo]:
    skills: dict[str, SkillInfo] = {}
    for category in ("shared", "personal", "work"):
        for skill_md in sorted((repo_root / "skills" / category).glob("*/SKILL.md")):
            text = skill_md.read_text(encoding="utf-8", errors="ignore")
            match = re.search(r"(?m)^description:\s*(.+)$", text)
            description = match.group(1).strip().strip('"') if match else ""
            skills[skill_md.parent.name] = SkillInfo(
                name=skill_md.parent.name,
                category=category,
                path=str(skill_md),
                description=description,
            )
    return skills


def slash_skills(text: str, known: set[str]) -> list[str]:
    seen: list[str] = []
    for match in SLASH_RE.finditer(text):
        skill = match.group(1)
        if skill in known and skill not in seen:
            seen.append(skill)
    return seen


def token_set(text: str) -> frozenset[str]:
    return frozenset(word for word in WORD_RE.findall(text.lower()) if word not in STOP_WORDS)


def load_jsonl_invocations(path: Path, known: set[str], cutoff: int | None) -> list[Invocation]:
    if not path.exists():
        return []

    invocations: list[Invocation] = []
    with path.open("rb") as handle:
        while True:
            offset = handle.tell()
            raw = handle.readline()
            if not raw:
                break
            try:
                data = json.loads(raw.decode("utf-8"))
            except json.JSONDecodeError:
                continue
            if not isinstance(data, dict):
                continue

            skill = data.get("skill")
            if not isinstance(skill, str) or skill not in known:
                continue

            ts = str(data.get("timestamp") or "")
            epoch = iso_to_epoch(ts)
            if not within_window(epoch, cutoff):
                continue

            source = data.get("source")
            if not isinstance(source, str) or not source:
                source = "slash" if data.get("prompt_hash") else "tracker"

            invocations.append(
                Invocation(
                    ts=ts or epoch_to_iso(epoch or int(dt.datetime.now(dt.timezone.utc).timestamp())),
                    ts_epoch=epoch,
                    harness=str(data.get("harness") or "unknown"),
                    skill=skill,
                    source=source,
                    transcript_src=data.get("transcript_src") if isinstance(data.get("transcript_src"), str) else None,
                    session_id=data.get("session_id") if isinstance(data.get("session_id"), str) else None,
                    message_id=data.get("message_id") if isinstance(data.get("message_id"), str) else None,
                    jsonl_path=str(path),
                    jsonl_offset=offset,
                    cwd=data.get("cwd") if isinstance(data.get("cwd"), str) else None,
                    prompt_hash=data.get("prompt_hash") if isinstance(data.get("prompt_hash"), str) else None,
                    tool_name=data.get("tool_name") if isinstance(data.get("tool_name"), str) else None,
                )
            )
    return invocations


def sqlite_readonly(path: Path) -> sqlite3.Connection:
    uri = f"file:{path}?mode=ro"
    return sqlite3.connect(uri, uri=True)


def load_opencode_history(
    db_path: Path, known: set[str], cutoff: int | None
) -> tuple[list[Invocation], list[PromptSignal]]:
    if not db_path.exists():
        return [], []

    cutoff_ms = cutoff * 1000 if cutoff is not None else None
    query = """
        SELECT
            s.directory,
            m.id,
            m.session_id,
            m.time_created,
            m.data,
            p.data
        FROM message m
        JOIN part p ON p.message_id = m.id
        JOIN session s ON s.id = m.session_id
        WHERE (? IS NULL OR m.time_created >= ?)
        ORDER BY m.time_created ASC, p.id ASC
    """

    invocations: list[Invocation] = []
    signals: list[PromptSignal] = []
    with sqlite_readonly(db_path) as conn:
        for cwd, message_id, session_id, created, message_raw, part_raw in conn.execute(query, (cutoff_ms, cutoff_ms)):
            message = json_loads(message_raw)
            if message.get("role") != "user":
                continue
            part = json_loads(part_raw)
            if part.get("type") != "text" or part.get("ignored") is True:
                continue
            text = part.get("text")
            if not isinstance(text, str) or not text.strip():
                continue

            epoch = ms_to_epoch(created)
            hashed = prompt_hash(text)
            matches = slash_skills(text, known)
            if matches:
                for skill in matches:
                    invocations.append(
                        Invocation(
                            ts=epoch_to_iso(epoch),
                            ts_epoch=epoch,
                            harness="opencode",
                            skill=skill,
                            source="slash-history",
                            transcript_src="opencode",
                            session_id=str(session_id),
                            message_id=str(message_id),
                            cwd=str(cwd or ""),
                            prompt_hash=hashed,
                        )
                    )
                    signals.append(
                        PromptSignal(
                            ts_epoch=epoch,
                            skill=skill,
                            prompt_hash=hashed,
                            tokens=token_set(text),
                            message_id=str(message_id),
                        )
                    )
            else:
                signals.append(
                    PromptSignal(
                        ts_epoch=epoch,
                        skill=None,
                        prompt_hash=hashed,
                        tokens=token_set(text),
                        message_id=str(message_id),
                    )
                )
    return invocations, signals


def connect_db(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS invocations (
            id INTEGER PRIMARY KEY,
            ts TEXT NOT NULL,
            ts_epoch INTEGER NOT NULL,
            harness TEXT NOT NULL,
            skill TEXT NOT NULL,
            source TEXT NOT NULL,
            transcript_src TEXT,
            session_id TEXT,
            message_id TEXT,
            jsonl_path TEXT,
            jsonl_offset INTEGER,
            cwd TEXT,
            prompt_hash TEXT,
            tool_name TEXT,
            UNIQUE(skill, source, harness, session_id, message_id, jsonl_path, jsonl_offset, prompt_hash)
        );
        CREATE INDEX IF NOT EXISTS idx_invocations_skill_ts ON invocations(skill, ts_epoch);
        CREATE INDEX IF NOT EXISTS idx_invocations_session ON invocations(session_id);

        CREATE TABLE IF NOT EXISTS skill_summary (
            skill TEXT PRIMARY KEY,
            category TEXT NOT NULL,
            path TEXT NOT NULL,
            description TEXT NOT NULL,
            total_30d INTEGER NOT NULL,
            total_90d INTEGER NOT NULL,
            total_all INTEGER NOT NULL,
            first_seen TEXT,
            last_seen TEXT,
            sources_30d TEXT NOT NULL,
            classification TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS skill_clusters (
            id INTEGER PRIMARY KEY,
            skill TEXT,
            cluster_label TEXT NOT NULL,
            exemplar_hash TEXT NOT NULL,
            exemplar_msg_id TEXT,
            cluster_size INTEGER NOT NULL,
            window_days INTEGER NOT NULL,
            computed_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS skill_near_miss (
            id INTEGER PRIMARY KEY,
            candidate_skill TEXT NOT NULL,
            similarity REAL NOT NULL,
            exemplar_hash TEXT NOT NULL,
            exemplar_msg_id TEXT,
            cluster_size INTEGER NOT NULL,
            computed_at TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS skill_outcomes (
            invocation_id INTEGER PRIMARY KEY,
            outcome TEXT NOT NULL,
            next_skill TEXT,
            follow_up_lag INTEGER,
            FOREIGN KEY(invocation_id) REFERENCES invocations(id) ON DELETE CASCADE
        );
        """
    )


def reset_derived(conn: sqlite3.Connection) -> None:
    conn.execute("DELETE FROM invocations")
    conn.execute("DELETE FROM skill_summary")
    conn.execute("DELETE FROM skill_clusters")
    conn.execute("DELETE FROM skill_near_miss")
    conn.execute("DELETE FROM skill_outcomes")


def insert_invocations(conn: sqlite3.Connection, invocations: Iterable[Invocation]) -> None:
    conn.executemany(
        """
        INSERT OR IGNORE INTO invocations (
            ts, ts_epoch, harness, skill, source, transcript_src, session_id,
            message_id, jsonl_path, jsonl_offset, cwd, prompt_hash, tool_name
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        [
            (
                inv.ts,
                inv.ts_epoch,
                inv.harness,
                inv.skill,
                inv.source,
                inv.transcript_src,
                inv.session_id,
                inv.message_id,
                inv.jsonl_path,
                inv.jsonl_offset,
                inv.cwd,
                inv.prompt_hash,
                inv.tool_name,
            )
            for inv in invocations
        ],
    )


def classify(total_30d: int, total_90d: int, total_all: int, skill: str) -> str:
    if total_30d >= 3:
        return "active"
    if total_30d > 0 or total_90d >= 2:
        return "warm"
    if total_all > 0:
        return "stale-review"
    if skill in KEEP_RARE:
        return "keep-safety-rare"
    return "never-seen"


def recompute_summary(conn: sqlite3.Connection, skills: dict[str, SkillInfo]) -> None:
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    cutoff_30 = now - 30 * 86400
    cutoff_90 = now - 90 * 86400
    updated = epoch_to_iso(now)

    for skill, info in sorted(skills.items()):
        rows = conn.execute(
            "SELECT ts_epoch, source, ts FROM invocations WHERE skill = ? ORDER BY ts_epoch ASC", (skill,)
        ).fetchall()
        total_all = len(rows)
        total_30 = sum(1 for ts_epoch, _source, _ts in rows if int(ts_epoch or 0) >= cutoff_30)
        total_90 = sum(1 for ts_epoch, _source, _ts in rows if int(ts_epoch or 0) >= cutoff_90)
        first_seen = rows[0][2] if rows else None
        last_seen = rows[-1][2] if rows else None
        sources = Counter(str(source) for ts_epoch, source, _ts in rows if int(ts_epoch or 0) >= cutoff_30)
        conn.execute(
            """
            INSERT INTO skill_summary (
                skill, category, path, description, total_30d, total_90d,
                total_all, first_seen, last_seen, sources_30d,
                classification, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                skill,
                info.category,
                info.path,
                info.description,
                total_30,
                total_90,
                total_all,
                first_seen,
                last_seen,
                json.dumps(dict(sorted(sources.items())), sort_keys=True),
                classify(total_30, total_90, total_all, skill),
                updated,
            ),
        )


def label_for_tokens(tokens: Iterable[str]) -> str:
    selected = sorted(tokens)[:5]
    return " ".join(selected) if selected else "unlabelled"


def recompute_clusters(conn: sqlite3.Connection, signals: list[PromptSignal], window_days: int) -> None:
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    computed_at = epoch_to_iso(now)
    cutoff = now - window_days * 86400

    by_hash: dict[tuple[str | None, str], list[PromptSignal]] = defaultdict(list)
    for signal in signals:
        if signal.ts_epoch >= cutoff:
            by_hash[(signal.skill, signal.prompt_hash)].append(signal)

    for (skill, hashed), grouped in by_hash.items():
        if len(grouped) < 2:
            continue
        exemplar = grouped[0]
        conn.execute(
            """
            INSERT INTO skill_clusters (
                skill, cluster_label, exemplar_hash, exemplar_msg_id,
                cluster_size, window_days, computed_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                skill,
                label_for_tokens(exemplar.tokens),
                hashed,
                exemplar.message_id,
                len(grouped),
                window_days,
                computed_at,
            ),
        )


def recompute_near_misses(conn: sqlite3.Connection, skills: dict[str, SkillInfo], signals: list[PromptSignal]) -> None:
    descriptions = {name: token_set(f"{name} {info.description}") for name, info in skills.items()}
    grouped: dict[str, list[PromptSignal]] = defaultdict(list)
    for signal in signals:
        if signal.skill is None and len(signal.tokens) >= 3:
            grouped[signal.prompt_hash].append(signal)

    computed_at = dt.datetime.now(dt.timezone.utc).isoformat()
    for hashed, items in grouped.items():
        if len(items) < 2:
            continue
        tokens = items[0].tokens
        best_skill = None
        best_score = 0.0
        for skill, skill_tokens in descriptions.items():
            if not skill_tokens:
                continue
            overlap = len(tokens & skill_tokens)
            union = len(tokens | skill_tokens)
            score = overlap / union if union else 0.0
            if score > best_score:
                best_skill = skill
                best_score = score
        if best_skill and best_score >= 0.12:
            conn.execute(
                """
                INSERT INTO skill_near_miss (
                    candidate_skill, similarity, exemplar_hash, exemplar_msg_id,
                    cluster_size, computed_at
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (best_skill, best_score, hashed, items[0].message_id, len(items), computed_at),
            )


def recompute_outcomes(conn: sqlite3.Connection) -> None:
    ids = [row[0] for row in conn.execute("SELECT id FROM invocations")]
    conn.executemany(
        "INSERT INTO skill_outcomes (invocation_id, outcome, next_skill, follow_up_lag) VALUES (?, 'unclear', NULL, NULL)",
        [(invocation_id,) for invocation_id in ids],
    )


def rebuild(args: argparse.Namespace) -> int:
    repo_root = expand_path(args.repo_root)
    skills = load_skill_inventory(repo_root)
    known = set(skills)
    cutoff = cutoff_epoch(None if args.all else args.days)

    invocations = load_jsonl_invocations(expand_path(args.log), known, cutoff)
    history_invocations, signals = load_opencode_history(expand_path(args.opencode_db), known, cutoff)
    invocations.extend(history_invocations)

    db_path = expand_path(args.db)
    with connect_db(db_path) as conn:
        init_schema(conn)
        reset_derived(conn)
        insert_invocations(conn, invocations)
        recompute_summary(conn, skills)
        recompute_clusters(conn, signals, args.cluster_days)
        recompute_near_misses(conn, skills, signals)
        recompute_outcomes(conn)

    print(f"skill stats rebuilt: {db_path}")
    print(f"skills indexed: {len(skills)}")
    print(f"invocations indexed: {len(invocations)}")
    return 0


def print_rows(rows: list[sqlite3.Row], columns: list[str]) -> None:
    if not rows:
        print("No rows.")
        return
    widths = [len(column) for column in columns]
    for row in rows:
        for index, column in enumerate(columns):
            widths[index] = max(widths[index], len(str(row[column] if row[column] is not None else "")))
    print("  ".join(column.ljust(widths[index]) for index, column in enumerate(columns)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        print(
            "  ".join(
                str(row[column] if row[column] is not None else "").ljust(widths[index])
                for index, column in enumerate(columns)
            )
        )


def open_stats_db(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(expand_path(path))
    conn.row_factory = sqlite3.Row
    init_schema(conn)
    return conn


def top(args: argparse.Namespace) -> int:
    column = "total_all" if args.all else f"total_{args.days}d"
    if column not in {"total_30d", "total_90d", "total_all"}:
        raise SystemExit("--days must be 30 or 90 unless --all is used")
    with open_stats_db(args.db) as conn:
        rows = conn.execute(
            f"""
            SELECT skill, {column} AS total, classification, sources_30d, last_seen
            FROM skill_summary
            ORDER BY {column} DESC, skill ASC
            LIMIT ?
            """,
            (args.limit,),
        ).fetchall()
    print_rows(rows, ["skill", "total", "classification", "sources_30d", "last_seen"])
    return 0


def unused(args: argparse.Namespace) -> int:
    column = f"total_{args.days}d"
    if column not in {"total_30d", "total_90d"}:
        raise SystemExit("--days must be 30 or 90")
    with open_stats_db(args.db) as conn:
        rows = conn.execute(
            f"""
            SELECT skill, classification, total_all, last_seen
            FROM skill_summary
            WHERE {column} = 0
            ORDER BY total_all ASC, skill ASC
            LIMIT ?
            """,
            (args.limit,),
        ).fetchall()
    print_rows(rows, ["skill", "classification", "total_all", "last_seen"])
    return 0


def describe(args: argparse.Namespace) -> int:
    with open_stats_db(args.db) as conn:
        summary = conn.execute("SELECT * FROM skill_summary WHERE skill = ?", (args.skill,)).fetchone()
        if not summary:
            print(f"No summary for skill: {args.skill}", file=sys.stderr)
            return 1
        rows = conn.execute(
            """
            SELECT ts, harness, source, transcript_src, session_id, message_id, prompt_hash
            FROM invocations
            WHERE skill = ?
            ORDER BY ts_epoch DESC
            LIMIT ?
            """,
            (args.skill, args.limit),
        ).fetchall()
    for key in ("skill", "classification", "total_30d", "total_90d", "total_all", "first_seen", "last_seen"):
        print(f"{key}: {summary[key]}")
    print("\nRecent invocations:")
    print_rows(rows, ["ts", "harness", "source", "transcript_src", "session_id", "message_id", "prompt_hash"])
    return 0


def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "dotfiles"
        skill_dir = root / "skills" / "shared" / "skill-toil-audit"
        skill_dir.mkdir(parents=True)
        (skill_dir / "SKILL.md").write_text(
            "---\nname: skill-toil-audit\ndescription: Audit repeated skills.\n---\n",
            encoding="utf-8",
        )
        log_path = Path(tmp) / "invocations.jsonl"
        log_path.write_text(
            json.dumps(
                {
                    "timestamp": dt.datetime.now(dt.timezone.utc).isoformat(),
                    "harness": "test",
                    "skill": "skill-toil-audit",
                    "source": "slash",
                    "session_id": "s1",
                    "prompt_hash": "abc123",
                }
            )
            + "\n",
            encoding="utf-8",
        )
        db_path = Path(tmp) / "skill-stats.sqlite"
        args = argparse.Namespace(
            repo_root=str(root),
            log=str(log_path),
            opencode_db=str(Path(tmp) / "missing.sqlite"),
            db=str(db_path),
            days=90,
            all=False,
            cluster_days=90,
        )
        assert rebuild(args) == 0
        with sqlite3.connect(db_path) as conn:
            row = conn.execute(
                "SELECT total_all, total_90d FROM skill_summary WHERE skill = 'skill-toil-audit'"
            ).fetchone()
            assert row == (1, 1)
            outcome = conn.execute("SELECT outcome FROM skill_outcomes").fetchone()
            assert outcome == ("unclear",)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build and query the privacy-safe skill usage SQLite index.")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--db", default=os.environ.get("SKILL_STATS_DB", DEFAULT_DB))
    subparsers = parser.add_subparsers(dest="command")

    rebuild_parser = subparsers.add_parser("rebuild-index", help="Rebuild the derived SQLite index")
    rebuild_parser.add_argument("--repo-root", default=os.environ.get("DOTFILES_ROOT", "~/dotfiles"))
    rebuild_parser.add_argument("--log", default=os.environ.get("SKILL_INVOCATION_LOG", DEFAULT_LOG))
    rebuild_parser.add_argument("--opencode-db", default=os.environ.get("OPENCODE_DB", DEFAULT_OPENCODE_DB))
    rebuild_parser.add_argument("--days", type=int, default=90)
    rebuild_parser.add_argument("--all", action="store_true")
    rebuild_parser.add_argument("--cluster-days", type=int, default=90)
    rebuild_parser.set_defaults(func=rebuild)

    top_parser = subparsers.add_parser("top", help="Show most-used skills")
    top_parser.add_argument("--days", type=int, choices=(30, 90), default=30)
    top_parser.add_argument("--all", action="store_true")
    top_parser.add_argument("--limit", type=int, default=20)
    top_parser.set_defaults(func=top)

    unused_parser = subparsers.add_parser("unused", help="Show skills with no recent usage")
    unused_parser.add_argument("--days", type=int, choices=(30, 90), default=90)
    unused_parser.add_argument("--limit", type=int, default=50)
    unused_parser.set_defaults(func=unused)

    describe_parser = subparsers.add_parser("describe", help="Show evidence for one skill")
    describe_parser.add_argument("skill")
    describe_parser.add_argument("--limit", type=int, default=10)
    describe_parser.set_defaults(func=describe)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("skill-stats self-test passed")
        return 0
    if not hasattr(args, "func"):
        parser.print_help()
        return 2
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
