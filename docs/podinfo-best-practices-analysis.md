# Best Practices Analysis: stefanprodan/podinfo

> Extracted from [podinfo](https://github.com/stefanprodan/podinfo) — a CNCF reference
> implementation showcasing microservice best practices in Kubernetes.

## Research Summary

### What podinfo does well (language-agnostic patterns)

| Pattern | podinfo Implementation | Dotfiles Equivalent |
|---------|----------------------|---------------------|
| **Unified Makefile** | Single `Makefile` for run/test/build/fmt/vet/release/version-set | No root Makefile — scattered scripts |
| **Test pyramid** | Unit tests → config validation → e2e tests (Kind clusters) | smoke-test.sh + CI validation (good, but not unified) |
| **Dirty tree check** | CI verifies no uncommitted changes after test runs | Missing |
| **Concurrency groups** | Workflows use `concurrency:` to cancel stale runs | Only in `validate-dotfiles.yml` |
| **Multi-stage Docker** | Builder → minimal alpine with non-root user | Devcontainer only (not optimized) |
| **Version management** | `version-set` target atomically updates all configs | No version pinning strategy |
| **Security scanning** | Trivy CVE scan + cosign signing + SBOM + provenance | TruffleHog + pattern grep (partial) |
| **Release automation** | Tag-triggered releases with goreleaser + changelog | Bundle creation only (sync.yml) |
| **Formatting as test** | `go fmt` + `go vet` baked into `make test` | `shfmt` in PR validation only |
| **Job dependencies** | Test must pass before release | Jobs run independently |

### What dotfiles already does well

- Multi-OS CI testing (ubuntu + macOS matrix)
- Profile-based setup (minimal/standard/comprehensive/dev/ops)
- Comprehensive smoke test suite with test counters
- Secret scanning (TruffleHog + pattern matching)
- Changed-files-based targeted testing (PR validation)
- Weekly maintenance automation (dependency audit, vulnerability scan)
- Conventional commit enforcement
- Shell syntax validation across Fish/Zsh/Bash

---

## Integration Plan

### Quick Wins (can apply immediately)

#### 1. Root Makefile — unified developer commands
**Why**: podinfo's biggest win is the Makefile as single entry point. Every developer
operation is a `make` target. The dotfiles repo has 90+ scripts but no root Makefile.

```makefile
# Key targets to add:
make test        # Run smoke tests + shellcheck + syntax validation
make lint        # shfmt + shellcheck + yamllint + json validation
make setup       # Run setup.sh with defaults
make validate    # Full validation suite
make doctor      # Run dotfiles-doctor checks
make clean       # Clean generated files, logs, temp artifacts
```

**File**: `Makefile` (root)
**Priority**: High

#### 2. Dirty tree check in CI
**Why**: podinfo checks that `git status` is clean after running tests/formatting.
This catches cases where a script generates files that weren't committed.

**File**: `.github/workflows/ci.yml` — add step after validation
**Priority**: High

#### 3. Concurrency groups on all workflows
**Why**: Prevents wasted CI minutes on stale pushes. podinfo applies this consistently.

**Files**: All `.github/workflows/*.yml`
**Priority**: Medium

### Moderate Changes (require some refactoring)

#### 4. Workflow consolidation
**Why**: podinfo has 4 focused workflows (test, release, e2e, cve-scan). The dotfiles
repo has 6 workflows with overlapping concerns (ci.yml and validate-dotfiles.yml both
do config validation; pr-validation.yml and ci.yml both do shellcheck).

**Recommendation**: Consolidate to 4 workflows:
- `ci.yml` — lint + test + security (runs on push/PR)
- `setup-test.yml` — setup script validation (runs on setup/brew changes)
- `release.yml` — bundle + changelog + tag (runs on tags/manual)
- `maintenance.yml` — weekly dependency audit + cleanup

**Priority**: Medium

#### 5. Formatting enforcement in `make test`
**Why**: podinfo bakes `fmt` and `vet` into the test target so formatting is never
skipped. The dotfiles repo only checks formatting in PR validation, which means
local development can drift.

**Approach**: Root Makefile `test` target runs:
- `shellcheck` on all .sh files
- `fish -n` on all .fish files
- `shfmt -d` on all .sh files (diff mode, no write)
- JSON/YAML validation
- smoke-test.sh

**Priority**: Medium

#### 6. Versioned releases with changelog
**Why**: podinfo uses tag-triggered releases with goreleaser for automatic changelog
generation. The dotfiles could use simple semantic versioning to track setup changes.

**Approach**:
- Add `VERSION` file at root
- `make release` creates git tag and pushes
- GitHub release workflow generates changelog from conventional commits
- Bundle artifact attached to release

**Priority**: Low-Medium

### Larger Initiatives (significant effort)

#### 7. Supply chain security (SBOM for Brewfile)
**Why**: podinfo generates SBOM for container images. The dotfiles could generate
a manifest of all installed packages with versions for auditability.

**Approach**: `make sbom` generates a JSON manifest of Brewfile packages + versions

**Priority**: Low

#### 8. E2E testing in containers (like podinfo's Kind clusters)
**Why**: podinfo deploys to real Kind clusters for e2e testing. The dotfiles already
has Docker test infrastructure but could run full setup validation in containers.

**Current state**: `scripts/docker/` has test infrastructure — this is already partially done.
**Gap**: CI doesn't run container-based tests automatically.

**Priority**: Low

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `Makefile` | Create | Root Makefile with test/lint/setup/validate/clean targets |
| `.github/workflows/ci.yml` | Modify | Add dirty-tree check, concurrency group |
| `.github/workflows/pr-validation.yml` | Modify | Add concurrency group |
| `.github/workflows/setup-test.yml` | Modify | Add concurrency group |
| `.github/workflows/sync.yml` | Modify | Add concurrency group, rename to release.yml |
| `.github/workflows/weekly-maintenance.yml` | Modify | Add concurrency group |
| `.github/workflows/validate-dotfiles.yml` | Remove | Consolidate into ci.yml |

## Dependencies/Prerequisites

- `shfmt` — already in Brewfile (verify)
- `shellcheck` — already in Brewfile (verify)
- `yamllint` — pip install in CI (already present)
- No new Brewfile additions needed

## Risks & Considerations

- **Makefile vs Fish functions**: The Makefile supplements Fish functions, doesn't replace them.
  Fish functions are for interactive use; Makefile is for CI/automation.
- **Workflow consolidation**: Must be done carefully to not break existing CI. Recommend
  adding new consolidated workflow first, then removing old ones.
- **POSIX check in PR validation**: Currently flags bash-isms in scripts that intentionally
  use bash. Should exclude files with `#!/usr/bin/env bash` shebang.

## Recommendation

**Priority order for implementation:**

1. **Root Makefile** — highest impact, lowest risk. Unifies all dev commands.
2. **Dirty tree check** — catches real bugs, 5-line addition to CI.
3. **Concurrency groups** — saves CI minutes, trivial to add.
4. **Workflow consolidation** — moderate effort, reduces maintenance burden.
5. **Versioned releases** — nice-to-have, enables rollback.
6. **SBOM/container e2e** — low priority, future consideration.

Items 1-3 can be implemented in this session. Items 4-6 are future work.
