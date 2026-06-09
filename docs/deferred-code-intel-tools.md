# Deferred Code-Intel Tools

Source of truth: `~/dotfiles/docs/deferred-code-intel-tools.md`.
Mirror: `~/obsidian/General Tech/Tooling/Deferred Code-Intel Tools.md`.
Last updated: 2026-06-09.

## Purpose

Keep a short list of code-intelligence tools that are worth remembering but not worth installing until a concrete use case appears.

The inclusion rule is strict: tools here must have near-zero idle context cost. Prefer CLI-shaped, pull-only tools that do nothing unless explicitly invoked. Do not add MCP servers, always-on repo maps, vector indexes, or server/index-heavy systems to this list.

## Currently Covered

- `rg` handles fast text search across code, docs, logs, and config.
- `sg` from ast-grep handles AST-aware structural search and rewrite between `rg` and LSP. Adopted in commit `1de70994`.
- Claude Code LSP plugins handle semantic queries for Python, TypeScript/JavaScript, Go, Rust, Bash, YAML, Terraform, Lua, and Nix.
- Semgrep is already profile-gated for ops/dev/comprehensive use cases when dataflow or taint analysis is actually needed.

## Deferred Tools

### scalex

Link: <https://github.com/nguyenyou/scalex>

What it is: Scala-focused code intelligence for agents, designed to answer structural and semantic questions without relying on a full Metals/BSP setup.

Gap it fills: Scala symbol/reference/type exploration when Metals is slow, brittle, or too expensive to warm up for an agent session.

Why not now: the active stack has no real Scala surface despite the `~/dotfiles-scala` directory name. Current work is covered by `rg`, `sg`, and existing LSP plugins.

Reconsider when:

- A real Scala repo lands in `~/work/*` with `build.sbt`, `build.sc`, `mill`, or substantial `.scala` files.
- Sessions repeatedly need Scala symbol, reference, or type queries.
- Metals/BSP warmup or fragility becomes the bottleneck after trying normal LSP wiring.

Adoption note: try Metals through the existing LSP pattern first. Use scalex only if Metals is the source of friction. Prefer CLI-only wiring if available; avoid MCP wiring unless structured tool calls clearly justify the schema cost.

### Comby

Link: <https://comby.dev/>

What it is: multi-language structural search and rewrite using lightweight match templates.

Gap it fills: broad structural rewrites where `sg` patterns are awkward, especially fuzzy matches across formatting or simple nested blocks.

Reconsider when:

- A refactor spans many files and is too structural for `rg` but too loose or cross-formatting for ast-grep.
- The target pattern is not language-specific enough to justify writing custom AST queries.

Adoption note: keep it CLI-only. Install on demand rather than adding to default profiles unless repeated bulk refactors make it routine.

### GritQL

Link: <https://github.com/getgrit/gritql>

What it is: structural code query and rewrite tooling with a different DSL from ast-grep.

Gap it fills: codemod-style transformations where ast-grep is possible but cumbersome.

Reconsider when:

- A repeated codemod pattern is hard to express with `sg`.
- Comby is too fuzzy and ast-grep is too grammar-bound for the job.

Adoption note: evaluate against ast-grep and Comby before wiring. Do not add it just to have another structural-search option.

### Aider grep-ast / Repo Map

Link: <https://github.com/Aider-AI/aider>

What it is: tree-sitter-backed repository orientation, including outlines of top-level code structure.

Gap it fills: on-demand orientation in unfamiliar large repositories without injecting an always-on repo map into every session.

Reconsider when:

- Work in a large unfamiliar repo repeatedly starts with broad file reads just to understand structure.
- `rg` finds too many candidates and LSP queries need better initial targeting.

Adoption note: prefer a pull-only script or standalone `grep-ast` style invocation. Do not add an always-on SessionStart repo map.

### repomix / code2prompt / files-to-prompt

Links:

- <https://github.com/yamadashy/repomix>
- <https://github.com/mufeedvh/code2prompt>
- <https://github.com/simonw/files-to-prompt>

What they are: one-shot repo/file bundlers for intentionally sending a selected codebase snapshot to a model.

Gap they fill: batch review, architecture summary, migration planning, or one-prompt audits on small or carefully scoped repos.

Reconsider when:

- The task is explicitly batch-shaped rather than interactive.
- The repo or selected subtree is small enough that a full prompt bundle is intentional.
- The output can be generated, used once, and discarded.

Adoption note: do not use for normal incremental sessions. These tools are low idle cost but can create huge one-time prompts if used carelessly.

### universal-ctags / GNU Global / codanna

Links:

- <https://ctags.io/>
- <https://www.gnu.org/software/global/>
- <https://github.com/bartolli/codanna>

What they are: tag or symbol indexes for fast symbol lookup without a full language server.

Gap they fill: cheap symbol navigation when LSP startup, project discovery, or dependency resolution is too slow for the task.

Reconsider when:

- LSP warmup becomes a measurable repeated bottleneck.
- A repo has enough symbols to need navigation but not enough setup stability for reliable LSP use.
- The index can be generated on demand and ignored by git.

Adoption note: prefer per-repo generated indexes over global always-on services. Do not add indexes to prompts by default.

## Do Not Track Here

Do not add tools whose main cost shape is always-on context, MCP schema tax, vector/index infrastructure, or org-scale code search. This registry is for low-idle-cost tools that should be remembered for future legitimate use cases, not for broad code-intelligence wishlists.
