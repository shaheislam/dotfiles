#!/Users/shaheislam/dotfiles/.venv/vault-search/bin/python3
"""
Obsidian Vault Semantic Search (Enhanced)

Query the embedding index for notes/blocks similar to a given note or text query.
Supports hybrid search, folder filtering, previews, and negative examples.

Features:
- Block-level results (shows specific sections)
- Hybrid search (semantic + keyword matching)
- Folder/path filtering
- Preview snippets
- Negative examples ("like X but not Y")
- Bidirectional similarity boost
- Query history

Usage:
    # Find notes similar to a specific file
    vault-search.py "Career/Articles/Prometheus.md"

    # Text query with hybrid search
    vault-search.py --query "kubernetes deployment" --hybrid

    # Filter by folder
    vault-search.py --query "monitoring" --folder "Career/"

    # Negative examples
    vault-search.py "Prometheus.md" --exclude "alerting"

    # Show query history
    vault-search.py --history
"""

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
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


def get_embedding_for_text(text: str, model_name: str = "all-MiniLM-L6-v2") -> np.ndarray:
    """Generate embedding for arbitrary text query."""
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer(model_name)
    return model.encode(text, show_progress_bar=False)


def keyword_score(query_words: set[str], keywords: list[str]) -> float:
    """Calculate keyword overlap score for hybrid search."""
    if not keywords:
        return 0.0
    keyword_set = set(keywords)
    overlap = len(query_words & keyword_set)
    return overlap / max(len(query_words), 1)


def compute_bidirectional_boost(
    query_idx: int,
    similarities: np.ndarray,
    embeddings: np.ndarray,
    boost_factor: float = 0.1
) -> np.ndarray:
    """
    Boost scores when similarity is mutual (A→B strong AND B→A strong).
    This indicates a stronger conceptual relationship.
    """
    boosted = similarities.copy()

    # For top candidates, check reverse similarity
    top_indices = np.argsort(similarities)[-50:]  # Check top 50

    for idx in top_indices:
        if idx == query_idx:
            continue
        # Compute reverse similarity (how similar is query to this result?)
        reverse_sim = cosine_similarity(embeddings[idx], embeddings[query_idx:query_idx+1])[0]
        # Boost if mutual
        mutual_strength = min(similarities[idx], reverse_sim)
        boosted[idx] += mutual_strength * boost_factor

    return boosted


def search_by_file(
    file_path: str,
    vault_path: Path,
    embeddings: np.ndarray,
    metadata: dict,
    top_k: int = 10,
    threshold: float = 0.0,
    folder_filter: str = None,
    exclude_terms: list[str] = None,
    hybrid: bool = False,
    bidirectional: bool = True,
) -> list[dict]:
    """Find blocks/notes similar to the given file."""
    files = metadata.get("files", {})
    blocks = metadata.get("blocks", [])

    # Normalize path
    if file_path.startswith(str(vault_path)):
        rel_path = str(Path(file_path).relative_to(vault_path))
    else:
        rel_path = file_path

    if not rel_path.endswith(".md"):
        rel_path = rel_path + ".md"

    # Find file in index
    if rel_path not in files:
        # Try matching by filename
        filename = Path(rel_path).name
        matches = [p for p in files if Path(p).name == filename]
        if matches:
            rel_path = matches[0]
        else:
            print(f"Error: File not found in index: {file_path}", file=sys.stderr)
            sys.exit(1)

    file_info = files[rel_path]
    block_indices = file_info.get("block_indices", [])

    if not block_indices:
        print(f"Error: No blocks indexed for {file_path}", file=sys.stderr)
        sys.exit(1)

    # Get average embedding for the file (combine all blocks)
    file_embeddings = embeddings[block_indices]
    query_embedding = np.mean(file_embeddings, axis=0)

    # Compute similarities
    similarities = cosine_similarity(query_embedding, embeddings)

    # Apply bidirectional boost
    if bidirectional and len(block_indices) > 0:
        similarities = compute_bidirectional_boost(
            block_indices[0], similarities, embeddings
        )

    # Build results
    results = []
    seen_files = {rel_path}  # Exclude query file

    for idx, block in enumerate(blocks):
        block_file = block.get("file", "")

        # Skip blocks from query file
        if block_file == rel_path:
            continue

        # Folder filter
        if folder_filter and not block_file.startswith(folder_filter):
            continue

        # Exclude terms filter
        if exclude_terms:
            preview_lower = block.get("preview", "").lower()
            heading_lower = block.get("heading", "").lower()
            if any(term.lower() in preview_lower or term.lower() in heading_lower
                   for term in exclude_terms):
                continue

        sim = float(similarities[idx])
        if sim < threshold:
            continue

        # Hybrid: boost by keyword overlap
        if hybrid and block_file in files:
            query_keywords = set(file_info.get("keywords", []))
            target_keywords = files[block_file].get("keywords", [])
            kw_score = keyword_score(query_keywords, target_keywords)
            sim = sim * 0.8 + kw_score * 0.2  # 80% semantic, 20% keyword

        results.append({
            "file": block_file,
            "title": files.get(block_file, {}).get("title", Path(block_file).stem),
            "heading": block.get("heading", ""),
            "preview": block.get("preview", ""),
            "line": block.get("start_line", 0),
            "score": sim,
        })

    # Sort by score, dedupe by file (keep best block per file)
    results.sort(key=lambda x: x["score"], reverse=True)

    deduped = []
    seen = set()
    for r in results:
        if r["file"] not in seen:
            seen.add(r["file"])
            deduped.append(r)
            if len(deduped) >= top_k:
                break

    return deduped


