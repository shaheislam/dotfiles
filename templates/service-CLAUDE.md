# Service Name

> Place this file at the repo root as `CLAUDE.md` or `.claude/CLAUDE.md`.
> Inherits from parent workspace CLAUDE.md (e.g., ~/work/CLAUDE.md).
> Remove this blockquote and customize the sections below.

## Service Context

- **Language**: <!-- e.g., Go 1.22, TypeScript 5.x, Python 3.12 -->
- **Framework**: <!-- e.g., Chi, Express, FastAPI -->
- **Database**: <!-- e.g., PostgreSQL 16, Redis, DynamoDB -->
- **Messaging**: <!-- e.g., Kafka, SQS, RabbitMQ -->

## Project Structure

<!-- Describe the layout so Claude navigates efficiently -->
<!-- ```
cmd/           - entrypoints
internal/
  api/         - HTTP handlers
  domain/      - business logic
  repo/        - database layer
migrations/    - SQL migrations
``` -->

## Commands

| Command | Description |
|---------|-------------|
| `make test` | Run unit tests |
| `make integration` | Run integration tests |
| `make lint` | Run linter |
| `make build` | Build binary/bundle |
| `make run` | Run locally |
<!-- | `make migrate` | Run database migrations | -->
<!-- | `make proto` | Regenerate protobuf | -->
<!-- | `make docker` | Build container image | -->

## Architecture Decisions

<!-- Key decisions Claude should respect -->
<!-- - Repository pattern for all DB access (no raw queries in handlers) -->
<!-- - Errors wrap with context via fmt.Errorf("op: %w", err) -->
<!-- - All endpoints require auth middleware except /healthz -->
<!-- - Feature flags via LaunchDarkly, not env vars -->

## API Conventions

<!-- Uncomment and customize -->
<!-- - RESTful routes: /api/v1/resources -->
<!-- - Request validation at handler layer -->
<!-- - Errors return { "error": "message", "code": "ERROR_CODE" } -->
<!-- - Pagination via cursor, not offset -->

## Testing

<!-- Uncomment and customize -->
<!-- - Table-driven tests for Go -->
<!-- - Testcontainers for integration tests (real DB, no mocks) -->
<!-- - Fixtures in testdata/ directories -->
<!-- - Minimum 80% coverage on new code -->

## Environment

<!-- Uncomment and customize -->
<!-- - Local: docker compose up -d (postgres, redis, kafka) -->
<!-- - Config: .env.local (gitignored), .env.example committed -->
<!-- - Secrets: never in code, use vault or env injection -->

## Gotchas

<!-- Things that would trip up someone (or an AI) new to this repo -->
<!-- - The ORM auto-migrates in dev but NOT in production -->
<!-- - Kafka consumers require manual partition assignment in tests -->
<!-- - The /legacy/* routes have different auth, don't touch without context -->
