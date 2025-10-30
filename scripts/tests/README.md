# Comprehensive Dotfiles Validation Tests

Validation test suite for dotfiles with **~65% comprehensive coverage** (Option 2 implementation).

## Test Coverage Overview

| Category | Coverage | Tests | Description |
|----------|----------|-------|-------------|
| Cross-Platform Abstractions | 100% | 50+ | OS detection, clipboard, paths, services |
| Fish Function Execution | 30% | 40+ | Actual function execution tests |
| Plugin Functionality | 70% | 45+ | Plugin behavior validation |
| Tool Integrations | 85% | 30+ | Fisher, OMZ, TPM, FZF, etc. |
| MCP Server Runtime | 60% | 35+ | MCP server invocation tests |
| Fish/Zsh Parity | 40% | 20+ | Shell equivalence testing |
| Error Scenarios | 50% | 30+ | Graceful degradation |
| Configuration Files | 50% | 15+ | Config validation |
| Performance | 30% | 5+ | Startup time benchmarks |

**Overall**: ~65% of dotfiles functionality tested

## Quick Start

### Run Comprehensive Validation

```bash
cd ~/dotfiles
./scripts/validate-comprehensive.sh
```

### Run Individual Test Modules

```bash
# Cross-platform abstractions
./scripts/tests/test-cross-platform.sh

# Fish function execution
./scripts/tests/test-fish-functions.sh

# Plugin functionality
./scripts/tests/test-plugin-functionality.sh

# MCP server runtime
./scripts/tests/test-mcp-runtime.sh

# Error scenarios
./scripts/tests/test-error-scenarios.sh
```

## Test Categories

### 1. Cross-Platform Abstractions ✅ (100% coverage)
**File**: `test-cross-platform.sh`

**What's tested**:
- Clipboard operations (pbcopy vs xclip/xsel/wl-copy)
- PATH management (macOS Homebrew vs Linux)
- Package managers (brew vs apt/dnf/yum/pacman)
- tmux shell configuration
- asdf version manager initialization
- Notification systems (terminal-notifier vs notify-send)
- Python site-packages paths
- Service management (launchd vs systemd)
- File watching tools (fswatch vs inotify-tools)
- npm installation strategies

**Test count**: 50+ tests

### 2. Fish Function Execution ⚡ (30% coverage)
**File**: `test-fish-functions.sh`

**What's tested** (20+ functions):
- `clipboard_copy` - Actual copy/paste verification
- `reset_fish` - Terminal reset functionality
- `grt`, `gwip`, `gunwip`, `gdv` - Git workflows
- `__git.current_branch`, `__git.default_branch` - Git helpers
- `cless`, `man`, `zcode` - Utility functions
- FZF functions - Search functionality
- Zoxide functions - Directory jumping
- Editor functions - Cursor, VS Code integration
- Abbreviation & autopair functions

**What's NOT tested** (60+ functions):
- AWS functions (requires AWS credentials)
- Kubernetes functions (requires cluster)
- Most git workflow functions
- History manipulation functions

**Test count**: 40+ tests

### 3. Plugin Functionality 🔌 (70% coverage)
**File**: `test-plugin-functionality.sh`

**What's tested**:
- **Fisher (Fish)**: Plugin listing, function loading
- **fzf.fish**: Keybindings, search functions
- **done**: Notification configuration, OS detection
- **Abbreviation tips**: Initialization, bind functions
- **Autopair**: Pairing logic, keybindings
- **Bang-bang**: History access
- **Oh My Zsh**: Plugin loading, aliases
- **zsh-autosuggestions**: Variable configuration
- **zsh-syntax-highlighting**: Plugin presence
- **TPM**: Plugin installation, tmux startup
- **tmux-yank**: Clipboard integration
- **FZF integration**: Environment vars, keybindings, search
- **Starship**: Prompt rendering, transient prompt
- **Zoxide**: Database queries, z command
- **direnv**: Hook activation, .envrc processing

**Test count**: 45+ tests

### 4. Tool Integrations ⚙️ (85% coverage)
**File**: Inline in `validate-comprehensive.sh`

**What's tested**:
- Fisher plugin manager
- Oh My Zsh plugin system
- TPM (tmux plugin manager)
- FZF (fuzzy finder)
- Starship (prompt)
- Zoxide (directory jumping)
- direnv (environment management)

**Test count**: 30+ tests

### 5. MCP Server Runtime 🤖 (60% coverage)
**File**: `test-mcp-runtime.sh`

**What's tested**:
- Runtime dependencies (bunx, pipx, uvx)
- Claude Desktop config (JSON validation)
- JavaScript MCP servers (8 servers tested)
  - browser-tools, sequential-thinking, github, memory
  - playwright, context7, duckduckgo, steampipe
- Python MCP servers (3 servers tested)
  - git, fetch, filesystem
- AWS MCP servers (5 servers tested)
  - aws-diagram, aws-documentation, aws-cdk, aws-iam
- MCP parity (Desktop vs CLI config)
- Error handling (non-blocking installations)
- Timeout behavior (5s timeout tests)

**What's NOT tested**:
- Actual MCP server responses
- MCP server functionality
- Complex MCP workflows