def search_by_query(
    query: str,
    vault_path: Path,
    embeddings: np.ndarray,
    metadata: dict,
    top_k: int = 10,
    threshold: float = 0.0,
    folder_filter: str = None,
    exclude_terms: list[str] = None,
    hybrid: bool = False,
) -> list[dict]:
    """Find blocks/notes matching a text query."""
    files = metadata.get("files", {})
    blocks = metadata.get("blocks", [])
    model_name = metadata.get("model", "all-MiniLM-L6-v2")

    # Map model short names to full names
    model_map = {
        "minilm": "all-MiniLM-L6-v2",
        "bge-small": "BAAI/bge-small-en-v1.5",
        "bge-base": "BAAI/bge-base-en-v1.5",
    }
    full_model = model_map.get(model_name, model_name)

    query_embedding = get_embedding_for_text(query, full_model)

    # Compute similarities
    similarities = cosine_similarity(query_embedding, embeddings)

    # Extract query keywords for hybrid search
    query_words = set(re.findall(r"\b[a-z]{3,}\b", query.lower()))

    # Build results
    results = []

    for idx, block in enumerate(blocks):
        block_file = block.get("file", "")

        # Folder filter
        if folder_filter and not block_file.startswith(folder_filter):
            continue

        # Exclude terms filter
        if exclude_terms:
            preview_lower = block.get("preview", "").lower()
            heading_lower = block.get("heading", "").lower()
            if any(term.lower() in preview_lower or term.lower() in heading_lower
                   for term in exclude_terms):
                continue

        sim = float(similarities[idx])
        if sim < threshold:
            continue

        # Hybrid: boost by keyword overlap
        if hybrid and block_file in files:
            target_keywords = files[block_file].get("keywords", [])
            kw_score = keyword_score(query_words, target_keywords)
            sim = sim * 0.7 + kw_score * 0.3  # 70% semantic, 30% keyword for queries

        results.append({
            "file": block_file,
            "title": files.get(block_file, {}).get("title", Path(block_file).stem),
            "heading": block.get("heading", ""),
            "preview": block.get("preview", ""),
            "line": block.get("start_line", 0),
            "score": sim,
        })

    # Sort and dedupe
    results.sort(key=lambda x: x["score"], reverse=True)

    deduped = []
    seen = set()
    for r in results:
        if r["file"] not in seen:
            seen.add(r["file"])
            deduped.append(r)
            if len(deduped) >= top_k:
                break

    return deduped


def save_query_history(vault_path: Path, query: str, query_type: str):
    """Save query to history file."""
    history_file = vault_path / ".vault-index" / "query_history.json"

    try:
        if history_file.exists():
            with open(history_file) as f:
                history = json.load(f)
        else:
            history = []

        history.append({
            "query": query,
            "type": query_type,
            "timestamp": datetime.now().isoformat(),
        })

        # Keep last 100 queries
        history = history[-100:]

        with open(history_file, "w") as f:
            json.dump(history, f, indent=2)
    except Exception:
        pass  # Don't fail on history errors


