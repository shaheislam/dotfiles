#!/usr/bin/env python3
"""
Obsidian Vault Semantic Indexer (Enhanced)

Builds a local embedding index with block-level granularity for semantic search.
Supports multiple embedding models and incremental updates.

Features:
- Block-level embeddings (sections/paragraphs, not just files)
- Multiple model support (minilm, bge-small, bge-base)
- Incremental indexing with change detection
- Keyword index for hybrid search

Usage:
    vault-index.py ~/obsidian                     # Full index with blocks
    vault-index.py ~/obsidian --file-level        # File-level only (faster)
    vault-index.py ~/obsidian --model bge-small   # Use different model
    vault-index.py ~/obsidian --force             # Rebuild from scratch
"""

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional

import numpy as np

# Available embedding models
MODELS = {
    "minilm": "all-MiniLM-L6-v2",  # 90MB, 384 dims, fastest
    "bge-small": "BAAI/bge-small-en-v1.5",  # 130MB, 384 dims, better quality
    "bge-base": "BAAI/bge-base-en-v1.5",  # 440MB, 768 dims, best quality
}

DEFAULT_MODEL = "minilm"


def get_model(model_name: str = DEFAULT_MODEL):
    """Load embedding model by name."""
    from sentence_transformers import SentenceTransformer

    model_id = MODELS.get(model_name, model_name)
    return SentenceTransformer(model_id)


def hash_content(content: str) -> str:
    """Generate hash of content for change detection."""
    return hashlib.md5(content.encode()).hexdigest()


def extract_title(content: str, path: Path) -> str:
    """Extract note title from content or filename."""
    lines = content.strip().split("\n")
    for line in lines:
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem


def extract_blocks(content: str, path: Path, min_block_size: int = 100) -> list[dict]:
    """
    Extract blocks (sections) from markdown content.

    Returns list of blocks with:
    - text: content for embedding
    - heading: section heading (or "intro" for content before first heading)
    - start_line: line number where block starts
    - preview: first ~100 chars for display
    """
    lines = content.split("\n")
    blocks = []

    current_block = []
    current_heading = "intro"
    current_start = 0
    heading_pattern = re.compile(r"^(#{1,6})\s+(.+)$")

    for i, line in enumerate(lines):
        match = heading_pattern.match(line)

        if match:
            # Save previous block if substantial
            if current_block:
                block_text = "\n".join(current_block).strip()
                if len(block_text) >= min_block_size:
                    blocks.append(
                        {
                            "text": block_text,
                            "heading": current_heading,
                            "start_line": current_start,
                            "preview": block_text[:150].replace("\n", " ").strip(),
                        }
                    )

            # Start new block
            current_heading = match.group(2).strip()
            current_start = i + 1
            current_block = [line]
        else:
            current_block.append(line)

    # Don't forget the last block
    if current_block:
        block_text = "\n".join(current_block).strip()
        if len(block_text) >= min_block_size:
            blocks.append(
                {
                    "text": block_text,
                    "heading": current_heading,
                    "start_line": current_start,
                    "preview": block_text[:150].replace("\n", " ").strip(),
                }
            )

    # If no blocks extracted (short file), use whole content
    if not blocks:
        blocks.append(
            {
                "text": content.strip(),
                "heading": extract_title(content, path),
                "start_line": 0,
                "preview": content[:150].replace("\n", " ").strip(),
            }
        )

    return blocks


def extract_keywords(content: str) -> list[str]:
    """Extract keywords for hybrid search."""
    # Remove markdown syntax
    text = re.sub(r"[#*_`\[\](){}]", " ", content)
    text = re.sub(r"\s+", " ", text).lower()

    # Extract words (3+ chars)
    words = re.findall(r"\b[a-z]{3,}\b", text)

    # Count frequencies
    freq = defaultdict(int)
    for word in words:
        freq[word] += 1

    # Return top keywords by frequency
    sorted_words = sorted(freq.items(), key=lambda x: x[1], reverse=True)
    return [w for w, _ in sorted_words[:30]]


def find_markdown_files(vault_path: Path) -> list[Path]:
    """Find all markdown files, excluding hidden dirs and templates."""
    files = []
    exclude_dirs = {".obsidian", ".vault-index", ".trash", "templates", ".git"}

    for path in vault_path.rglob("*.md"):
        parts = path.relative_to(vault_path).parts
        if any(part.startswith(".") or part in exclude_dirs for part in parts):
            continue
        files.append(path)

    return sorted(files)


