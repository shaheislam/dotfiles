# JFDI Executive Assistant

The JFDI (Just F***ing Do It) system captures session metadata, extracts memories, and syncs to Obsidian.

## Available Commands

- `/jfdi-sync` - Sync sessions to database and Obsidian
- `/jfdi-extract` - Extract memories from sessions
- `/jfdi-recall` - Query memories on demand
- `/jfdi-synthesis` - Generate weekly synthesis reports

## Quick Status

Run the following to check JFDI status:

```bash
cd /mounts/second-brain/jfdi

# Check session sync status
npx tsx scripts/sync-sessions.ts --status

# Check database stats
npx tsx -e "
import { initDatabase, getSessionStats, getMemoryStats, closeDatabase } from './src/db/index.js';
initDatabase();

const sessions = getSessionStats();
const memories = getMemoryStats();

console.log('=== JFDI Status ===');
console.log(\`Sessions: \${sessions.total} total, \${sessions.unprocessedCount} pending\`);
console.log(\`Memories: \${memories.total} total\`);
console.log(\`Avg Confidence: \${(memories.avgConfidence * 100).toFixed(0)}%\`);

closeDatabase();
"
```

## System Location

- **Project**: `/mounts/second-brain/jfdi/`
- **Database**: `/mounts/second-brain/jfdi/db/jfdi.db`
- **Obsidian**: `/mounts/obsidian/Claude/`

## Workflow

1. **Sync**: Run `/jfdi-sync` to sync new sessions
2. **Extract**: Run `/jfdi-extract` to extract memories
3. **Review**: Check memories in Obsidian
4. **Synthesize**: Run `/jfdi-synthesis` weekly

Report the current status of the JFDI system.
