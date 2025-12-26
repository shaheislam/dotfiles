#!/Users/shaheislam/dotfiles/.venv/vault-search/bin/python3
"""
Obsidian Vault Embedding Visualization

Creates 2D visualizations of note embeddings using dimensionality reduction.
Outputs HTML with interactive visualization or PNG image.

Usage:
    # Generate interactive HTML visualization
    vault-visualize.py --output vault-map.html

    # Use UMAP instead of t-SNE (faster for large vaults)
    vault-visualize.py --method umap --output vault-map.html

    # Export just coordinates as JSON
    vault-visualize.py --format json --output coordinates.json

    # Color by folder
    vault-visualize.py --color-by folder --output vault-map.html
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


def compute_file_embeddings(embeddings: np.ndarray, metadata: dict) -> tuple[list[str], np.ndarray, list[dict]]:
    """Compute average embedding for each file from its blocks."""
    files_meta = metadata.get("files", {})
    files = []
    file_embeddings = []
    file_info_list = []

    for rel_path, file_info in files_meta.items():
        block_indices = file_info.get("block_indices", [])
        if block_indices:
            file_emb = np.mean(embeddings[block_indices], axis=0)
            files.append(rel_path)
            file_embeddings.append(file_emb)
            file_info_list.append({
                "path": rel_path,
                "title": file_info.get("title", Path(rel_path).stem),
                "folder": str(Path(rel_path).parent) if str(Path(rel_path).parent) != "." else "root",
                "keywords": file_info.get("keywords", [])[:5],
            })

    return files, np.array(file_embeddings), file_info_list


def reduce_dimensions(embeddings: np.ndarray, method: str = "tsne", perplexity: int = 30) -> np.ndarray:
    """Reduce embeddings to 2D using t-SNE or UMAP."""
    if method == "umap":
        try:
            from umap import UMAP
            reducer = UMAP(n_components=2, random_state=42, n_neighbors=15, min_dist=0.1)
            return reducer.fit_transform(embeddings)
        except ImportError:
            print("UMAP not installed. Install with: pip install umap-learn", file=sys.stderr)
            print("Falling back to t-SNE...", file=sys.stderr)
            method = "tsne"

    if method == "tsne":
        from sklearn.manifold import TSNE
        # Adjust perplexity for small datasets
        perplexity = min(perplexity, len(embeddings) - 1)
        perplexity = max(5, perplexity)
        tsne = TSNE(n_components=2, random_state=42, perplexity=perplexity, n_iter=1000)
        return tsne.fit_transform(embeddings)

    elif method == "pca":
        from sklearn.decomposition import PCA
        pca = PCA(n_components=2, random_state=42)
        return pca.fit_transform(embeddings)

    else:
        raise ValueError(f"Unknown method: {method}")


def generate_html_visualization(
    coordinates: np.ndarray,
    file_info: list[dict],
    color_by: str = "folder",
    title: str = "Obsidian Vault Map"
) -> str:
    """Generate interactive HTML visualization using Plotly."""

    # Prepare data
    x = coordinates[:, 0].tolist()
    y = coordinates[:, 1].tolist()
    labels = [f["title"] for f in file_info]
    paths = [f["path"] for f in file_info]
    folders = [f["folder"] for f in file_info]

    # Color mapping
    if color_by == "folder":
        colors = folders
    else:
        colors = ["note"] * len(file_info)

    # Generate unique colors for each folder
    unique_folders = list(set(folders))
    color_palette = [
        "#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00",
        "#ffff33", "#a65628", "#f781bf", "#999999", "#66c2a5",
        "#fc8d62", "#8da0cb", "#e78ac3", "#a6d854", "#ffd92f",
    ]

    folder_colors = {f: color_palette[i % len(color_palette)] for i, f in enumerate(unique_folders)}
    point_colors = [folder_colors[f] for f in folders]

    # Build HTML with embedded Plotly
    html = f"""<!DOCTYPE html>
<html>
<head>
    <title>{title}</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: #1a1a2e;
            color: #eee;
        }}
        h1 {{
            text-align: center;
            color: #7aa2f7;
        }}
        #chart {{
            width: 100%;
            height: 80vh;
        }}
        .legend {{
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            justify-content: center;
            margin-top: 10px;
        }}
        .legend-item {{
            display: flex;
            align-items: center;
            gap: 5px;
            padding: 5px 10px;
            background: #16213e;
            border-radius: 4px;
        }}
        .legend-color {{
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }}
    </style>
