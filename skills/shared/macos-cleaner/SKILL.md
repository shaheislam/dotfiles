---
name: macos-cleaner
description: Analyze and recover macOS disk space with safety-first protocols. Use when disk is full, investigating storage usage, cleaning caches, or auditing what's consuming space. Triggers on "disk full", "clean up disk", "free space", "storage usage", "what's using space", or "reclaim disk".
argument-hint: "[--deep] [--docker] [--dry-run] [--target ~/path]"
allowed-tools: Bash, Read, Glob, Grep
---

# macOS Cleaner

Analyze and recover disk space with safety-first protocols. Never auto-delete.

## Arguments

- `$ARGUMENTS` - Optional:
  - `--deep` - Include ~/Library and system caches in analysis
  - `--docker` - Focus on Docker/container storage
  - `--dry-run` - Analysis only, no cleanup commands
  - `--target PATH` - Analyze a specific directory

## Safety Rules (Non-Negotiable)

1. **NEVER** execute `rm -rf` without explicit user confirmation
2. **NEVER** use `docker system prune` or `docker volume prune` (too aggressive)
3. **NEVER** skip analysis to save time
4. **NEVER** delete items without showing what they contain and rebuild cost
5. **ALWAYS** present findings before any action
6. **ALWAYS** classify items by safety level before suggesting removal

## Phase 1: Disk Overview

```bash
# Overall disk usage
df -h /

# Top-level home directory usage (depth 1)
du -sh ~/* ~/.[!.]* 2>/dev/null | sort -rh | head -20
```

## Phase 2: Category Analysis

Analyze each major category:

```bash
# Developer caches
du -sh ~/.npm ~/.cache ~/.cargo ~/.rustup ~/.local 2>/dev/null | sort -rh

# Homebrew (cache + orphaned deps)
du -sh "$(brew --prefix)/Cellar" "$(brew --cache)" 2>/dev/null
brew autoremove --dry-run 2>/dev/null | tail -5

# Python caches
du -sh ~/.cache/pip ~/.local/pipx 2>/dev/null | sort -rh

# Nix store (if present)
du -sh /nix/store 2>/dev/null
nix-store --gc --print-dead 2>/dev/null | wc -l

# Application caches
du -sh ~/Library/Caches/* 2>/dev/null | sort -rh | head -15

# Xcode (if present)
du -sh ~/Library/Developer/Xcode/DerivedData 2>/dev/null
du -sh ~/Library/Developer/CoreSimulator 2>/dev/null
xcrun simctl list devices unavailable 2>/dev/null | grep -c "unavailable"

# Claude Code sessions
du -sh ~/.claude/projects 2>/dev/null

# Trash
du -sh ~/.Trash 2>/dev/null
```

If `--docker` or Docker is detected:
```bash
docker system df 2>/dev/null
docker images --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' 2>/dev/null | sort -t$'\t' -k2 -rh | head -15
docker volume ls --format '{{.Name}}' 2>/dev/null | while read v; do
  echo "$v: $(docker volume inspect "$v" --format '{{.Mountpoint}}')"
done
```

If `--deep`:
```bash
# Large files anywhere in home
find ~ -type f -size +100M -not -path "*/\.*Time Machine*" 2>/dev/null | head -20 | while read f; do
  du -sh "$f"
done

# Old downloads
find ~/Downloads -type f -mtime +90 2>/dev/null | wc -l
du -sh ~/Downloads 2>/dev/null
```

## Phase 3: Classify Findings

Present a table with safety classification:

| Item | Size | Safety | Contents | Rebuild Cost |
|------|------|--------|----------|-------------|
| `~/.Trash` | 5.2G | SAFE | Deleted files already in trash | None |
| `brew --cache` | 3.1G | SAFE | Downloaded package archives | Re-downloads on next install |
| `~/.npm/_cacache` | 1.8G | CAUTION | npm package cache | Re-downloads, slow on bad network |
| `~/.cache/pip` | 500M | SAFE | pip download cache | Re-downloads on next install |
| `DerivedData` | 12G | CAUTION | Xcode build cache | 10-30 min rebuild per project |
| Unavailable sims | 3G | SAFE | Old iOS simulator runtimes | No rebuild cost |
| `~/.claude/projects` | 800M | CAUTION | Session history | Lost forever, use /continue-claude-work first |
| `/nix/store` dead | 5G | SAFE | Unreferenced Nix packages | Re-downloads if needed |
| `brew` orphans | 1G | SAFE | Unused dependency packages | Reinstalls if needed |
| Docker volumes | 8G | DANGER | May contain databases | Inspect before removing |

### Safety Levels

- **SAFE**: No data loss risk. Can be regenerated automatically.
- **CAUTION**: Regeneratable but with time/bandwidth cost. Explain trade-off.
- **DANGER**: May contain unique data. Requires inspection before removal.
- **PRESERVE**: Should never be deleted (active projects, configs, credentials).

## Phase 4: Generate Cleanup Commands

Present commands grouped by safety level. User executes them, we don't.

```bash
# === SAFE (no confirmation needed) ===
# Empty trash (X.XG)
# rm -rf ~/.Trash/*

# Clear Homebrew cache (X.XG)
# brew cleanup --prune=0

# Remove orphaned Homebrew dependencies (X.XG)
# brew autoremove

# Clear pip cache (X.XG)
# pip cache purge

# Remove unavailable Xcode simulators (X.XG)
# xcrun simctl delete unavailable

# Garbage-collect Nix store dead paths (X.XG)
# nix-collect-garbage -d

# === CAUTION (confirm each) ===
# Clear npm cache (X.XG) - will re-download on next install
# npm cache clean --force

# Clear Xcode DerivedData (X.XG) - projects rebuild in 10-30 min
# rm -rf ~/Library/Developer/Xcode/DerivedData/*

# === TOTAL RECOVERABLE: X.XG (safe) + X.XG (with trade-offs)
```

For Docker, list per-container/per-volume commands, never bulk prune:
```bash
# Remove specific unused image (confirm)
# docker rmi <image:tag>

# Remove specific volume (AFTER inspecting)
# docker volume rm <volume-name>
```

## Phase 5: Report

```
Disk Usage Report
=================
Total disk: XXG / XXG (XX% used)
Home directory: XXG

Recoverable space:
  SAFE:    X.XG (no risk)
  CAUTION: X.XG (with rebuild cost)
  DANGER:  X.XG (requires inspection)

Recommended: Start with SAFE items (X.XG savings, zero risk)
```

## Docker-Specific Safeguards

When handling Docker volumes:
1. List all volumes with their associated containers
2. Identify database volumes (mysql, postgres, redis, mongo)
3. For database volumes, suggest inspection before removal:
   ```bash
   # Inspect volume contents via temp container
   docker run --rm -v VOLUME_NAME:/data alpine ls -la /data
   ```
4. Delete per-project only, never batch

## What NOT to Clean

These are almost never worth cleaning (high rebuild cost, low space gain):
- `~/.ssh/` - SSH keys (tiny, irreplaceable)
- `~/.gnupg/` - GPG keys (tiny, irreplaceable)
- `~/.config/` - Application configs (tiny, hard to recreate)
- `~/Library/Keychains/` - macOS keychain (irreplaceable)
- Active git repos with uncommitted work
