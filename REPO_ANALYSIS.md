# Sensei Repository Analysis

**Repository**: [XiaohuiChen-personal/xiaohui-agentic-playground](https://github.com/XiaohuiChen-personal/xiaohui-agentic-playground/tree/main/3-crew-ai/sensei)
**Path**: `3-crew-ai/sensei`
**Analyzed**: 2026-02-06

---

## What It Does

**Sensei** ("先生" - Teacher/Master) is an **AI-powered adaptive learning tutor** built with CrewAI's multi-agent framework. Users tell Sensei what they want to learn (any topic - from Linear Algebra to CUDA Programming), and the system:

1. **Generates a structured curriculum** tailored to the user's experience level and learning style
2. **Teaches concepts interactively** with AI-generated lessons containing explanations, code examples, and key takeaways
3. **Answers questions** contextually through a Q&A chat interface
4. **Assesses understanding** through adaptive quizzes with multiple question types
5. **Provides intelligent feedback** analyzing performance, identifying weak areas, and suggesting next steps
6. **Tracks progress** across all courses with visual indicators and learning statistics

---

## Architecture: Multi-Agent Crew System

The core innovation is using **three specialized CrewAI crews**, each containing purpose-built AI agents that collaborate on different aspects of the learning experience.

### Crew 1: Curriculum Crew (Flow-Based)

**Purpose**: Generate a complete course from a topic string.

**Architecture**: Uses a `CurriculumFlow` (CrewAI Flow pattern) with three sequential steps:

| Step | Agent | LLM | Role |
|------|-------|-----|------|
| 1. Outline | Curriculum Architect | Gemini 3 Pro | Plans course structure (modules + concept titles) |
| 2. Expand | Content Researcher | Claude Opus 4.5 | Expands each module with detailed content **in parallel** |
| 3. Aggregate | (programmatic) | - | Combines expanded modules into a `Course` object |

**Key design decisions**:
- Step 2 uses `asyncio.gather()` to expand all modules in parallel, significantly reducing generation time
- Each module processes independently (~8K max tokens) to prevent truncation issues
- Short-term memory enabled within a run; long-term memory disabled to prevent cross-session contamination
- Fallback mechanisms handle failed module expansions gracefully

### Crew 2: Teaching Crew (Dynamic Task Selection)

**Purpose**: Generate lessons and answer Q&A questions.

**Architecture**: Two independent agents that run separately (not as a combined crew):

| Agent | LLM | Role |
|-------|-----|------|
| Knowledge Teacher | Claude Opus 4.5 | Generates comprehensive lessons with explanations, code examples, key takeaways |
| Q&A Mentor | GPT 5.2 | Answers questions contextually based on current lesson and chat history |

**Key design decisions**:
- Does NOT use `@CrewBase` decorator because it expects all agents to run together; this crew needs agents to run independently
- Creates focused "mini-crews" with a single agent-task pair per operation
- Input validation on all public methods with explicit error handling

### Crew 3: Assessment Crew (Sequential, Dynamic Task Selection)

**Purpose**: Generate quizzes and evaluate learner performance.

**Architecture**: Two agents running in separate phases (separated by user action - taking the quiz):

| Agent | LLM | Phase |
|-------|-----|-------|
| Quiz Designer | Claude Opus 4.5 | Phase 1: Creates targeted quiz questions |
| Performance Analyst | GPT 5.2 | Phase 2: Evaluates answers and provides feedback |

**Key design decisions**:
- Uses CrewAI's `output_pydantic` for reliable structured output (QuizOutput, QuizEvaluationOutput)
- Supports four question types: multiple choice, true/false, code, open-ended
- Open-ended questions are flagged for **semantic evaluation** by the AI (not simple string matching)
- Weak concepts from previous attempts influence question focus (adaptive difficulty)
- Score calculation separates non-open-ended (exact match) from open-ended (AI-evaluated)

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Framework** | CrewAI (>=0.86.0) | Multi-agent orchestration |
| **Frontend** | Streamlit (>=1.41.0) | Interactive web UI |
| **LLMs** | Claude Opus 4.5, GPT 5.2, Gemini 3 Pro | Via LiteLLM universal interface |
| **Data Validation** | Pydantic (>=2.10.0) | Schema validation and type safety |
| **Database** | SQLite | Progress tracking |
| **File Storage** | JSON files | Course content persistence |
| **Observability** | LangSmith + OpenTelemetry | LLM tracing and debugging |
| **Package Manager** | uv | Dependency management |
| **Build System** | Hatchling | Python packaging |

---

## Data Model (Pydantic Schemas)

### Core Learning Entities
```
Course
├── id, title, description, created_at
├── computed: total_modules, total_concepts, completion_percentage, estimated_hours
└── modules: list[Module]
    ├── id, title, description, order, estimated_minutes
    ├── computed: concept_count, completed_concepts, completion_percentage
    └── concepts: list[Concept]
        ├── id, title, content, order
        ├── status: NOT_STARTED | IN_PROGRESS | COMPLETED
        ├── mastery: 0.0-1.0
        └── questions_asked: int
```

### Quiz & Assessment
```
Quiz
├── id, module_id, module_title, created_at
└── questions: list[QuizQuestion]
    ├── question_type: MULTIPLE_CHOICE | TRUE_FALSE | CODE | OPEN_ENDED
    ├── options, correct_answer, explanation
    ├── concept_id (links back to assessed concept)
    └── difficulty: 1-5

QuizResult
├── score: 0.0-1.0, passed: bool (80% threshold)
├── weak_concepts: list[str] (concept IDs needing review)
├── feedback: str (AI-generated, personalized)
└── computed: score_percentage
```

### User & Session
```
UserPreferences
├── name, learning_style, session_length_minutes
├── experience_level: BEGINNER | INTERMEDIATE | ADVANCED
├── goals, is_onboarded

LearningSession
├── course_id, current_module_idx, current_concept_idx
├── chat_history: list[ChatMessage]
├── concepts_covered, questions_asked
└── methods: add_message(), advance_concept(), go_back_concept()
```

### LLM Output Schemas (Curriculum Generation Pipeline)
```
Step 1: CurriculumOutline → ModuleOutline → ConceptOutline  (structure only)
Step 2: ModuleOutput → ConceptOutput                         (full content)
Step 3: CourseOutput                                          (assembled)
```

---

## Application Layers

### Layer 1: Storage (`src/sensei/storage/`)
- `database.py` - SQLite for progress tracking
- `file_storage.py` - JSON file storage for course content
- `memory_manager.py` - CrewAI memory configuration and formatting utilities

### Layer 2: Services (`src/sensei/services/`)
Business logic layer that orchestrates storage and crews:
- `user_service.py` - User preferences and onboarding
- `course_service.py` - Course CRUD, creation via Curriculum Crew
- `learning_service.py` - Lesson generation via Teaching Crew
- `quiz_service.py` - Quiz generation/evaluation via Assessment Crew
- `progress_service.py` - Progress tracking and statistics

### Layer 3: UI (`src/sensei/ui/`)
Streamlit-based interface:
- `pages/` - Dashboard, new course, learning, quiz, progress, settings, onboarding
- `components/` - Reusable Streamlit widgets

### Layer 4: Entry Point (`src/sensei/app.py`)
Streamlit app managing page routing, service initialization, session state, and navigation callbacks.

---

## User Flow

```
1. Onboarding → Set name, learning style, experience level, goals
2. New Course → Enter topic → Curriculum Crew generates structured course
3. Learning → Navigate concepts → Teaching Crew generates lessons
4. Q&A → Ask questions → Q&A Mentor provides contextual answers
5. Quiz → Complete module → Assessment Crew generates quiz
6. Results → Performance Analyst evaluates → Feedback + next steps
7. Progress → Track completion across all courses
```

---

## Testing Strategy

| Suite | Scope | API Calls? |
|-------|-------|------------|
| `tests/test_models/` | Pydantic schema validation | No |
| `tests/test_storage/` | Database + file operations | No |
| `tests/test_services/` | Business logic (mocked crews) | No |
| `tests/test_crews/` | CrewAI crew logic (mocked LLMs) | No |
| `tests/test_ui/` | Streamlit components | No |
| `tests/test_functional/` | Real LLM API calls | Yes (costs money) |
| `tests/test_e2e/` | End-to-end flows | Yes |

- Default `pytest` runs **only unit tests** (functional + e2e excluded via pytest config)
- Coverage target: **90%** (currently ~94%)
- Functional tests require all three API keys (OpenAI, Anthropic, Google)

---

## Project Status

Milestones M1-M9 are complete. **M10 (End-to-End Integration & Polish)** is in progress.

---

## Why Multi-Agent?

The README explains the rationale:

| Benefit | Description |
|---------|-------------|
| **Specialization** | Each agent is an expert in its domain (curriculum design, teaching, assessment) |
| **Parallelization** | Multiple agents work simultaneously (e.g., expanding modules in parallel) |
| **Quality** | Different LLMs excel at different tasks - best model for each role |
| **Maintainability** | Clean separation of concerns makes extending and debugging easier |

---

## Key Design Patterns

1. **Flow Pattern** (Curriculum Crew): Multi-step generation with state management and async parallel expansion
2. **Dynamic Task Selection** (Teaching + Assessment Crews): Single-agent mini-crews instead of monolithic crew execution
3. **Structured Output** (`output_pydantic`): LLM outputs are validated against Pydantic schemas for reliability
4. **Semantic Evaluation**: Open-ended quiz answers evaluated by AI for understanding, not exact string matching
5. **Adaptive Assessment**: Weak concepts from previous attempts influence future quiz focus areas
6. **Session Isolation**: Short-term memory only within a run; no cross-session contamination
