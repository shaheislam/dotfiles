# RULES.md - Actionable Rules

Simple actionable rules for Claude Code framework operation.

## Core Operational Rules

### Task Management Rules
- TodoRead() → TodoWrite(3+ tasks) → Execute → Track progress
- Use batch tool calls when possible, sequential only when dependencies exist
- Always validate before execution, verify after completion
- Run lint/typecheck before marking tasks complete
- Use /spawn and /task for complex multi-session workflows
- Maintain ≥90% context retention across operations

### File Operation Security
- Always use Read tool before Write or Edit operations
- Use absolute paths only, prevent path traversal attacks
- Prefer batch operations and transaction-like behavior
- Never commit automatically unless explicitly requested OR auto-commit mode is enabled via /commit-mode on

### Framework Compliance
- Check package.json/pyproject.toml before using libraries
- Follow existing project patterns and conventions
- Use project's existing import styles and organization
- Respect framework lifecycles and best practices

### Git Commit Standards
- **NEVER** use emojis in commit messages
- **NEVER** reference "Claude", "Claude Code", or any AI assistant names in commits
- Use conventional commit format: `type: brief description`
- Keep commits professional, clear, and tool-agnostic
- Focus on what changed and why, not who or what tool made the change

### Bash Command Chaining
- Use `;` not `&&` when chaining independent commands where the second's failure should not mask the first's success (e.g., `bd close ID; bd sync --from-main`)
- Only use `&&` when the second command genuinely depends on the first succeeding

### Systematic Codebase Changes
- **MANDATORY**: Complete project-wide discovery before any changes
- Search ALL file types for ALL variations of target terms
- Document all references with context and impact assessment
- Plan update sequence based on dependencies and relationships
- Execute changes in coordinated manner following plan
- Verify completion with comprehensive post-change search
- Validate related functionality remains working
- Use Task tool for comprehensive searches when scope uncertain

## Quick Reference

### Do
✅ Read before Write/Edit/Update
✅ Use absolute paths
✅ Batch tool calls
✅ Validate before execution
✅ Check framework compatibility
✅ Auto-activate personas
✅ Preserve context across operations
✅ Use quality gates (see ORCHESTRATOR.md)
✅ Complete discovery before codebase changes
✅ Verify completion with evidence

### Don't
❌ Skip Read operations
❌ Use relative paths
❌ Auto-commit without permission
❌ Ignore framework patterns
❌ Skip validation steps
❌ Mix user-facing content in config
❌ Override safety protocols
❌ Make reactive codebase changes
❌ Mark complete without verification
❌ Use emojis in commit messages
❌ Reference AI assistants in commits
❌ Chain independent commands with `&&` (use `;` instead)

### Auto-Triggers
- Wave mode: complexity ≥0.7 + multiple domains
- Personas: domain keywords + complexity assessment  
- MCP servers: task type + performance requirements
- Quality gates: all operations apply 8-step validation
