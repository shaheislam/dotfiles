# OpenCode Agent Guide

Rules for `~/dotfiles/.config/opencode`.

## Scope

- Use OpenCode customization rules only for OpenCode config, agents, skills, plugins, MCP servers, and permission rules.
- Do not apply OpenCode customization patterns to normal application code.
- Keep durable OpenCode configuration in `~/dotfiles`; generated runtime surfaces can be materialized elsewhere.

## Configuration

- Keep plugin and harness behavior aligned with Claude-compatible hooks when relevant.
- Update docs when adding commands, agents, skills, or plugin behavior that agents need to know.
- Prefer small changes to existing plugin files over adding parallel mechanisms.
- OpenCode tmux status is event-driven through `plugin/harness-compat.ts`; `scripts/opencode/tmux-open.sh` only handles tmux setup, alternate-screen behavior, attach tracking, and cleanup.
- The harness plays a macOS idle bell on primary-session `session.status: idle`; set `OPENCODE_BELL=0` to disable it or `OPENCODE_BELL_SOUND=/path/to/file.aiff` to override the sound.
- Keep slash commands in `command/` short and low-context; avoid fragment expanders or large boilerplate unless usage data justifies the picker/context cost.

## Validation

- Run `scripts/test-filter.sh opencode` for OpenCode config changes.
- Run targeted syntax checks for edited TypeScript or JavaScript files when applicable.
- Check MCP parity with `scripts/test-filter.sh mcp` when MCP server wiring changes.
