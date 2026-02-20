# ManageAI Workflow Library

Production-ready n8n workflows for ManageAI's 4 personas plus automated monitoring.

## Required Environment Variables

| Variable | Required | Description |
|---|---|---|
| `AGENTICMAKEBUILDER_URL` | Yes | AgenticMakeBuilder API (default hardcoded: `https://agenticmakebuilder-production.up.railway.app`) |
| `SLACK_WEBHOOK_URL` | For monitors | Slack incoming webhook URL for pipeline and cost alerts |

---

## Persona Workflows

### 1. Daniel — Sales Follow-Up

**Webhook:** `POST /webhook/daniel/followup`

Generates personalized sales follow-up messages with stage-appropriate next actions.

| Input | Type | Required | Description |
|---|---|---|---|
| `customer_name` | string | Yes | Customer contact name |
| `company` | string | No | Company name |
| `last_interaction` | string | No | Summary of last interaction |
| `deal_stage` | string | No | `discovery`, `proposal`, `negotiation`, `closed_won`, `closed_lost` |

**Output:** `follow_up_message`, `next_action`, `deal_stage`, `sent_at`

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/daniel/followup \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Jane Smith",
    "company": "Acme Corp",
    "last_interaction": "Demo call on Feb 15, showed interest in enterprise plan",
    "deal_stage": "proposal"
  }'
```

---

### 2. Sarah — Content Generator

**Webhook:** `POST /webhook/sarah/content`

Generates content in blog, email, or social format with audience and tone targeting.

| Input | Type | Required | Description |
|---|---|---|---|
| `topic` | string | Yes | Content topic |
| `format` | string | No | `blog`, `email`, or `social` (default: `blog`) |
| `target_audience` | string | No | Target audience description |
| `tone` | string | No | Tone of voice (default: `professional`) |

**Output:** `content`, `format`, `word_count`, `created_at`

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/sarah/content \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "How AI automation reduces operational costs for agencies",
    "format": "blog",
    "target_audience": "agency owners",
    "tone": "conversational"
  }'
```

---

### 3. Andrew — Ops Report

**Webhook:** `POST /webhook/andrew/report`

Generates operations reports combining cost data with Andrew's narrative analysis.

| Input | Type | Required | Description |
|---|---|---|---|
| `client_id` | string | Yes | Client identifier |
| `report_type` | string | No | `weekly` or `monthly` (default: `weekly`) |
| `include_costs` | boolean | No | Include cost breakdown (default: `true`) |

**Output:** `report_markdown`, `total_cost`, `avg_margin`, `period`

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/andrew/report \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "acme-corp",
    "report_type": "weekly",
    "include_costs": true
  }'
```

---

### 4. Rebecka — Meeting Prep

**Webhook:** `POST /webhook/rebecka/meeting`

Generates meeting briefs with structured agendas and preparation notes.

| Input | Type | Required | Description |
|---|---|---|---|
| `client_name` | string | Yes | Client name |
| `meeting_type` | string | No | Type of meeting (default: `general`) |
| `agenda_items` | string[] | No | List of agenda items |
| `attendees` | string[] | No | List of attendee names/emails |

**Output:** `meeting_brief`, `agenda_formatted`, `prep_notes`, `send_to`

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/rebecka/meeting \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "Acme Corp",
    "meeting_type": "quarterly review",
    "agenda_items": ["Q4 performance review", "Budget planning for Q1", "New feature requests"],
    "attendees": ["jane@acme.com", "bob@acme.com"]
  }'
```

---

## Automated Monitors

### 5. Pipeline Monitor (Hourly)

**Trigger:** Runs every 1 hour via schedule.

Checks for stalled projects (>48h no update), generates a daily briefing if any are found, and sends a Slack alert.

**Flow:** Schedule -> GET /supervisor/stalled -> If stalled > 0 -> POST /briefing/daily -> POST Slack

**Requires:** `SLACK_WEBHOOK_URL` environment variable.

---

### 6. Cost Weekly Report (Monday 9am)

**Trigger:** Runs every Monday at 9:00 AM via cron.

Pulls the weekly cost report and sends a formatted summary to Slack.

**Flow:** Schedule (Mon 9am) -> POST /costs/report -> Format markdown -> POST Slack

**Requires:** `SLACK_WEBHOOK_URL` environment variable.

---

## Importing All Workflows

### Via n8n UI

1. Open https://n8n-production-13ed.up.railway.app
2. Go to **Workflows** -> **Import from File**
3. Import each JSON file from this directory

### Via API

```bash
API_KEY="your-n8n-api-key"
BASE="https://n8n-production-13ed.up.railway.app"

for wf in daniel-sales-followup sarah-content-generator andrew-ops-report \
          rebecka-meeting-prep pipeline-monitor cost-weekly-report; do
  echo "Importing $wf..."
  ID=$(curl -s -X POST "$BASE/api/v1/workflows" \
    -H "X-N8N-API-KEY: $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"workflows/$wf.json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))")
  echo "  Created: $ID"
  curl -s -X POST "$BASE/api/v1/workflows/$ID/activate" \
    -H "X-N8N-API-KEY: $API_KEY" > /dev/null
  echo "  Activated"
done
```
