#!/usr/bin/env python3
"""
Obsidian Vault Backlink Suggester

Analyzes your vault and suggests where you should add links between notes.
Identifies semantically related content that isn't explicitly linked.

Usage:
    # Suggest links for a specific file
    vault-suggest.py "Career/Articles/Prometheus.md"

    # Suggest links for entire vault (top opportunities)
    vault-suggest.py --all

    # Output as markdown checklist
    vault-suggest.py "note.md" --format markdown
"""

import argparse
import json
import re
import sys
from pathlib import Path

import numpy as np


def load_index(index_dir: Path) -> tuple[np.ndarray, dict]:
    """Load the embedding index."""
    embeddings_path = index_dir / "embeddings.npy"
    metadata_path = index_dir / "metadata.json"

    if not embeddings_path.exists() or not metadata_path.exists():
        print("Error: Index not found. Run vault-index.py first.", file=sys.stderr)
        sys.exit(1)

    embeddings = np.load(embeddings_path)
    with open(metadata_path) as f:
        metadata = json.load(f)

    return embeddings, metadata


def cosine_similarity(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Compute cosine similarity between vector a and matrix b."""
    a_norm = a / (np.linalg.norm(a) + 1e-9)
    b_norm = b / (np.linalg.norm(b, axis=1, keepdims=True) + 1e-9)
    return np.dot(b_norm, a_norm)


def extract_existing_links(content: str) -> set[str]:
    """Extract all wiki-links from note content."""
    # Match [[link]] and [[link|alias]]
    pattern = r"\[\[([^\]|]+)(?:\|[^\]]+)?\]\]"
    matches = re.findall(pattern, content)
    # Normalize: remove .md extension if present
    return {m.replace(".md", "") for m in matches}


def find_link_opportunities(
    file_path: str,
    vault_path: Path,
    embeddings: np.ndarray,
    metadata: dict,
    min_similarity: float = 0.5,
    max_suggestions: int = 10,
) -> list[dict]:
    """Find notes that should be linked but aren't."""
    files = metadata.get("files", {})
    blocks = metadata.get("blocks", [])

    # Normalize path
    if file_path.startswith(str(vault_path)):
        rel_path = str(Path(file_path).relative_to(vault_path))
    else:
        rel_path = file_path

    if not rel_path.endswith(".md"):
        rel_path = rel_path + ".md"

    if rel_path not in files:
        filename = Path(rel_path).name
        matches = [p for p in files if Path(p).name == filename]
        if matches:
            rel_path = matches[0]
        else:
            print(f"Error: File not found: {file_path}", file=sys.stderr)
            sys.exit(1)

    # Read actual file content to find existing links
    full_path = vault_path / rel_path
    try:
        content = full_path.read_text(encoding="utf-8")
    except:
        content = full_path.read_text(encoding="latin-1")

    existing_links = extract_existing_links(content)
    # Also consider the file itself as "linked"
    existing_links.add(rel_path.replace(".md", ""))
    existing_links.add(Path(rel_path).stem)

    # Get file's embedding
    file_info = files[rel_path]
    block_indices = file_info.get("block_indices", [])

    if not block_indices:
        print(f"Error: No blocks indexed for {file_path}", file=sys.stderr)
        sys.exit(1)

    file_embeddings = embeddings[block_indices]
    query_embedding = np.mean(file_embeddings, axis=0)

    # Compute similarities
    similarities = cosine_similarity(query_embedding, embeddings)

    # Find unlinked but similar files
    suggestions = []
    seen_files = set()

    for idx, block in enumerate(blocks):
        block_file = block.get("file", "")

        # Skip self
        if block_file == rel_path:
            continue

        # Skip already seen files
        if block_file in seen_files:
            continue
        seen_files.add(block_file)

        # Check if already linked
        block_file_stem = Path(block_file).stem
        block_file_no_ext = block_file.replace(".md", "")
        if block_file_stem in existing_links or block_file_no_ext in existing_links:
            continue

        sim = float(similarities[idx])
        if sim < min_similarity:
            continue

        # Find the best matching section in target file
        target_blocks = [b for b in blocks if b.get("file") == block_file]
        best_section = None
        best_section_sim = 0

        for tb in target_blocks:
            tb_idx = blocks.index(tb)
            if similarities[tb_idx] > best_section_sim:
                best_section_sim = similarities[tb_idx]
                best_section = tb.get("heading", "")

        suggestions.append(
            {
                "target_file": block_file,
                "target_title": files.get(block_file, {}).get("title", Path(block_file).stem),
                "target_section": best_section,
                "similarity": sim,
                "preview": block.get("preview", ""),
                "reason": f"Semantically similar ({sim:.0%} match)",
            }
        )

    # Sort by similarity
    suggestions.sort(key=lambda x: x["similarity"], reverse=True)

    return suggestions[:max_suggestions]


def find_vault_wide_opportunities(
    vault_path: Path,
    embeddings: np.ndarray,
    metadata: dict,
    min_similarity: float = 0.6,
    max_suggestions: int = 20,
) -> list[dict]:
    """Find the best linking opportunities across the entire vault."""
    files = metadata.get("files", {})
    blocks = metadata.get("blocks", [])

    # For each file, find its best unlinked match
    all_opportunities = []

    for rel_path, file_info in files.items():
        full_path = vault_path / rel_path
        if not full_path.exists():
            continue

        try:
            content = full_path.read_text(encoding="utf-8")
        except:
            try:
                content = full_path.read_text(encoding="latin-1")
            except:
                continue

        existing_links = extract_existing_links(content)
        existing_links.add(rel_path.replace(".md", ""))
        existing_links.add(Path(rel_path).stem)

        block_indices = file_info.get("block_indices", [])
        if not block_indices:
            continue

        file_embeddings = embeddings[block_indices]
        query_embedding = np.mean(file_embeddings, axis=0)
        similarities = cosine_similarity(query_embedding, embeddings)

        # Find best unlinked match
        seen_files = {rel_path}
        for idx in np.argsort(similarities)[::-1]:
            if idx >= len(blocks):
                continue

            block = blocks[idx]
            block_file = block.get("file", "")

            if block_file in seen_files:
                continue
            seen_files.add(block_file)

            block_file_stem = Path(block_file).stem
            block_file_no_ext = block_file.replace(".md", "")
            if block_file_stem in existing_links or block_file_no_ext in existing_links:
                continue

            sim = float(similarities[idx])
            if sim < min_similarity:
                break

            all_opportunities.append(
                {
                    "source_file": rel_path,
                    "source_title": file_info.get("title", Path(rel_path).stem),
                    "target_file": block_file,
                    "target_title": files.get(block_file, {}).get("title", Path(block_file).stem),
                    "similarity": sim,
                    "reason": f"{sim:.0%} semantic similarity",
                }
            )
            break  # Only one suggestion per source file

    # Sort by similarity and dedupe bidirectional pairs
    all_opportunities.sort(key=lambda x: x["similarity"], reverse=True)

    # Remove duplicate pairs (A→B and B→A)
    seen_pairs = set()
    deduped = []
    for opp in all_opportunities:
        pair = tuple(sorted([opp["source_file"], opp["target_file"]]))
        if pair not in seen_pairs:
            seen_pairs.add(pair)
            deduped.append(opp)
            if len(deduped) >= max_suggestions:
                break

    return deduped


def format_suggestions(suggestions: list[dict], output_format: str = "plain", source_file: str = None) -> str:
    """Format suggestions for output."""
    if output_format == "json":
        return json.dumps(suggestions, indent=2)

    elif output_format == "markdown":
        lines = ["# Suggested Links\n"]
        if source_file:
            lines.append(f"For: `{source_file}`\n")

        for s in suggestions:
            target = s.get("target_file") or s.get("target_title", "")
            title = s.get("target_title", Path(target).stem)
            sim = s.get("similarity", 0)
            reason = s.get("reason", "")

            lines.append(f"- [ ] [[{Path(target).stem}|{title}]] ({sim:.0%})")
            if s.get("target_section"):
                lines.append(f"  - Section: {s['target_section']}")
            if s.get("preview"):
                lines.append(f'  - *"{s["preview"][:80]}..."*')

        return "\n".join(lines)

    else:  # plain
        lines = []
        if source_file:
            lines.append(f"Link suggestions for: {source_file}\n")

        for i, s in enumerate(suggestions, 1):
            target = s.get("target_file", "")
            title = s.get("target_title", Path(target).stem)
            sim = s.get("similarity", 0)

            if "source_file" in s:
                # Vault-wide format
                lines.append(f"{i}. {s['source_title']} → {title}")
                lines.append(f"   {s['source_file']} → {target}")
            else:
                # Single-file format
                lines.append(f"{i}. {title} ({sim:.0%} similar)")
                lines.append(f"   Path: {target}")
                if s.get("target_section"):
                    lines.append(f"   Section: {s['target_section']}")
                if s.get("preview"):
                    lines.append(f'   "{s["preview"][:80]}..."')

            lines.append(f"   Reason: {s.get('reason', 'Semantic similarity')}")
            lines.append("")

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Suggest backlinks for Obsidian vault notes")
    parser.add_argument(
        "file",
        nargs="?",
        help="File to suggest links for",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Find best linking opportunities across entire vault",
    )
    parser.add_argument(
        "--vault",
        type=Path,
        default=Path.home() / "obsidian",
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--min-similarity",
        "-s",
        type=float,
        default=0.5,
        help="Minimum similarity threshold (default: 0.5)",
    )
    parser.add_argument(
        "--max",
        "-n",
        type=int,
        default=10,
        help="Maximum suggestions (default: 10)",
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["plain", "markdown", "json"],
        default="plain",
        help="Output format (default: plain)",
    )

    args = parser.parse_args()

    if not args.file and not args.all:
        parser.error("Either file path or --all is required")

    # Load index
    index_dir = args.vault / ".vault-index"
    embeddings, metadata = load_index(index_dir)

    # Generate suggestions
    if args.all:
        suggestions = find_vault_wide_opportunities(
            args.vault,
            embeddings,
            metadata,
            args.min_similarity,
            args.max,
        )
        print(format_suggestions(suggestions, args.format))
    else:
        suggestions = find_link_opportunities(
            args.file,
            args.vault,
            embeddings,
            metadata,
            args.min_similarity,
            args.max,
        )
        print(format_suggestions(suggestions, args.format, args.file))


if __name__ == "__main__":
    main()
