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

- **`test-workflow.json`** — Ping/pong endpoint (`GET /webhook/ping`). Import first to verify your deployment.
- **`sample-make-equivalent.json`** — Full workflow bridging n8n to agenticmakebuilder `POST /plan` with webhook trigger, input validation, HTTP request, error handling via `onError: continueRegularOutput`, and response transformation.

## Connecting to AgenticMakeBuilder

The sample workflow connects to:
- **AgenticMakeBuilder:** https://agenticmakebuilder-production.up.railway.app

### Quick test

```bash
# Simple prompt
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/plan \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Build a webhook that validates order data and sends to Slack"}'

# Structured request (full agenticmakebuilder format)
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/plan \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Acme Corp",
    "original_request": "Webhook receives order, validates, notifies Slack",
    "ticket_summary": "Order notification workflow",
    "business_objective": "Automate order alerts",
    "trigger_type": "webhook",
    "trigger_description": "HTTP POST with JSON order payload",
    "processing_steps": ["Validate order JSON via util", "Format message via util"],
    "output_action": "Send to Slack channel via slack",
    "expected_output": "Slack notification sent"
  }'
```

The workflow validates input, forwards to agenticmakebuilder `/plan`, transforms the response, and returns the plan with metadata.

## Local Development

```bash
cp .env.example .env
# Fill in your values
docker compose up
```

n8n will be available at `http://localhost:5678`.
