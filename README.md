# ManageAI n8n v2.0

Self-hosted n8n deployment for ManageAI with advanced workflow orchestration, retry logic, health monitoring, and a full CLI.

**Live instance:** https://n8n-production-13ed.up.railway.app

## What's New in v2

- **Enhanced persona outputs** — SEO keywords, reading time, calendar blocks, CRM flags, priority levels
- **Retry logic** — Daniel workflow retries on 503 with 5s backoff
- **Orchestration workflows** — Full project pipeline (5-step), persona selector, batch briefing, alert router
- **Health monitoring** — 30-minute webhook health checks across all endpoints
- **Knowledge sync** — Daily 6am automated reindex + briefing + cost report
- **CLI v2** — `manage-workflows.sh` with status, logs, export, health, demo commands
- **Test suite** — Parallel webhook tests, interactive demo, load testing

## Workflows (14 total)

### Infrastructure
| Workflow | Type | Path |
|---|---|---|
| Ping/Pong Test | Webhook | `GET /webhook/ping` |
| Make Equivalent | Webhook | `POST /webhook/plan` |

### Persona Workflows (v2 Enhanced)
| Workflow | Webhook | Key Enhancements |
|---|---|---|
| Daniel - Sales Follow-Up | `POST /webhook/daniel/followup` | Retry logic, `recommended_template`, `priority`, `crm_update_needed` |
| Sarah - Content Generator | `POST /webhook/sarah/content` | `seo_keywords[]`, `reading_time_minutes`, `format_metadata{}` |
| Andrew - Ops Report | `POST /webhook/andrew/report` | Parallel data fetches, `pipeline_summary`, `health_status`, `data_sources[]` |
| Rebecka - Meeting Prep | `POST /webhook/rebecka/meeting` | `calendar_block` (ICS), `pre_read[]`, `follow_up_email_template` |

### Orchestration Workflows
| Workflow | Webhook | Purpose |
|---|---|---|
| Full Project Pipeline | `POST /webhook/project/pipeline` | 5-step orchestration: plan, verify, cost, memory, orchestrate |
| Persona Selector | `POST /webhook/persona/select` | Auto-route by department/urgency to correct persona |
| Batch Briefing | `POST /webhook/briefing/batch` | Generate briefings for up to 5 clients |
| Alert Router | `POST /webhook/alerts/route` | Route alerts to persona + Slack notification |

### Scheduled Monitors
| Workflow | Schedule | Purpose |
|---|---|---|
| Pipeline Monitor | Every 1 hour | Stalled project alerts to Slack |
| Cost Weekly Report | Monday 9am | Weekly cost summary to Slack |
| Knowledge Sync | Daily 6am | System health, reindex, briefing, costs |
| Webhook Health Check | Every 30 min | Test all webhook endpoints, alert on failure |

## Quick Test

```bash
# Ping
curl https://n8n-production-13ed.up.railway.app/webhook/ping

# Daniel (with v2 enrichment)
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/daniel/followup \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Jane", "company": "Acme", "deal_stage": "negotiation"}'

# Full pipeline (master orchestration)
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/project/pipeline \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Demo Corp", "original_request": "Automate leads", "trigger_type": "webhook", "output_action": "API response"}'

# Persona auto-selector
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/persona/select \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Acme", "department": "marketing", "urgency": "high"}'
```

## Scripts

| Script | Command | Purpose |
|---|---|---|
| `manage-workflows.sh` | `bash scripts/manage-workflows.sh <cmd>` | Full CLI: list, status, sync, logs, export, health, demo |
| `test-all-webhooks.sh` | `bash scripts/test-all-webhooks.sh` | Parallel test of all 6 webhook workflows |
| `demo.sh` | `bash scripts/demo.sh` | Interactive 10-step demo of all workflow types |
| `load-test.sh` | `bash scripts/load-test.sh` | 40 concurrent requests (10 per persona) |

### Running the Demo

```bash
# Set your n8n URL (defaults to production)
export N8N_BASE="https://n8n-production-13ed.up.railway.app"

# Full interactive demo
bash scripts/demo.sh

# Quick health check
bash scripts/manage-workflows.sh health

# Run all webhook tests
bash scripts/test-all-webhooks.sh
```

## Deploy to Railway

### Prerequisites
- [Railway account](https://railway.app)
- GitHub repo connected to Railway

### Step-by-step

1. **Clone this repo**
   ```bash
   git clone https://github.com/Brian2169fdsa/manageai-n8n.git
   ```

2. **Create Railway project** with PostgreSQL database

3. **Set environment variables**
   ```
   N8N_BASIC_AUTH_ACTIVE=true
   N8N_BASIC_AUTH_USER=<your-username>
   N8N_BASIC_AUTH_PASSWORD=<your-password>
   N8N_HOST=<your-railway-domain>
   WEBHOOK_URL=https://<your-railway-domain>/
   DB_TYPE=postgresdb
   DB_POSTGRESDB_HOST=${{Postgres.PGHOST}}
   DB_POSTGRESDB_PORT=${{Postgres.PGPORT}}
   DB_POSTGRESDB_DATABASE=${{Postgres.PGDATABASE}}
   DB_POSTGRESDB_USER=${{Postgres.PGUSER}}
   DB_POSTGRESDB_PASSWORD=${{Postgres.PGPASSWORD}}
   SLACK_WEBHOOK_URL=<your-slack-webhook-url>
   ```

4. **Deploy** — Railway auto-deploys on push

5. **Import workflows**
   ```bash
   export N8N_API_KEY="your-api-key"
   bash scripts/manage-workflows.sh sync
   ```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `N8N_BASIC_AUTH_ACTIVE` | Yes | Enable basic auth |
| `N8N_BASIC_AUTH_USER` | Yes | UI login username |
| `N8N_BASIC_AUTH_PASSWORD` | Yes | UI login password |
| `N8N_HOST` | Yes | Public hostname |
| `WEBHOOK_URL` | Yes | Webhook base URL |
| `DB_TYPE` | Yes | `postgresdb` |
| `DB_POSTGRESDB_HOST` | Yes | PostgreSQL host |
| `DB_POSTGRESDB_PORT` | No | PostgreSQL port (default: 5432) |
| `DB_POSTGRESDB_DATABASE` | Yes | Database name |
| `DB_POSTGRESDB_USER` | Yes | Database user |
| `DB_POSTGRESDB_PASSWORD` | Yes | Database password |
| `AGENTICMAKEBUILDER_URL` | No | AMB API URL (hardcoded default) |
| `SLACK_WEBHOOK_URL` | For monitors | Slack webhook for alerts |

## Connecting to AgenticMakeBuilder

All workflows connect to: **https://agenticmakebuilder-production.up.railway.app**

Endpoints used:
- `/persona/test` — All persona workflows
- `/plan`, `/verify` — Full project pipeline
- `/costs/track`, `/costs/summary`, `/costs/report` — Cost tracking
- `/persona/memory`, `/persona/context` — Knowledge sync
- `/supervisor/stalled` — Pipeline monitor
- `/health` — System health checks

## Local Development

```bash
cp .env.example .env
# Fill in your values
docker compose up
```

n8n will be available at `http://localhost:5678`.

See [`workflows/README.md`](workflows/README.md) for complete workflow documentation.
