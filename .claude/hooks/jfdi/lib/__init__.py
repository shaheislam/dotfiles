"""
JFDI Hook Libraries

Shared utilities for JFDI Claude Code hooks.
"""

from .config import *
from .ripgrep_search import (
    run_ripgrep,
    run_ripgrep_content,
    search_corrections,
    search_by_entity,
    search_by_keywords,
    search_recent_memories,
    search_by_type,
    find_session_by_id,
    extract_entities_from_prompt,
    extract_keywords_from_prompt,
    parse_memory_file,
    parse_session_file,
)
from .markdown_writer import (
    slugify,
    generate_short_id,
    format_frontmatter,
    update_frontmatter,
    write_session,
    write_memory,
    write_audit,
    write_synthesis,
)
