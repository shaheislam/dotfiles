---
name: jfdi-recall
description: Query memories from the JFDI database on demand. Use when searching past session insights, recalling corrections, decisions, or learned patterns from previous work.
---

# JFDI Recall

Query memories from the JFDI database on demand.

## Usage

```
/jfdi-recall [query] [--type TYPE] [--days N]
```

## What it does

1. Searches the memory database for relevant memories
2. Prioritizes corrections and high-confidence memories
3. Returns formatted memory context

## Query Options

- `query`: Search term to find in memory titles, summaries, or entities
- `--type TYPE`: Filter by memory type (correction, decision, learning, etc.)
- `--days N`: Only show memories from last N days

## Instructions

$ARGUMENTS

Query the JFDI database for relevant memories. Run:

```bash
cd /mounts/second-brain/jfdi

# Query all recent corrections
npx tsx -e "
import { initDatabase, getRecentCorrections, getMemoriesByType } from './src/db/index.js';
initDatabase();

// Get recent corrections (always important)
const corrections = getRecentCorrections(30, 10);
console.log('=== Recent Corrections ===');
for (const m of corrections) {
  console.log(\`[\${m.memory_type}] \${m.title}\`);
  console.log(\`  \${m.summary}\`);
  console.log(\`  Confidence: \${Math.round(m.confidence_score * 100)}%\`);
  console.log();
}
"
```

Present the memories found in a clear, actionable format. Highlight any corrections that might be relevant to the current conversation.
