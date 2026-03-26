---
name: prompt-optimizer
description: Transform vague prompts into precise EARS specifications with domain theory grounding. Use when refining requirements, improving prompt quality, or converting loose descriptions into structured, testable specifications. Triggers on "optimize prompt", "improve this requirement", "make this more specific", or "EARS".
argument-hint: "<requirement-or-prompt-text>"
allowed-tools: WebSearch, WebFetch, Read, Grep, Glob, Bash
---

# Prompt Optimizer

Transform vague requirements into precise specifications using EARS (Easy Approach to Requirements Syntax).

## Input

`$ARGUMENTS` - The requirement, prompt, or feature description to optimize.

## Step 1: Analyze the Original

Identify gaps in the input:

| Gap Type | What to Look For |
|----------|-----------------|
| Overly broad scope | "handle all cases", "support everything" |
| Missing triggers | No event or condition that initiates the behavior |
| Ambiguous language | "fast", "user-friendly", "robust", "seamless" |
| Absent constraints | No bounds on resources, time, or scope |
| Missing error cases | Only happy path described |
| Untestable criteria | No way to verify compliance |

Output a brief gap analysis before proceeding.

## Step 2: Apply EARS Patterns

Transform using these five patterns:

### Ubiquitous (always active)
```
The system shall [action].
```
Example: "The system shall display timestamps in ISO 8601 format."

### Event-Driven (triggered by occurrence)
```
When [trigger], the system shall [action].
```
Example: "When the user submits the form, the system shall validate all required fields."

### State-Driven (while condition holds)
```
While [state], the system shall [action].
```
Example: "While the network connection is unavailable, the system shall queue outgoing requests."

### Conditional (if-then)
```
If [condition], the system shall [action].
```
Example: "If the input exceeds 1000 characters, the system shall truncate and display a warning."

### Unwanted Behavior Prevention
```
If [condition], the system shall prevent [undesired action].
```
Example: "If the session token is expired, the system shall prevent API calls and redirect to login."

Choose the pattern that best matches the requirement. Complex requirements may combine multiple patterns.

## Step 3: Ground in Domain Theory

Read `references/domain_theories.md` for the full theory catalog (50+ theories across 10 domains). Match the requirement to the most relevant domain and cite the specific theory.

Quick domain lookup:

| Domain | Key Theories | When to Use |
|--------|-------------|-------------|
| Productivity | GTD, Eisenhower, Kanban, JTBD | Task management, workflow, prioritization |
| UX/UI | Gestalt, Fitts's Law, Hick's Law, Nielsen | Interface layout, interaction design |
| Behavior | BJ Fogg, Hook Model, Nudge Theory | User engagement, habit formation |
| Security | Zero Trust, Least Privilege, OWASP | Auth, access control, data protection |
| Architecture | SOLID, CAP, 12-Factor, Conway's Law | System design, module boundaries |
| Data | ACID, Eventual Consistency, CQRS | Storage, transactions, query patterns |
| Testing | Test Pyramid, Boundary Analysis, Chaos Engineering | Verification, quality gates |
| Performance | Amdahl's Law, Little's Law, Backpressure | Scaling, throughput, latency |
| Operations | SLO/SLI, MTTR>MTBF, Circuit Breaker | Reliability, monitoring, incident response |
| Communication | AIDA, Cialdini's Principles, Info Architecture | Messaging, content structure |

For each cited theory, include: theory name, one sentence on how it applies, and what it implies for the requirement.

## Step 4: Extract Concrete Examples

For each EARS requirement, provide:

1. **Success scenario** with realistic data
2. **Error scenario** with expected error handling
3. **Edge case** with boundary conditions

Use specific values, not placeholders:
- Bad: "user enters invalid input"
- Good: "user enters 'abc' in the age field (expected: integer 0-150)"

## Step 5: Generate Enhanced Prompt

Structure the optimized output:

```markdown
## Role
[Who should handle this - specific expertise needed]

## Context
[Domain theory grounding - why this approach]

## Requirements (EARS)
1. [EARS requirement 1]
2. [EARS requirement 2]
...

## Examples
### Success
[Concrete success scenario with data]

### Error Handling
[Concrete error scenario with expected behavior]

### Edge Cases
[Boundary conditions]

## Acceptance Criteria
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
...

## Constraints
- [Resource limits]
- [Time bounds]
- [Scope boundaries]
```

## Step 6: Present Results

Show a comparison:

```
ORIGINAL:
[Original requirement text]

GAPS FOUND:
- [Gap 1]
- [Gap 2]

OPTIMIZED (EARS):
[Structured EARS requirements]

DOMAIN GROUNDING:
[Theory and rationale]

ENHANCED PROMPT:
[Complete enhanced prompt from Step 5]
```

## Handling Compound Requirements

If the input contains multiple concerns, decompose into atomic EARS statements:

**Signal words**: "and", "also", "including", "as well as", "with support for"

**Before** (compound):
> "The system should handle user uploads fast and securely with good error messages"

**After** (decomposed):
1. When a user uploads a file, the system shall begin processing within 2 seconds.
2. When a user uploads a file, the system shall validate the file type against an allowlist before processing.
3. If an upload fails validation, the system shall display the rejection reason and accepted file types.

Each atomic statement gets its own EARS pattern, domain theory citation, and examples.

## Non-Functional Requirement Patterns

For performance, scalability, and reliability requirements, use measurable EARS extensions:

**Performance**:
```
The system shall [action] within [time] under [load].
```
Example: "The system shall return search results within 200ms under 1000 concurrent users."

**Availability**:
```
The system shall maintain [metric] of [target] measured over [period].
```
Example: "The system shall maintain uptime of 99.9% measured over each calendar month."

**Scalability**:
```
The system shall support [capacity] without [degradation condition].
```
Example: "The system shall support 10,000 concurrent WebSocket connections without exceeding 4GB memory."

**Data Integrity**:
```
The system shall ensure [data property] even when [failure scenario].
```
Example: "The system shall ensure no duplicate transactions even when the client retries a timed-out request."

## Quality Checks

Before presenting results, verify:
- [ ] Every requirement uses an EARS pattern
- [ ] No ambiguous adjectives remain (fast, good, easy, robust)
- [ ] All scenarios include concrete data values
- [ ] At least one error case is covered
- [ ] Acceptance criteria are binary pass/fail testable
- [ ] Domain theory is cited where applicable
- [ ] Compound requirements are decomposed into atomic statements
- [ ] Non-functional requirements include measurable thresholds
