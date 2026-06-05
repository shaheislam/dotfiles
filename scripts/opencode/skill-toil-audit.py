#!/usr/bin/env python3
"""Audit OpenCode history for repetitive workflows that may deserve skills.

The script is intentionally read-only. It opens the OpenCode SQLite database
with SQLite's immutable/read-only URI mode, parses message/part JSON in Python,
and reports candidates rather than creating skills automatically.
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


DEFAULT_DB = "~/.local/share/opencode/opencode.db"
SECRET_PATTERNS = [
    re.compile(r"(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*['\"]?[^\s'\"]+"),
    re.compile(r"\b(sk-[A-Za-z0-9_-]{12,})\b"),
    re.compile(r"\b(gh[pousr]_[A-Za-z0-9_]{12,})\b"),
]
NOISE_PREFIXES = (
    "▣ dcp |",
    "dcp |",
    "[image",
    "respond with exactly:",
    "the following tool was executed by the user",
)
TOY_PROMPTS = {
    "2+2",
    "what is 2+2?",
    "what is the capital of japan?",
}
GENERIC_ACTION_PROMPTS = {
    "implement this",
    "implement this.",
    "implement",
    "make this change",
    "make these changes",
    "yes do this",
    "do this",
}
STOP_WORDS = {
    "the",
    "and",
    "for",
    "that",
    "this",
    "with",
    "from",
    "into",
    "have",
    "what",
    "when",
    "where",
    "would",
    "could",
    "should",
    "our",
    "your",
    "you",
    "can",
    "are",
    "is",
    "was",
    "were",
    "they",
    "them",
    "then",
    "than",
    "also",
    "just",
    "about",
    "there",
    "their",
    "these",
    "those",
    "make",
    "implement",
    "change",
    "changes",
    "conversation",
    "fork",
    "new",
    "session",
    "theme",
    "title",
}


@dataclasses.dataclass(frozen=True)
class PromptEntry:
    text: str
    session_title: str
    directory: str
    session_id: str
    time_created: int


@dataclasses.dataclass
class Candidate:
    key: str
    kind: str
    title: str
    action: str
    score: int
    reason: str
    prompts: list[PromptEntry]
    existing_skill: str | None = None

    @property
    def count(self) -> int:
        return len(self.prompts)

    @property
    def distinct_sessions(self) -> int:
        return len({prompt.session_id for prompt in self.prompts})

    @property
    def latest_ms(self) -> int:
        return max(prompt.time_created for prompt in self.prompts)


def expand_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def sqlite_readonly_connection(db_path: Path) -> sqlite3.Connection:
    if not db_path.exists():
        raise FileNotFoundError(f"OpenCode database not found: {db_path}")
    uri = f"file:{db_path}?mode=ro&immutable=1"
    return sqlite3.connect(uri, uri=True)


def json_loads(raw: str) -> dict[str, Any]:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def redact(text: str) -> str:
    redacted = text
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub(
            lambda match: match.group(0).split("=", 1)[0] + "=[REDACTED]" if "=" in match.group(0) else "[REDACTED]",
            redacted,
        )
    return redacted


def normalize_prompt(text: str) -> str:
    text = redact(text).strip().lower()
    text = re.sub(r"```.*?```", " [code-block] ", text, flags=re.DOTALL)
    text = re.sub(r"`[^`]+`", " [inline-code] ", text)
    text = re.sub(r"https?://\S+", " [url] ", text)
    text = re.sub(r"/users/[^\s]+", " [path] ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def prompt_hash(text: str) -> str:
    return hashlib.sha1(normalize_prompt(text).encode("utf-8")).hexdigest()[:10]


def is_noise(text: str) -> bool:
    normalized = normalize_prompt(text)
    if not normalized:
        return True
    if normalized in TOY_PROMPTS:
        return True
    return normalized.startswith(NOISE_PREFIXES)


def load_entries(conn: sqlite3.Connection, days: int | None) -> list[PromptEntry]:
    cutoff_ms = None
    if days is not None:
        cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days)
        cutoff_ms = int(cutoff.timestamp() * 1000)

    query = """
        SELECT
            s.title,
            s.directory,
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

    entries: list[PromptEntry] = []
    for title, directory, session_id, created, message_raw, part_raw in conn.execute(query, (cutoff_ms, cutoff_ms)):
        message = json_loads(message_raw)
        if message.get("role") != "user":
            continue

        part = json_loads(part_raw)
        if part.get("type") != "text" or part.get("ignored") is True:
            continue

        text = part.get("text")
        if not isinstance(text, str) or is_noise(text):
            continue

        entries.append(
            PromptEntry(
                text=redact(text),
                session_title=str(title or "Untitled"),
                directory=str(directory or ""),
                session_id=str(session_id),
                time_created=int(created or 0),
            )
        )
    return entries


