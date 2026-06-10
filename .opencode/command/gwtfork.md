---
description: Fork the current OpenCode session into a new gwtt worktree and tmux window
agent: build
---

Run the command below to fork the current OpenCode conversation into a new OpenCode-backed worktree using the existing `gwtt` workflow.

Arguments:

```text
$ARGUMENTS
```

This command is normally intercepted by the OpenCode fork command plugin and run without a model call.

If you see this text as an assistant response, the plugin did not load; run this fallback from a shell:

```fish
opencode-forkworktree $ARGUMENTS
```
