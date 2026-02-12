#!/usr/bin/env python3
"""
DeepWiki Context Injection Hook

Injects relevant DeepWiki repository recommendations based on file type.
When Claude reads a file, this hook suggests repos that can be queried
via mcp__deepwiki__ask_question for best practices guidance.
"""

import json
import sys
from pathlib import Path

# Language-to-repo mapping (curated best practice sources)
LANGUAGE_REPOS = {
    # Python ecosystem
    "python": ["python/cpython", "pallets/flask", "django/django", "fastapi/fastapi"],
    # TypeScript/JavaScript ecosystem
    "typescript": ["microsoft/TypeScript", "DefinitelyTyped/DefinitelyTyped", "total-typescript/ts-reset"],
    "javascript": ["nodejs/node", "facebook/react", "vuejs/core"],
    # Go ecosystem
    "go": ["golang/go", "gin-gonic/gin", "gofiber/fiber"],
    # Rust ecosystem
    "rust": ["rust-lang/rust", "tokio-rs/tokio", "serde-rs/serde"],
    # DevOps/Config
    "yaml": ["kubernetes/kubernetes", "helm/helm"],
    "dockerfile": ["moby/moby", "docker/compose"],
    "terraform": ["hashicorp/terraform", "gruntwork-io/terragrunt"],
    # Shell
    "bash": ["koalaman/shellcheck", "dylanaraps/pure-bash-bible"],
    "fish": ["fish-shell/fish-shell"],
    # Lua (Neovim)
    "lua": ["neovim/neovim", "folke/lazy.nvim", "LazyVim/LazyVim"],
    # Nix
    "nix": ["NixOS/nixpkgs", "nix-community/home-manager"],
}

# Extension to language mapping
EXTENSION_MAP = {
    # Python
    ".py": "python",
    ".pyi": "python",
    ".pyx": "python",
    # TypeScript/JavaScript
    ".ts": "typescript",
    ".tsx": "typescript",
    ".mts": "typescript",
    ".cts": "typescript",
    ".js": "javascript",
    ".jsx": "javascript",
    ".mjs": "javascript",
    ".cjs": "javascript",
    # Go
    ".go": "go",
    # Rust
    ".rs": "rust",
    # DevOps
    ".yaml": "yaml",
    ".yml": "yaml",
    ".tf": "terraform",
    ".hcl": "terraform",
    # Shell
    ".sh": "bash",
    ".bash": "bash",
    ".fish": "fish",
    # Lua
    ".lua": "lua",
    # Nix
    ".nix": "nix",
}


def get_language_from_path(file_path: str) -> str | None:
    """Detect language from file path."""
    path = Path(file_path)

    # Check for special filenames
    filename = path.name.lower()
    if filename == "dockerfile" or filename.startswith("dockerfile."):
        return "dockerfile"
    if filename in ("go.mod", "go.sum"):
        return "go"
    if filename in ("cargo.toml", "cargo.lock"):
        return "rust"
    if filename == "flake.nix":
        return "nix"

    # Check extension
    suffix = path.suffix.lower()
    return EXTENSION_MAP.get(suffix)


def main():
    try:
        # Read input data from stdin
        input_data = json.load(sys.stdin)

        tool_input = input_data.get("tool_input", {})
        file_path = tool_input.get("file_path", "")

        if not file_path:
            sys.exit(0)

        # Detect language
        language = get_language_from_path(file_path)

        if not language:
            sys.exit(0)  # Unknown language, no context needed

        # Get relevant repos
        repos = LANGUAGE_REPOS.get(language, [])

        if not repos:
            sys.exit(0)

        # Build minimal system message (top 3 repos)
        repo_list = ", ".join(repos[:3])

        output = {"systemMessage": f"DeepWiki repos for {language}: {repo_list}"}

        print(json.dumps(output))
        sys.exit(0)

    except Exception:
        # Silent failure - never block reads
        sys.exit(0)


if __name__ == "__main__":
    main()