def load_existing_skills(repo_root: Path) -> dict[str, str]:
    skills: dict[str, str] = {}
    for root in (repo_root / "skills" / "shared", repo_root / "skills" / "personal", repo_root / "skills" / "work"):
        if not root.is_dir():
            continue
        for skill_md in sorted(root.glob("*/SKILL.md")):
            content = skill_md.read_text(encoding="utf-8", errors="replace")
            description_match = re.search(r"^description:\s*(.+)$", content, re.MULTILINE)
            description = description_match.group(1).strip().strip("\"'") if description_match else ""
            skills[skill_md.parent.name] = description
    return skills


def token_set(text: str) -> set[str]:
    tokens = set()
    for token in re.findall(r"[a-z0-9][a-z0-9-]{2,}", normalize_prompt(text)):
        if token in STOP_WORDS:
            continue
        if token[0].isdigit():
            continue
        if not re.search(r"[a-z]", token):
            continue
        tokens.add(token)
    return tokens


def nearest_skill(text: str, skills: dict[str, str]) -> str | None:
    tokens = token_set(text)
    if not tokens:
        return None
    best_name = None
    best_score = 0
    for name, description in skills.items():
        skill_tokens = token_set(f"{name} {description}")
        overlap = len(tokens & skill_tokens)
        if overlap > best_score:
            best_name = name
            best_score = overlap
    return best_name if best_score >= 2 else None