</head>
<body>
    <h1>{title}</h1>
    <div id="chart"></div>
    <div class="legend" id="legend"></div>

    <script>
        const data = {{
            x: {json.dumps(x)},
            y: {json.dumps(y)},
            labels: {json.dumps(labels)},
            paths: {json.dumps(paths)},
            folders: {json.dumps(folders)},
            colors: {json.dumps(point_colors)}
        }};

        const trace = {{
            x: data.x,
            y: data.y,
            mode: 'markers+text',
            type: 'scatter',
            text: data.labels,
            textposition: 'top center',
            textfont: {{
                size: 9,
                color: '#888'
            }},
            marker: {{
                size: 10,
                color: data.colors,
                opacity: 0.8,
                line: {{
                    color: '#fff',
                    width: 1
                }}
            }},
            hoverinfo: 'text',
            hovertext: data.labels.map((l, i) => `<b>${{l}}</b><br>${{data.paths[i]}}<br>Folder: ${{data.folders[i]}}`),
        }};

        const layout = {{
            paper_bgcolor: '#1a1a2e',
            plot_bgcolor: '#1a1a2e',
            font: {{ color: '#eee' }},
            showlegend: false,
            hovermode: 'closest',
            xaxis: {{
                showgrid: false,
                zeroline: false,
                showticklabels: false
            }},
            yaxis: {{
                showgrid: false,
                zeroline: false,
                showticklabels: false
            }},
            margin: {{ t: 20, b: 20, l: 20, r: 20 }}
        }};

        Plotly.newPlot('chart', [trace], layout);

        // Build legend
        const folderColors = {json.dumps(folder_colors)};
        const legend = document.getElementById('legend');
        for (const [folder, color] of Object.entries(folderColors)) {{
            const item = document.createElement('div');
            item.className = 'legend-item';
            item.innerHTML = `<div class="legend-color" style="background: ${{color}}"></div><span>${{folder}}</span>`;
            legend.appendChild(item);
        }}
    </script>
</body>
</html>"""

    return html


def main():
    parser = argparse.ArgumentParser(
        description="Visualize Obsidian vault embeddings in 2D"
    )
    parser.add_argument(
        "--vault",
        type=Path,
        default=Path.home() / "obsidian",
        help="Path to Obsidian vault (default: ~/obsidian)",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        required=True,
        help="Output file path",
    )
    parser.add_argument(
        "--method", "-m",
        choices=["tsne", "umap", "pca"],
        default="tsne",
        help="Dimensionality reduction method (default: tsne)",
    )
    parser.add_argument(
        "--perplexity", "-p",
        type=int,
        default=30,
        help="t-SNE perplexity (default: 30)",
    )
    parser.add_argument(
        "--color-by", "-c",
        choices=["folder", "none"],
        default="folder",
        help="How to color points (default: folder)",
    )
    parser.add_argument(
        "--format", "-f",
        choices=["html", "json"],
        default="html",
        help="Output format (default: html)",
    )

    args = parser.parse_args()

    # Load index
    index_dir = args.vault / ".vault-index"
    embeddings, metadata = load_index(index_dir)

    # Get file-level embeddings
    print("Computing file embeddings...")
    files, file_embeddings, file_info = compute_file_embeddings(embeddings, metadata)

    if len(files) < 3:
        print("Error: Need at least 3 files for visualization", file=sys.stderr)
        sys.exit(1)

    print(f"Reducing {len(files)} files to 2D using {args.method}...")
    coordinates = reduce_dimensions(file_embeddings, args.method, args.perplexity)

    if args.format == "json":
        output_data = {
            "method": args.method,
            "points": [
                {
                    "x": float(coordinates[i, 0]),
                    "y": float(coordinates[i, 1]),
                    **file_info[i]
                }
                for i in range(len(files))
            ]
        }
        args.output.write_text(json.dumps(output_data, indent=2))
    else:
        html = generate_html_visualization(
            coordinates,
            file_info,
            args.color_by,
            "Obsidian Vault Map"
        )
        args.output.write_text(html)

    print(f"Visualization saved to {args.output}")
    print(f"  Files visualized: {len(files)}")


if __name__ == "__main__":
    main()
