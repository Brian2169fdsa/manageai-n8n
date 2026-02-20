# ManageAI n8n v3.0

Self-hosted n8n deployment for ManageAI with 34 production workflows: Make.com deployment bridge, webhook registry, error replay system, analytics engine, multi-tenant routing, persona chaining, and a full CLI management suite.

**Live instance:** https://n8n-production-13ed.up.railway.app
**AMB Backend:** https://agenticmakebuilder-production.up.railway.app
**GitHub:** https://github.com/Brian2169fdsa/manageai-n8n

## Quick Start

```bash
# First-run setup
bash scripts/setup.sh

# Import & activate all workflows
bash scripts/manage-workflows.sh sync

# Test all webhooks
bash scripts/manage-workflows.sh health

# Run full demo (15 steps)
bash scripts/demo.sh

# Live monitoring dashboard
bash scripts/monitor.sh
```

## Workflows (34 total)

| Category | Count | Webhooks |
|----------|-------|----------|
| Core Personas | 4 | daniel/followup, sarah/content, andrew/report, rebecka/meeting |
| Orchestration | 4 | project/pipeline, persona/select, briefing/batch, alerts/route |
| Make.com Bridge | 5 | makecom/deploy, makecom/status, makecom/teardown, makecom/run, makecom/monitor |
| Webhook Registry | 3 | registry/register, registry/list, registry/test |
| Error Replay | 4 | errors/capture, errors/list, errors/replay, errors/resolve |
| Analytics | 3 | analytics/usage, analytics/report, analytics/cost |
| Multi-Tenant | 2 | tenant/route, tenant/config |
| Advanced Persona | 3 | persona/chain, persona/compare, persona/memory-sync |
| Scheduled | 4 | (cron: daily 6am, hourly, monday 9am, every 30min) |
| Legacy | 2 | plan, ping |

See [workflows/README.md](workflows/README.md) for full documentation.

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/manage-workflows.sh` | CLI v3: list, sync, health, registry, errors, analytics, tenants, chain, compare |
| `scripts/demo.sh` | 15-step interactive demo with all workflow categories |
| `scripts/monitor.sh` | Live dashboard with auto-refresh (infrastructure + webhooks + services) |
| `scripts/setup.sh` | First-run setup: prereqs, connectivity, API validation, file inventory |
| `scripts/test-all-webhooks.sh` | Parallel webhook testing with field validation |
| `scripts/load-test.sh` | 40 concurrent requests for load testing |

## Infrastructure

```
Docker (n8nio/n8n) → Railway
  ├── PostgreSQL (n8n backend)
  ├── docker-entrypoint.sh (runtime PORT mapping)
  └── 34 workflows (auto-import on sync)

AMB FastAPI → Railway
  ├── /persona/test (all 4 personas)
  ├── /plan, /verify, /deploy
  ├── /costs/*, /health
  └── /persona/memory, /persona/context
```

## Deploy

```bash
# Railway (production)
railway up

# Local Docker
docker-compose up -d
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| N8N_BASE | n8n instance URL | https://n8n-production-13ed.up.railway.app |
| N8N_API_KEY | n8n API key | (loaded from /tmp/n8n-api-key.txt) |
| SLACK_WEBHOOK_URL | Slack webhook for alerts | (placeholder) |
| DATABASE_URL | PostgreSQL connection | (Railway auto-provision) |

## Version History

| Version | Workflows | Key Features |
|---------|-----------|-------------|
| v1.0.0 | 2 | Initial deploy, make-equivalent bridge, ping test |
| v1.1.0 | 8 | 4 personas + 2 scheduled monitors |
| v2.0.0 | 14 | Error handling, retry, orchestration, batch, alerts, health checks, CLI v2 |
| v3.0.0 | 34 | Make.com bridge, webhook registry, error replay, analytics, multi-tenant, persona chain/compare, CLI v3 |
