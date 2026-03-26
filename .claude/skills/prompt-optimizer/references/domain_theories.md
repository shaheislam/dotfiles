# Domain Theories Reference

When grounding EARS requirements, match the requirement's domain to applicable theories below. Cite the theory name and explain in one sentence how it applies.

## Productivity & Task Management
| Theory | When to Apply |
|--------|--------------|
| GTD (Getting Things Done) | Capture/organize/review workflows, inbox processing |
| Eisenhower Matrix | Priority triage (urgent vs important) |
| Pomodoro Technique | Time-boxed work intervals, focus management |
| Kanban | Visual workflow, WIP limits, pull-based systems |
| JTBD (Jobs To Be Done) | Feature design framed as user outcomes |
| Parkinson's Law | Work expands to fill time - set explicit deadlines |
| Zeigarnik Effect | Unfinished tasks stay in memory - show progress |

## UX & Interface Design
| Theory | When to Apply |
|--------|--------------|
| Gestalt Principles | Proximity, similarity, closure in visual layout |
| Fitts's Law | Target size and distance affect click/tap speed |
| Hick's Law | More choices = slower decisions - reduce options |
| Nielsen's 10 Heuristics | General usability evaluation checklist |
| Miller's Law (7+-2) | Working memory limits on displayed items |
| Jakob's Law | Users expect your site to work like others they use |
| Doherty Threshold | Response < 400ms feels instant, maintain flow |
| Progressive Disclosure | Show basics first, details on demand |

## Behavior & Engagement
| Theory | When to Apply |
|--------|--------------|
| BJ Fogg Behavior Model | Behavior = Motivation x Ability x Prompt |
| Hook Model (Nir Eyal) | Trigger -> Action -> Variable Reward -> Investment |
| Self-Determination Theory | Autonomy, competence, relatedness drive motivation |
| Nudge Theory | Default options guide behavior without restricting |
| Peak-End Rule | Users judge experiences by peak moment and ending |
| Endowment Effect | Users overvalue what they already have/configured |

## Security & Trust
| Theory | When to Apply |
|--------|--------------|
| Zero Trust Architecture | Never trust, always verify - even internal |
| Principle of Least Privilege | Grant minimum access needed for the task |
| Defense in Depth | Multiple security layers, no single point of failure |
| OWASP Top 10 | Common web vulnerabilities checklist |
| CIA Triad | Confidentiality, Integrity, Availability trade-offs |
| Kerckhoffs's Principle | System security shouldn't depend on secrecy of design |

## Software Architecture
| Theory | When to Apply |
|--------|--------------|
| SOLID Principles | Class/module design (single responsibility, etc.) |
| CAP Theorem | Distributed systems: choose 2 of consistency/availability/partition tolerance |
| 12-Factor App | Cloud-native application design patterns |
| Conway's Law | System structure mirrors org structure |
| YAGNI | Don't build for hypothetical future needs |
| DRY / Rule of Three | Abstract after 3 duplications, not before |
| Separation of Concerns | Each module handles one aspect of functionality |

## Data & Storage
| Theory | When to Apply |
|--------|--------------|
| ACID Properties | Transaction guarantees (atomicity, consistency, isolation, durability) |
| Eventual Consistency | Distributed data that converges over time |
| CQRS | Separate read and write models for different optimization |
| Event Sourcing | Store state changes as immutable event log |
| Normalization (1NF-BCNF) | Database schema design to reduce redundancy |
| Cache Invalidation | "Two hard problems": when to expire cached data |

## Testing & Quality
| Theory | When to Apply |
|--------|--------------|
| Test Pyramid | Many unit tests, fewer integration, fewest E2E |
| Property-Based Testing | Generate random inputs, verify invariants hold |
| Mutation Testing | Verify tests catch injected code changes |
| Boundary Value Analysis | Test at edges of valid input ranges |
| Equivalence Partitioning | One test per input class, not per value |
| Chaos Engineering | Inject failures to test system resilience |

## Communication & Marketing
| Theory | When to Apply |
|--------|--------------|
| AIDA Model | Attention -> Interest -> Desire -> Action funnel |
| Jobs To Be Done | Frame messaging around user outcomes |
| Cialdini's 6 Principles | Reciprocity, scarcity, authority, consistency, liking, consensus |
| Information Architecture | Organize content for findability and comprehension |

## Performance & Scalability
| Theory | When to Apply |
|--------|--------------|
| Amdahl's Law | Parallelism speedup limited by serial fraction |
| Little's Law | L = lambda * W (queue length = arrival rate * wait time) |
| Thundering Herd | Many processes wake simultaneously on shared event |
| Backpressure | Slow consumers signal producers to throttle |
| Circuit Breaker | Stop calling failing services, fail fast instead |

## Operations & Reliability
| Theory | When to Apply |
|--------|--------------|
| SLO/SLI/SLA Framework | Define, measure, and commit to reliability targets |
| MTTR > MTBF | Optimize recovery time over failure prevention |
| Observability (3 Pillars) | Logs, metrics, traces for system understanding |
| Blast Radius | Limit scope of failures through isolation |
| Graceful Degradation | Serve reduced functionality rather than total failure |
