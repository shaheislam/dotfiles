# Git Workflows Quick Reference

Personal Git workflow documentation covering shell aliases, Neovim integrations, and custom scripts.

---

## Quick Find - Most Common Operations

| Task | Shell | Neovim | Notes |
|------|-------|--------|-------|
| Stage files | `ga <file>` | `<leader>hs` | Stage hunk in Neovim |
| Stage all | `gaa` | `<leader>hS` | Stage entire buffer |
| Commit | `gc` / `gcm "msg"` | `<leader>gc` | Verbose / with message |
| Amend commit | `gc!` | `:gca` | Opens editor |
| Push | `gp` | `<leader>gp` | Push to remote |
| Push (set upstream) | `gpu` | - | For new branches |
| Pull | `gl` / `glr` | - | Normal / with rebase |
| View diff | `gd` | `<leader>gd` | Unstaged changes |
| View staged | `gdca` | `<leader>gS` | Staged changes only |
| Branch switch | `CTRL-G CTRL-B` | `<leader>gb` | Fuzzy picker |
| Blame line | - | `<leader>hb` | Full blame info |
| Interactive rebase | `grbi` | - | `git rebase -i` |
| Stash | `gsta` / `CTRL-G CTRL-S` | `<leader>gs` | Stash / picker |
| File history | - | `<leader>gh` | Diffview history |
| Check identity | `gci` | - | Validate Git config |

---

## 1. Shell Aliases (Fish)

> Source: `~/.config/fish/functions/__git.init.fish`

### Core Commands

| Alias | Command | Description |
|-------|---------|-------------|
| `g` | `git` | Base command |
| `ga` | `git add` | Stage file |
| `gaa` | `git add --all` | Stage all |
| `gau` | `git add --update` | Stage modified only |
| `gapa` | `git add --patch` | Interactive staging |

### Commits

| Alias | Command | Description |
|-------|---------|-------------|
| `gc` | `git commit -v` | Commit (verbose) |
| `gc!` | `git commit -v --amend` | Amend last commit |
| `gcn!` | `git commit --no-edit --amend` | Amend without editor |
| `gca` | `git commit -a -v` | Stage all + commit |
| `gcm` | `git commit -m` | Commit with message |
| `gcfx` | `git commit --fixup` | Create fixup commit |

### Diff & Log

| Alias | Command | Description |
|-------|---------|-------------|
| `gd` | `git diff` | Unstaged changes |
| `gdca` | `git diff --cached` | Staged changes |
| `gdt` | `git difftool` | Open diff tool |
| `glog` | `git log --oneline --graph` | Pretty log |
| `gloga` | `git log --oneline --graph --all` | All branches |
| `glg` | `git log --stat` | Log with stats |

### Branches

| Alias | Command | Description |
|-------|---------|-------------|
| `gb` | `git branch -vv` | List with tracking |
| `gba` | `git branch -a -v` | All branches |
| `gbd` | `git branch -d` | Delete branch |
| `gbD` | `git branch -D` | Force delete |
| `gco` | `git checkout` | Checkout |
| `gcb` | `git checkout -b` | Create + checkout |
| `gsw` | `git switch` | Switch branch |

### Remote Operations

| Alias | Command | Description |
|-------|---------|-------------|
| `gf` | `git fetch` | Fetch |
| `gfa` | `git fetch --all --prune` | Fetch all + prune |
| `gfm` | `git fetch origin + merge` | Fetch + merge default |
| `gl` | `git pull` | Pull |
| `glr` | `git pull --rebase` | Pull with rebase |
| `gp` | `git push` | Push |
| `gp!` | `git push --force-with-lease` | Safe force push |
| `gpu` | `git push origin <branch> -u` | Push + set upstream |
| `ggp` | `git push origin <current>` | Push current branch |

### Rebase & Merge

| Alias | Command | Description |
|-------|---------|-------------|
| `grb` | `git rebase` | Rebase |
| `grbi` | `git rebase -i` | Interactive rebase |
| `grbm` | `git rebase <default-branch>` | Rebase on main/master |
| `grba` | `git rebase --abort` | Abort rebase |
| `grbc` | `git rebase --continue` | Continue rebase |
| `gm` | `git merge` | Merge |
| `gmt` | `git mergetool --no-prompt` | Merge tool |

### Stash

| Alias | Command | Description |
|-------|---------|-------------|
| `gsta` | `git stash` | Stash changes |
| `gstl` | `git stash list` | List stashes |
| `gstp` | `git stash pop` | Apply + remove stash |
| `gstd` | `git stash drop` | Delete stash |
| `gsts` | `git stash show -p` | Show stash diff |

### Reset & Restore

