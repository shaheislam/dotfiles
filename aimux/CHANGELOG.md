# Changelog

All notable changes to aimux are documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.2.0] - 2026-03-14

### Added
- TOML configuration system (`~/.aimux/config.toml`) with env var overrides
- Provider plugin system with built-in providers: claude, codex, ollama
- Go daemon (`aimuxd`) with proper signal handling and PID file locking
- Workspace state persistence (`~/.aimux/state/*.json`) with atomic writes
- Witness process for agent lifecycle monitoring
- Queue system with priority dispatch and concurrent execution limits
- Log viewer (`aimux log`) with follow, workspace filtering, and clear
- Launch templates (`templates/launch/`) for reproducible agent startup
- Integration test suite (BATS) for new, kill, status, run
- Unit test suite (BATS) for _common.sh and _config.sh
- Go test suite for config, state, and queue packages
- CI/CD via GitHub Actions (shellcheck, bats, go test, release)
- Architecture documentation
- Provider system documentation
- Configuration reference documentation
- Migration guide from dotfiles gwt-* functions

### Changed
- Version bump from 0.1.0 to 0.2.0
- Configuration format changed from YAML to TOML
- Status command reads from state files with live tmux fallback
- Run command uses provider abstraction instead of hardcoded claude/codex
- Daemon uses provider system for state detection
- Kill command cleans up state files and witness processes
- Help text updated with log command and configuration path
- Completions updated for log subcommand and provider flag values

### Fixed
- Daemon PID file race condition (Go binary uses flock)
- State persistence across daemon restarts

## [0.1.0] - 2026-03-13

### Added
- Initial MVP with core subcommands: new, status, run, attach, kill, doctor, daemon, notify
- Shell completions for Fish, Bash, and Zsh
- Homebrew formula
- Tokyo Night color scheme for agent state display
- Queue stub (placeholder for full implementation)
- CLI smoke tests (BATS)
- tmux config snippet for status bar integration
