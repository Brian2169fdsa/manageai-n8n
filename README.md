# ManageAI n8n

Self-hosted n8n deployment for ManageAI, designed for Railway with PostgreSQL backend.

**Live instance:** https://n8n-production-13ed.up.railway.app

## Deploy to Railway

### Prerequisites

- [Railway account](https://railway.app)
- GitHub repo connected to Railway

### Step-by-step

1. **Fork or clone this repo**

   ```bash
   git clone https://github.com/Brian2169fdsa/manageai-n8n.git
   ```

2. **Create a new project on Railway**

   Go to [railway.app/new](https://railway.app/new) and select "Deploy from GitHub repo".

3. **Add a PostgreSQL database**

   In your Railway project, click "New" -> "Database" -> "PostgreSQL". Railway will provision the database and provide connection variables.

4. **Set environment variables**

   In your n8n service settings, add the following variables under the "Variables" tab. See the [Environment Variables](#environment-variables) section below for descriptions.

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
   ```

   Railway will interpolate the `${{Postgres.*}}` references automatically.

5. **Deploy**

   Railway auto-deploys on push. The health check at `/healthz` confirms the instance is live.

6. **Verify**

   Import the test workflow and hit `GET https://<your-domain>/webhook/ping`. You should get a `pong` response.

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `N8N_BASIC_AUTH_ACTIVE` | Yes | Enable basic auth for the n8n UI (`true`) |
| `N8N_BASIC_AUTH_USER` | Yes | Username for n8n UI login |
| `N8N_BASIC_AUTH_PASSWORD` | Yes | Password for n8n UI login |
| `N8N_HOST` | Yes | Public hostname (e.g. `n8n-production-13ed.up.railway.app`) |
| `WEBHOOK_URL` | Yes | Full base URL for webhooks (e.g. `https://n8n-production-13ed.up.railway.app/`) |
| `DB_TYPE` | Yes | Database type — set to `postgresdb` |
| `DB_POSTGRESDB_HOST` | Yes | PostgreSQL host |
| `DB_POSTGRESDB_PORT` | No | PostgreSQL port (default: `5432`) |
| `DB_POSTGRESDB_DATABASE` | Yes | PostgreSQL database name |
| `DB_POSTGRESDB_USER` | Yes | PostgreSQL username |
| `DB_POSTGRESDB_PASSWORD` | Yes | PostgreSQL password |
| `AGENTICMAKEBUILDER_URL` | No | URL of the agenticmakebuilder API (default: `https://agenticmakebuilder-production.up.railway.app`) |

## Importing Workflows

1. Open your n8n instance in a browser
2. Go to **Workflows** -> **Import from File**
3. Upload any JSON file from the `workflows/` directory

Or use the n8n API:

```bash
curl -X POST https://<your-domain>/api/v1/workflows \
  -H "X-N8N-API-KEY: <your-api-key>" \
  -H "Content-Type: application/json" \
  -d @workflows/test-workflow.json
```

### Available Workflows

**Infrastructure:**

- **`test-workflow.json`** — Ping/pong endpoint (`GET /webhook/ping`). Import first to verify deployment.
- **`sample-make-equivalent.json`** — Bridge to agenticmakebuilder `POST /plan`.

**Persona Workflows:**

| Workflow | Webhook | Persona |
|---|---|---|
| [`daniel-sales-followup.json`](workflows/daniel-sales-followup.json) | `POST /webhook/daniel/followup` | Daniel — Sales follow-ups |
| [`sarah-content-generator.json`](workflows/sarah-content-generator.json) | `POST /webhook/sarah/content` | Sarah — Content generation |
| [`andrew-ops-report.json`](workflows/andrew-ops-report.json) | `POST /webhook/andrew/report` | Andrew — Ops reports |
| [`rebecka-meeting-prep.json`](workflows/rebecka-meeting-prep.json) | `POST /webhook/rebecka/meeting` | Rebecka — Meeting prep |

**Automated Monitors:**

| Workflow | Trigger | Purpose |
|---|---|---|
| [`pipeline-monitor.json`](workflows/pipeline-monitor.json) | Every 1 hour | Stalled project alerts to Slack |
| [`cost-weekly-report.json`](workflows/cost-weekly-report.json) | Monday 9am | Weekly cost summary to Slack |

See [`workflows/README.md`](workflows/README.md) for full documentation, inputs, and example curl commands.

## Connecting to AgenticMakeBuilder

All persona workflows connect to:
- **AgenticMakeBuilder:** https://agenticmakebuilder-production.up.railway.app

### Quick test

```bash
# Ping/pong
curl https://n8n-production-13ed.up.railway.app/webhook/ping

# Daniel — sales follow-up
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/daniel/followup \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Jane Smith", "company": "Acme Corp", "deal_stage": "proposal"}'

# Sarah — content generation
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/sarah/content \
  -H "Content-Type: application/json" \
  -d '{"topic": "AI automation for agencies", "format": "blog"}'

# Andrew — ops report
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/andrew/report \
  -H "Content-Type: application/json" \
  -d '{"client_id": "acme-corp", "report_type": "weekly"}'

# Rebecka — meeting prep
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/rebecka/meeting \
  -H "Content-Type: application/json" \
  -d '{"client_name": "Acme Corp", "meeting_type": "quarterly review", "agenda_items": ["Q4 review", "Q1 planning"]}'
```

## Local Development

```bash
cp .env.example .env
# Fill in your values
docker compose up
```

n8n will be available at `http://localhost:5678`.
