# Postiz: Research Findings and Usage Guide

## What is Postiz?

Postiz is an **open-source, AI-powered social media scheduling platform** (AGPL-3.0 licensed) — a self-hostable alternative to Buffer and Hypefury. It combines content creation, workflow automation, scheduling, analytics, and team collaboration into a single platform.

**Repository**: https://github.com/gitroomhq/postiz-app
**Cloud**: https://platform.postiz.com

## Architecture

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Frontend | Next.js 14.2, React 18.3, Tailwind CSS | Web UI with calendar, editor, analytics |
| Backend | NestJS 10, Node.js 22+ | API gateway with 17 controllers |
| Orchestrator | Temporal 1.14.0 | Durable workflow execution for scheduling |
| Extension | Vite + WebExtensions | Chrome/Firefox quick-post plugin |
| Database | PostgreSQL + Prisma ORM | Persistent data storage |
| Cache | Redis (ioredis) | Session storage and analytics caching |

The monorepo uses **pnpm workspaces** with three shared libraries (nestjs-libraries, react-shared-libraries, helpers).

## Supported Platforms (14+)

| Category | Platforms |
|----------|-----------|
| Professional | LinkedIn (profiles + pages), X (Twitter) |
| Visual | Instagram, Pinterest, Threads, Dribbble |
| Video | YouTube, TikTok |
| Social Networks | Facebook Pages, Bluesky, Mastodon, Reddit |
| Communication | Discord, Slack |
| Business | Google My Business |

Each platform implements the `SocialAbstract` base class, providing uniform methods for OAuth, posting, media uploads, and analytics.

## Key Features

### Content Creation
- TipTap rich text editor
- Uppy-based media uploads (S3/Cloudflare R2 storage)
- AI content generation via OpenAI + CopilotKit
- Emoji picker and formatting tools

### Scheduling & Publishing
- Calendar-based post scheduling with Temporal durable execution
- Automatic retries with configurable policies
- Bulk scheduling across multiple platforms
- Draft and review workflows
- Posts survive application restarts

### Team Collaboration
- Role-based access: SUPERADMIN, ADMIN, USER
- Organization workspaces with multi-user support
- Tier-based feature gating (FREE, STANDARD, PRO via Stripe)

### Analytics
- Engagement metrics and performance tracking
- Analytics caching with Redis
- Multi-platform insights aggregation

## Self-Hosting Guide

### Requirements
- Node.js 22.12.0+
- PostgreSQL database
- Redis instance
- S3-compatible object storage (optional, for media)

### Quick Start (Docker)
```bash
git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app
# Docker setup available in var/docker/
docker compose up -d
```

### Manual Setup
```bash
git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app
pnpm install
pnpm run prisma-db-push    # Initialize database schema
pnpm run dev                # Start all services locally (development)
pnpm run build && pnpm pm2  # Production via PM2
```

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | Token signing key |
| `FRONTEND_URL` | CORS and cookie domain |
| `TEMPORAL_ADDRESS` | Temporal workflow server |
| `STORAGE_PROVIDER` | Media storage backend |
| `CLOUDFLARE_*` | Cloudflare R2 storage config |
| `OPENAI_API_KEY` | AI content generation |
| `STRIPE_SECRET_KEY` | Payment processing |
| `STRIPE_PUBLISHABLE_KEY` | Payment processing (client) |

## LinkedIn Integration Details

LinkedIn receives first-class treatment through `LinkedInProvider`:
- **OAuth**: Full OAuth 2.0 flow with token refresh
- **Posting**: Profile and company page posting with rich text
- **Media**: Image and video uploads
- **Analytics**: Engagement metrics collection
- **Token Management**: Background refresh via Temporal workflows

## How to Use Postiz for Our Workflow

### 1. Schedule Posts Across Platforms
Use the calendar UI to draft and schedule posts to LinkedIn, X, Instagram, etc. simultaneously.

### 2. AI-Assisted Content
Leverage the OpenAI integration to generate post variations, optimize copy, and adapt content for each platform.

### 3. Team Workflows
Set up organization workspaces for team members to collaborate on content review and approval.

### 4. API Integration
Use the REST API or Node.js SDK (`@postiz/node`) for programmatic scheduling:
- `POST /posts` — Create and schedule posts
- `GET /analytics` — Retrieve performance metrics
- `GET /integrations` — Manage connected accounts

### 5. Automation Connectors
Integrate with N8N, Make.com, or Zapier for workflow automation triggers.

## Relationship to LinkedIn Automation Scripts

Postiz handles **content publishing** (scheduling posts, cross-platform distribution). The Playwright automation scripts (see `scripts/linkedin-automation/`) handle **network growth** (connecting with engagers). Together they form a complete LinkedIn strategy:

1. **Postiz** publishes content on schedule
2. **Playwright scripts** identify who engages with that content
3. **Playwright scripts** send connection requests to those engagers
4. **Postiz analytics** track growth from new connections