| Alias | Command | Description |
|-------|---------|-------------|
| `grh` | `git reset` | Reset |
| `grhh` | `git reset --hard` | Hard reset |
| `gru` | `git reset --` | Unstage file |
| `grs` | `git restore` | Restore file |
| `grss` | `git restore --staged` | Unstage file |

### Worktrees

| Alias | Command | Description |
|-------|---------|-------------|
| `gwt` | `git worktree` | Worktree command |
| `gwta` | `git worktree add` | Add worktree |
| `gwtl` | `git worktree list` | List worktrees |
| `gwtr` | `git worktree remove` | Remove worktree |

### GitLab MR (Work)

| Alias | Command | Description |
|-------|---------|-------------|
| `gmr` | `git push + MR options` | Create GitLab MR |
| `gmwps` | MR + merge when pipeline succeeds | Auto-merge on green |

---

## 2. FZF-Git Keybindings (Terminal)

> Source: `~/.config/fish/functions/fzf-git.sh`

### CTRL-G Prefix Commands

| Keybinding | Action | Preview |
|------------|--------|---------|
| `CTRL-G CTRL-F` | Files (modified/staged) | Diff preview |
| `CTRL-G CTRL-B` | Branches | Log preview |
| `CTRL-G CTRL-T` | Tags | Release notes |
| `CTRL-G CTRL-R` | Remotes | Branch list |
| `CTRL-G CTRL-H` | Commit hashes | Full diff |
| `CTRL-G CTRL-S` | Stashes | Content preview |
| `CTRL-G CTRL-L` | Reflogs | Entry details |
| `CTRL-G CTRL-W` | Worktrees | Status |
| `CTRL-G CTRL-E` | Each ref (all) | All refs |
| `CTRL-G ?` | Show keybindings | Help |

**In FZF picker**: `CTRL-O` opens GitHub/GitLab URL in browser

### Tab Completion Context

> Source: `~/.config/fish/functions/_git_fzf_tab_complete.fish`

| Command | Tab Shows | Notes |
|---------|-----------|-------|
| `git add <TAB>` | Uncommitted files | Modified/untracked |
| `git checkout <TAB>` | Branches | Files after `--` |
| `git branch -d <TAB>` | Branches | For deletion |
| `git merge <TAB>` | Branches | To merge |
| `git rebase <TAB>` | Branches | Rebase target |
| `git cherry-pick <TAB>` | Commits | Recent commits |
| `git push <TAB>` | Remotes | Then branches |
| `git stash <TAB>` | Stashes | For apply/drop |
| `git worktree add <TAB>` | Path + branches | Smart suggestions |
| `git clean <TAB>` | Untracked files | With tree preview |
| `git reset --hard <TAB>` | Commits | For hard reset |

### Custom FZF Functions

| Function | Alias | Description |
|----------|-------|-------------|
| `_fzf_lua_git_branches` | - | Checkout branch (Enter) / Copy name (Ctrl-y) |
| `_fzf_lua_git_commits` | - | Select commit SHA for piping |
| `_fzf_lua_git_stash` | - | Apply (Enter) / Drop (Ctrl-x) stash |
| `_fzf_lua_git_diffview` | - | Toggle Diffview for working dir |
| `_fzf_lua_git_pr_preview` | - | PR preview against base branch |
| `_fzf_search_git_log` | - | Search log with preview |
| `_fzf_search_git_status` | - | Search status with diff preview |

---

## 3. Neovim Git Keybindings

### Gitsigns - Hunks & Blame

> Source: `~/neovim/lua/plugins/git.lua`

#### Navigation

| Key | Action |
|-----|--------|
| `]c` / `[c` | Next / Previous hunk |
| `]C` / `[C` | Last / First hunk |
| `]p` / `[p` | Next / Prev hunk with preview |
| `]g` / `[g` | Skip adjacent hunks |
| `]s` / `[s` | Staged hunks only |
| `]u` / `[u` | Unstaged hunks only |

#### Staging & Reset

