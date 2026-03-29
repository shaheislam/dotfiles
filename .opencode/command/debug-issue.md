---
description: Investigate an integration or workflow issue without broad edits
agent: dotfiles-debug
model: openai/gpt-5.1-codex
---

Investigate the following issue in this repository:

$ARGUMENTS

Current branch state:

!`git -c core.fsmonitor=false status --short --branch`

Use the smallest relevant probes first. Identify the exact failing layer and propose the minimum fix.
