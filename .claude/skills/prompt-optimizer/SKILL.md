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

Match the requirement to relevant frameworks:

| Domain | Frameworks |
|--------|-----------|
| UX/UI | Gestalt principles, Fitts's Law, Nielsen heuristics |
| Productivity | GTD, Eisenhower matrix, Pomodoro |
| Behavior | BJ Fogg Behavior Model, Hook Model |
| Security | Zero Trust, OWASP Top 10, Principle of Least Privilege |
| Architecture | SOLID, CAP theorem, 12-factor app |
| Data | ACID, eventual consistency, CQRS |
| Testing | Test pyramid, property-based testing, mutation testing |

Add a one-line note citing which theory applies and why.

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

## Quality Checks

Before presenting results, verify:
- [ ] Every requirement uses an EARS pattern
- [ ] No ambiguous adjectives remain (fast, good, easy, robust)
- [ ] All scenarios include concrete data values
- [ ] At least one error case is covered
- [ ] Acceptance criteria are binary pass/fail testable
- [ ] Domain theory is cited where applicable
