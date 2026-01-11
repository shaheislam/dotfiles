"""
Ripgrep Search Utilities

Fast filesystem search using ripgrep (rg).
No database required - searches Obsidian vault directly.
"""

import subprocess
import re
from pathlib import Path
from typing import List, Tuple, Optional, Dict, Any
from datetime import datetime, timedelta

from .config import (
    OBSIDIAN_VAULT, CLAUDE_DIR, MEMORIES_DIR, SESSIONS_DIR,
    MAX_ITEMS_PER_TYPE, STOP_WORDS
)


def run_ripgrep(
    pattern: str,
    path: Optional[Path] = None,
    flags: Optional[List[str]] = None,
    timeout: int = 5
) -> List[str]:
    """
    Run ripgrep and return matching file paths.

    Args:
        pattern: Regex pattern to search for
        path: Directory to search in (defaults to vault)
        flags: Additional rg flags
        timeout: Command timeout in seconds

    Returns:
        List of matching file paths
    """
    cmd = ['rg', '-l', '--type', 'md']
    if flags:
        cmd.extend(flags)
    cmd.append(pattern)
    cmd.append(str(path or OBSIDIAN_VAULT))

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        if result.returncode == 0:
            return [p.strip() for p in result.stdout.strip().split('\n') if p.strip()]
        return []
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def run_ripgrep_content(
    pattern: str,
    path: Optional[Path] = None,
    context_lines: int = 2,
    timeout: int = 5
) -> List[Tuple[str, str]]:
    """
    Run ripgrep and return file paths with matching content snippets.

    Args:
        pattern: Regex pattern to search for
        path: Directory to search in (defaults to vault)
        context_lines: Lines of context around matches
        timeout: Command timeout in seconds

    Returns:
        List of (file_path, snippet) tuples
    """
    cmd = ['rg', '--type', 'md', '-H', '-n', f'-C{context_lines}']
    cmd.append(pattern)
    cmd.append(str(path or OBSIDIAN_VAULT))

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        if result.returncode == 0:
            matches = []
            current_file = None
            current_content = []

            for line in result.stdout.split('\n'):
                if ':' in line:
                    parts = line.split(':', 2)
                    if len(parts) >= 2:
                        file_path = parts[0]
                        if file_path != current_file:
                            if current_file and current_content:
                                matches.append((current_file, '\n'.join(current_content[-5:])))
                            current_file = file_path
                            current_content = []
                        if len(parts) >= 3:
                            current_content.append(parts[2])

            if current_file and current_content:
                matches.append((current_file, '\n'.join(current_content[-5:])))

            return matches[:10]
        return []
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return []


def search_corrections(limit: int = MAX_ITEMS_PER_TYPE) -> List[Dict[str, Any]]:
    """
    Get recent corrections (always relevant, highest priority).

    Returns:
        List of correction memory dicts with title, summary, file
    """
    corrections_dir = MEMORIES_DIR / 'corrections'
    if not corrections_dir.exists():
        return []

    corrections = []
    files = sorted(corrections_dir.glob('*.md'), key=lambda f: f.stat().st_mtime, reverse=True)

    for file in files[:limit]:
        try:
            content = file.read_text()
            memory = parse_memory_file(content, file)
            if memory:
                corrections.append(memory)
        except Exception:
            pass

    return corrections


def search_by_entity(entity: str, limit: int = MAX_ITEMS_PER_TYPE) -> List[Dict[str, Any]]:
    """
    Search memories that mention a specific entity.

    Args:
        entity: Entity name to search for (person, project, etc.)
        limit: Maximum results to return

    Returns:
        List of matching memory dicts
    """
    if not MEMORIES_DIR.exists():
        return []

    # Search for entity in frontmatter entities field or content
    files = run_ripgrep(entity, MEMORIES_DIR, ['-i'])

    memories = []
    seen_files = set()

    for file_path in files[:limit * 2]:  # Get extra to account for duplicates
        if file_path in seen_files:
            continue
        seen_files.add(file_path)

        try:
            content = Path(file_path).read_text()
            memory = parse_memory_file(content, Path(file_path))
            if memory:
                memories.append(memory)
        except Exception:
            pass

        if len(memories) >= limit:
            break

    return memories


