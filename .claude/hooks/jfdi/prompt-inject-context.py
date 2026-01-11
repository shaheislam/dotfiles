#!/usr/bin/env python3
"""
UserPromptSubmit Hook - Inject relevant memories into prompts.

This hook triggers when the user submits a prompt and:
1. Extracts entities and keywords from the prompt
2. Searches memories using ripgrep
3. Injects relevant context into the conversation

Hook Input (stdin JSON):
{
  "hook_type": "UserPromptSubmit",
  "session_id": "abc123",
  "prompt": "User's message",
  "cwd": "/path/to/project"
}

Hook Output (stdout JSON):
{
  "continue": true,
  "context": "<memory_context>...</memory_context>"
}
"""

import json
import sys
from pathlib import Path
from typing import List, Dict, Any

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent))

from lib.config import MAX_ITEMS_PER_TYPE, MAX_CONTEXT_LENGTH, MEMORIES_DIR
from lib.ripgrep_search import (
    search_corrections,
    search_by_entity,
    search_by_keywords,
    search_recent_memories,
    extract_entities_from_prompt,
    extract_keywords_from_prompt
)


def format_memory_for_context(memory: Dict[str, Any]) -> str:
    """Format a memory dict as a brief context string."""
    mem_type = memory.get('type', 'memory')
    title = memory.get('title', 'Untitled')
    summary = memory.get('summary', '')[:150]

    return f'- [{mem_type}] **{title}**: {summary}'


def build_memory_context(
    corrections: List[Dict],
    entity_memories: List[Dict],
    keyword_memories: List[Dict],
    recent_memories: List[Dict]
) -> str:
    """
    Build formatted memory context for injection.

    Deduplicates and prioritizes memories.
    """
    sections = []
    seen_titles = set()

    # Corrections are always first (highest priority)
    if corrections:
        lines = ['## Corrections (Important)']
        for mem in corrections:
            title = mem.get('title', '')
            if title and title not in seen_titles:
                seen_titles.add(title)
                lines.append(format_memory_for_context(mem))
        if len(lines) > 1:
            sections.append('\n'.join(lines))

    # Entity-matched memories
    if entity_memories:
        lines = ['## Related Memories']
        for mem in entity_memories:
            title = mem.get('title', '')
            if title and title not in seen_titles:
                seen_titles.add(title)
                lines.append(format_memory_for_context(mem))
        if len(lines) > 1:
            sections.append('\n'.join(lines))

    # Keyword-matched memories (only if we have room)
    if keyword_memories and len(sections) < 3:
        lines = []
        for mem in keyword_memories:
            title = mem.get('title', '')
            if title and title not in seen_titles:
                seen_titles.add(title)
                lines.append(format_memory_for_context(mem))
        if lines:
            if not entity_memories:
                sections.append('## Related Memories\n' + '\n'.join(lines))
            else:
                # Append to existing Related section
                for i, sec in enumerate(sections):
                    if sec.startswith('## Related'):
                        sections[i] += '\n' + '\n'.join(lines)
                        break

    # Recent memories as fallback (if we found very little)
    if len(seen_titles) < 3 and recent_memories:
        lines = []
        for mem in recent_memories:
            title = mem.get('title', '')
            if title and title not in seen_titles:
                seen_titles.add(title)
                lines.append(format_memory_for_context(mem))
        if lines:
            sections.append('## Recent Context\n' + '\n'.join(lines[:3]))

    if not sections:
        return ''

    context = '\n\n'.join(sections)

    # Truncate if too long
    if len(context) > MAX_CONTEXT_LENGTH:
        context = context[:MAX_CONTEXT_LENGTH] + '\n\n[... truncated ...]'

    return context


def should_skip_prompt(prompt: str) -> bool:
    """
    Determine if we should skip memory retrieval for this prompt.

    Skip for:
    - Slash commands
    - Very short prompts
    - Simple acknowledgments
    """
    prompt_lower = prompt.lower().strip()

    # Skip slash commands
    if prompt.startswith('/'):
        return True

    # Skip very short prompts
    if len(prompt) < 10:
        return True

    # Skip simple acknowledgments
    simple_responses = {
        'yes', 'no', 'ok', 'okay', 'sure', 'thanks', 'thank you',
        'y', 'n', 'yep', 'nope', 'got it', 'sounds good', 'perfect',
        'continue', 'go ahead', 'proceed'
    }
    if prompt_lower in simple_responses:
        return True

    return False


def main():
    """Main hook entry point."""
    # Read hook input from stdin
    try:
        input_data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception):
        print(json.dumps({"continue": True}))
        return

    prompt = input_data.get('prompt', '')

    # Check if we should skip
    if should_skip_prompt(prompt):
        print(json.dumps({"continue": True}))
        return

    # Check if memories directory exists
    if not MEMORIES_DIR.exists():
        print(json.dumps({"continue": True}))
        return

    # Always get corrections (they're critical)
    corrections = search_corrections(limit=3)

    # Extract entities and keywords from prompt
    entities = extract_entities_from_prompt(prompt)
    keywords = extract_keywords_from_prompt(prompt)

    # Search for entity-related memories
    entity_memories = []
    for entity in entities[:3]:
        entity_memories.extend(search_by_entity(entity, limit=2))

    # Search for keyword-related memories
    keyword_memories = []
    if keywords:
        keyword_memories = search_by_keywords(keywords[:5], limit=3)

    # Get recent memories as fallback
    recent_memories = []
    if len(entity_memories) + len(keyword_memories) < 2:
        recent_memories = search_recent_memories(days=7, limit=3)

    # Build context
    context = build_memory_context(
        corrections=corrections,
        entity_memories=entity_memories,
        keyword_memories=keyword_memories,
        recent_memories=recent_memories
    )

    if context:
        wrapped = f'\n<memory_context>\n{context}\n</memory_context>\n'
        print(json.dumps({
            "continue": True,
            "context": wrapped
        }))
    else:
        print(json.dumps({"continue": True}))


if __name__ == "__main__":
    main()
