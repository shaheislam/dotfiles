---
description: Fork the current OpenCode session into a new gwtt worktree and tmux window
agent: build
---

Run the command below to fork the current OpenCode conversation into a new OpenCode-backed worktree using the existing `gwtt` workflow.

Arguments:

```text
$ARGUMENTS
```

Command output:

!`fish -c 'opencode-forkworktree $argv' -- $ARGUMENTS 2>&1`

Report the resulting tmux/worktree launch line briefly. Do not inspect, plan, or make any other changes in this session.