def search_by_keywords(
    keywords: List[str],
    limit: int = MAX_ITEMS_PER_TYPE
) -> List[Dict[str, Any]]:
    """
    Search memories by keywords from prompt.

    Args:
        keywords: List of keywords to search for
        limit: Maximum results to return

    Returns:
        List of matching memory dicts
    """
    if not MEMORIES_DIR.exists() or not keywords:
        return []

    memories = []
    seen_files = set()

    # Build OR pattern for ripgrep
    pattern = '|'.join(re.escape(k) for k in keywords[:5])

    files = run_ripgrep(pattern, MEMORIES_DIR, ['-i'])

    for file_path in files:
        if file_path in seen_files:
            continue
        seen_files.add(file_path)

        try:
            content = Path(file_path).read_text()
            memory = parse_memory_file(content, Path(file_path))
            if memory:
                memories.append(memory)
        except Exception:
            pass

        if len(memories) >= limit:
            break

    return memories


def search_recent_memories(days: int = 7, limit: int = MAX_ITEMS_PER_TYPE) -> List[Dict[str, Any]]:
    """
    Get recently created memories.

    Args:
        days: Number of days back to search
        limit: Maximum results to return

    Returns:
        List of recent memory dicts
    """
    if not MEMORIES_DIR.exists():
        return []

    cutoff = datetime.now() - timedelta(days=days)
    memories = []

    # Use find for date-based filtering (faster than ripgrep for this)
    try:
        result = subprocess.run(
            ['find', str(MEMORIES_DIR), '-name', '*.md', '-mtime', f'-{days}', '-type', 'f'],
            capture_output=True,
            text=True,
            timeout=5
        )

        if result.returncode == 0:
            files = [f.strip() for f in result.stdout.strip().split('\n') if f.strip()]

            for file_path in sorted(files, reverse=True)[:limit]:
                try:
                    content = Path(file_path).read_text()
                    memory = parse_memory_file(content, Path(file_path))
                    if memory:
                        memories.append(memory)
                except Exception:
                    pass
    except Exception:
        pass

    return memories


def search_by_type(
    memory_type: str,
    limit: int = MAX_ITEMS_PER_TYPE
) -> List[Dict[str, Any]]:
    """
    Get memories of a specific type.

    Args:
        memory_type: Type of memory (correction, decision, etc.)
        limit: Maximum results to return

    Returns:
        List of memory dicts of that type
    """
    type_dir = MEMORIES_DIR / f'{memory_type}s'
    if not type_dir.exists():
        # Try without 's' suffix
        type_dir = MEMORIES_DIR / memory_type
        if not type_dir.exists():
            return []

    memories = []
    files = sorted(type_dir.glob('*.md'), key=lambda f: f.stat().st_mtime, reverse=True)

    for file in files[:limit]:
        try:
            content = file.read_text()
            memory = parse_memory_file(content, file)
            if memory:
                memories.append(memory)
        except Exception:
            pass

    return memories


def find_session_by_id(session_id: str) -> Optional[Path]:
    """
    Find a session file by session ID.

    Args:
        session_id: Claude Code session ID

    Returns:
        Path to session file or None
    """
    if not SESSIONS_DIR.exists():
        return None

    # Search in frontmatter
    files = run_ripgrep(f'^session_id: {session_id}', SESSIONS_DIR)

    if files:
        return Path(files[0])

    # Try filename pattern
    for file in SESSIONS_DIR.glob(f'*{session_id[:8]}*.md'):
        return file

    return None


