# Codex Plugin Workflow Improvements

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate the codex plugin's capabilities (review gate, adversarial review, status, rescue) into existing gwt-ticket, wrap-up, and gwt-status workflows.

**Architecture:** Five changes that wire the codex plugin's slash commands into the existing orchestration layer. Each change is additive — no existing behavior is removed. The review gate uses the plugin's SessionStart/Stop hooks, adversarial review hooks into wrap-up's validation step, and status integrates into gwt-status's display loop.

**Tech Stack:** Fish shell (gwt-ticket.fish, gwt-status.fish), Markdown (wrap-up SKILL.md), Bash (codex-bridge-review.sh)

---

### Task 1: Review Gate Flag for gwt-ticket

Add `--review-gate` flag to gwt-ticket that injects `/codex:setup --enable-review-gate` as a skill invocation at session start.

**Files:**
- Modify: `.config/fish/functions/gwt-ticket.fish:92` (add variable)
- Modify: `.config/fish/functions/gwt-ticket.fish:476` (add case in arg parser)
- Modify: `.config/fish/functions/gwt-ticket.fish:783` (add help text)
- Modify: `.config/fish/functions/gwt-ticket.fish:1787` (inject skill)

**Step 1: Add the review_gate variable declaration**

At line 92, after `set -l gate_type ""`, add:

```fish
set -l review_gate false
```

**Step 2: Add the --review-gate case in argument parser**

After the `--codex-profile` case block (around line 507), add:

```fish
case --review-gate
    set review_gate true
```

**Step 3: Add help text**

After the `--codex-profile` help line (around line 784), add:

```
echo "  --review-gate        Enable Codex stop-time review gate (blocks session end until Codex approves)"
```

**Step 4: Inject the codex:setup skill when review_gate is true**

At line 1787 (the skill injection block), before the existing `if test (count $skills) -gt 0` block, add:

```fish
# Inject review gate skill if requested
if $review_gate
    set -p skills "codex:setup --enable-review-gate"
end
```

This uses `set -p` (prepend) so the review gate setup runs before any other skills.

**Step 5: Add example to help**

After the existing skill example (line 861), add:

```
echo "  gwt-ticket ENG-123 \"Add feature\" \"Details\" --review-gate"
```

**Step 6: Validate syntax**

Run: `fish --no-execute .config/fish/functions/gwt-ticket.fish`
Expected: No output (clean parse)

**Step 7: Commit**

```bash
git add .config/fish/functions/gwt-ticket.fish
git commit -m "feat: add --review-gate flag to gwt-ticket for codex stop-time review"
```

---

### Task 2: Pre-commit Adversarial Review in wrap-up

Add a `/codex:adversarial-review --wait` step to the wrap-up skill, between validation and commit generation.

**Files:**
- Modify: `.claude/skills/wrap-up/SKILL.md:63-73` (insert step between tests and commit)

**Step 1: Insert adversarial review step after tests**

Between the existing "### 3. Run Tests" and "### 4. Generate Commit" sections, insert a new section. Renumber subsequent sections (4→5, 5→6, 6→7).

The new section:

```markdown
### 4. Codex Adversarial Review (if available)

If the codex plugin is installed (check: `ls ~/.claude/plugins/marketplaces/openai-codex/ 2>/dev/null`), run a pre-commit adversarial review:

```bash
# Only run if there are staged or unstaged changes to review
git diff --shortstat --cached; git diff --shortstat
```

If there are changes:
- Invoke `/codex:adversarial-review --wait --scope working-tree`
- Review the output for BLOCK/ALLOW verdict
- If BLOCK: report the issues and stop — do NOT commit. Suggest the user fix the issues and re-run `/wrap-up`
- If ALLOW or review unavailable (Codex not installed/authenticated): continue to commit

This step is skipped silently if:
- Codex CLI is not installed
- No changes exist to review
- `--no-commit` was specified (no point reviewing if not committing)
```

**Step 2: Renumber remaining sections**

- "### 4. Generate Commit" → "### 5. Generate Commit"
- "### 5. Update Task Status" → "### 6. Update Task Status"
- "### 6. Report Summary" → "### 7. Report Summary"

**Step 3: Update summary template**

In the report summary section, add a Codex Review line:

```
Codex Review: {ALLOW/BLOCK/SKIPPED}
```

**Step 4: Commit**

```bash
git add .claude/skills/wrap-up/SKILL.md
git commit -m "feat: add codex adversarial review step to wrap-up skill"
```

---

### Task 3: Codex Rescue Delegation in gwt-ticket Prompt

Add prompt instructions for using `/codex:rescue` when tasks have 3+ independent subtasks.

**Files:**
- Modify: `.config/fish/functions/gwt-ticket.fish:1650` (inject rescue guidance into dynamic beads suffix)

**Step 1: Append rescue delegation guidance to beads suffix**

After the existing beads workflow instructions (around line 1668, after the "Subtask state survives..." line), add:

```fish
CODEX DELEGATION — For independent subtasks, consider using /codex:rescue to delegate work to Codex in background:
- Use when a subtask is self-contained and doesn't depend on your current work
- Run: /codex:rescue --background 'Complete subtask: TITLE. Details: DESCRIPTION'
- Check progress: /codex:status
- Get results: /codex:result JOB_ID
Only delegate when you have 3+ subtasks AND the subtask is truly independent."
```

**Step 2: Validate syntax**

