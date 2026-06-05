#!/usr/bin/env python3
"""Privacy-safe skill invocation tracker for agent prompt hooks."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


SLASH_RE = re.compile(r"(?m)^\s*/([a-z0-9][a-z0-9-]{0,63})(?=\s|$)")


def expand_path(value: str) -> Path:
    return Path(os.path.expandvars(os.path.expanduser(value))).resolve()


def dotfiles_root() -> Path:
    return expand_path(os.environ.get("DOTFILES_ROOT", "~/dotfiles"))


def state_root() -> Path:
    return expand_path(os.environ.get("XDG_STATE_HOME", "~/.local/state"))


def canonical_skills(root: Path) -> set[str]:
    skills = set()
    for skill_md in root.glob("skills/*/*/SKILL.md"):
        skills.add(skill_md.parent.name)
    return skills


def prompt_from_payload(payload: dict[str, Any]) -> str:
    prompt = payload.get("prompt")
    if isinstance(prompt, str):
        return prompt
    tool_input = payload.get("tool_input")
    if isinstance(tool_input, dict) and isinstance(tool_input.get("prompt"), str):
        return str(tool_input["prompt"])
    return ""


def prompt_hash(prompt: str) -> str:
    normalized = re.sub(r"\s+", " ", prompt.strip().lower())
    return hashlib.sha1(normalized.encode("utf-8")).hexdigest()[:16]


def invoked_skills(prompt: str, known_skills: set[str]) -> list[str]:
    seen = []
    for match in SLASH_RE.finditer(prompt):
        skill = match.group(1)
        if skill in known_skills and skill not in seen:
            seen.append(skill)
    return seen


def write_jsonl(path: Path, entries: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        for entry in entries:
            handle.write(json.dumps(entry, sort_keys=True, separators=(",", ":")) + "\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Log explicit slash-skill invocations without storing prompt text.")
    parser.add_argument("--harness", default=os.environ.get("SKILL_INVOCATION_HARNESS", "unknown"))
    parser.add_argument(
        "--log", default=os.environ.get("SKILL_INVOCATION_LOG", "~/.local/state/agent-skills/invocations.jsonl")
    )
    parser.add_argument("--self-test", action="store_true")
    return parser


def run(payload: dict[str, Any], harness: str, log_path: Path, root: Path) -> int:
    prompt = prompt_from_payload(payload)
    skills = invoked_skills(prompt, canonical_skills(root))
    if not skills:
        return 0

    now = dt.datetime.now(dt.timezone.utc).isoformat()
    entries = []
    for skill in skills:
        entries.append(
            {
                "timestamp": now,
                "harness": harness,
                "skill": skill,
                "session_id": payload.get("session_id"),
                "cwd": payload.get("cwd") or os.environ.get("CLAUDE_PROJECT_DIR"),
                "prompt_hash": prompt_hash(prompt),
            }
        )
    write_jsonl(log_path, entries)
    return len(entries)


def self_test() -> None:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "dotfiles"
        skill_dir = root / "skills" / "shared" / "skill-toil-audit"
        skill_dir.mkdir(parents=True)
        (skill_dir / "SKILL.md").write_text("---\nname: skill-toil-audit\n---\n", encoding="utf-8")
        log_path = Path(tmp) / "invocations.jsonl"
        payload = {"prompt": "/skill-toil-audit --save token=secret", "session_id": "s1", "cwd": "/repo"}
        assert run(payload, "test", log_path, root) == 1
        data = log_path.read_text(encoding="utf-8")
        assert "skill-toil-audit" in data
        assert "token=secret" not in data


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("log-skill-invocation self-test passed")
        return 0

    try:
        payload = json.load(sys.stdin)
        if not isinstance(payload, dict):
            return 0
        run(payload, args.harness, expand_path(args.log), dotfiles_root())
    except Exception as exc:
        print(f"skill invocation logging skipped: {exc}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