def extract_entities_from_prompt(prompt: str) -> List[str]:
    """
    Extract potential entities from a prompt.

    Looks for:
    - Capitalized words (names, projects)
    - Quoted strings
    - File paths

    Args:
        prompt: User's prompt text

    Returns:
        List of potential entity names
    """
    entities = []

    # Capitalized words (potential names)
    words = prompt.split()
    for word in words:
        clean = word.strip('.,!?:;()[]{}"\'-')
        if clean and clean[0].isupper() and clean.isalpha() and len(clean) > 2:
            # Skip common words that happen to be capitalized
            if clean.lower() not in {'The', 'This', 'That', 'What', 'When', 'Where', 'How', 'Why', 'Can', 'Could', 'Would', 'Should', 'Will', 'Did', 'Does', 'Has', 'Have', 'Had', 'Are', 'Is', 'Was', 'Were', 'Be', 'Been', 'Being', 'Do', 'Done', 'Let', 'Just', 'Now', 'Here', 'There', 'Also', 'But', 'And', 'Or', 'Not', 'No', 'Yes', 'If', 'Then', 'So', 'For', 'From', 'To', 'In', 'On', 'At', 'By', 'Up', 'Out', 'About', 'Into', 'Over', 'After', 'Before', 'Between', 'Under', 'Again', 'Further', 'Once', 'Same', 'Such', 'Very', 'Too', 'Only', 'Own', 'Each', 'Every', 'Both', 'Few', 'More', 'Most', 'Other', 'Some', 'Any', 'All', 'Many'}:
                entities.append(clean)

    # Quoted strings
    quoted = re.findall(r'["\']([^"\']+)["\']', prompt)
    entities.extend(quoted)

    # File paths
    paths = re.findall(r'(?:^|[\s,])([~./]?(?:[\w-]+/)+[\w.-]+)', prompt)
    entities.extend(paths)

    return list(set(entities))[:10]


def extract_keywords_from_prompt(prompt: str) -> List[str]:
    """
    Extract significant keywords from a prompt.

    Args:
        prompt: User's prompt text

    Returns:
        List of significant keywords
    """
    # Find words 4+ chars, not stop words
    words = re.findall(r'\b\w{4,}\b', prompt.lower())
    keywords = [w for w in words if w not in STOP_WORDS]

    return list(set(keywords))[:10]


def parse_memory_file(content: str, file_path: Path) -> Optional[Dict[str, Any]]:
    """
    Parse a memory markdown file into a dict.

    Args:
        content: File content
        file_path: Path to the file

    Returns:
        Memory dict or None if parsing fails
    """
    try:
        # Parse YAML frontmatter
        if content.startswith('---'):
            end = content.find('---', 3)
            if end > 0:
                frontmatter_text = content[3:end].strip()
                body = content[end + 3:].strip()
            else:
                frontmatter_text = ''
                body = content
        else:
            frontmatter_text = ''
            body = content

        # Extract frontmatter fields
        frontmatter = {}
        for line in frontmatter_text.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                frontmatter[key.strip()] = value.strip().strip('"\'')

        # Extract title from body
        title_match = re.search(r'^#\s+(.+)$', body, re.MULTILINE)
        title = title_match.group(1) if title_match else file_path.stem

        # Extract summary
        summary = ''
        summary_match = re.search(r'## Summary\s*\n([\s\S]*?)(?=\n##|\Z)', body)
        if summary_match:
            summary = summary_match.group(1).strip()[:300]

        # Get relative path
        try:
            rel_path = str(file_path.relative_to(OBSIDIAN_VAULT))
        except ValueError:
            rel_path = str(file_path)

        return {
            'title': title,
            'type': frontmatter.get('type', 'memory'),
            'confidence': float(frontmatter.get('confidence', 0.5)),
            'formed': frontmatter.get('formed', ''),
            'summary': summary,
            'file': rel_path,
            'entities': frontmatter.get('entities', '').split(',') if frontmatter.get('entities') else []
        }
    except Exception:
        return None


def parse_session_file(content: str, file_path: Path) -> Optional[Dict[str, Any]]:
    """
    Parse a session markdown file into a dict.

    Args:
        content: File content
        file_path: Path to the file

    Returns:
        Session dict or None if parsing fails
    """
    try:
        # Parse YAML frontmatter
        if content.startswith('---'):
            end = content.find('---', 3)
            if end > 0:
                frontmatter_text = content[3:end].strip()
                body = content[end + 3:].strip()
            else:
                frontmatter_text = ''
                body = content
        else:
            frontmatter_text = ''
            body = content

        # Extract frontmatter fields
        frontmatter = {}
        for line in frontmatter_text.split('\n'):
            if ':' in line:
                key, value = line.split(':', 1)
                frontmatter[key.strip()] = value.strip().strip('"\'')

        return {
            'session_id': frontmatter.get('session_id', file_path.stem),
            'created': frontmatter.get('created', ''),
            'work_type': frontmatter.get('work_type', 'general'),
            'memories_extracted': frontmatter.get('memories_extracted', 'false').lower() == 'true',
            'file': str(file_path),
            'content': body
        }
    except Exception:
        return None
