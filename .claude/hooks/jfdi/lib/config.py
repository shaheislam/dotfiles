"""
JFDI Configuration

Central configuration for paths, constants, and memory types.
"""

import os
from pathlib import Path
from typing import Dict, Any

# Paths
OBSIDIAN_VAULT = Path(os.environ.get('OBSIDIAN_VAULT', os.path.expanduser('~/obsidian')))
CLAUDE_DIR = OBSIDIAN_VAULT / 'Claude'
SESSIONS_DIR = CLAUDE_DIR / 'Sessions'
MEMORIES_DIR = CLAUDE_DIR / 'Memories'
AUDIT_DIR = CLAUDE_DIR / 'Audit'
SYNTHESIS_DIR = CLAUDE_DIR / 'Synthesis'

# Claude Code session files
CLAUDE_PROJECTS_DIR = Path(os.path.expanduser('~/.claude/projects'))

# Memory Types and their info
MEMORY_TYPES: Dict[str, Dict[str, Any]] = {
    'correction': {
        'priority': 'critical',
        'description': 'User correction of agent behavior - highest priority',
        'min_confidence': 0.7,
        'emoji': '!!'
    },
    'decision': {
        'priority': 'high',
        'description': 'Architectural or design decision',
        'min_confidence': 0.5,
        'emoji': '->'
    },
    'insight': {
        'priority': 'high',
        'description': 'New understanding or realization',
        'min_confidence': 0.5,
        'emoji': '*'
    },
    'learning': {
        'priority': 'high',
        'description': 'Technical knowledge or skill learned',
        'min_confidence': 0.5,
        'emoji': '+'
    },
    'commitment': {
        'priority': 'high',
        'description': 'Promise or plan made',
        'min_confidence': 0.5,
        'emoji': '@'
    },
    'pattern': {
        'priority': 'medium',
        'description': 'Repeated behavior or preference',
        'min_confidence': 0.5,
        'emoji': '~'
    },
    'workflow': {
        'priority': 'medium',
        'description': 'Process or workflow improvement',
        'min_confidence': 0.5,
        'emoji': '>>'
    },
}

# Memory categories
MEMORY_CATEGORIES = [
    'technical',
    'systems',
    'relationship',
    'creative',
    'planning'
]

# Extraction trigger patterns (for Python regex)
TRIGGER_PATTERNS = {
    'user_correction': {
        'patterns': [
            r'\bno[,.]?\s+(?:don\'?t|do not|that\'?s not|wrong|incorrect)',
            r'\bactually[,.]?\s+(?:I want|it should|use|let\'?s)',
            r'\binstead[,.]?\s+(?:of|use|do|let\'?s)',
            r'\bdon\'?t\s+(?:do that|use|add|include)',
            r'\bthat\'?s\s+(?:wrong|incorrect|not right|not what)',
            r'\bwrong\b',
            r'\bincorrect\b',
            r'\bnot what I (?:asked|wanted|meant)',
        ],
        'priority': 'critical',
        'memory_type': 'correction'
    },
    'enthusiasm_signal': {
        'patterns': [
            r'\bperfect\b',
            r'\bexactly\b',
            r'\bthat\'?s\s+(?:great|awesome|amazing|brilliant|perfect)',
            r'\blove\s+(?:it|this|that)',
            r'\bexcellent\b',
            r'\bwonderful\b',
            r'\byes[!]+',
            r'\bnice(?:\s+work|job|one)?[!]+',
        ],
        'priority': 'high',
        'memory_type': 'insight'
    },
    'negative_reaction': {
        'patterns': [
            r'\bnever\s+(?:do that|use|add)',
            r'\bstop\s+(?:doing|adding|using)',
            r'\bhate\s+(?:it|this|that|when)',
            r'\bterrible\b',
            r'\bawful\b',
            r'\bhorrible\b',
            r'\bplease\s+(?:stop|don\'?t)',
        ],
        'priority': 'critical',
        'memory_type': 'correction'
    },
    'recovery_pattern': {
        'patterns': [
            r'(?:that|this)\s+(?:worked|works|fixed it)',
            r'(?:now|finally)\s+(?:it works|working|fixed)',
            r'\bsuccess(?:ful(?:ly)?)?[!]*',
            r'\bthat\s+did\s+(?:it|the trick)',
        ],
        'priority': 'high',
        'memory_type': 'learning'
    },
}

# Failure patterns for recovery detection
FAILURE_PATTERNS = [
    r'(?:didn\'?t|doesn\'?t|not)\s+work',
    r'error',
    r'failed',
    r'try\s+(?:again|another|different)',
    r'let\'?s\s+try',
]

# Success patterns for recovery detection
SUCCESS_PATTERNS = [
    r'(?:that|this|it)\s+works?',
    r'worked',
    r'fixed',
    r'success',
    r'finally',
    r'got it',
]

# Stop words for keyword extraction
STOP_WORDS = {
    'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had',
    'her', 'was', 'one', 'our', 'out', 'has', 'have', 'been', 'would',
    'could', 'there', 'their', 'will', 'when', 'what', 'this', 'that',
    'with', 'from', 'they', 'been', 'have', 'many', 'some', 'them', 'than',
    'into', 'each', 'make', 'like', 'just', 'over', 'such', 'take', 'more',
    'also', 'back', 'only', 'come', 'your', 'about', 'which', 'their',
    'these', 'after', 'would', 'should', 'could', 'being', 'other',
    'claude', 'please', 'want', 'need', 'help', 'using', 'file', 'code'
}

# Limits
MAX_CONTEXT_LENGTH = 4000
MAX_ITEMS_PER_TYPE = 5
MAX_MEMORIES_PER_SESSION = 10
MAX_TRANSCRIPT_LENGTH = 15000

# Work type classification patterns
WORK_TYPE_PATTERNS = {
    'development': [r'implement', r'create', r'build', r'code', r'feature', r'component'],
    'debugging': [r'debug', r'fix', r'bug', r'error', r'issue', r'problem'],
    'research': [r'research', r'explore', r'investigate', r'find', r'search', r'understand'],
    'planning': [r'plan', r'design', r'architect', r'strategy', r'roadmap'],
    'testing': [r'test', r'spec', r'coverage', r'assertion'],
    'documentation': [r'document', r'readme', r'comment', r'explain'],
    'refactoring': [r'refactor', r'cleanup', r'reorganize', r'restructure'],
}

# Audit tools to track
AUDIT_TOOLS = ['Edit', 'Write', 'Bash', 'Task', 'WebFetch', 'WebSearch']