| Key | Action |
|-----|--------|
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hS` | Stage buffer |
| `<leader>hu` | Undo stage hunk |
| `<leader>hR` | Reset buffer |
| `<leader>hP` | Preview then stage |

#### Blame & Diff

| Key | Action |
|-----|--------|
| `<leader>hb` | Blame current line |
| `<leader>hB` | Toggle blame display |
| `<leader>hv` | Blame entire buffer |
| `<leader>go` | Open blamed commit in Diffview |
| `<leader>hd` | Diff against index |
| `<leader>hD` | Diff against HEAD~1 |
| `<leader>hc` | Diff against any revision |

#### Toggles

| Key | Action |
|-----|--------|
| `<leader>ht` | Toggle deleted lines (virtual text) |
| `<leader>hw` | Toggle word diff |
| `<leader>hL` | Toggle line highlight |
| `<leader>hg` | Toggle git signs |

#### Text Objects

| Key | Action |
|-----|--------|
| `ih` | Inside hunk |
| `ah` | Around hunk (with context) |

### Diffview - Diffs & History

> Source: `~/neovim/lua/plugins/git.lua`

#### Main Commands

| Key | Action |
|-----|--------|
| `<leader>gd` | Toggle Diffview (open/close) |
| `<leader>gh` | File history (current file) |
| `<leader>gH` | Repository history (all files) |
| `<leader>gL` | Line history (cursor position) |
| `<leader>gL` (visual) | Line history (selection) |
| `<leader>gm` | Merge conflicts view |
| `<leader>gP` | PR preview (vs base branch) |
| `<leader>gS` | Staged changes only |
| `<leader>gF` | Diff two arbitrary files |

#### In Diffview Navigation

| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | Next / Prev file |
| `[F` / `]F` | First / Last file |
| `gf` | Go to file (current window) |
| `<C-w><C-f>` | Go to file (split) |
| `<C-w>gf` | Go to file (new tab) |
| `<leader>e` | Focus file panel |
| `<leader>b` | Toggle file panel |
| `g<C-x>` | Cycle diff layout |
| `q` | Close Diffview |

#### Merge Conflict Resolution

| Key | Action |
|-----|--------|
| `co` | Choose OURS |
| `ct` | Choose THEIRS |
| `cb` | Choose BASE |
| `ca` | Choose ALL |
| `dx` | Delete conflict region |
| `[x` / `]x` | Prev / Next conflict |
| `<leader>cO/T/B/A` | Whole file resolution |

#### Commit Cycling

| Key | Scope | Action |
|-----|-------|--------|
| `[r` / `]r` | File | Cycle commits for current file |
| `[R` / `]R` | Repo | Cycle commits for entire repo |
| `gco` | - | Checkout TO commit (current) |
| `gcO` | - | Checkout FROM commit (parent) |

### Fugitive - Git Commands

> Source: `~/neovim/lua/plugins/git.lua`

| Key | Action |
|-----|--------|
| `<leader>gp` | Git push (split) |
| `<leader>gc` | Git commit (split) |
| `<leader>gB` | Open file in GitHub/GitLab |

#### Command Abbreviations

| Abbrev | Expands To |
|--------|------------|
| `:G` | `:Git` |
| `:gst` | `:Git status` |
| `:gco` | `:Git checkout` |
| `:gll` | `:Git pull` |
| `:gpo` | `:Git push origin` |
| `:gpof` | `:Git push origin --force-with-lease` |
| `:ga` | `:Git add` |
| `:gaa` | `:Git add --all` |
| `:gc` | `:Git commit` |
| `:gca` | `:Git commit --amend` |
| `:gcm` | `:Git commit -m` |
| `:gd` | `:Git diff` |
| `:gds` | `:Git diff --staged` |
| `:gl` | `:Git log` |
| `:glo` | `:Git log --oneline -20` |
| `:glg` | `:Git log --graph --oneline` |
| `:gb` | `:Git branch` |
| `:gsw` | `:Git switch` |
| `:gf` | `:Git fetch` |
| `:gfa` | `:Git fetch --all` |
| `:gm` | `:Git merge` |
| `:gr` | `:Git rebase` |
| `:gri` | `:Git rebase -i` |
| `:gsh` | `:Git stash` |
| `:gshp` | `:Git stash pop` |
| `:gcp` | `:Git cherry-pick` |
| `:grh` | `:Git reset HEAD` |
| `:grhh` | `:Git reset --hard HEAD` |

### FZF-Lua Git Pickers

> Source: `~/neovim/lua/plugins/fzf-lua.lua`

| Key | Picker |
|-----|--------|
| `<leader>gg` | Git status |
| `<leader>gl` | Git commits |
| `<leader>gb` | Git branches |
| `<leader>gf` | Git files (tracked) |
| `<leader>gC` | Buffer commits (current file) |
| `<leader>gs` | Git stash |
| `<leader>gx` | Find Git conflicts |
| `<leader>gD` | Unified Diffview picker |

#### Unified Diffview Picker (`<leader>gD`)

| Key | Action |
|-----|--------|
| `Ctrl-H` | Switch to commits |
| `Ctrl-B` | Switch to branches |
| `Ctrl-S` | Switch to stashes |
| `Ctrl-W` | Switch to worktrees |
| `Ctrl-/` | Toggle preview |
| `Ctrl-X` | Clear selection |

### Octo - GitHub/GitLab

> Source: `~/neovim/lua/plugins/octo.lua`

| Key | Action |
|-----|--------|
| `<leader>On` | Notifications |
| `<leader>Oi` | List issues |
| `<leader>OI` | Search issues |
| `<leader>Oc` | Create issue |
| `<leader>Op` | List PRs |
| `<leader>OP` | Search PRs |
| `<leader>OC` | Create PR |
| `<leader>Ox` | Checkout PR |
| `<leader>Or` | Start review |
| `<leader>OR` | Resume review |
| `<leader>Os` | Submit review |
| `<leader>Ob` | Open repo in browser |
| `<leader>Oy` | Copy repo URL |
| `<leader>Od` | Open PR in DiffView |

### Clipboard Diff

| Key | Action |
|-----|--------|
| `<leader>gK` | Diff buffer vs clipboard |
| `<leader>gK` (visual) | Diff selection vs clipboard |

### Yank with Git Context

| Key | Action |
|-----|--------|
| `<leader>yr` (visual) | Yank with relative path from Git root |
| `<leader>ya` (visual) | Yank with absolute path |

---

## 4. Custom Scripts

### git-mass-branch.sh

> Source: `~/dotfiles/scripts/git-mass-branch.sh`

Create branches across multiple repos in parallel.

```bash
# Usage
cd ~/work
git-mass-branch.sh feature/new-dashboard
git-mass-branch.sh feature/name --dry-run
```

**Operations per repo**: Stash -> Checkout default -> Pull -> Create branch

### setup-git-local-excludes.sh

> Source: `~/dotfiles/scripts/tools/setup-git-local-excludes.sh`
> Fish wrapper: `gitlocal-setup`

Configure .gitignore_local symlinks for all repos.

```bash
# Usage
gitlocal-setup ~/work
gitlocal-setup --dry-run
gitlocal-setup --force --add-pattern '*.tmp'
```

**Default excludes**: `.gitignore_local`, `*.local`, `.env.local`, `.vscode/`, `.idea/`, `.claude/`, `.codex/`, `.DS_Store`, `*.swp`, `.pyrightconfig.json`

### git-check-identity (gci)

> Source: `~/.config/fish/functions/git-check-identity.fish`

Display current Git identity and authentication status.

```bash
# Usage
gci
# or
git-check-identity
```

**Shows**: Remote URL, current user/email, SSH auth status, recommended config

### git-smart

> Source: `~/.config/fish/functions/git-smart.fish`

Validates Git configuration before pushing. Warns if email doesn't match repo owner.

### git-auto-remote (gar)

> Source: `~/.config/fish/functions/git-auto-remote.fish`

Automatically set Git remote based on repository owner.

---

## 5. Multi-Account Management

### Configuration

| Context | Email |
|---------|-------|
| Personal (shaheislam) | `shaheislam@hotmail.co.uk` |
| Work (DFE) | `shahe.islam@education.gov.uk` |
| Default (global) | `shaheislam@users.noreply.github.com` |

### Workflow

1. **Check identity before work**: `gci`
2. **Push validates automatically**: `git-smart` warns on mismatch
3. **Fix remote if needed**: `gar` (git-auto-remote)

### Post-Clone Hook

> Source: `~/.config/git/templates/hooks/post-checkout`

Automatically sets up `.gitignore_local` on clone.

---

## 6. Tool Configuration

### Delta (Diff Pager)

> Source: `~/.gitconfig`

- Side-by-side display
- Catppuccin Mocha syntax theme
- Line numbers enabled
- Hyperlinks with file:// protocol

### Git Diff Tool

```bash
git difftool main HEAD  # Opens FZF file picker -> DiffviewOpen
```

### Lazygit

```bash
lg  # Alias for lazygit
```

---

## 7. Git Config Highlights

> Source: `~/.gitconfig`

| Setting | Value | Purpose |
|---------|-------|---------|
| `pager` | delta | Modern diff viewer |
| `diff.tool` | nvimdiff | Neovim for diffs |
| `merge.conflictStyle` | zdiff3 | 3-way conflict markers |
| `diff.algorithm` | histogram | Efficient for large files |
| `merge.tool` | Opens DiffviewOpen | Visual merge resolution |

---

## Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Wrong email on commit | Run `gci` to check, update `.gitconfig` |
| Push blocked by git-smart | Check email matches repo owner |
| Can't find branch | Use `CTRL-G CTRL-B` for fuzzy search |
| Conflict resolution | `<leader>gm` opens Diffview merge view |
| Need to see file history | `<leader>gh` in Neovim |
| Accidentally staged wrong file | `<leader>hu` to undo stage hunk |
