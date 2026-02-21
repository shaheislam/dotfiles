# TASK: codecompanion

## Question
Is it worth installing CodeCompanion (https://github.com/olimorris/codecompanion.nvim) into our Neovim config?

## Answer
**Yes** - CodeCompanion is a strong fit for this setup. Here's the analysis:

### Why Install

1. **Fills a gap**: The current Neovim config has 78 plugins but zero AI tools. CodeCompanion adds chat, inline editing, and agentic workflows without duplicating any existing functionality.

2. **Provider flexibility**: Supports 15+ HTTP adapters (Anthropic, OpenAI, Ollama, Gemini, etc.) and 8+ ACP agents (Claude Code, Codex, OpenCode). This aligns with the existing stack - Anthropic API is already available, and Ollama is configured in the dotfiles.

3. **Zero-conflict dependencies**: Both required deps (plenary.nvim, nvim-treesitter) are already installed. Optional blink.cmp integration works natively.

4. **Excellent maintenance**: 6.2k stars, v18.7.0 (released Feb 18, 2026), 385 total releases, 163 contributors, 0 open issues. One of the most actively maintained Neovim plugins.

5. **Complements Claude Code**: When editing in Neovim directly (not through Claude Code), CodeCompanion provides in-editor AI assistance. Different use case than the terminal-based Claude Code workflow.

### What It Does NOT Do

- **No inline autocomplete** (like Copilot ghost-text). This is a deliberate design decision by the maintainer. If you want that, add copilot.lua separately.
- **Not a replacement for Claude Code CLI** - it's complementary. Claude Code operates at the project level; CodeCompanion operates at the buffer/chat level.

### What Was Implemented

**Files modified in `~/neovim`:**

1. **`lua/plugins/codecompanion.lua`** (new) - Plugin config with:
   - Anthropic as primary adapter (claude-sonnet-4)
   - Ollama as secondary adapter (qwen2.5-coder:7b)
   - `<leader>a` prefix keymaps for all AI operations
   - Lazy-loaded on commands and keymaps

2. **`lua/plugins/blink-cmp.lua`** (modified) - Added CodeCompanion completion source for slash commands and variables in chat buffers

3. **`lua/plugins/which-key.lua`** (modified) - Registered `<leader>a` group as "ai (CodeCompanion)"

### Keymaps

| Key | Mode | Action |
|-----|------|--------|
| `<leader>aa` | n, v | Action Palette (all commands) |
| `<leader>ac` | n, v | Toggle Chat buffer |
| `<leader>ai` | n, v | Inline Assist (prompt) |
| `<leader>ae` | v | Explain selection |
| `<leader>af` | v | Fix selection |
| `<leader>at` | v | Generate tests for selection |
| `<leader>ad` | v | Add selection to chat |

### Setup Required

Set `ANTHROPIC_API_KEY` environment variable (add to Fish config if not already present from Claude Code usage). For Ollama, ensure it's running locally.

### Alternatives Considered

| Plugin | Stars | Verdict |
|--------|-------|---------|
| **avante.nvim** | ~14k | More "Cursor-like" but worse docs, more bugs (200+ open issues), requires compiled artifacts |
| **copilot.lua** | ~3k | Inline autocomplete only - complementary, not a replacement |
| **CopilotChat.nvim** | ~3.5k | GitHub Copilot-only provider - less flexible |

CodeCompanion is the best choice for a provider-agnostic, well-maintained, Neovim-native AI assistant.
