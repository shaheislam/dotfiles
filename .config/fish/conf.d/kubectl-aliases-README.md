# kubectl-aliases Integration with fzf

## Overview

This directory contains auto-generated kubectl aliases from [ahmetb/kubectl-aliases](https://github.com/ahmetb/kubectl-aliases). The aliases work seamlessly with the existing fzf integration in `~/.config/fish/functions/kubectl.fish`.

## How It Works

1. **Alias Expansion (First)**: Fish abbreviations expand before command execution
   - `kgpo` → `kubectl get pod`
   - `kgdep` → `kubectl get deployment`
   - `ksysgpo` → `kubectl --namespace=kube-system get pod`

2. **kubectl Wrapper Intercepts (Second)**: `~/.config/fish/functions/kubectl.fish` checks if command is `get`
   - If `get` detected, triggers fzf interactive selection
   - If `-o/--output` flag present, skips fzf (direct output mode)

3. **fzf Integration Activates (Third)**:
   - Interactive resource selection via `kubectl-fzf-wrapper.sh`
   - YAML preview with bat syntax highlighting
   - Custom keybindings:
     - `Ctrl-D` / `Ctrl-U`: Page down/up in preview
     - `Ctrl-Y`: Open full YAML in bat (paginated)
     - `Ctrl-E`: Describe resource with `kubectl describe`

## Examples

```fish
# Simple pod listing with fzf
kgpo
# Expands to: kubectl get pod
# Triggers fzf interactive selection

# Deployment in kube-system namespace
ksysgdep
# Expands to: kubectl --namespace=kube-system get deployment
# Triggers fzf with namespace filter

# Direct YAML output (skips fzf)
kgpooyaml
# Expands to: kubectl get pods -o=yaml
# Skips fzf due to -o flag, outputs directly
```

## Alias Categories

- **Basic operations**: `k`, `kg` (get), `kd` (describe), `krm` (delete)
- **Resources**: `po` (pods), `dep` (deployment), `svc` (service), `ing` (ingress)
- **Namespaces**: `sys` prefix for kube-system (e.g., `ksysgpo`)
- **Output formats**: `oyaml` (YAML), `owide` (wide), `ojson` (JSON)
- **Flags**: `sl` (show-labels), `w` (watch), `all` (all-namespaces)

## Regenerating Aliases

The aliases are automatically generated during setup via `scripts/setup.sh`. To manually regenerate:

```bash
cd ~/dotfiles
python3 scripts/generate-kubectl-aliases.py fish > .config/fish/conf.d/kubectl-aliases.fish
```

## Compatibility Notes

✅ **Works with**:
- fzf interactive selection
- YAML/JSON preview in bat
- Namespace filtering
- Watch mode (without fzf)
- Label selectors

⚠️ **Bypasses fzf when**:
- `-o/--output` flag is present (intended behavior)
- Output format specified in alias (e.g., `kgpooyaml`)

## Total Aliases

780 aliases covering all common kubectl operations and resource types.
