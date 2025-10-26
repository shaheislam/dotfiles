# Local History Fix for fzf-lua

## Problem Summary

Local history (`ctrl-r` → `ctrl-d`) was not working correctly in fzf-lua picker mode because:

1. **Timing Issue**: fzf writes search terms to history file **during** active picker session (when you press Enter or use ctrl-p/ctrl-n)
2. **Unprefixed Entries**: fzf writes raw search terms without CWD prefix (e.g., "terraform" instead of "/Users/shaheislam/dotfiles|terraform")
3. **Late Processing**: `process_history_file()` only runs **after** picker closes (100ms delay)
4. **Race Condition**: If you press `ctrl-r` during the same session, it reads the file before prefixes are added
5. **Filtering Fails**: Local scope filtering skips unprefixed entries since it can't determine their directory

## Root Cause

```
Timeline of Events (BROKEN):
1. User opens live_grep in /path/to/dir
2. User types "search_term" and presses Enter
3. fzf immediately writes "search_term" to history file (unprefixed)
4. User presses ctrl-r to view history (still in same picker session)
5. search_history_action reads history file → finds "search_term" (unprefixed)
6. Local scope filtering skips "search_term" (no CWD to compare)
7. User sees empty local history ❌
8. 100ms later, process_history_file runs and adds prefix (too late)
```

## Solution Implemented

### 1. New Function: `ensure_history_prefixed()` (Line 108-144)

```lua
-- Ensure history file has CWD prefixes (called before reading for local scope)
-- This ensures unprefixed entries written by fzf during picker session get prefixed immediately
local function ensure_history_prefixed(history_file, cwd)
  -- Reads history file
  -- Adds CWD prefix to any unprefixed entries
  -- Writes back atomically
end
```

**Purpose**: Pre-process history file **before** reading it for local scope filtering.

### 2. Integration in `search_history_action()` (Line 689-694)

```lua
-- Ensure local history file is prefixed before reading (critical for local scope)
-- This handles unprefixed entries written by fzf during the current picker session
if picker_type and picker_type ~= "default" then
  local local_history_file = get_history_path(picker_type, local_cwd)
  ensure_history_prefixed(local_history_file, local_cwd)
end
```

**Effect**: When you press `ctrl-r`, unprefixed entries get prefixed **immediately** before filtering.

### 3. Defensive Fallback in `get_history_for_scope()` (Line 743-750)

```lua
else
  -- Defensive fallback: unprefixed entry found despite ensure_history_prefixed
  -- Treat as belonging to current directory (this file should be for current dir)
  if not seen[line] then
    seen[line] = true
    table.insert(all_history, line)
  end
end
```

**Purpose**: Handle any edge case where unprefixed entries slip through.

## Fixed Timeline

```
Timeline of Events (FIXED):
1. User opens live_grep in /path/to/dir
2. User types "search_term" and presses Enter
3. fzf immediately writes "search_term" to history file (unprefixed)
4. User presses ctrl-r to view history (still in same picker session)
5. search_history_action calls ensure_history_prefixed()
   → Reads history file
   → Finds "search_term" (unprefixed)
   → Adds prefix: "/path/to/dir|search_term"
   → Writes back atomically
6. Local scope filtering reads history file
   → Finds "/path/to/dir|search_term"
   → Extracts CWD: "/path/to/dir"
   → Matches current directory ✅
   → Displays "search_term" in local history ✅
```

## Testing

### Manual Test
1. Open Neovim in `/Users/shaheislam/dotfiles`
2. Press `<leader>fg` (live_grep)
3. Type "test_search" and press Enter
4. Press `ctrl-r` (open history)
5. Press `ctrl-d` (switch to local scope)
6. Verify "test_search" appears in local history ✅

### Automated Test
```bash
~/dotfiles/test-local-history-fix.sh
```

## Files Modified

- `.config/nvim/lua/plugins/fzf-lua.lua`
  - Added `ensure_history_prefixed()` function (line 108-144)
  - Integrated into `search_history_action()` (line 689-694)
  - Added defensive fallback in local scope filtering (line 743-750)

## Key Insights

1. **fzf Native History**: fzf's `--history` option writes to file immediately, not when picker closes
2. **Lua Post-Processing**: Custom processing must happen **before** reading, not **after** writing
3. **Directory Context**: CWD at picker open time may differ from actual search directory (Oil.nvim support)
4. **Race Conditions**: Multiple pickers/sessions can overlap, requiring atomic file operations

## Performance Impact

- Minimal: `ensure_history_prefixed()` only runs when:
  1. User presses `ctrl-r` (history search)
  2. History file exists and has unprefixed entries
- File I/O is buffered and atomic
- No impact on normal picker operations
