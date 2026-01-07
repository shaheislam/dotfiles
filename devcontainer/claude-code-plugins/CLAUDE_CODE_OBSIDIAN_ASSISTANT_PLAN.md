# Claude Code Executive Assistant with Obsidian Integration

## Implementation Plan

Based on the JFDI system architecture described in the video transcripts, this plan outlines how to build a similar executive assistant that captures Claude Code metadata, inputs/outputs, and automatically syncs everything to an Obsidian vault.

---

## 0. Your Existing Infrastructure (Leverage These)

Your setup already has many foundational pieces in place:

### Obsidian Vault (`/mounts/obsidian/`)
- **Auto-commit system**: Git-based with fswatch, smart commit messages, 5-second debounce
- **AI plugins**: smart-connections (semantic search), smart-chatgpt, smart-context
- **Daily notes**: `Daily/YYYY/MM-Mon/` structure with templates
- **Frontmatter pattern**: `id`, `aliases`, `tags` (extend for sessions/memories)
- **Dataview**: Already installed for dynamic queries
- **Existing folders**: Career, DfE, PLB, Clippings, Organization

### Claude Code Hooks (`/mounts/dotfiles/.claude/hooks/`)
- `add-context.py` - Already injects timestamp, git info, environment context
- `log_pre_tool_use.py` - Existing logging infrastructure
- `use_bun.py` - Enforces bun/bunx
- Can add new hooks for session capture and memory injection

### MCP Servers (Already Configured)
- `context7` - Documentation lookup
- `playwright` - Web automation
- `steampipe` - PostgreSQL access (can use for session storage!)
- `deepwiki` - Research context

### Claude Framework (`/mounts/dotfiles/.claude/`)
- `AGENTS.md` - 12 specialized agent personas
- `MODES.md` - Task management, introspection modes
- `ORCHESTRATOR.md` - Multi-domain workflow patterns
- `COMMANDS.md` - Custom commands system

### Neovim Integration
- Hot-reload system watching for file changes
- `<leader>yr` - Yank with relative path (perfect for context)
- Obsidian.nvim with semantic search via Python scripts

---

## 1. System Overview

### Core Concept
Build an AI-powered executive assistant that:
- Captures all Claude Code session data (inputs, outputs, tool calls, file touches)
- Automatically extracts "memories" from sessions (decisions, insights, corrections, patterns)
- Stores everything in a searchable database with vector embeddings
- Syncs to an Obsidian vault for human-readable knowledge management
- Uses Claude Code hooks for real-time context injection

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERFACE LAYER                          │
│  - Chat wrapper (optional web UI)                                │
│  - Obsidian vault (markdown files)                               │
│  - Slash commands & skills                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    CLAUDE CODE LAYER                             │
│  - Headless mode API                                             │
│  - Hooks (user_prompt_submit, tool_use, stop)                   │
│  - Session management                                            │
│  - Slash commands                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    PROCESSING LAYER                              │
│  - Session sync job (every 5 min)                               │
│  - Memory catcher job (every 15 min)                            │
│  - Weekly synthesis job                                          │
│  - Obsidian sync job                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    STORAGE LAYER                                 │
│  - PostgreSQL/SQLite + pgvector                                 │
│  - Obsidian vault (markdown)                                     │
│  - Local embeddings (Ollama)                                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Phase 1: Claude Code Session Capture

### 2.1 Session Data Extraction

Claude Code stores sessions as JSONL files in `~/.claude/projects/`. Extract and process these files.

**Data to capture per session:**
- `session_id` - Unique identifier
- `created_at` / `updated_at` - Timestamps
- `first_message` - User's initial prompt
- `last_message` - Most recent message
- `full_transcript` - Complete JSONL content
- `user_messages` - Array of all user inputs
- `assistant_messages` - Array of all Claude responses
- `tool_calls` - Array of tool invocations with parameters
- `files_touched` - Files read, edited, or created
- `work_type` - Classified type (development, research, planning, etc.)
- `token_usage` - Estimated tokens used

**Implementation:**
```typescript
// session-sync.ts
interface ClaudeSession {
  sessionId: string;
  createdAt: Date;
  updatedAt: Date;
  firstMessage: string;
  lastMessage: string;
  fullTranscript: object[];
  userMessages: string[];
  assistantMessages: string[];
  toolCalls: ToolCall[];
  filesTouched: string[];
  workType: string;
  tokenEstimate: number;
}

// Sync job runs every 5 minutes
async function syncSessions() {
  const sessionDir = path.join(os.homedir(), '.claude/projects');
  const jsonlFiles = await glob(`${sessionDir}/**/*.jsonl`);

  for (const file of jsonlFiles) {
    const session = await parseSessionFile(file);
    await upsertSession(session);
  }
}
```

### 2.2 Database Schema