Run: `fish --no-execute .config/fish/functions/gwt-ticket.fish`
Expected: No output (clean parse)

**Step 3: Commit**

```bash
git add .config/fish/functions/gwt-ticket.fish
git commit -m "feat: add codex rescue delegation guidance to gwt-ticket beads prompt"
```

---

### Task 4: Simplify codex-bridge-review.sh Using Plugin Runtime

Replace the manual Codex process management in `codex-bridge-review.sh` with calls to the codex plugin's companion runtime for review execution.

**Files:**
- Modify: `scripts/codex-bridge-review.sh:~180-240` (replace raw codex invocation with companion)

**Step 1: Read the current Codex invocation section**

The bridge script currently spawns raw `codex` processes. Identify the `run_codex_review` function.

**Step 2: Add companion runtime helper**

Near the top of the script (after the existing function definitions), add a helper that uses the plugin's companion script:

```bash
# Use codex plugin companion if available (structured review output)
CODEX_COMPANION="${HOME}/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs"

run_codex_review_via_companion() {
    local review_mode="${1:-review}"
    local diff_content="$2"
    local timeout="${CROSS_PROVIDER_TIMEOUT:-120}"

    if [[ -x "$(command -v node)" ]] && [[ -f "$CODEX_COMPANION" ]]; then
        local result
        result=$(echo "$diff_content" | timeout "${timeout}s" node "$CODEX_COMPANION" "$review_mode" --wait --scope working-tree 2>/dev/null)
        local exit_code=$?
        if [[ $exit_code -eq 0 ]] && [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    return 1  # Fall back to raw codex
}
```

**Step 3: Integrate companion into the review loop**

In the main review loop, try the companion first, fall back to raw codex:

```bash
# Try companion runtime first, fall back to raw codex
if ! review_output=$(run_codex_review_via_companion "$mode" "$diff"); then
    review_output=$(run_codex_raw "$mode" "$diff")
fi
```

**Step 4: Validate syntax**

Run: `bash -n scripts/codex-bridge-review.sh`
Expected: No errors

**Step 5: Commit**

```bash
git add scripts/codex-bridge-review.sh
git commit -m "refactor: use codex companion runtime in bridge review when available"
```

---

### Task 5: Codex Status in gwt-status

Add a Codex job status column to the gwt-status display.

**Files:**
- Modify: `.config/fish/functions/gwt-status.fish:88-103` (add header column)
- Modify: `.config/fish/functions/gwt-status.fish:159-210` (add codex status lookup per worktree)

**Step 1: Detect codex companion availability**

After the `agent_state_script` detection (around line 50), add:

```fish
# Detect codex companion for job status
set -l codex_companion "$HOME/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs"
set -l has_codex false
if command -q node; and test -f "$codex_companion"
    set has_codex true
end
```

**Step 2: Add CODEX column to header**

In the header printing section (~line 88-103), add a CODEX column after STATUS:

```fish
if $has_codex
    # Extended header with codex column
    printf "%-40s %-20s %-15s %-10s %-15s\n" WORKTREE BRANCH CONTAINER STATUS CODEX
    printf "%-40s %-20s %-15s %-10s %-15s\n" (string repeat -n 40 "-") (string repeat -n 20 "-") (string repeat -n 15 "-") (string repeat -n 10 "-") (string repeat -n 15 "-")
end
```

**Step 3: Query codex status per worktree**

Inside the worktree loop (around line 197), before the printf, add codex job lookup:

```fish
# Codex job status
set -l codex_display -
if $has_codex
    set -l codex_json (cd "$wt_path" 2>/dev/null; and node "$codex_companion" status --json 2>/dev/null | string collect)
    if test -n "$codex_json"
        set -l active_count (echo "$codex_json" | jq -r '.active // 0' 2>/dev/null)
        set -l last_status (echo "$codex_json" | jq -r '.lastStatus // "none"' 2>/dev/null)
        if test "$active_count" -gt 0 2>/dev/null
            set codex_display "[$active_count active]"
        else if test "$last_status" != "none" -a "$last_status" != "null"
            set codex_display "$last_status"
        end
    end
end
```

**Step 4: Include codex in output printf**

Update the printf calls in the display section to include the codex column when available.

**Step 5: Validate syntax**

Run: `fish --no-execute .config/fish/functions/gwt-status.fish`
Expected: No output (clean parse)

**Step 6: Commit**

```bash
git add .config/fish/functions/gwt-status.fish
git commit -m "feat: add codex job status column to gwt-status display"
```

---

## Dependency Order

Tasks 1-5 are independent — they can be implemented in parallel or any order. Each touches different files or different sections:

| Task | File | Section |
|------|------|---------|
| 1 | gwt-ticket.fish | arg parsing, help, skill injection |
| 2 | wrap-up/SKILL.md | validation steps |
| 3 | gwt-ticket.fish | beads prompt suffix (non-overlapping with Task 1) |
| 4 | codex-bridge-review.sh | review function |
| 5 | gwt-status.fish | display loop |

**Note:** Tasks 1 and 3 both touch gwt-ticket.fish but in completely different sections (arg parsing vs. prompt construction), so they can be done sequentially without conflict.

## Final Validation

After all tasks:

```bash
fish --no-execute .config/fish/functions/gwt-ticket.fish
fish --no-execute .config/fish/functions/gwt-status.fish
bash -n scripts/codex-bridge-review.sh
stow --simulate --verbose .
```
