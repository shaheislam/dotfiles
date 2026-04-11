#!/usr/bin/env python3
"""
generate-concept-pages.py - Generate Obsidian Concept/MOC pages from session files.

Scans Claude session synthesis files in ~/obsidian/Claude/Sessions/ and produces
Concept pages at ~/obsidian/Claude/Concepts/<entity-slug>.md — one page per entity
that meets the minimum reference threshold.

Usage:
    generate-concept-pages.py [--dry-run] [--limit N] [--min-refs N]
                               [--entities "foo,bar,baz"] [--vault PATH]
"""

import argparse
import hashlib
import os
import re
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Default entity list — tool/tech names common across this dotfiles ecosystem
# Ordered roughly by strategic value (not frequency) so the index reads well.
# ---------------------------------------------------------------------------

DEFAULT_ENTITIES: list[tuple[str, str, str]] = [
    # (slug, display_name, tag)
    ("fish", "Fish Shell", "tech/fish"),
    ("tmux", "tmux", "tech/tmux"),
    ("neovim", "Neovim", "tech/neovim"),
    ("opencode", "OpenCode", "tech/opencode"),
    ("beads", "Beads", "tech/beads"),
    ("mcp", "MCP", "tech/mcp"),
    ("hooks", "Claude Hooks", "tech/claude-hooks"),
    ("stow", "GNU Stow", "tech/stow"),
    ("homebrew", "Homebrew", "tech/homebrew"),
    ("ralph", "Ralph Loop", "tech/ralph-loop"),
    ("obsidian", "Obsidian", "tech/obsidian"),
    ("docker", "Docker", "tech/docker"),
    ("aws", "AWS", "tech/aws"),
    ("terraform", "Terraform", "tech/terraform"),
    ("otel", "OpenTelemetry", "tech/otel"),
    ("python", "Python", "tech/python"),
    ("nix", "Nix", "tech/nix"),
    ("ghostty", "Ghostty", "tech/ghostty"),
    ("kubernetes", "Kubernetes", "tech/kubernetes"),
    ("codex", "Codex CLI", "tech/codex"),
]

# Canonical multi-word aliases that count as mentions of a slug.
# E.g. "brew" counts as a mention of "homebrew".
ALIASES: dict[str, list[str]] = {
    "homebrew": ["brew", "brewfile"],
    "fish": ["fish shell", "fishrc"],
    "neovim": ["nvim", "lazyvim"],
    "mcp": ["mcp server", "mcp servers", "modelcontextprotocol"],
    "hooks": ["claude hooks", "prehook", "posthook", "pretooluse", "posttooluse", "sessionstart", "stoptoken"],
    "beads": ["bd ", "bead ", "bd list", "bd create", "bd close"],
    "ralph": ["ralph-loop", "ralph loop", "ralph_loop"],
    "otel": ["opentelemetry", "otlp", "grafana lgtm", "otel-lgtm"],
    "kubernetes": ["k8s", "kubectl", "k3d", "helm"],
    "docker": ["devcontainer", "colima", "docker-compose", "dockerfile"],
    "aws": ["cloudwatch", "lambda", "iam ", "s3 ", "cloudfront"],
}


