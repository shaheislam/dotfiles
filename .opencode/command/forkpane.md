---
description: Fork the current OpenCode session into a new tmux split pane
agent: build
---

Run the command below to fork the current OpenCode conversation into a new tmux split pane in the same window.

Arguments:

```text
$ARGUMENTS
```

This command is normally intercepted by the OpenCode fork command plugin and run without a model call. It opens a timeline picker before creating the pane fork unless `--full` or `--message <id>` is provided.

If you see this text as an assistant response, the plugin did not load; run this fallback from a shell inside tmux:

```fish
opencode-forkpane $ARGUMENTS
```