```sql
-- Core sessions table
CREATE TABLE claude_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT UNIQUE NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  first_message TEXT,
  last_message TEXT,
  full_transcript JSONB,
  user_messages JSONB,
  assistant_messages JSONB,
  tool_calls JSONB,
  files_touched TEXT[],
  work_type TEXT,
  token_estimate INTEGER,
  classified BOOLEAN DEFAULT FALSE,
  classification_title TEXT,
  memory_extracted BOOLEAN DEFAULT FALSE,
  synced_to_obsidian BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_sessions_created ON claude_sessions(created_at DESC);
CREATE INDEX idx_sessions_work_type ON claude_sessions(work_type);
```

---

## 3. Phase 2: Memory Extraction System

### 3.1 Memory Catcher

Automatically extract "moments of consequential decision" from sessions.

**Memory Types:**
| Type | Description | Priority |
|------|-------------|----------|
| `decision` | Explicit choices made | High |
| `insight` | New understanding gained | High |
| `correction` | Mistakes corrected (either direction) | Critical |
| `pattern` | Repeated behaviors detected | Medium |
| `commitment` | Promises or plans made | High |
| `learning` | Technical or systems learning | High |
| `workflow` | Process improvements | Medium |
| `gap` | Missing connections identified | Medium |

**Extraction Triggers (inspired by Google's research):**
1. **Recovery patterns** - Failed attempt followed by success
2. **User corrections** - "No, do it this way instead"
3. **Enthusiasm signals** - "That's exactly what I wanted!"
4. **Negative reactions** - "Never do that again"
5. **Repeat requests** - Same thing asked multiple times

**Memory Schema:**
```sql
CREATE TABLE memories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id TEXT REFERENCES claude_sessions(session_id),
  memory_type TEXT NOT NULL,
  category TEXT, -- technical, systems, relationship, creative, etc.
  title TEXT NOT NULL,
  summary TEXT NOT NULL,
  reasoning TEXT, -- Why this was extracted as a memory
  original_context TEXT, -- Chunk from session
  confidence_score FLOAT,
  related_entities JSONB, -- {people: [], projects: [], files: []}
  formed_at TIMESTAMP NOT NULL, -- When the moment happened
  created_at TIMESTAMP DEFAULT NOW(),
  embedding vector(1536), -- For semantic search
  obsidian_path TEXT -- Path in Obsidian vault
);

CREATE INDEX idx_memories_type ON memories(memory_type);
CREATE INDEX idx_memories_formed ON memories(formed_at DESC);
CREATE INDEX idx_memories_embedding ON memories USING ivfflat (embedding vector_cosine_ops);
```

### 3.2 Memory Extraction Prompt

```markdown
# Memory Catcher Instructions

Analyze this Claude Code session transcript and extract memories.

## What to Extract
Look for "moments of consequential decision" - information worth remembering:
- **Decisions**: Explicit choices made about implementation, design, or approach
- **Insights**: New understanding or realizations
- **Corrections**: When user corrected the AI or vice versa
- **Patterns**: Repeated behaviors or preferences
- **Commitments**: Plans, promises, or intentions expressed
- **Learning**: Technical knowledge gained
- **Workflows**: Process improvements discovered
- **Gaps**: Missing connections between systems

## Extraction Triggers (prioritize these)
1. Recovery patterns (failed then succeeded)
2. User corrections ("no, do X instead")
3. Enthusiasm signals ("perfect!", "exactly right")
4. Negative reactions ("don't do that")
5. Repeated requests

## Output Format
For each memory, provide:
- type: decision|insight|correction|pattern|commitment|learning|workflow|gap
- category: technical|systems|relationship|creative|planning|communication
- title: Brief descriptive title (5-10 words)
- summary: 1-2 sentence summary
- reasoning: Why this is worth remembering
- confidence: 0.0-1.0 confidence score
- entities: Related people, projects, files
- context: Relevant chunk from transcript

Extract 0-10 memories per session. Quality over quantity.
```

---

## 4. Phase 3: Obsidian Integration

### 4.1 Vault Structure (Integrated with Your Existing Vault)

Your vault already has established conventions. New JFDI folders will follow your patterns:

```
/mounts/obsidian/
├── templates/                    # EXISTING - add new templates here
│   ├── daily.md                  # Your existing daily template
│   ├── session.md                # NEW: Claude session template
│   ├── memory.md                 # NEW: Memory extraction template
│   └── audit-activity.md         # NEW: Audit trail template
│
├── Daily/                        # EXISTING - enhanced with session links
│   └── 2026/01-Jan/
│       └── 2026-01-04.md         # Add "## Claude Sessions" section
│
├── Claude/                       # NEW: Main JFDI folder
│   ├── Sessions/                 # Session transcripts
│   │   └── 2026/01/
│   │       ├── 2026-01-04-abc123.md
│   │       └── 2026-01-04-def456.md
│   │
│   ├── Memories/                 # Extracted memories by type
│   │   ├── decisions/
│   │   ├── insights/
│   │   ├── corrections/
│   │   ├── patterns/
│   │   ├── learning/
│   │   └── workflows/
│   │
│   ├── Audit/                    # Audit trails by date
│   │   └── 2026-01-04/
│   │       ├── session-sync-activity.md
│   │       └── memory-catcher-activity.md
│   │
│   ├── Synthesis/                # Weekly synthesis reports
│   │   ├── weekly/
│   │   │   └── 2026-W01.md
│   │   └── patterns/
│   │       └── discovered-patterns.md
│   │
│   └── _Index.md                 # Dataview dashboard (see below)
│
├── DfE/                          # EXISTING - link sessions to tickets
├── PLB/                          # EXISTING - link sessions to projects
├── Career/                       # EXISTING
└── .claude/                      # EXISTING - Claude Code settings
```

### 4.1.1 Dataview Dashboard (`Claude/_Index.md`)

```markdown
---
id: claude-index
aliases: [JFDI Dashboard, Claude Sessions]
tags: [index, claude, dashboard]
---

# Claude Assistant Dashboard

## Recent Sessions
\`\`\`dataview
TABLE
  work_type as "Type",
  length(files_touched) as "Files",
  memory_count as "Memories"
FROM "Claude/Sessions"
SORT created DESC
LIMIT 10
\`\`\`

## Memories by Type
\`\`\`dataview
TABLE
  length(rows) as "Count"
FROM "Claude/Memories"
GROUP BY memory_type
\`\`\`

## Recent Corrections (High Value)
\`\`\`dataview
LIST summary
FROM "Claude/Memories/corrections"
SORT formed DESC
LIMIT 5
\`\`\`

## Unprocessed Sessions
\`\`\`dataview
LIST
FROM "Claude/Sessions"
WHERE !memory_extracted
\`\`\`

## Weekly Synthesis
\`\`\`dataview
TABLE
  patterns_found as "Patterns",
  recommendations as "Recommendations"
FROM "Claude/Synthesis/weekly"
SORT file.name DESC
LIMIT 4
\`\`\`
```

### 4.2 Obsidian Templates

**Session Template (`_system/templates/session.md`):**
```markdown
---
type: session
session_id: {{session_id}}
created: {{created_at}}
updated: {{updated_at}}
work_type: {{work_type}}
tokens: {{token_estimate}}
files_touched:
{{#files_touched}}
  - "{{.}}"
{{/files_touched}}
memories_extracted: {{memory_count}}
tags:
  - session
  - {{work_type}}
---

# Session: {{title}}

## Summary
{{summary}}

## First Message
> {{first_message}}

## Key Tool Calls
{{#tool_calls}}
- `{{tool}}`: {{description}}
{{/tool_calls}}

## Files Touched
{{#files_touched}}
- [[{{.}}]]
{{/files_touched}}

## Extracted Memories
{{#memories}}
- [[{{memory_path}}|{{memory_title}}]]
{{/memories}}

## Full Transcript
<details>
<summary>Click to expand</summary>

{{transcript_markdown}}

</details>
```

**Memory Template (`_system/templates/memory.md`):**
```markdown
---
type: memory
memory_type: {{memory_type}}
category: {{category}}
confidence: {{confidence}}
formed: {{formed_at}}
session: "[[sessions/{{session_path}}]]"
entities:
{{#entities}}
  - "[[entities/{{.}}]]"
{{/entities}}
tags:
  - memory
  - {{memory_type}}
  - {{category}}
---

# {{title}}

## Summary
{{summary}}

## Why This Matters
{{reasoning}}

## Original Context
> {{original_context}}

## Related
- Session: [[sessions/{{session_path}}]]
{{#entities}}
- [[entities/{{.}}]]
{{/entities}}
```

### 4.3 Sync Logic

```typescript
// obsidian-sync.ts
async function syncToObsidian(config: ObsidianConfig) {
  const unsyncedSessions = await db.query(
    'SELECT * FROM claude_sessions WHERE synced_to_obsidian = FALSE'
  );

  for (const session of unsyncedSessions) {
    // Generate markdown from template
    const markdown = renderTemplate('session', session);

    // Write to vault
    const datePath = format(session.created_at, 'yyyy/MM/yyyy-MM-dd');
    const filePath = path.join(
      config.vaultPath,
      'sessions',
      datePath,
      `session-${session.session_id.slice(0, 8)}.md`
    );

    await fs.mkdir(path.dirname(filePath), { recursive: true });
    await fs.writeFile(filePath, markdown);

    // Mark as synced
    await db.query(
      'UPDATE claude_sessions SET synced_to_obsidian = TRUE, obsidian_path = $1 WHERE id = $2',
      [filePath, session.id]
    );
  }

  // Sync memories
  const unsyncedMemories = await db.query(
    'SELECT * FROM memories WHERE obsidian_path IS NULL'
  );

  for (const memory of unsyncedMemories) {
    const markdown = renderTemplate('memory', memory);
    const filePath = path.join(
      config.vaultPath,
      'memories',
      memory.memory_type,
      `${slugify(memory.title)}.md`
    );

    await fs.writeFile(filePath, markdown);
    await db.query(
      'UPDATE memories SET obsidian_path = $1 WHERE id = $2',
      [filePath, memory.id]
    );
  }

  // Update indexes
  await updateIndexes(config);
}
```

---

## 5. Phase 4: Claude Code Hooks Integration

### 5.0 Integration with Your Existing Hooks

Your hooks live at `/mounts/dotfiles/.claude/hooks/`. We'll add new hooks alongside:

**Existing hooks to leverage:**
- `add-context.py` - Already injects timestamp, git info → extend to inject memories
- `log_pre_tool_use.py` - Can log tool usage for audit trail

**New hooks to create:**
```
/mounts/dotfiles/.claude/hooks/
├── add-context.py              # EXISTING - modify to include memory retrieval
├── log_pre_tool_use.py         # EXISTING - extend for audit trail
├── use_bun.py                  # EXISTING
├── memory-retrieval.py         # NEW: Inject relevant memories on prompt submit
├── session-checkpoint.py       # NEW: Save session state on stop
└── file-memory-lookup.py       # NEW: Lookup memories when files are touched
```

### 5.1 Hook Configuration

Your hooks are configured in `/mounts/dotfiles/.claude/settings.json`. Add new hook entries:
```json
{
  "hooks": {
    "user_prompt_submit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/memory-retrieval.sh \"$PROMPT\""
          }
        ]
      }
    ],
    "tool_use": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/file-memory-lookup.sh \"$TOOL_INPUT\""
          }
        ]
      }
    ],
    "stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/session-checkpoint.sh \"$SESSION_ID\""
          }
        ]
      }
    ]
  }
}
```

### 5.2 Memory Retrieval Hook

```bash
#!/bin/bash
# memory-retrieval.sh

PROMPT="$1"
API_URL="http://localhost:3001/api/memory/retrieve"

# Call retrieval API
MEMORIES=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"$PROMPT\"}")

# If memories found, output context injection
if [ -n "$MEMORIES" ] && [ "$MEMORIES" != "[]" ]; then
  echo "<context_injection>"
  echo "## Relevant Memories"
  echo "$MEMORIES" | jq -r '.[] | "- **\(.title)** (\(.memory_type)): \(.summary)"'
  echo "</context_injection>"
fi
```

### 5.3 Retrieval Algorithm

```typescript
// memory-retrieval.ts
interface RetrievalConfig {
  semanticWeight: number;      // 0.6
  entityWeight: number;        // 0.3
  recencyWeight: number;       // 0.1
  minConfidence: number;       // 0.5
  maxResults: number;          // 10
  feedbackBoost: number;       // 0.05 per thumbs up/down
}

async function retrieveMemories(query: string, config: RetrievalConfig) {
  // 1. Extract entities from query
  const entities = await extractEntities(query);

  // 2. Generate embedding for semantic search
  const queryEmbedding = await generateEmbedding(query);

  // 3. Entity-based retrieval
  const entityMemories = await db.query(`
    SELECT m.*,
           0.8 as entity_score
    FROM memories m
    WHERE m.related_entities ?| $1
  `, [entities]);

  // 4. Semantic retrieval
  const semanticMemories = await db.query(`
    SELECT m.*,
           1 - (m.embedding <=> $1) as semantic_score
    FROM memories m
    WHERE 1 - (m.embedding <=> $1) > $2
    ORDER BY semantic_score DESC
    LIMIT 50
  `, [queryEmbedding, config.minConfidence]);

  // 5. Merge and re-rank
  const allMemories = mergeMemories(entityMemories, semanticMemories);

  // 6. Apply re-ranking algorithm
  const rankedMemories = allMemories.map(m => {
    let score = 0;

    // Semantic similarity
    score += (m.semantic_score || 0) * config.semanticWeight;

    // Entity match
    score += (m.entity_score || 0) * config.entityWeight;

    // Recency boost
    const daysSince = daysBetween(m.formed_at, new Date());
    score += Math.exp(-daysSince / 30) * config.recencyWeight;

    // Feedback adjustment
    score += (m.thumbs_up - m.thumbs_down) * config.feedbackBoost;

    // Intent boosting
    if (query.match(/error|mistake|wrong|fix/i) && m.memory_type === 'correction') {
      score *= 1.3;
    }

    return { ...m, finalScore: score };
  });

  // 7. Filter and return top results
  return rankedMemories
    .filter(m => m.finalScore > config.minConfidence)
    .sort((a, b) => b.finalScore - a.finalScore)
    .slice(0, config.maxResults);
}
```

---

## 6. Phase 5: Audit Trail & Learning System

### 6.1 Audit Trail Generation

Every agent/workflow generates an audit trail file.

**Audit Trail Template:**
```markdown
---
type: audit
agent: {{agent_name}}
timestamp: {{timestamp}}
duration_ms: {{duration}}
success: {{success}}
---

# {{agent_name}} Activity - {{timestamp}}

## What Happened
{{summary}}

## Actions Taken
{{#actions}}
- {{.}}
{{/actions}}

## Decisions Made
{{#decisions}}
### {{decision_title}}
- **Context**: {{context}}
- **Options Considered**: {{options}}
- **Chosen**: {{chosen}}
- **Reasoning**: {{reasoning}}
{{/decisions}}

## Data Generated
{{#outputs}}
- {{.}}
{{/outputs}}

## Cross-Agent Notes
{{cross_agent_notes}}

## Files Modified
{{#files}}
- `{{.}}`
{{/files}}
```

### 6.2 Weekly Synthesis

```typescript
// weekly-synthesis.ts
async function runWeeklySynthesis() {
  const weekStart = startOfWeek(new Date());
  const weekEnd = endOfWeek(new Date());

  // Gather data
  const auditTrails = await getAuditTrailsForPeriod(weekStart, weekEnd);
  const memories = await getMemoriesForPeriod(weekStart, weekEnd);
  const sessions = await getSessionsForPeriod(weekStart, weekEnd);
  const gitHistory = await getGitCommitsForPeriod(weekStart, weekEnd);

  // Run synthesis agents in parallel
  const [patterns, recommendations, gaps] = await Promise.all([
    runPatternMiner(auditTrails, memories),
    runRecommendationTracker(sessions),
    runGapDetector(memories)
  ]);

  // Generate synthesis report
  const synthesis = {
    weeklyPatterns: patterns,
    recommendations: recommendations.map(r => ({
      ...r,
      implemented: false,
      confidenceScore: r.confidence
    })),
    systemGaps: gaps,
    crossWeekTrends: await analyzeCrossWeekTrends(weekStart),
    technicalVelocity: calculateVelocity(gitHistory)
  };

  // Save to Obsidian
  const markdown = renderTemplate('weekly-synthesis', synthesis);
  await fs.writeFile(
    path.join(config.vaultPath, 'synthesis/weekly', `${format(weekStart, 'yyyy-Www')}.md`),
    markdown
  );

  // Queue recommendations for review
  for (const rec of recommendations) {
    if (rec.confidence > 0.7) {
      await createFeatureIdea(rec);
    }
  }
}
```

---

## 7. Implementation Phases (Accelerated - Leveraging Your Existing Setup)

Since you already have significant infrastructure, the timeline is compressed:

### Phase 1: Session Capture (Days 1-3)
- [ ] Create session sync script (TypeScript/Bun) to read `~/.claude/projects/*.jsonl`
- [ ] Set up SQLite database (or use Steampipe PostgreSQL via your MCP)
- [ ] Create `Claude/` folder structure in Obsidian vault
- [ ] Add session template to `/mounts/obsidian/templates/`
- [ ] Build basic sync job (cron or launchd like your auto-commit)

**Already done for you:**
- ✅ Auto-commit system (will auto-commit new session files)
- ✅ Frontmatter patterns established
- ✅ Dataview installed for queries

### Phase 2: Memory Extraction (Days 4-7)
- [ ] Create memory extraction prompt (see Section 3.2)
- [ ] Build memory catcher job (runs every 15 min)
- [ ] Add memory template to Obsidian
- [ ] Integrate with smart-connections for semantic search (see 7.1 below)
- [ ] Create `memory-retrieval.py` hook

**Already done for you:**
- ✅ smart-connections plugin (semantic search)
- ✅ `add-context.py` hook (extend for memories)
- ✅ Ollama likely available for local embeddings

### Phase 3: Context Injection (Days 8-10)
- [ ] Modify `add-context.py` to query memories
- [ ] Create `file-memory-lookup.py` hook for Read/Edit events
- [ ] Add `session-checkpoint.py` for stop events
- [ ] Test memory injection in real workflows

**Already done for you:**
- ✅ Hook infrastructure working
- ✅ Pre-tool-use logging exists

### Phase 4: Audit & Synthesis (Days 11-14)
- [ ] Create audit trail generator (extends `log_pre_tool_use.py`)
- [ ] Build weekly synthesis command (`/mounts/dotfiles/.claude/commands/weekly-synthesis.md`)
- [ ] Add pattern miner to your AGENTS.md
- [ ] Create synthesis template and Dataview queries

**Already done for you:**
- ✅ AGENTS.md framework for new agents
- ✅ COMMANDS.md system for new slash commands
- ✅ ORCHESTRATOR.md patterns for workflows

### Phase 5: Integration & Polish (Days 15-17)
- [ ] Link sessions to existing DfE tickets and PLB projects
- [ ] Enhance daily template with session summary section
- [ ] Add feedback mechanism (thumbs up/down in frontmatter)
- [ ] Create monitoring Dataview dashboard
- [ ] Document in your framework files

---

### 7.1 Leveraging smart-connections for Semantic Search

Instead of building custom vector search, use your existing smart-connections plugin:

**How it works:**
1. smart-connections already indexes your entire vault
2. It provides semantic search via the plugin API
3. Your Neovim has `vault-search.py` that queries it

**Integration approach:**
```python
# In memory-retrieval.py hook
import subprocess
import json

def get_relevant_memories(query: str, limit: int = 5):
    """Query smart-connections via your existing vault-search.py"""
    result = subprocess.run(
        ['python3', '/mounts/neovim/scripts/vault-search.py',
         '--query', query,
         '--folder', 'Claude/Memories',
         '--limit', str(limit)],
        capture_output=True, text=True
    )
    return json.loads(result.stdout)
```

**Benefits:**
- No additional embedding infrastructure needed
- Leverages existing Obsidian indexing
- Already works with your Neovim integration
- Updates automatically as vault changes

---

## 7.2 New Agents for AGENTS.md

Add these agent personas to `/mounts/dotfiles/.claude/AGENTS.md`:

```markdown
## Memory Catcher Agent

**Activation**: Invoked by cron job every 15 minutes
**Purpose**: Extract memories from recent Claude Code sessions
**Personality**: Meticulous librarian who values precision over quantity

### Triggers
- New sessions in database without `memory_extracted = true`
- Manual invocation via `/memory-extract` command

### Behavior
1. Load unprocessed sessions from database
2. For each session, identify moments of consequential decision:
   - Recovery patterns (fail → succeed)
   - User corrections
   - Enthusiasm/frustration signals
   - Repeated requests
3. Generate structured memory entries
4. Save to `Claude/Memories/{type}/` in Obsidian
5. Update session record as processed

### Memory Types
| Type | Priority | Description |
|------|----------|-------------|
| correction | Critical | Mistakes corrected |
| decision | High | Explicit choices |
| insight | High | New understanding |
| learning | High | Technical knowledge |
| pattern | Medium | Repeated behaviors |
| workflow | Medium | Process improvements |
| gap | Medium | Missing connections |

---

## Pattern Miner Agent

**Activation**: Weekly synthesis command
**Purpose**: Find patterns across audit trails and memories
**Personality**: Data scientist looking for signal in noise

### Triggers
- Weekly cron (Mondays)
- Manual via `/weekly-synthesis`

### Behavior
1. Gather all audit trails from the week
2. Analyze memory distribution and themes
3. Look for repeated patterns that could become SOPs
4. Identify system gaps and improvement opportunities
5. Generate synthesis report with confidence scores
6. Queue high-confidence recommendations

---

## Strategic Adviser Agent

**Activation**: During morning overview or on-demand
**Purpose**: Surface proactive recommendations
**Personality**: Thoughtful mentor who anticipates needs

### Triggers
- Part of daily briefing workflow
- When gaps or patterns have high confidence

### Behavior
1. Review recent synthesis reports
2. Check pending recommendations
3. Match current context to stored patterns
4. Suggest improvements or next actions
5. Track whether suggestions are implemented
```

## 7.3 New Commands for COMMANDS.md

Add these commands to `/mounts/dotfiles/.claude/commands/`:

**`/mounts/dotfiles/.claude/commands/memory-extract.md`:**
```markdown
# Memory Extraction Command

Extract memories from recent Claude Code sessions.

## Usage
```
/memory-extract [--session SESSION_ID] [--days N]
```

## Behavior
1. Query database for unprocessed sessions
2. Run Memory Catcher Agent on each
3. Generate memory files in Obsidian
4. Report extraction summary

## Options
- `--session`: Process specific session
- `--days`: Look back N days (default: 1)
```

**`/mounts/dotfiles/.claude/commands/weekly-synthesis.md`:**
```markdown
# Weekly Synthesis Command

Generate weekly synthesis report from audit trails and memories.

## Usage
```
/weekly-synthesis [--week YYYY-Www]
```

## Behavior
1. Gather audit trails from the week
2. Run Pattern Miner Agent
3. Generate synthesis report
4. Save to `Claude/Synthesis/weekly/`
5. Update pattern database

## Output
- Weekly synthesis markdown file
- Updated pattern confidence scores
- Queued recommendations
```

**`/mounts/dotfiles/.claude/commands/recall.md`:**
```markdown
# Memory Recall Command

Explicitly recall memories related to a topic.

## Usage
```
/recall <query>
```

## Behavior
1. Query smart-connections for relevant memories
2. Display top matches with confidence scores
3. Optionally inject into current context

## Examples
```
/recall kubernetes deployment patterns
/recall last time we worked on DfE ticket 1901
/recall corrections about terraform
```
```

---

## 8. Technology Stack (Using Your Existing Tools)

### Already Available
- **Runtime**: Bun (enforced via your `use_bun.py` hook)
- **Database**: Steampipe PostgreSQL (via your MCP server) or SQLite
- **Embeddings**: smart-connections (Obsidian) + Ollama (if needed)
- **Job Scheduler**: launchd (like your auto-commit system)
- **Hooks**: Python hooks in `/mounts/dotfiles/.claude/hooks/`
- **Semantic Search**: smart-connections + vault-search.py

### To Add
- **SQLite**: For local session database (lightweight, no server)
- **better-sqlite3**: Bun-compatible SQLite driver
- **Handlebars/Mustache**: For Obsidian template rendering

### Optional Enhancements
- **Web UI**: Could build with your existing stack if desired
- **Vector DB**: sqlite-vss if smart-connections isn't sufficient

---

## 9. Configuration

**Main config file (`config.json`):**
```json
{
  "database": {
    "type": "postgresql",
    "connectionString": "postgresql://localhost:5432/claude_assistant"
  },
  "obsidian": {
    "vaultPath": "/path/to/obsidian/vault",
    "syncInterval": "5m"
  },
  "claudeCode": {
    "sessionsPath": "~/.claude/projects",
    "syncInterval": "5m"
  },
  "memory": {
    "extractionInterval": "15m",
    "minConfidence": 0.5,
    "maxMemoriesPerSession": 10
  },
  "embeddings": {
    "provider": "ollama",
    "model": "nomic-embed-text",
    "dimensions": 768
  },
  "synthesis": {
    "schedule": "0 9 * * 1",
    "lookbackDays": 7
  }
}
```

---

## 10. Key Insights from Original System

1. **Trust Through Transparency**: The system provides maximum visibility into what's happening, which builds trust and creates value.

2. **Progressive Context Loading**: Use includes and lazy loading to manage context efficiently.

3. **Moments of Consequence**: Focus memory extraction on decision points, not just information.

4. **Hybrid Retrieval**: Combine entity-based lookup with semantic search, then filter semantically to avoid "ADHD triggers."

5. **Flat Files Work**: Text-based memory without vector search can be surprisingly powerful before adding complexity.

6. **Feedback Loops**: Simple thumbs up/down voting compounds over time to improve retrieval quality.

7. **Audit Everything**: Every agent creates an audit trail, enabling pattern detection and SOP generation.

8. **Weekly Synthesis**: Regular synthesis sessions turn raw data into actionable insights and system improvements.

---

## 11. Quick Start: First Weekend Sprint

Here's a concrete plan for getting started this weekend:

### Day 1: Foundation (Saturday Morning)

**1. Create Obsidian folder structure:**
```bash
cd /mounts/obsidian
mkdir -p Claude/{Sessions,Memories/{decisions,insights,corrections,patterns,learning,workflows},Audit,Synthesis/{weekly,patterns}}
```

**2. Add session template (`/mounts/obsidian/templates/session.md`):**
```markdown
---
id: session-{{session_id}}
type: session
created: {{created}}
work_type: {{work_type}}
files_touched: {{files_touched}}
memory_extracted: false
tags: [session, {{work_type}}]
---

# {{title}}

## Summary
{{summary}}

## First Message
> {{first_message}}

## Tool Calls
{{tool_calls}}

## Files Touched
{{#files_touched}}
- [[{{.}}]]
{{/files_touched}}
```

**3. Create basic session sync script (`/mounts/dotfiles/scripts/claude-session-sync.ts`):**
```typescript
#!/usr/bin/env bun

import { Database } from "bun:sqlite";
import { glob } from "glob";
import { readFile, writeFile, mkdir } from "fs/promises";
import { join, basename } from "path";
import Handlebars from "handlebars";

const CLAUDE_SESSIONS_DIR = join(Bun.env.HOME!, ".claude/projects");
const OBSIDIAN_VAULT = "/mounts/obsidian";
const DB_PATH = join(OBSIDIAN_VAULT, ".claude/sessions.db");

// Initialize database
const db = new Database(DB_PATH);
db.run(`
  CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    created_at TEXT,
    updated_at TEXT,
    first_message TEXT,
    last_message TEXT,
    work_type TEXT,
    files_touched TEXT,
    memory_extracted INTEGER DEFAULT 0,
    obsidian_path TEXT
  )