def show_query_history(vault_path: Path, limit: int = 20):
    """Display recent query history."""
    history_file = vault_path / ".vault-index" / "query_history.json"

    if not history_file.exists():
        print("No query history found.")
        return

    with open(history_file) as f:
        history = json.load(f)

    print(f"Recent queries (last {min(limit, len(history))}):\n")
    for entry in reversed(history[-limit:]):
        ts = entry.get("timestamp", "")[:16].replace("T", " ")
        qtype = entry.get("type", "unknown")
        query = entry.get("query", "")
        print(f"  [{ts}] ({qtype}) {query}")


def format_results(results: list[dict], output_format: str = "fzf") -> str:
    """Format results for output."""
    if output_format == "fzf":
        # Format: "path\tscore\ttitle\theading\tpreview" for fzf-lua
        lines = []
        for r in results:
            line_info = f":{r['line']}" if r.get('line', 0) > 0 else ""
            heading = r.get('heading', '')
            if heading and heading != r.get('title', ''):
                display = f"{r['title']} > {heading}"
            else:
                display = r['title']
            lines.append(f"{r['file']}{line_info}\t{r['score']:.2f}\t{display}\t{r.get('preview', '')[:80]}")
        return "\n".join(lines)

    elif output_format == "json":
        return json.dumps(results, indent=2)

    else:  # plain
        lines = []
        for r in results:
            heading = r.get('heading', '')
            if heading and heading != r.get('title', ''):
                title_display = f"{r['title']} > {heading}"
            else:
                title_display = r['title']

            lines.append(f"{r['score']:.2f}  {title_display}")
            lines.append(f"       {r['file']}:{r.get('line', 0)}")
            if r.get('preview'):
                preview = r['preview'][:100] + "..." if len(r.get('preview', '')) > 100 else r.get('preview', '')
                lines.append(f"       \"{preview}\"")
            lines.append("")
        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Search Obsidian vault for semantically similar notes/blocks"
    )
    parser.add_argument(
        "file",
        nargs="?",
        help="File to find similar notes for (relative or absolute path)",
    )
    parser.add_argument(
        "--query", "-q",
        help="Text query to search for (instead of file)",
    )
    parser.add_argument(
        "--vault",
        type=Path,
        default=Path.home() / "obsidian",
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--top", "-n",
        type=int,
        default=10,
        help="Number of results (default: 10)",
    )
    parser.add_argument(
        "--threshold", "-t",
        type=float,
        default=0.0,
        help="Minimum similarity threshold (default: 0.0)",
    )
    parser.add_argument(
        "--folder", "-d",
        help="Filter results to this folder prefix",
    )
    parser.add_argument(
        "--exclude", "-x",
        action="append",
        help="Exclude results containing these terms (can repeat)",
    )
    parser.add_argument(
        "--hybrid",
        action="store_true",
        help="Use hybrid search (semantic + keyword matching)",
    )
    parser.add_argument(
        "--no-bidirectional",
        action="store_true",
        help="Disable bidirectional similarity boost",
    )
    parser.add_argument(
        "--format", "-f",
        choices=["fzf", "json", "plain"],
        default="fzf",
        help="Output format (default: fzf)",
    )
    parser.add_argument(
        "--history",
        action="store_true",
        help="Show recent query history",
    )

    args = parser.parse_args()

    # Handle history display
    if args.history:
        show_query_history(args.vault)
        return

    if not args.file and not args.query:
        parser.error("Either file path or --query is required")

    # Load index
    index_dir = args.vault / ".vault-index"
    embeddings, metadata = load_index(index_dir)

    # Search
    if args.query:
        save_query_history(args.vault, args.query, "text")
        results = search_by_query(
            args.query,
            args.vault,
            embeddings,
            metadata,
            args.top,
            args.threshold,
            args.folder,
            args.exclude,
            args.hybrid,
        )
    else:
        save_query_history(args.vault, args.file, "file")
        results = search_by_file(
            args.file,
            args.vault,
            embeddings,
            metadata,
            args.top,
            args.threshold,
            args.folder,
            args.exclude,
            args.hybrid,
            not args.no_bidirectional,
        )

    # Output
    if results:
        print(format_results(results, args.format))
    else:
        print("No similar notes found", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