def classify_prompt_group(key: str, prompts: list[PromptEntry], skills: dict[str, str]) -> Candidate:
    sample = prompts[-1].text
    normalized = normalize_prompt(sample)
    existing = nearest_skill(sample, skills)
    distinct_sessions = len({prompt.session_id for prompt in prompts})
    avg_len = sum(len(prompt.text) for prompt in prompts) // max(len(prompts), 1)

    if normalized in GENERIC_ACTION_PROMPTS:
        action = "inspect-session-theme"
        reason = "Repeated prompt is generic; mine surrounding session titles before creating a skill."
        title = "Generic implementation follow-up"
        kind = "prompt-repeat"
    elif existing:
        action = "improve-existing-skill"
        reason = (
            f"Prompt overlaps existing `{existing}` skill; prefer improving that workflow over creating a duplicate."
        )
        title = f"Improve `{existing}` coverage"
        kind = "existing-skill-overlap"
    elif avg_len < 80 and distinct_sessions >= 2:
        action = "script-alias-or-command"
        reason = "Repeated prompt is short and likely operational; consider a command, alias, or small script first."
        title = sample[:72].replace("\n", " ")
        kind = "short-repeat"
    else:
        action = "new-skill-candidate"
        reason = "Repeated multi-step request looks suitable for durable instructions and regression examples."
        title = sample.splitlines()[0][:72]
        kind = "workflow-repeat"

    score = len(prompts) * 3 + distinct_sessions * 5 + min(avg_len // 80, 5)
    if action == "new-skill-candidate":
        score += 8
    if action == "improve-existing-skill":
        score += 5

    return Candidate(
        key=key,
        kind=kind,
        title=title,
        action=action,
        score=score,
        reason=reason,
        prompts=prompts,
        existing_skill=existing,
    )


def cluster_prompt_repeats(entries: list[PromptEntry], min_count: int, skills: dict[str, str]) -> list[Candidate]:
    groups: dict[str, list[PromptEntry]] = defaultdict(list)
    for entry in entries:
        groups[normalize_prompt(entry.text)].append(entry)

    candidates = [
        classify_prompt_group(key, prompts, skills) for key, prompts in groups.items() if len(prompts) >= min_count
    ]
    return candidates


def cluster_session_themes(entries: list[PromptEntry], min_count: int, skills: dict[str, str]) -> list[Candidate]:
    by_theme: dict[str, list[PromptEntry]] = defaultdict(list)
    for entry in entries:
        tokens = [token for token in token_set(entry.session_title) if len(token) > 3]
        for token in tokens:
            by_theme[token].append(entry)

    candidates: list[Candidate] = []
    for token, prompts in by_theme.items():
        distinct_sessions = len({prompt.session_id for prompt in prompts})
        if distinct_sessions < min_count:
            continue
        existing = nearest_skill(token, skills)
        action = "improve-existing-skill" if existing else "new-skill-candidate"
        title = f"Recurring session theme: {token}"
        score = distinct_sessions * 6 + len(prompts)
        if existing:
            score += 5
        candidates.append(
            Candidate(
                key=f"theme:{token}",
                kind="session-theme",
                title=title,
                action=action,
                score=score,
                reason="Multiple sessions share this theme; inspect whether a repeatable workflow exists.",
                prompts=prompts,
                existing_skill=existing,
            )
        )
    return candidates


def apply_decisions(candidates: list[Candidate], decisions_path: Path | None) -> list[Candidate]:
    if decisions_path is None or not decisions_path.exists():
        return candidates
    data = json.loads(decisions_path.read_text(encoding="utf-8"))
    rejected = set(data.get("rejected", [])) if isinstance(data, dict) else set()
    accepted = set(data.get("accepted", [])) if isinstance(data, dict) else set()
    filtered = [candidate for candidate in candidates if candidate.key not in rejected]
    for candidate in filtered:
        if candidate.key in accepted:
            candidate.score += 20
            candidate.reason = f"Previously accepted. {candidate.reason}"
    return filtered


def top_candidates(
    entries: list[PromptEntry], min_count: int, skills: dict[str, str], decisions_path: Path | None
) -> list[Candidate]:
    candidates = cluster_prompt_repeats(entries, min_count, skills)
    candidates.extend(cluster_session_themes(entries, min_count, skills))
    candidates = apply_decisions(candidates, decisions_path)
    candidates.sort(key=lambda candidate: (candidate.score, candidate.latest_ms), reverse=True)
    return candidates


def format_time(ms: int) -> str:
    if not ms:
        return "unknown"
    return dt.datetime.fromtimestamp(ms / 1000, tz=dt.timezone.utc).strftime("%Y-%m-%d")


def proposed_skill_name(candidate: Candidate) -> str:
    words = [token for token in token_set(candidate.title) if token not in {"recurring", "session", "theme"}]
    if not words:
        name = f"workflow-{candidate.key[:8]}"
    else:
        name = "-".join(words[:4])[:64].strip("-")
    name = re.sub(r"[^a-z0-9-]+", "-", name.lower()).strip("-")
    return name or "workflow-candidate"


def candidate_to_dict(candidate: Candidate) -> dict[str, Any]:
    samples = []
    seen: set[str] = set()
    for prompt in reversed(candidate.prompts):
        key = prompt_hash(prompt.text)
        if key in seen:
            continue
        seen.add(key)
        samples.append(
            {
                "prompt_hash": key,
                "text": prompt.text[:500],
                "session_title": prompt.session_title,
                "directory": prompt.directory,
                "date": format_time(prompt.time_created),
            }
        )
        if len(samples) == 3:
            break

    return {
        "key": candidate.key,
        "kind": candidate.kind,
        "title": candidate.title,
        "action": candidate.action,
        "score": candidate.score,
        "count": candidate.count,
        "distinct_sessions": candidate.distinct_sessions,
        "latest": format_time(candidate.latest_ms),
        "existing_skill": candidate.existing_skill,
        "proposed_skill_name": proposed_skill_name(candidate) if candidate.action == "new-skill-candidate" else None,
        "reason": candidate.reason,
        "samples": samples,
    }


def render_markdown(candidates: list[Candidate], entries: list[PromptEntry], args: argparse.Namespace) -> str:
    lines = [
        "# Skill TOIL Audit",
        "",
        f"Generated: {dt.datetime.now(dt.timezone.utc).strftime('%Y-%m-%d %H:%M:%SZ')}",
        f"Window: {'all history' if args.days is None else str(args.days) + ' days'}",
        f"Prompts analyzed: {len(entries)}",
        f"Minimum repeat/session count: {args.min_count}",
        "",
        "## Decision Rule",
        "",
        "Create or improve a skill only when the candidate has a repeatable multi-step workflow, durable instructions, or a safety/quality benefit. Otherwise prefer a command, alias, script, documentation, or no action.",
        "",
        "## Candidates",
        "",
    ]

    if not candidates:
        lines.append("No candidates met the current threshold.")
        return "\n".join(lines) + "\n"

    for index, candidate in enumerate(candidates[: args.limit], start=1):
        data = candidate_to_dict(candidate)
        lines.extend(
            [
                f"### {index}. {data['title']}",
                "",
                f"- Action: `{data['action']}`",
                f"- Score: `{data['score']}`",
                f"- Kind: `{data['kind']}`",
                f"- Count: `{data['count']}` prompts across `{data['distinct_sessions']}` sessions",
                f"- Latest: `{data['latest']}`",
                f"- Existing skill: `{data['existing_skill'] or 'none'}`",
                f"- Proposed skill name: `{data['proposed_skill_name'] or 'n/a'}`",
                f"- Reason: {data['reason']}",
                "",
                "Samples:",
            ]
        )
        for sample in data["samples"]:
            text = sample["text"].replace("\n", " ")
            lines.append(f"- `{sample['date']}` `{sample['session_title']}`: {text}")
        if args.stubs and data["proposed_skill_name"]:
            skill_name = data["proposed_skill_name"]
            lines.extend(
                [
                    "",
                    "Draft skill stub:",
                    "",
                    "```markdown",
                    "---",
                    f"name: {skill_name}",
                    f"description: Use when recurring OpenCode history shows the `{skill_name}` workflow needs durable instructions and regression examples.",
                    "---",
                    "",
                    f"# {skill_name}",
                    "",
                    "## Trigger",
                    "",
                    "Use when the user asks for this repeatable workflow again.",
                    "",
                    "## Workflow",
                    "",
                    "1. Inspect the current repo and relevant existing skills before editing.",
                    "2. Apply the smallest durable change that removes the repeated TOIL.",
                    "3. Add or update regression checks for the workflow.",
                    "4. Run relevant validation and summarize outcomes.",
                    "```",
                ]
            )
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def render_json(candidates: list[Candidate], entries: list[PromptEntry], args: argparse.Namespace) -> str:
    return (
        json.dumps(
            {
                "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
                "window_days": args.days,
                "prompts_analyzed": len(entries),
                "min_count": args.min_count,
                "candidates": [candidate_to_dict(candidate) for candidate in candidates[: args.limit]],
            },
            indent=2,
            sort_keys=True,
        )
        + "\n"
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Audit OpenCode history for skill-worthy repeated TOIL.")
    parser.add_argument("--db", default=DEFAULT_DB, help="OpenCode SQLite DB path. Default: %(default)s")
    parser.add_argument(
        "--repo-root",
        default=str(Path(__file__).resolve().parents[2]),
        help="Dotfiles repo root for existing skill lookup.",
    )
    parser.add_argument("--days", type=int, default=30, help="History window in days. Use --all for full history.")
    parser.add_argument("--all", action="store_true", help="Analyze all available history.")
    parser.add_argument("--min-count", type=int, default=3, help="Minimum repeat count or distinct sessions.")
    parser.add_argument("--limit", type=int, default=20, help="Maximum candidates to print.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of Markdown.")
    parser.add_argument("--save", help="Write the report to this path as well as stdout.")
    parser.add_argument(
        "--stubs",
        action="store_true",
        help="Include implementation-ready draft SKILL.md stubs for new-skill candidates.",
    )
    parser.add_argument("--decisions", help="Optional JSON file with accepted/rejected candidate keys.")
    parser.add_argument("--self-test", action="store_true", help="Run fixture-backed regression tests and exit.")
    return parser


def run(args: argparse.Namespace) -> str:
    args.days = None if args.all else args.days
    conn = sqlite_readonly_connection(expand_path(args.db))
    try:
        entries = load_entries(conn, args.days)
    finally:
        conn.close()
    skills = load_existing_skills(expand_path(args.repo_root))
    decisions_path = expand_path(args.decisions) if args.decisions else None
    candidates = top_candidates(entries, args.min_count, skills, decisions_path)
    return render_json(candidates, entries, args) if args.json else render_markdown(candidates, entries, args)


def create_fixture_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE session (id text PRIMARY KEY, title text, directory text);
        CREATE TABLE message (id text PRIMARY KEY, session_id text, time_created integer, data text);
        CREATE TABLE part (id text PRIMARY KEY, message_id text, session_id text, data text);
        """
    )
    now = int(dt.datetime.now(dt.timezone.utc).timestamp() * 1000)
    sessions = [
        ("s1", "OpenCode session history mining", "/repo"),
        ("s2", "OpenCode session history mining", "/repo"),
        ("s3", "Skill eval regression", "/repo"),
    ]
    conn.executemany("INSERT INTO session VALUES (?, ?, ?)", sessions)
    rows = [
        (
            "m1",
            "s1",
            now - 3000,
            {"role": "user"},
            "p1",
            {"type": "text", "text": "Can we mine OpenCode history for skill candidates?"},
        ),
        (
            "m2",
            "s2",
            now - 2000,
            {"role": "user"},
            "p2",
            {"type": "text", "text": "Can we mine OpenCode history for skill candidates?"},
        ),
        (
            "m3",
            "s3",
            now - 1000,
            {"role": "user"},
            "p3",
            {"type": "text", "text": "▣ DCP | compressed", "ignored": True},
        ),
        ("m4", "s3", now - 500, {"role": "assistant"}, "p4", {"type": "text", "text": "assistant text"}),
    ]
    for message_id, session_id, created, message_data, part_id, part_data in rows:
        conn.execute(
            "INSERT INTO message VALUES (?, ?, ?, ?)", (message_id, session_id, created, json.dumps(message_data))
        )
        conn.execute("INSERT INTO part VALUES (?, ?, ?, ?)", (part_id, message_id, session_id, json.dumps(part_data)))
    conn.commit()
    conn.close()


def self_test() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        db_path = tmp_path / "opencode.db"
        repo_root = tmp_path / "repo"
        skill_dir = repo_root / "skills" / "shared" / "skill-toil-audit"
        skill_dir.mkdir(parents=True)
        (skill_dir / "SKILL.md").write_text(
            "---\nname: skill-toil-audit\ndescription: Audit OpenCode session history for repeated skill candidates.\n---\n",
            encoding="utf-8",
        )
        create_fixture_db(db_path)

        parser = build_parser()
        args = parser.parse_args(
            ["--db", str(db_path), "--repo-root", str(repo_root), "--all", "--min-count", "2", "--json"]
        )
        report = json.loads(run(args))
        assert report["prompts_analyzed"] == 2, report
        assert report["candidates"], report
        assert report["candidates"][0]["count"] == 2, report
        assert "DCP" not in json.dumps(report), report


def main(argv: Iterable[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(list(argv) if argv is not None else None)
    if args.self_test:
        self_test()
        print("skill-toil-audit self-test passed")
        return 0

    report = run(args)
    if args.save:
        save_path = expand_path(args.save)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        save_path.write_text(report, encoding="utf-8")
    sys.stdout.write(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