`);

async function syncSessions() {
  const sessionFiles = await glob(`${CLAUDE_SESSIONS_DIR}/**/*.jsonl`);

  for (const file of sessionFiles) {
    const sessionId = basename(file, ".jsonl");
    const content = await readFile(file, "utf-8");
    const lines = content.trim().split("\n").map(l => JSON.parse(l));

    // Extract key data
    const userMessages = lines.filter(l => l.type === "human");
    const firstMessage = userMessages[0]?.content || "";
    const lastMessage = userMessages[userMessages.length - 1]?.content || "";

    // Upsert to database
    db.run(`
      INSERT OR REPLACE INTO sessions
      (id, created_at, updated_at, first_message, last_message)
      VALUES (?, datetime('now'), datetime('now'), ?, ?)
    `, [sessionId, firstMessage.slice(0, 500), lastMessage.slice(0, 500)]);

    console.log(`Synced: ${sessionId}`);
  }
}

syncSessions();
```

### Day 1: Memory Hook (Saturday Afternoon)

**4. Create memory retrieval hook (`/mounts/dotfiles/.claude/hooks/memory-retrieval.py`):**
```python
#!/usr/bin/env python3
"""
Memory retrieval hook for Claude Code.
Injects relevant memories into context on user_prompt_submit.
"""

import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

OBSIDIAN_VAULT = Path("/mounts/obsidian")
DB_PATH = OBSIDIAN_VAULT / ".claude/sessions.db"

def get_recent_corrections(limit=3):
    """Get recent correction memories."""
    corrections_dir = OBSIDIAN_VAULT / "Claude/Memories/corrections"
    if not corrections_dir.exists():
        return []

    files = sorted(corrections_dir.glob("*.md"), key=lambda f: f.stat().st_mtime, reverse=True)
    memories = []

    for f in files[:limit]:
        content = f.read_text()
        # Extract summary from frontmatter
        if "summary:" in content:
            for line in content.split("\n"):
                if line.startswith("summary:"):
                    memories.append(line.replace("summary:", "").strip())
                    break

    return memories

def main():
    # Read hook input
    hook_input = json.loads(sys.stdin.read())
    prompt = hook_input.get("prompt", "")

    # Skip if prompt is a command
    if prompt.startswith("/"):
        return

    # Get relevant memories
    corrections = get_recent_corrections(3)

    if corrections:
        context = "\n<memory_context>\n"
        context += "## Recent Corrections (remember these):\n"
        for c in corrections:
            context += f"- {c}\n"
        context += "</memory_context>\n"

        # Output context injection
        print(json.dumps({"context": context}))

if __name__ == "__main__":
    main()
```

