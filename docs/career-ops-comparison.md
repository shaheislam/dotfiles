# Career-Ops vs `/cv-generate`: Job Search Workflow Comparison

> Generated: 2026-04-10
> Sources: [santifer/career-ops](https://github.com/santifer/career-ops) (README, SETUP, ARCHITECTURE, CUSTOMIZATION) + local `/cv-generate` skill documentation (`.claude/skills/cv-generate/SKILL.md`) + `jobapps/skills.md`

## Executive Summary

- **Career-Ops** is a full job-search operating system: Claude-driven modes orchestrate Playwright scanners, scoring heuristics, PDF generation, TSV trackers, and a Go dashboard. It is opinionated, multi-agent, and expects you to run your entire pipeline inside its repo.
- **`/cv-generate` + `skills.md`** is a targeted tool: it reads a single job description + skills database, then produces a LaTeX CV/PDF tailored to that role. There is no portal discovery, scoring rubric, or tracker baked in.
- Career-Ops is therefore **far more complete** for end-to-end search management, but it also demands heavier setup (Node/Playwright/Go, portals.yml, profile.yml) and assumes you adopt its data layouts. Our skill wins for lightweight, LaTeX-first customization inside the existing dotfiles workflow.
- The two systems can coexist: use Career-Ops when you need batch evaluations, portal scanning, and a canonical tracker; keep `/cv-generate` for quick-turn, LaTeX-centric resume variants or when you only need to adapt bullet points using the curated `skills.md` taxonomy.

## How Career-Ops Operates

1. **Inputs**: Candidate profile (`config/profile.yml`), `cv.md`, optional `article-digest.md`, plus scanner config (`portals.yml`).
2. **Invocation**: Run `/career-ops` (or paste a job URL) inside Claude Code. Modes (`modes/*.md`) drive the dialogue for auto-eval, scan, batch, pdf, tracker, etc.
3. **Acquisition**: Playwright spiders pull posting data (Greenhouse, Ashby, Lever, custom company pages). Batch runner can fan out to N Claude workers via `claude -p`.
4. **Evaluation**: Six-block rubric (role summary, CV match, leveling, comp research, personalization plan, STAR stories) plus 10 weighted scoring dimensions.
5. **Outputs**: Markdown report, ATS HTML→PDF (Space Grotesk + DM Sans template), TSV tracker entries merged into `data/applications.md`, plus STAR story bank updates.
6. **Governance**: Scripts such as `merge-tracker.mjs`, `verify-pipeline.mjs`, and `normalize-statuses.mjs` enforce integrity; an optional Go TUI (`dashboard/`) visualizes the pipeline.

## Feature Comparison

| Capability | Career-Ops | `/cv-generate` + `skills.md` | Notes |
|------------|------------|-------------------------------|-------|
| **Primary goal** | Full job-search cockpit (discover → evaluate → personalize → track) | Generate a single optimized CV/PDF for a known JD | `/cv-generate` assumes you already picked the role. |
| **Inputs** | `cv.md`, `article-digest.md`, `config/profile.yml`, `portals.yml`, modes prompts | `/jobapps/jobdescription.md`, `/jobapps/skills.md`, `/jobapps/cv.md`, `resume.cls` | Both rely on structured personal context, but formats differ (HTML vs LaTeX templates). |
| **Automation scope** | Scanning, classification, scoring, negotiation prep, tracker updates, STAR story bank | Skill matching + LaTeX regeneration only | Career-Ops wraps the entire job loop; `/cv-generate` focuses on resume tailoring. |
| **Job intake** | Paste URL or JD; portal scanner hits 45+ prebuilt companies; batch TSV queue | Manual copy of JD into markdown file | Career-Ops saves time when hunting broadly. |
| **Evaluation heuristic** | 6-block reasoning + weighted 10-dimension score (1-5) | Textual relevance heuristic implied via skills matching; no numeric scoring | `/cv-generate` leaves evaluation to the human. |
| **Output artifacts** | Report markdown, ATS PDF, TSV tracker, pipeline dashboard | LaTeX + PDF (optional cover letter/gap analysis text) | Our tool’s LaTeX outputs integrate with existing jobapps repo + compile script. |
| **Batch/parallelism** | `batch-runner.sh` orchestrates `claude -p` workers; resume/resume | Single command per target; manual loops | Batch mode is unique to Career-Ops. |
| **Portal search** | Playwright automation + search queries | None | Requires Playwright install + config. |
| **Tracker / data store** | Canonical `data/applications.md` + merger scripts + Go TUI | No persistence besides generated PDFs | Could integrate by exporting `/cv-generate` results into Career-Ops tracker if desired. |
| **Customization** | Change archetypes, negotiation scripts, states, fonts via markdown/html templates; AI expected to edit its own prompts | Adjust `skills.md`, `jobdescription.md`, `cv.md`, `.cls`, CLI flags (length/style/etc.) | `/cv-generate` emphasizes structured LaTeX layout control; Career-Ops leans on Claude editing the repo live. |
| **Tech stack** | Node 18+, Playwright (Chromium), Go 1.21 for dashboard, Claude Code orchestrations | Fish/Bash wrappers + LaTeX toolchain via `scripts/compile-cv.sh` | Career-Ops is JavaScript-heavy; `/cv-generate` depends on TeX. |
| **Setup complexity** | npm install, Playwright download, Portal/profile configuration, dashboards optional | Ensure jobapps directory + TeX env exist (already part of dotfiles) | `/cv-generate` is lower friction inside this repo. |
| **Multilingual support** | README + prompts translated (ES/PT/KO/JA); heuristics independent of language | Language-agnostic but templates currently English-biased | Career-Ops invests in translation and multi-lingual docs. |
| **Observability** | `verify-pipeline.mjs`, TUI, batch-state TSV, portal logs | Manual review of generated PDF | Stronger guardrails in Career-Ops. |

## Strengths by Use Case

**Choose Career-Ops when...**
- You need a centralized, opinionated system to scan 10+ portals, score hundreds of offers, and maintain a TSV/markdown tracker without spreadsheets.
- Batch throughput matters (parallel Claude workers) or you want a TUI dashboard to triage opportunities.
- You want the agent to suggest negotiation scripts, STAR stories, and comp research alongside the generated CV.

**Choose `/cv-generate` when...**
- You already know which role to target and just need a polished, ATS-friendly LaTeX PDF drawn from the curated `skills.md` taxonomy.
- Your workflow is anchored inside `jobapps/` with strict layout rules (3 pages, `resume.cls`, compile script) and you prefer deterministic outputs.
- You want fine-grained CLI control (`--length`, `--focus`, `--company`, `--format tex`, etc.) without installing Playwright or managing portal configs.

## Integration Opportunities

1. **Feed `skills.md` into Career-Ops**: Convert the existing taxonomy into `article-digest.md` or embedded archetype tables so the richer achievements inform Career-Ops scoring.
2. **Use `/cv-generate` as a rendering backend**: Career-Ops currently renders HTML → PDF; for roles that demand the LaTeX layout, let Career-Ops produce the evaluation/report while `/cv-generate` compiles the final resume variant.
3. **Share tracker data**: Export `/cv-generate` runs (recruiter/date metadata) into the Career-Ops TSV merge script to keep a single source of truth without abandoning the lightweight command.
4. **Progressive adoption**: Start with `/cv-generate` for individual applications; when pipeline volume grows, drop the same inputs (CV, narrative, proof points) into Career-Ops to unlock scanning + batch workflows.

## Implemented Bridge

- `scripts/cv/sync-career-ops.sh` now derives `~/career-ops/cv.md`, `~/career-ops/config/profile.yml`, and `~/career-ops/portals.yml` from the canonical `jobapps` data without symlinks.
- `scripts/cv/career-ops-bridge` syncs those files, optionally runs Career-Ops doctor, then hands off to `scripts/cv/cv-generate` so LaTeX/PDF generation still uses the existing strict renderer.
- `scripts/cv/cv-generate`, `scripts/cv/cv-generator-unified.py`, and `scripts/cv/compile-cv.sh` are now worktree-aware via `DOTFILES_ROOT` / `JOBAPPS_DIR`, so the pipeline works from this repo instead of assuming `~/dotfiles`.

## Recommendation

- For this ticket, keep `/cv-generate` as the fast-path résumé generator embedded in dotfiles.
- Adopt Career-Ops when you need an end-to-end agentic pipeline; use the bridge scripts above when you want Career-Ops context and discovery without giving up the LaTeX layout guarantees in `/cv-generate`.