def load_existing_index(index_dir: Path) -> tuple[Optional[np.ndarray], dict]:
    """Load existing index if available."""
    embeddings_path = index_dir / "embeddings.npy"
    metadata_path = index_dir / "metadata.json"

    if embeddings_path.exists() and metadata_path.exists():
        embeddings = np.load(embeddings_path)
        with open(metadata_path) as f:
            metadata = json.load(f)
        return embeddings, metadata

    return None, {"version": 2, "model": DEFAULT_MODEL, "files": {}, "blocks": []}


def save_index(index_dir: Path, embeddings: np.ndarray, metadata: dict):
    """Save index to disk."""
    index_dir.mkdir(parents=True, exist_ok=True)

    np.save(index_dir / "embeddings.npy", embeddings)
    with open(index_dir / "metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)


def build_index(
    vault_path: Path,
    model_name: str = DEFAULT_MODEL,
    block_level: bool = True,
    incremental: bool = True,
    force: bool = False,
    min_block_size: int = 100,
):
    """Build or update the embedding index."""
    index_dir = vault_path / ".vault-index"

    # Load existing index
    existing_embeddings, metadata = load_existing_index(index_dir)

    # Force rebuild if model changed or version mismatch
    if metadata.get("model") != model_name or metadata.get("version", 1) < 2:
        print(f"Model or version changed, forcing full rebuild")
        force = True

    if force:
        existing_embeddings = None
        metadata = {"version": 2, "model": model_name, "files": {}, "blocks": []}

    # Find all markdown files
    md_files = find_markdown_files(vault_path)
    print(f"Found {len(md_files)} markdown files")

    # Determine which files need (re)indexing
    files_to_index = []
    files_unchanged = []

    for path in md_files:
        rel_path = str(path.relative_to(vault_path))
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            content = path.read_text(encoding="latin-1")

        current_hash = hash_content(content)

        if incremental and rel_path in metadata["files"]:
            if metadata["files"][rel_path].get("hash") == current_hash:
                files_unchanged.append(rel_path)
                continue

        files_to_index.append((path, rel_path, content, current_hash))

    # Handle deleted files
    existing_paths = set(metadata["files"].keys())
    current_paths = {str(p.relative_to(vault_path)) for p in md_files}
    deleted_paths = existing_paths - current_paths

    if deleted_paths:
        print(f"Removing {len(deleted_paths)} deleted files from index")

    if not files_to_index and not deleted_paths:
        print("Index is up to date, no changes needed")
        return

    print(f"Indexing {len(files_to_index)} files ({len(files_unchanged)} unchanged)")
    if block_level:
        print("Using block-level embeddings")

    # Load model
    print(f"Loading embedding model: {model_name}...")
    model = get_model(model_name)

    # Build new blocks list
    new_blocks = []
    new_file_metadata = {}

    # First, preserve unchanged files' blocks
    if existing_embeddings is not None:
        old_blocks = metadata.get("blocks", [])
        for rel_path in files_unchanged:
            file_info = metadata["files"][rel_path]
            block_indices = file_info.get("block_indices", [file_info.get("index")])

            for old_idx in block_indices:
                if old_idx is not None and old_idx < len(old_blocks):
                    old_block = old_blocks[old_idx].copy()
                    old_block["embedding_idx"] = len(new_blocks)
                    new_blocks.append(old_block)

            # Update file metadata with new block indices
            new_indices = list(range(len(new_blocks) - len(block_indices), len(new_blocks)))
            new_file_metadata[rel_path] = {
                "hash": file_info["hash"],
                "title": file_info["title"],
                "keywords": file_info.get("keywords", []),
                "block_indices": new_indices,
            }

    # Process new/changed files
    all_texts_to_embed = []
    embedding_map = []  # Maps embedding index to (rel_path, block_info)

    for i, (path, rel_path, content, file_hash) in enumerate(files_to_index):
        try:
            title = extract_title(content, path)
            keywords = extract_keywords(content)

            if block_level:
                blocks = extract_blocks(content, path, min_block_size)
            else:
                # File-level: single block per file
                blocks = [
                    {
                        "text": f"{title}\n{title}\n{content}",
                        "heading": title,
                        "start_line": 0,
                        "preview": content[:150].replace("\n", " ").strip(),
                    }
                ]

            block_indices = []
            for block in blocks:
                # Prepend file context to block for better embeddings
                embed_text = f"File: {title}\nSection: {block['heading']}\n\n{block['text']}"
                all_texts_to_embed.append(embed_text)

                block_info = {
                    "file": rel_path,
                    "heading": block["heading"],
                    "start_line": block["start_line"],
                    "preview": block["preview"],
                    "embedding_idx": None,  # Will be set after embedding
                }
                embedding_map.append((rel_path, block_info))
                block_indices.append(len(new_blocks) + len(embedding_map) - 1)

            new_file_metadata[rel_path] = {
                "hash": file_hash,
                "title": title,
                "keywords": keywords,
                "block_indices": block_indices,
            }

            if (i + 1) % 10 == 0:
                print(f"  Processed {i + 1}/{len(files_to_index)} files")

        except Exception as e:
            print(f"  Error processing {rel_path}: {e}")

    # Generate embeddings in batch (much faster)
    if all_texts_to_embed:
        print(f"Generating embeddings for {len(all_texts_to_embed)} blocks...")
        new_embeddings = model.encode(
            all_texts_to_embed,
            show_progress_bar=True,
            batch_size=32,
        )

        # Add new blocks with their embeddings
        for idx, (rel_path, block_info) in enumerate(embedding_map):
            block_info["embedding_idx"] = len(new_blocks)
            new_blocks.append(block_info)

    # Combine embeddings
    if existing_embeddings is not None and files_unchanged:
        # Get embeddings for unchanged blocks
        old_blocks = metadata.get("blocks", [])
        unchanged_embeddings = []
        for rel_path in files_unchanged:
            file_info = metadata["files"][rel_path]
            block_indices = file_info.get("block_indices", [file_info.get("index")])
            for old_idx in block_indices:
                if old_idx is not None and old_idx < len(existing_embeddings):
                    unchanged_embeddings.append(existing_embeddings[old_idx])

        if unchanged_embeddings and all_texts_to_embed:
            all_embeddings = np.vstack(
                [
                    np.array(unchanged_embeddings, dtype=np.float32),
                    new_embeddings.astype(np.float32),
                ]
            )
        elif unchanged_embeddings:
            all_embeddings = np.array(unchanged_embeddings, dtype=np.float32)
        else:
            all_embeddings = new_embeddings.astype(np.float32)
    else:
        all_embeddings = new_embeddings.astype(np.float32) if all_texts_to_embed else np.array([])

    # Build final metadata
    final_metadata = {
        "version": 2,
        "model": model_name,
        "block_level": block_level,
        "files": new_file_metadata,
        "blocks": new_blocks,
    }

    # Save index
    save_index(index_dir, all_embeddings, final_metadata)

    total_blocks = len(new_blocks)
    total_files = len(new_file_metadata)
    print(f"\nIndex saved: {total_files} files, {total_blocks} blocks")
    print(f"  Embeddings: {index_dir / 'embeddings.npy'} ({all_embeddings.nbytes / 1024:.1f} KB)")
    print(f"  Metadata: {index_dir / 'metadata.json'}")


def main():
    parser = argparse.ArgumentParser(description="Build semantic search index for Obsidian vault")
    parser.add_argument(
        "vault",
        type=Path,
        nargs="?",
        default=Path.home() / "obsidian",
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--model",
        "-m",
        choices=list(MODELS.keys()),
        default=DEFAULT_MODEL,
        help=f"Embedding model to use (default: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--file-level",
        action="store_true",
        help="Use file-level embeddings only (faster, less granular)",
    )
    parser.add_argument(
        "--min-block-size",
        type=int,
        default=100,
        help="Minimum characters for a block (default: 100)",
    )
    parser.add_argument(
        "--incremental",
        action="store_true",
        default=True,
        help="Only index new/changed files (default)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Rebuild entire index from scratch",
    )

    args = parser.parse_args()

    if not args.vault.exists():
        print(f"Error: Vault not found at {args.vault}")
        sys.exit(1)

    build_index(
        args.vault,
        model_name=args.model,
        block_level=not args.file_level,
        incremental=not args.force,
        force=args.force,
        min_block_size=args.min_block_size,
    )


if __name__ == "__main__":
    main()