def parse_frontmatter(content: str) -> dict:
    """Extract YAML-like frontmatter key: value pairs (simple parser, no deps)."""
    fm: dict = {}
    lines = content.split("\n")
    if not lines or lines[0].strip() != "---":
        return fm
    for i, line in enumerate(lines[1:], 1):
        if line.strip() == "---":
            break
        m = re.match(r'^(\w[\w_-]*):\s*"?([^"]*)"?\s*$', line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm


def extract_title_from_session(content: str, fm: dict, filename: str) -> str:
    """Extract a human-readable title, preferring the first H1 after frontmatter."""
    # Try H1 heading
    h1 = re.search(r"^# (.+)$", content, re.MULTILINE)
    if h1:
        title = h1.group(1).strip()
        # Skip generic "Session: foo" where foo is just the branch slug
        if not re.match(r"^Session:\s*\w{1,20}$", title):
            return title
    # Fall back to frontmatter title if it looks meaningful
    fm_title = fm.get("title", "").strip()
    if fm_title and fm_title not in ("null", "None", ""):
        return fm_title
    # Last resort: derive from filename
    stem = Path(filename).stem
    # Remove date prefix and synth UUID: 2026-04-01-synth-<uuid>
    stem = re.sub(r"^\d{4}-\d{2}-\d{2}-synth-", "", stem)
    return stem[:60]


def session_mentions_entity(content_lower: str, slug: str) -> bool:
    """Return True if the session content mentions this entity (by slug or alias)."""
    # Primary: whole-word match on the slug itself
    pattern = r"\b" + re.escape(slug) + r"\b"
    if re.search(pattern, content_lower):
        return True
    # Aliases
    for alias in ALIASES.get(slug, []):
        if alias in content_lower:
            return True
    return False


def compute_content_checksum(text: str) -> str:
    """SHA-1 of rendered concept body (for manual-edit detection)."""
    return hashlib.sha1(text.encode()).hexdigest()[:12]


def load_memories(vault_path: Path) -> dict[str, list[dict]]:
    """
    Load memory files from Claude/Memories/ subdirectories.
    Returns a dict mapping memory_type -> list of {path, title, entities, slug}
    """
    memories_root = vault_path / "Claude" / "Memories"
    result: dict[str, list[dict]] = defaultdict(list)
    if not memories_root.exists():
        return result

    for subdir in memories_root.iterdir():
        if not subdir.is_dir():
            continue
        mem_type = subdir.name
        for fpath in sorted(subdir.glob("*.md")):
            content = fpath.read_text(encoding="utf-8", errors="replace")
            fm = parse_frontmatter(content)
            # Extract entities from frontmatter
            entities_raw = fm.get("entities", "")
            entities: list[str] = []
            if entities_raw:
                # Could be "- foo\n- bar" style or comma list
                entities = [
                    e.strip().strip('"').strip("'").lower()
                    for e in re.split(r"[,\n]", entities_raw)
                    if e.strip().strip('"').strip("'")
                ]
            # Extract H1 title
            h1 = re.search(r"^# (.+)$", content, re.MULTILINE)
            title = h1.group(1).strip() if h1 else fpath.stem
            # Vault-relative path for wikilink (no .md extension)
            rel = fpath.relative_to(vault_path)
            vault_rel = str(rel.with_suffix(""))

            result[mem_type].append(
                {
                    "path": vault_rel,
                    "title": title,
                    "entities": entities,
                    "filename": fpath.name,
                }
            )

    return result


def find_relevant_memories(memories: dict[str, list[dict]], slug: str) -> dict[str, list[dict]]:
    """Return memories that mention this entity slug in their entities field."""
    relevant: dict[str, list[dict]] = {}
    aliases_for = [slug] + ALIASES.get(slug, [])
    for mem_type, items in memories.items():
        matched = []
        for item in items:
            for alias in aliases_for:
                if any(alias in ent for ent in item["entities"]):
                    matched.append(item)
                    break
        if matched:
            relevant[mem_type] = matched
    return relevant


def derive_summary(slug: str, display_name: str, sessions: list[dict]) -> str:
    """Derive a 1-2 sentence summary from session data."""
    # Look for "## Objective" or "## Lessons & Insights" sections in high-signal sessions
    candidates: list[str] = []
    for s in sessions[:5]:
        content = s.get("content", "")
        # Extract first sentence from Lessons section
        m = re.search(r"## Lessons.*?\n+(.+?)(?:\n|$)", content, re.DOTALL)
        if m:
            lesson = m.group(1).strip().lstrip("- *")
            if len(lesson) > 40 and len(lesson) < 300:
                candidates.append(lesson[:250])
        # Extract Objective section
        m2 = re.search(r"## Objective\n+(.+?)(?:\n\n|\Z)", content, re.DOTALL)
        if m2:
            obj = m2.group(1).strip()[:200]
            if len(obj) > 40:
                candidates.append(obj)

    if candidates:
        return candidates[0]
    return f"{display_name} — tool appearing across {len(sessions)} sessions in this workflow."


def render_concept_page(
    slug: str,
    display_name: str,
    tag: str,
    sessions: list[dict],
    memories: dict[str, list[dict]],
    limit: int,
    today: str,
    manual_notes: str = "",
) -> str:
    """Render the full concept page markdown.

    Strategy: build body first, compute its checksum, then build frontmatter
    with the checksum already embedded.  Single pass — no post-hoc regex.
    """
    session_count = len(sessions)
    top_sessions = sessions[:limit]
    summary = derive_summary(slug, display_name, sessions)

    # --- Session list ---
    session_lines: list[str] = []
    for s in top_sessions:
        wikilink = f"[[Claude/Sessions/{s['stem']}|{s['title']}]]"
        session_lines.append(f"- {wikilink}")

    # --- Memory sections ---
    decision_lines: list[str] = []
    learning_lines: list[str] = []
    for item in memories.get("decision", [])[:5]:
        decision_lines.append(f"- [[{item['path']}|{item['title']}]]")
    for mem_type in ("learning", "learnings"):
        for item in memories.get(mem_type, [])[:5]:
            learning_lines.append(f"- [[{item['path']}|{item['title']}]]")

    # --- Body (no frontmatter yet) ---
    body_lines: list[str] = [
        f"# {display_name}",
        "",
        "## Summary",
        "",
        summary,
        "",
        f"## Sessions where this appeared ({session_count} total, showing {len(top_sessions)})",
        "",
    ]
    body_lines.extend(session_lines if session_lines else ["_None found._"])
    body_lines.append("")

    if decision_lines:
        body_lines += ["## Key decisions involving this", ""] + decision_lines + [""]

    if learning_lines:
        body_lines += ["## Lessons learned", ""] + learning_lines + [""]

    notes_content = manual_notes or "<!-- Add manual notes here. They will be preserved across regenerations. -->"
    body_lines += ["## Notes", "", notes_content, ""]

    body = "\n".join(body_lines)

    # --- Checksum of body ---
    checksum = compute_content_checksum(body)

    # --- Frontmatter (with checksum baked in) ---
    fm_lines: list[str] = [
        "---",
        "type: concept",
        f"entity: {slug}",
        f"created: {today}",
        f"sessions_referencing: {session_count}",
        f"checksum: {checksum}",
        "tags:",
        "  - concept",
        f"  - {tag}",
        "---",
        "",
    ]

    return "\n".join(fm_lines) + body


def extract_manual_notes(existing_content: str) -> str:
    """Extract the ## Notes section from an existing page, preserving manual edits."""
    m = re.search(r"## Notes\n(.*?)(?:\n## |\Z)", existing_content, re.DOTALL)
    if m:
        notes = m.group(1).strip()
        if notes and notes != "<!-- Add manual notes here. They will be preserved across regenerations. -->":
            return notes
    return ""


def parse_stored_checksum(existing_content: str) -> Optional[str]:
    """Extract the stored checksum from frontmatter (field name: checksum)."""
    m = re.search(r"^checksum:\s*(\S+)", existing_content, re.MULTILINE)
    return m.group(1) if m else None


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Obsidian Concept/MOC pages from Claude session files.")
    parser.add_argument(
        "--vault",
        default=os.path.expanduser("~/obsidian"),
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=10,
        help="Max sessions to show per concept page (default: 10)",
    )
    parser.add_argument(
        "--min-refs",
        type=int,
        default=3,
        help="Min session references for a concept to qualify (default: 3)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be generated without writing files",
    )
    parser.add_argument(
        "--entities",
        default="",
        help="Comma-separated entity slugs to process (overrides default list)",
    )
    args = parser.parse_args()

    vault_path = Path(args.vault)
    sessions_dir = vault_path / "Claude" / "Sessions"
    concepts_dir = vault_path / "Claude" / "Concepts"
    today = date.today().isoformat()

    if not sessions_dir.exists():
        print(f"ERROR: Sessions dir not found: {sessions_dir}", file=sys.stderr)
        return 1

    # Build entity list
    if args.entities:
        slugs_requested = [s.strip().lower() for s in args.entities.split(",") if s.strip()]
        entity_lookup = {e[0]: e for e in DEFAULT_ENTITIES}
        entity_list = []
        for s in slugs_requested:
            if s in entity_lookup:
                entity_list.append(entity_lookup[s])
            else:
                # Treat unknown slug as (slug, Slug, "tech/<slug>")
                entity_list.append((s, s.capitalize(), f"tech/{s}"))
    else:
        entity_list = DEFAULT_ENTITIES

    # Collect synth session files
    synth_files = sorted(
        (f for f in sessions_dir.glob("*-synth-*.md")),
        key=lambda p: p.name,
        reverse=True,  # most recent first
    )
    print(f"Found {len(synth_files)} synth session files")

    # Load all sessions into memory (read once, reuse for all entities)
    sessions_data: list[dict] = []
    for fpath in synth_files:
        try:
            content = fpath.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        fm = parse_frontmatter(content)
        title = extract_title_from_session(content, fm, fpath.name)
        sessions_data.append(
            {
                "stem": fpath.stem,
                "title": title,
                "content": content,
                "content_lower": content.lower(),
                "date": fm.get("date", ""),
            }
        )

    # Load memories (done once)
    memories_all = load_memories(vault_path)

    # Per-entity processing
    generated: list[tuple[str, int]] = []  # (slug, session_count)
    skipped: list[tuple[str, int]] = []

    for slug, display_name, tag in entity_list:
        # Find sessions mentioning this entity
        matched = [s for s in sessions_data if session_mentions_entity(s["content_lower"], slug)]

        count = len(matched)
        if count < args.min_refs:
            skipped.append((slug, count))
            continue

        # Find relevant memories
        relevant_memories = find_relevant_memories(memories_all, slug)

        # Check for existing page — preserve manual notes, detect manual edits
        concept_file = concepts_dir / f"{slug}.md"
        existing_content = ""
        stored_checksum = None
        manual_notes = ""
        if concept_file.exists():
            existing_content = concept_file.read_text(encoding="utf-8", errors="replace")
            stored_checksum = parse_stored_checksum(existing_content)
            manual_notes = extract_manual_notes(existing_content)
            # Warn if body was edited manually (checksum mismatch)
            if stored_checksum:
                # Body = everything after the closing "---\n" of frontmatter
                close = existing_content.find("\n---\n", existing_content.index("---") + 3)
                if close != -1:
                    old_body = existing_content[close + 5 :]
                    actual = compute_content_checksum(old_body)
                    if actual != stored_checksum:
                        print(f"  [warn] {slug}: manual edits detected — Notes section preserved, rest regenerated")

        # Render (checksum computed inside render_concept_page, baked into frontmatter)
        rendered = render_concept_page(
            slug=slug,
            display_name=display_name,
            tag=tag,
            sessions=matched,
            memories=relevant_memories,
            limit=args.limit,
            today=today,
            manual_notes=manual_notes,
        )

        if args.dry_run:
            print(f"\n{'=' * 60}")
            print(f"DRY RUN: {concept_file}")
            print(f"  entity: {display_name}, sessions: {count}")
            print(
                f"  memories: decisions={len(relevant_memories.get('decision', []))}, "
                f"learnings={len(relevant_memories.get('learning', [])) + len(relevant_memories.get('learnings', []))}"
            )
            print(f"--- first 25 lines ---")
            print("\n".join(rendered.split("\n")[:25]))
        else:
            concepts_dir.mkdir(parents=True, exist_ok=True)
            concept_file.write_text(rendered, encoding="utf-8")
            print(f"  written: {concept_file.name} ({count} sessions)")

        generated.append((slug, count))

    # Generate _index.md
    index_path = concepts_dir / "_index.md"
    index_lines = [
        "---",
        "type: concept-index",
        f"updated: {today}",
        "tags:",
        "  - concept",
        "  - index",
        "---",
        "",
        "# Concept Index — Maps of Content",
        "",
        "Auto-generated index of concept pages cross-referencing Claude sessions.",
        f"Last updated: {today}",
        "",
        "## Concepts",
        "",
    ]
    for slug, count in sorted(generated, key=lambda x: -x[1]):
        # Look up display name
        display = next((e[1] for e in entity_list if e[0] == slug), slug.capitalize())
        index_lines.append(f"- [[Claude/Concepts/{slug}|{display}]] — {count} sessions")
    index_lines.append("")
    if skipped:
        index_lines.append("## Below threshold (< min-refs)")
        index_lines.append("")
        for slug, count in sorted(skipped, key=lambda x: -x[1]):
            display = next((e[1] for e in entity_list if e[0] == slug), slug.capitalize())
            index_lines.append(f"- {display}: {count} sessions")
        index_lines.append("")
    index_content = "\n".join(index_lines)

    if args.dry_run:
        print(f"\n{'=' * 60}")
        print(f"DRY RUN: {index_path}")
        print(index_content[:800])
    else:
        concepts_dir.mkdir(parents=True, exist_ok=True)
        index_path.write_text(index_content, encoding="utf-8")
        print(f"  written: {index_path.name}")

    # Summary
    print(f"\nSummary: {len(generated)} concepts generated, {len(skipped)} below threshold (min-refs={args.min_refs})")
    if generated:
        print("Generated:")
        for slug, count in sorted(generated, key=lambda x: -x[1]):
            display = next((e[1] for e in entity_list if e[0] == slug), slug)
            print(f"  {display:20s} {count:4d} sessions")

    return 0


if __name__ == "__main__":
    sys.exit(main())
