# Skills Index

46 skills organized by function. Each skill is a directory containing `SKILL.md` (and optionally reference files). Invoke with `/skill-name` or by telling Claude to use the skill.

## Categories

### Session Lifecycle
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `start` | `/start` | Load context, find next unblocked task, begin work |
| `wrap-up` | `/wrap-up` | Validate, test, commit, close current task |
| `session-review` | `/session-review` | End-of-session retrospective |
| `commit-mode` | `/commit-mode` | Toggle auto-commit behavior |
| `continue-claude-work` | `/continue-claude-work` | Recover context from interrupted sessions |

### Content & Knowledge
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `youtube` | `/youtube URL` | Fetch transcript, summarize, save to Obsidian |
| `article` | `/article URL` | Clip web article to Obsidian |
| `diagram` | `/diagram` | Create visual diagrams, save to Obsidian |
| `confluence` | `/confluence` | Convert markdown to Confluence format |

### Development & Quality
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `ship` | `/ship` | Pre-flight, sync, validate, commit, push, PR |
| `fix` | `/fix` | Diagnose and fix dotfiles breakage |
| `dotfiles-sync` | `/dotfiles-sync` | Sync dotfiles with stow |
| `security-audit` | `/security-audit` | OWASP + STRIDE security audit |
| `retro` | `/retro` | Git history retrospective |

### Research & Analysis
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `research-spike` | `/research-spike` | Structured research for tech decisions |
| `gap-analysis` | `/gap-analysis` | Analyze external sources, find value-add gaps |
| `best-practice` | `/best-practice` | Extract best practices from a URL |
| `fact-checker` | `/fact-checker` | Verify factual claims with sources |
| `prompt-optimizer` | `/prompt-optimizer` | Transform prompts into EARS specs |

### JFDI Memory System
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `jfdi` | `/jfdi` | Executive assistant for session metadata |
| `jfdi-sync` | `/jfdi-sync` | Sync sessions to JFDI database |
| `jfdi-extract` | `/jfdi-extract` | Extract memories from sessions |
| `jfdi-recall` | `/jfdi-recall` | Query memories on demand |
| `jfdi-synthesis` | `/jfdi-synthesis` | Generate weekly synthesis reports |
| `dream` | `/dream` | 4-phase memory consolidation |

### Ticket & Project Management
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `todo` | `/todo` | Quick ticket creation (Linear/Jira) |
| `ticket-execute` | `/ticket-execute` | Execute ticket autonomously |
| `jira` | `/jira` | Jira ticket CRUD |
| `jira-batch` | `/jira-batch` | Batch create Jira tickets from markdown |
| `cv-generate` | `/cv-generate` | Generate optimized LaTeX CV |

### Infrastructure & Tools
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `aws-profile` | `/aws-profile` | Switch AWS profile with granted |
| `s3-search` | `/s3-search` | Search S3 with s3grep |
| `s3-upload` | `/s3-upload` | Upload to S3 |
| `mcp-restart` | `/mcp-restart` | Restart MCP servers |
| `fish-reload` | `/fish-reload` | Reload Fish config |
| `git-config-fix` | `/git-config-fix` | Fix git configuration |
| `claude-cleanup` | `/claude-cleanup` | Clean ~/.claude directories |
| `macos-cleaner` | `/macos-cleaner` | Recover macOS disk space |

### Safety & Guardrails
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `careful` | `/careful` | Enable destructive command warnings |
| `freeze` | `/freeze` | Lock edits to single directory |
| `unfreeze` | `/unfreeze` | Remove freeze restriction |
| `guard` | `/guard` | Maximum safety (careful + freeze) |

### Context & Vault Management
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `context-health` | `/context-health` | Audit Obsidian vault and context infrastructure |
| `morning-brief` | `/morning-brief` | Daily briefing from Obsidian vault (vault-reference pattern) |

### Browser & Automation
| Skill | Trigger | Purpose |
|-------|---------|---------|
| `agent-browser` | `/agent-browser` | Browser automation for AI agents |
| `capture-screen` | `/capture-screen` | Programmatic screenshot capture |
| `cross-ref` | `/cross-ref` | Cross-reference worktree changes |

## Adding New Skills

See `workflows.md` in `.claude/context/` for the standard skill creation workflow.