**5. Register hook in settings:**
Add to `/mounts/dotfiles/.claude/settings.json`:
```json
{
  "hooks": {
    "user_prompt_submit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "python3 /mounts/dotfiles/.claude/hooks/memory-retrieval.py"
          }
        ]
      }
    ]
  }
}
```

### Day 2: Memory Extraction (Sunday)

**6. Create memory extraction command (`/mounts/dotfiles/.claude/commands/extract-memories.md`):**
```markdown
# Extract Memories from Recent Sessions

Analyze recent Claude Code sessions and extract memorable moments.

## Instructions

1. Read unprocessed sessions from the database at `/mounts/obsidian/.claude/sessions.db`
2. For each session, identify moments of consequential decision:
   - **Corrections**: When I corrected you or you corrected me
   - **Decisions**: Explicit choices about implementation
   - **Learning**: Technical knowledge gained
   - **Insights**: New understanding
3. For each memory, create a markdown file in the appropriate folder:
   - `/mounts/obsidian/Claude/Memories/{type}/{slugified-title}.md`
4. Use this frontmatter format:
   ```yaml
   ---
   id: mem-{uuid}
   type: memory
   memory_type: {correction|decision|learning|insight}
   session_id: {source-session}
   formed: {timestamp-from-session}
   confidence: {0.0-1.0}
   tags: [memory, {memory_type}]
   ---
   ```
5. Include:
   - Title (5-10 words)
   - Summary (1-2 sentences)
   - Why this matters
   - Original context snippet

## Quality Guidelines
- Extract 0-5 memories per session (quality over quantity)
- Confidence > 0.7 for corrections, > 0.5 for others
- Link back to source session with `[[Claude/Sessions/...]]`
```

