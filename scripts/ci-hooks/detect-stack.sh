#!/usr/bin/env bash
# detect-stack.sh — Detect technology stack from project marker files.
# Outputs one or more stack identifiers, one per line.
# Exit 0 with output = detected; exit 1 = no detection.

set -euo pipefail

PROJECT_DIR="${1:-.}"

# Resolve to absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

detected=()

# Node / TypeScript
if [[ -f "$PROJECT_DIR/package.json" ]]; then
    if [[ -f "$PROJECT_DIR/tsconfig.json" ]] || grep -q '"typescript"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        detected+=(typescript)
    else
        detected+=(node)
    fi
fi

# Python
if [[ -f "$PROJECT_DIR/pyproject.toml" ]] || [[ -f "$PROJECT_DIR/setup.py" ]] || [[ -f "$PROJECT_DIR/setup.cfg" ]] || [[ -f "$PROJECT_DIR/requirements.txt" ]]; then
    detected+=(python)
fi

# Go
if [[ -f "$PROJECT_DIR/go.mod" ]]; then
    detected+=(go)
fi

# Rust
if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
    detected+=(rust)
fi

# Ruby
if [[ -f "$PROJECT_DIR/Gemfile" ]]; then
    detected+=(ruby)
fi

# Java / Kotlin
if [[ -f "$PROJECT_DIR/pom.xml" ]] || [[ -f "$PROJECT_DIR/build.gradle" ]] || [[ -f "$PROJECT_DIR/build.gradle.kts" ]]; then
    detected+=(java)
fi

# Terraform
if compgen -G "$PROJECT_DIR/*.tf" >/dev/null 2>&1; then
    detected+=(terraform)
fi

# Docker
if [[ -f "$PROJECT_DIR/Dockerfile" ]] || [[ -f "$PROJECT_DIR/docker-compose.yml" ]] || [[ -f "$PROJECT_DIR/docker-compose.yaml" ]]; then
    detected+=(docker)
fi

# Shell scripts (if scripts/ dir has .sh files)
if compgen -G "$PROJECT_DIR/scripts/*.sh" >/dev/null 2>&1 || compgen -G "$PROJECT_DIR/*.sh" >/dev/null 2>&1; then
    detected+=(shell)
fi

if [[ ${#detected[@]} -eq 0 ]]; then
    exit 1
fi

printf '%s\n' "${detected[@]}"
