# Dotfiles Refactoring Report

_Updated: 2026-02-13_
_Original: 2025-01-13_

## Performance Audit Results

### Baseline Measurement
- **Fish shell startup time**: 1.298s (before refactoring)
- **After refactoring**: 0.67-0.75s (warm cache)
- **Improvement**: ~500ms faster (40-50% reduction)

### Root Causes Identified

| Bottleneck | Time (ms) | Status |
|-----------|-----------|--------|
| `thefuck --alias` (uncached subprocess) | ~557ms | FIXED - now cached |
| `carapace _carapace fish` (uncached subprocess) | ~230ms | FIXED - now cached |
| `fzf --fish` (uncached subprocess) | ~69ms | FIXED - now cached |
| `mise settings add` (runs every startup) | ~50ms | FIXED - removed |
| `atuin uuid` (subprocess per startup) | ~15ms | Kept (needed for session ID) |
| `__cache_tool_init` version checks (subprocess per tool) | ~5-15ms x8 | FIXED - mtime-based |
| nix.fish (15KB parsed eagerly) | ~20-50ms | FIXED - functions lazy-loaded |

## Changes Made

### 1. Cache thefuck, carapace, fzf initialization (~856ms saved)
- `thefuck --alias | source` -> `__cache_tool_init thefuck "thefuck --alias"`
- `carapace _carapace fish | source` -> `__cache_tool_init carapace "carapace _carapace fish"`
- `fzf --fish | source` -> `__cache_tool_init fzf "fzf --fish"`

### 2. Improved `__cache_tool_init` function
- **Before**: Always called `tool --version` subprocess even on cache hits
- **After**: Uses binary mtime comparison - zero subprocess calls on cache hits
- Saves ~40-120ms across 8 cached tools

### 3. Removed per-startup `mise settings add` call
- `mise settings add idiomatic_version_file_enable_tools ruby` is a persistent setting
- Only needs to run once, not every shell startup

### 4. Moved nix.fish functions to lazy-loaded files
- Extracted 13 functions from 15KB conf.d/nix.fish to individual function files
- conf.d/nix.fish reduced from 421 lines to 58 lines (86% reduction)
- Functions now lazy-load on first use instead of parsing at startup
- Functions extracted: `nix-shell-with`, `nix-search`, `nix-update`, `nix-clean`, `nix-lsps`, `nix-init-flake`, `nix-status`, `nix-inheritance`, `hm-switch`, `hm-update`, `hm-packages`, `hm-generations`, `hm-rollback`, `nix-install`

## Future Improvement Suggestions

### High Impact (Terminal Speed)

#### 1. Extract inline functions from config.fish to function files
**Estimated savings**: 100-200ms
**Functionality impact**: None (preserves all features)

config.fish still has ~60+ inline function definitions (splash wrappers, AWS functions, git helpers, Docker functions, etc.). Each function defined inline is parsed on every startup. Moving them to `~/.config/fish/functions/` makes them lazy-loaded.

**Top candidates** (largest inline functions):
- `ssmc` (~100 lines) - AWS SSM connect
- `assume` (~80 lines) - Granted AWS role assumption
- `ct-view` (~140 lines) - CloudTrail viewer
- `gd-view` (~120 lines) - GuardDuty viewer
- `s3-logs`, `s3-dates`, `s3-browse`, `logs` (~200 lines combined)
- Splash wrapper functions (`docker`, `go`, `npm`, `yarn`, `pnpm`, `terraform`, `journalctl`, `tail`, `cat`, `less`) (~150 lines)
- `gwtaf`, `gwtabf`, `gco`, `gstash` (~100 lines)
- `dps`, `killp`, `psf`, `psg`, `port`, `ports` (~200 lines)

#### 2. Convert aliases to abbreviations
**Estimated savings**: 10-50ms
**Functionality impact**: Abbreviations expand in-place (visible in command line) vs aliases (transparent)

Fish abbreviations are slightly more efficient than aliases. The ~80+ aliases in config.fish could be converted to abbreviations where appropriate. Note: this changes UX slightly as abbreviations show the expanded form.

#### 3. Defer Atuin initialization
**Estimated savings**: ~15ms
**Functionality impact**: First command history might not be captured

The `atuin uuid` call could be deferred to first command execution rather than shell startup.

#### 4. Lazy-load the `done.fish` conf.d file
**Estimated savings**: ~20ms
**Functionality impact**: First long-running command might not trigger notification

The 14KB done.fish notification plugin loads eagerly. It could be restructured to only activate when a command actually finishes.

### Medium Impact (Simplicity)

#### 5. Remove deprecated Docker functions
The `dps` function and related Docker management functions are marked as deprecated (replaced by CTRL-D FZF keybindings). Removing them would reduce config.fish by ~50 lines.

#### 6. Consolidate duplicate FZF configuration
FZF configuration is split across config.fish and conf.d/fzf.fish. The rg/fd fallback logic and color theme could be unified.

#### 7. Remove WSL-specific code on macOS-only setups
If this is solely a macOS dotfiles repo, the WSL-specific block (~30 lines) in config.fish could be moved to a separate conf.d file that's only sourced on WSL.

### Low Impact (Code Quality)

#### 8. Standardize function naming
Current mix of `kebab-case` (nix-clean), `camelCase` (gwtaf), and `snake_case` (_atuin_preexec). Standardizing to `kebab-case` for public functions and `__underscore_prefix` for private would improve discoverability.

#### 9. Add function descriptions to all functions
Many inline functions lack `--description` flags. Fish uses these for completion hints and `functions --description` output.

#### 10. Audit abbreviation/alias overlap
Some commands have both an alias and an abbreviation (e.g., kubectl has aliases in config.fish AND abbreviations in plugins.fish). Consolidating would prevent confusion.

### Research-Based Suggestions

#### 11. Consider fish_add_path over manual PATH manipulation
The nix.fish file uses manual `contains` + `set -gx PATH` patterns. `fish_add_path` (Fish 3.2+) handles deduplication automatically and is idempotent.

#### 12. Profile with `fish --profile-startup`
Fish 3.7+ has `--profile-startup` which only profiles startup code (not the `exit` command). This gives more accurate startup profiling than `--profile`.

#### 13. Consider zoxide over z.fish
If not already migrated, zoxide (Rust-based) is significantly faster than the pure-Fish z.fish implementation for directory jumping.

## Implementation Priority

1. **Done**: Cache thefuck/carapace/fzf, improve __cache_tool_init, trim nix.fish
2. **Next**: Extract remaining inline functions from config.fish (items 1, 5, 7)
3. **Later**: Abbreviation conversion, done.fish deferral, naming standardization