**Test count**: 35+ tests

### 6. Fish/Zsh Parity 🐚 (40% coverage)
**File**: Inline in `validate-comprehensive.sh`

**What's tested**:
- Environment variables (EDITOR, VISUAL, LANG)
- Tool initialization (starship, zoxide, direnv, fzf)
- Python alias

**What's NOT tested**:
- PATH parity
- Function equivalence
- Completion parity
- Keybinding equivalence

**Test count**: 20+ tests

### 7. Error Scenarios & Graceful Degradation 🛡️ (50% coverage)
**File**: `test-error-scenarios.sh`

**What's tested**:
- Missing tool handling
- Invalid Git operations (non-git directories)
- Missing dependencies (fzf, zoxide, direnv)
- Corrupted config detection
- Permission errors
- Network failures
- Plugin load failures
- Resource exhaustion (timeouts)
- PATH configuration errors
- Symlink conflicts

**Test count**: 30+ tests

### 8. Configuration Files 📝 (50% coverage)
**File**: Inline in `validate-comprehensive.sh`

**What's tested**:
- Shell configs (syntax validation)
- Tool configs (existence checks)
- Stow symlinks

**Test count**: 15+ tests

### 9. Performance Metrics ⚡ (30% coverage)
**File**: Inline in `validate-comprehensive.sh`

**What's tested**:
- Fish startup time (<1s)
- Zsh startup time (<1s)

**What's NOT tested**:
- Command completion latency
- Plugin load times
- Memory usage
- Network operation timeouts

**Test count**: 5+ tests

## Test Infrastructure

### Test Helpers Library
**File**: `lib/test-helpers.sh`

**Provides**:
- Test execution wrappers with timing
- Color-coded output functions
- OS detection utilities
- Clipboard testing helpers
- Git repo test utilities
- Performance measurement tools
- Test result tracking & summaries

### Test Execution Flow

```
validate-comprehensive.sh
├── Sources test-helpers.sh
├── Runs cross-platform tests
├── Runs fish-functions tests  ← NEW (Option 2)
├── Runs plugin-functionality tests  ← NEW (Option 2)
├── Runs inline tool integration tests
├── Runs inline fish-functions tests (sample)
├── Runs mcp-runtime tests  ← NEW (Option 2)
├── Runs inline parity tests
├── Runs error-scenarios tests  ← NEW (Option 2)
├── Runs inline config tests
├── Runs inline performance tests
└── Generates comprehensive summary
```

## Expected Output

```
========================================
  Comprehensive Dotfiles Validation
  OS: macOS
  [timestamp]
========================================

[Test output for each category...]

========================================
COMPREHENSIVE VALIDATION SUMMARY
========================================

Test Results by Category:
==========================
  ✅ Cross-Platform Abstractions
  ✅ Fish Function Execution
  ✅ Plugin Functionality
  ✅ Tool Integrations
  ✅ Fish Functions
  ✅ MCP Server Runtime
  ✅ Fish/Zsh Parity
  ✅ Error Scenarios & Graceful Degradation
  ✅ Configuration Files
  ✅ Performance

Performance Metrics:
===================
  Fish startup: 320ms
  Zsh startup: 450ms

Overall Category Pass Rate: 100% (10/10)

✅ COMPREHENSIVE VALIDATION PASSED
Your dotfiles are well-configured and functional!
Coverage: ~65% (Option 2 implementation complete)
```

## Coverage Roadmap

### Current: Option 2 (~65% coverage) ✅
- Function execution tests
- Plugin functionality tests
- MCP runtime invocation
- Error scenario testing

### Future: Option 3 (~90% coverage)
- Integration workflow tests
- Complete Fish/Zsh parity validation
- Full MCP response testing
- Performance regression suite
- Setup script validation
- Accessibility testing

## Development

### Adding New Tests

1. **Create test module**:
   ```bash
   cp scripts/tests/test-cross-platform.sh scripts/tests/test-new-category.sh
   chmod +x scripts/tests/test-new-category.sh
   ```

2. **Update validate-comprehensive.sh**:
   ```bash
   run_category "New Category" "$SCRIPT_DIR/tests/test-new-category.sh"
   ```

3. **Update summary categories**:
   Add to the category loop in final summary section.

### Test Writing Guidelines

- Use `run_test` for critical tests (failures count as failures)
- Use `run_test_warn` for optional tests (failures count as warnings)
- Use `run_test_expect` for output validation tests
- Always include test descriptions
- Group related tests with `print_subheader`
- Clean up test artifacts
- Handle missing dependencies gracefully with `((TESTS_SKIPPED++))`

## Known Limitations

1. **AWS Functions**: Not tested (requires AWS credentials)
2. **Kubernetes Functions**: Not tested (requires cluster)
3. **MCP Response Testing**: Only invocation tested, not responses
4. **Integration Workflows**: No end-to-end scenario testing
5. **Performance Regression**: No historical baseline tracking

## Contributing

When adding new dotfiles features:
1. Update relevant test module
2. Add tests for new functions
3. Update this README
4. Run validation suite before committing

## License

Part of personal dotfiles repository.
