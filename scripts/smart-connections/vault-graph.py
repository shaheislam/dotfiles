#!/usr/bin/env python3
"""
Obsidian Vault Connection Graph Export

Exports the semantic similarity graph as JSON for visualization.
Can be imported into tools like Obsidian's graph view or external visualizers.

Usage:
    # Export full graph (edges above threshold)
    vault-graph.py --output graph.json

    # Export with custom threshold
    vault-graph.py --threshold 0.6 --output graph.json

    # Export only top N connections per node
    vault-graph.py --top-per-node 5 --output graph.json

    # Export as DOT format for Graphviz
    vault-graph.py --format dot --output graph.dot
"""

import argparse
import json
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


def compute_file_embeddings(embeddings: np.ndarray, metadata: dict) -> dict[str, np.ndarray]:
    """Compute average embedding for each file from its blocks."""
    files = metadata.get("files", {})
    file_embeddings = {}

    for rel_path, file_info in files.items():
        block_indices = file_info.get("block_indices", [])
        if block_indices:
            file_emb = np.mean(embeddings[block_indices], axis=0)
            file_embeddings[rel_path] = file_emb

    return file_embeddings


def build_similarity_matrix(file_embeddings: dict[str, np.ndarray]) -> tuple[list[str], np.ndarray]:
    """Build pairwise similarity matrix for all files."""
    files = list(file_embeddings.keys())
    n = len(files)

    # Stack embeddings into matrix
    emb_matrix = np.array([file_embeddings[f] for f in files])

    # Normalize
    norms = np.linalg.norm(emb_matrix, axis=1, keepdims=True) + 1e-9
    emb_matrix = emb_matrix / norms

    # Compute all pairwise similarities
    sim_matrix = np.dot(emb_matrix, emb_matrix.T)

    return files, sim_matrix


def export_graph(
    vault_path: Path,
    embeddings: np.ndarray,
    metadata: dict,
    threshold: float = 0.4,
    top_per_node: int = None,
    include_clusters: bool = True,
) -> dict:
    """Export similarity graph as JSON structure."""
    files_meta = metadata.get("files", {})

    # Compute file-level embeddings
    file_embeddings = compute_file_embeddings(embeddings, metadata)

    if not file_embeddings:
        return {"nodes": [], "edges": [], "clusters": []}

    # Build similarity matrix
    files, sim_matrix = build_similarity_matrix(file_embeddings)

    # Build nodes
    nodes = []
    for rel_path in files:
        file_info = files_meta.get(rel_path, {})
        folder = str(Path(rel_path).parent)
        if folder == ".":
            folder = "root"

        nodes.append(
            {
                "id": rel_path,
                "label": file_info.get("title", Path(rel_path).stem),
                "folder": folder,
                "keywords": file_info.get("keywords", [])[:10],
            }
        )

    # Build edges
    edges = []
    n = len(files)

    for i in range(n):
        # Get similarities for this node
        sims = sim_matrix[i].copy()
        sims[i] = 0  # Exclude self

        if top_per_node:
            # Only keep top N connections
            top_indices = np.argsort(sims)[-top_per_node:]
            for j in top_indices:
                if sims[j] >= threshold:
                    edges.append(
                        {
                            "source": files[i],
                            "target": files[j],
                            "weight": float(sims[j]),
                        }
                    )
        else:
            # All connections above threshold
            for j in range(i + 1, n):  # Upper triangle only
                if sims[j] >= threshold:
                    edges.append(
                        {
                            "source": files[i],
                            "target": files[j],
                            "weight": float(sims[j]),
                        }
                    )

    # Simple clustering by folder
    clusters = []
    if include_clusters:
        folder_groups = {}
        for node in nodes:
            folder = node["folder"]
            if folder not in folder_groups:
                folder_groups[folder] = []
            folder_groups[folder].append(node["id"])

        for folder, members in folder_groups.items():
            clusters.append(
                {
                    "id": folder,
                    "label": folder,
                    "members": members,
                }
            )

    return {
        "nodes": nodes,
        "edges": edges,
        "clusters": clusters,
        "metadata": {
            "total_nodes": len(nodes),
            "total_edges": len(edges),
            "threshold": threshold,
            "top_per_node": top_per_node,
        },
    }


def export_dot(graph: dict) -> str:
    """Export graph as DOT format for Graphviz."""
    lines = ["graph VaultConnections {"]
    lines.append("  layout=fdp;")
    lines.append("  overlap=false;")
    lines.append("  splines=true;")
    lines.append("")

    # Nodes
    for node in graph["nodes"]:
        label = node["label"].replace('"', '\\"')[:30]
        folder = node["folder"]
        lines.append(f'  "{node["id"]}" [label="{label}" group="{folder}"];')

    lines.append("")

    # Edges
    for edge in graph["edges"]:
        weight = edge["weight"]
        # Scale weight for visualization
        penwidth = max(0.5, weight * 3)
        lines.append(f'  "{edge["source"]}" -- "{edge["target"]}" [weight={weight:.2f} penwidth={penwidth:.1f}];')

    lines.append("}")
    return "\n".join(lines)


def export_obsidian_canvas(graph: dict) -> dict:
    """Export as Obsidian Canvas format."""
    import math

    nodes = []
    edges = []

    # Arrange nodes in a circle
    n = len(graph["nodes"])
    radius = max(500, n * 30)

    for i, node in enumerate(graph["nodes"]):
        angle = (2 * math.pi * i) / n
        x = radius * math.cos(angle)
        y = radius * math.sin(angle)

        nodes.append(
            {
                "id": node["id"],
                "type": "file",
                "file": node["id"],
                "x": int(x),
                "y": int(y),
                "width": 250,
                "height": 50,
            }
        )

    for i, edge in enumerate(graph["edges"]):
        edges.append(
            {
                "id": f"edge_{i}",
                "fromNode": edge["source"],
                "toNode": edge["target"],
                "fromSide": "right",
                "toSide": "left",
            }
        )

    return {
        "nodes": nodes,
        "edges": edges,
    }


def main():
    parser = argparse.ArgumentParser(description="Export Obsidian vault semantic connection graph")
    parser.add_argument(
        "--vault",
        type=Path,
        default=Path.home() / "obsidian",
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--threshold",
        "-t",
        type=float,
        default=0.4,
        help="Minimum similarity threshold for edges (default: 0.4)",
    )
    parser.add_argument(
        "--top-per-node",
        "-n",
        type=int,
        help="Only include top N connections per node",
    )
    parser.add_argument(
        "--format",
        "-f",
        choices=["json", "dot", "canvas"],
        default="json",
        help="Output format (default: json)",
    )
    parser.add_argument(
        "--no-clusters",
        action="store_true",
        help="Don't include folder-based clusters",
    )

    args = parser.parse_args()

    # Load index
    index_dir = args.vault / ".vault-index"
    embeddings, metadata = load_index(index_dir)

    # Build graph
    graph = export_graph(
        args.vault,
        embeddings,
        metadata,
        args.threshold,
        args.top_per_node,
        not args.no_clusters,
    )

    # Format output
    if args.format == "dot":
        output = export_dot(graph)
    elif args.format == "canvas":
        output = json.dumps(export_obsidian_canvas(graph), indent=2)
    else:
        output = json.dumps(graph, indent=2)

    # Write output
    if args.output:
        args.output.write_text(output)
        print(f"Graph exported to {args.output}")
        print(f"  Nodes: {graph['metadata']['total_nodes']}")
        print(f"  Edges: {graph['metadata']['total_edges']}")
    else:
        print(output)


if __name__ == "__main__":
    main()
