Review recent changes and remove AI slop — unnecessary verbosity, over-engineering, and bloat.

## What to Look For
1. **Unnecessary comments**: Comments that just restate what the code does
2. **Over-abstraction**: Helper functions used only once, premature generalization
3. **Verbose error handling**: Try/catch blocks for things that can't fail
4. **Feature flags for nothing**: Configuration for things that don't need to be configurable
5. **Dead code**: Unused imports, unreachable branches, TODO comments without tickets
6. **Bloated types**: Overly complex type definitions that could be simpler
7. **Unnecessary defensive coding**: Null checks on things that are never null

## Steps
1. Run `git diff main...HEAD --stat` to see what files changed
2. For each changed file, read the diff and identify slop
3. Fix issues directly — don't just report them
4. Keep changes minimal and focused on removing bloat
5. Commit with message format: `refactor: remove unnecessary <what>`

## Rules
- Only touch files that were already modified in this branch
- Don't add new features or change behavior
- Don't reformat code that wasn't changed
- Preserve all existing tests