**7. Test the system:**
```bash
# Run session sync
cd /mounts/dotfiles/scripts && bun claude-session-sync.ts

# Manually run memory extraction
claude /extract-memories

# Check Obsidian for new files
ls /mounts/obsidian/Claude/Memories/*/
```

### Next Steps After Weekend

1. **Set up cron jobs** (like your auto-commit LaunchAgent)
2. **Enhance memory retrieval** with smart-connections semantic search
3. **Add audit trail generation** to existing `log_pre_tool_use.py`
4. **Create weekly synthesis command**
5. **Build Dataview dashboard**

---

## 12. Files to Create Summary

| File | Location | Purpose |
|------|----------|---------|
| `claude-session-sync.ts` | `/mounts/dotfiles/scripts/` | Sync JSONL sessions to SQLite |
| `memory-retrieval.py` | `/mounts/dotfiles/.claude/hooks/` | Inject memories on prompt |
| `session.md` | `/mounts/obsidian/templates/` | Session template |
| `memory.md` | `/mounts/obsidian/templates/` | Memory template |
| `extract-memories.md` | `/mounts/dotfiles/.claude/commands/` | Memory extraction command |
| `weekly-synthesis.md` | `/mounts/dotfiles/.claude/commands/` | Weekly synthesis command |
| `recall.md` | `/mounts/dotfiles/.claude/commands/` | On-demand memory recall |
| `_Index.md` | `/mounts/obsidian/Claude/` | Dataview dashboard |
| `sessions.db` | `/mounts/obsidian/.claude/` | SQLite session database |
