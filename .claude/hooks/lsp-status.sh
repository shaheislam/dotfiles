#!/bin/bash
# SessionStart hook: Report available LSP servers to Claude Code context
# This injects a system message so Claude knows which LSP capabilities are active.
# Lightweight: only checks PATH for binaries, no network calls.

# LSP binary → language mapping
declare -A LSP_BINS=(
    ["pyright-langserver"]="Python"
    ["typescript-language-server"]="TypeScript/JavaScript"
    ["gopls"]="Go"
    ["rust-analyzer"]="Rust"
    ["bash-language-server"]="Bash/Shell"
    ["yaml-language-server"]="YAML"
    ["terraform-ls"]="Terraform"
    ["lua-language-server"]="Lua"
    ["nil"]="Nix"
)

available=()
for bin in "${!LSP_BINS[@]}"; do
    if command -v "$bin" >/dev/null 2>&1; then
        available+=("${LSP_BINS[$bin]}")
    fi
done

# Only output if at least one LSP is available
if [ ${#available[@]} -gt 0 ]; then
    # Sort for consistent output
    IFS=$'\n' sorted=($(sort <<<"${available[*]}"))
    unset IFS

    echo "LSP servers active: ${sorted[*]}. Use the LSP tool for code intelligence (goToDefinition, findReferences, hover, documentSymbol, workspaceSymbol)."
fi

exit 0
