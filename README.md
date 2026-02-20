# ManageAI n8n

Self-hosted n8n deployment for ManageAI, designed for Railway with PostgreSQL backend.

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
| `N8N_HOST` | Yes | Public hostname (e.g. `manageai-n8n.up.railway.app`) |
| `WEBHOOK_URL` | Yes | Full base URL for webhooks (e.g. `https://manageai-n8n.up.railway.app/`) |
| `DB_TYPE` | Yes | Database type — set to `postgresdb` |
| `DB_POSTGRESDB_HOST` | Yes | PostgreSQL host |
| `DB_POSTGRESDB_PORT` | No | PostgreSQL port (default: `5432`) |
| `DB_POSTGRESDB_DATABASE` | Yes | PostgreSQL database name |
| `DB_POSTGRESDB_USER` | Yes | PostgreSQL username |
| `DB_POSTGRESDB_PASSWORD` | Yes | PostgreSQL password |
| `AGENTICMAKEBUILDER_URL` | No | URL of the agenticmakebuilder API (used by sample workflow) |
| `AGENTICMAKEBUILDER_API_KEY` | No | API key for agenticmakebuilder (used by sample workflow) |

## Importing Workflows

1. Open your n8n instance in a browser
2. Go to **Workflows** -> **Import from File**
3. Upload any JSON file from the `workflows/` directory

### Available Workflows

- **`test-workflow.json`** — Ping/pong endpoint. Import first to verify your deployment.
- **`sample-make-equivalent.json`** — Full workflow mirroring the agenticmakebuilder `POST /plan` flow with webhook trigger, HTTP request, error handling, and response transformation.

## Connecting to AgenticMakeBuilder

The sample workflow calls the agenticmakebuilder API. To connect:

1. Set `AGENTICMAKEBUILDER_URL` to your agenticmakebuilder instance URL (e.g. `https://your-app.up.railway.app`)
2. Set `AGENTICMAKEBUILDER_API_KEY` to a valid API key
3. Import `workflows/sample-make-equivalent.json`
4. Activate the workflow
5. Send a POST request to your n8n webhook:

   ```bash
   curl -X POST https://<your-n8n-domain>/webhook/plan \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Create a workflow that sends a Slack message when a new row is added to Google Sheets"}'
   ```

   The workflow validates the input, forwards it to agenticmakebuilder `/api/plan`, transforms the response, and returns the generated plan.

## Local Development

```bash
cp .env.example .env
# Fill in your values
docker compose up
```

n8n will be available at `http://localhost:5678`.
