# Dotfiles Refactoring Plan

_Generated: 2025-01-13_

## Overview

This document outlines potential improvements identified in the dotfiles repository structure and organization.

## Priority Improvements

### 1. Fish Config Modularization (High Priority)

**Current State**:

- `config.fish` is 2,402 lines long
- Contains 63 embedded functions
- Difficult to navigate and maintain

**Proposed Solution**:

- Extract functions into separate files in `~/.config/fish/functions/`
- Create organized function groups:
  - `aws-functions.fish` - 11 AWS/S3 related functions
  - `git-functions.fish` - 10 git-related functions
  - `utility-functions.fish` - remaining utility functions
- Keep only initialization and environment setup in main `config.fish`

**Benefits**:

- Fish loads functions on-demand (performance improvement)
- Easier to find and modify specific functions
- Better organization for version control

### 2. Script Organization (Medium Priority)

**Current State**:

- 30 scripts in `/scripts` directory
- Inconsistent naming conventions
- No clear categorization

**Proposed Solution**:

```
scripts/
├── setup/         # Installation and setup scripts
├── aws/          # AWS-related utilities
├── tmux/         # Tmux management scripts
└── tools/        # Miscellaneous tools
```

**Benefits**:

- Clear organization by purpose
- Easier discovery of scripts
- Potential to consolidate similar scripts

### 3. Remove Backup/Archive Files (Quick Win)

**Current State**:

- Multiple `.backup`, `.bak`, `.archive` files found:
  - `.claude/usage/meta.json.bak`
  - `.claude/PERSONAS.md.archive`
  - `.config/fish/config.fish.backup`
  - Various other backup files

**Proposed Solution**:

- Remove all backup files from repository
- Add patterns to `.gitignore`:
  ```
  *.backup
  *.bak
  *.archive
  *.orig
  *~
  ```

**Benefits**:

- Cleaner repository
- Reduced clutter
- Prevents accidental commits of backup files

### 4. Setup Script Modularization (COMPLETED)

**Status**: DONE - The setup system has been consolidated and modularized.

**Current State**:

- `scripts/setup.sh` is the main orchestrator (~1,300 lines)
- Modular library files in `scripts/lib/`:
  - `common.sh` - Shared utilities and helpers
  - `package-manager.sh` - Cross-platform package management
  - `shell-setup.sh` - Shell configurations (Fish, Zsh, Oh My Zsh, Powerlevel10k)
- Phase-based execution for clean separation
- Cross-platform support (macOS and Linux)

**Benefits Achieved**:

- Modular execution via phases
- Library code reuse
- Better error isolation
- Profile-based installation (minimal, developer, comprehensive)

### 5. Config Duplication Cleanup (Low Priority)

**Current State**:

- Some configurations exist in multiple places
- Settings in both `conf.d/` and main config
- Potential conflicts or overrides

**Proposed Solution**:

- Audit all configuration files
- Consolidate plugin configurations
- Document configuration hierarchy
- Create clear separation of concerns

**Benefits**:

- Reduced confusion
- Predictable configuration behavior
- Easier troubleshooting

### 6. Path Management Consolidation (Quick Win)

**Current State**:

- Multiple PATH additions scattered throughout configs
- Hard to track what's adding to PATH
- Potential duplicates

**Proposed Solution**:

- Create `~/.config/fish/paths.fish`
- Centralize all PATH modifications
- Source from main config
- Add comments explaining each PATH addition

**Benefits**:

- Single source of truth for PATH
- Easier debugging of PATH issues
- Clear documentation of why each path is needed

### 7. Function Naming Standardization (Low Priority)

**Current State**:

- Inconsistent naming conventions
- Some functions use underscores, others don't
- No clear naming pattern

**Proposed Solution**:

- Adopt consistent naming convention:
  - Private functions: `__function_name`
  - Public functions: `function_name`
  - AWS functions: `aws_function_name`
  - Git functions: `git_function_name`
- Add descriptive comments to complex functions

**Benefits**:

- Predictable function names
- Clear public/private distinction
- Better autocomplete suggestions

### 8. Documentation Generation (Nice to Have)

**Current State**:

- No comprehensive list of available functions
- Users must read source to discover features

**Proposed Solution**:

- Add header comments to all functions
- Generate `FUNCTIONS.md` with:
  - Function name
  - Description
  - Usage examples
  - Parameters
- Consider using a documentation generator

**Benefits**:

- Better discoverability
- Easier onboarding for new machines
- Reference documentation

## Implementation Strategy

### Phase 1: Quick Wins (1-2 hours)

1. Remove backup files
2. Update `.gitignore`
3. Consolidate PATH management

### Phase 2: Function Extraction (2-4 hours)

1. Extract AWS functions
2. Extract Git functions
3. Extract utility functions
4. Test all functions still work

### Phase 3: Script Organization (2-3 hours)

1. Create directory structure
2. Move scripts to appropriate directories
3. Update any references to scripts

### Phase 4: Setup Script Refactor (3-4 hours)

1. Split setup script into modules
2. Test each module independently
3. Update main script to source modules

### Phase 5: Documentation (2-3 hours)

1. Add function documentation
2. Generate FUNCTIONS.md
3. Update main README

## Expected Outcomes

- **Performance**: Faster shell startup time
- **Maintainability**: Easier to modify and extend
- **Discoverability**: Clear organization and documentation
- **Reliability**: Modular components easier to test
- **Collaboration**: Better structure for sharing/contributing

## Notes

- All changes should be tested on a fresh system
- Consider creating a backup branch before major refactoring
- Each phase can be implemented independently
- Prioritize based on immediate needs and available time

