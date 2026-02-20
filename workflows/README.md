# ManageAI n8n Workflow Library v2

Production-ready n8n workflows for ManageAI's 4 personas, orchestration pipelines, automated monitors, and health checks.

## Architecture Overview

```
                          ManageAI n8n Platform v2

  ┌──────────────┐     ┌──────────────────────────────────────────┐
  │  Client/API  │────>│  n8n (Railway)                           │
  │  Request     │     │                                          │
  └──────────────┘     │  Webhook ─> Validate ─> Transform ─────>│──> Response
                       │                │                         │
                       │                v                         │
                       │  ┌─────────────────────────────┐         │
                       │  │  AgenticMakeBuilder (AMB)   │         │
                       │  │  /persona/test              │         │
                       │  │  /plan, /verify, /costs/*   │         │
                       │  │  /persona/memory, /health   │         │
                       │  └─────────────────────────────┘         │
                       │                                          │
                       │  Scheduled Workflows:                    │
                       │  ┌─ Pipeline Monitor (1h) ──> Slack      │
                       │  ├─ Cost Report (Mon 9am) ──> Slack      │
                       │  ├─ Knowledge Sync (6am) ──> Slack       │
                       │  └─ Health Check (30min) ──> Slack       │
                       └──────────────────────────────────────────┘
```

## Required Environment Variables

| Variable | Required | Description |
|---|---|---|
| `AGENTICMAKEBUILDER_URL` | Yes | AgenticMakeBuilder API (hardcoded default: `https://agenticmakebuilder-production.up.railway.app`) |
| `SLACK_WEBHOOK_URL` | For monitors | Slack incoming webhook URL for alerts |

---

## Section 1 — Persona Webhooks (v2 Enhanced)

| Workflow | Webhook Path | Required Inputs | Enhanced Outputs | Status |
|---|---|---|---|---|
| Daniel - Sales Follow-Up | `POST /webhook/daniel/followup` | `customer_name` | `recommended_template`, `crm_update_needed`, `priority` + retry logic | Live |
| Sarah - Content Generator | `POST /webhook/sarah/content` | `topic` | `seo_keywords[]`, `reading_time_minutes`, `format_metadata{}` | Live |
| Andrew - Ops Report | `POST /webhook/andrew/report` | `client_id` | `pipeline_summary{}`, `health_status{}`, `data_sources[]` | Live |
| Rebecka - Meeting Prep | `POST /webhook/rebecka/meeting` | `client_name` | `calendar_block`, `pre_read[]`, `follow_up_email_template` | Live |

### Daniel — Sales Follow-Up

**Webhook:** `POST /webhook/daniel/followup`

| Input | Type | Required | Description |
|---|---|---|---|
| `customer_name` | string | Yes | Customer contact name |
| `company` | string | No | Company name |
| `last_interaction` | string | No | Summary of last interaction |
| `deal_stage` | string | No | `discovery`, `proposal`, `negotiation`, `closed_won`, `closed_lost` |

**Enhanced Output:**
- `follow_up_message` — AI-generated follow-up
- `next_action` — Stage-appropriate next step
- `recommended_template` — `closing-template`, `intro-template`, `proposal-template`, or `general-followup-template`
- `crm_update_needed` — `true` if deal_stage is negotiation/closed
- `priority` — `high` (negotiation) or `medium` (all others)
- `deal_stage`, `customer_name`, `company`, `sent_at`

**Error handling:** 503 from AMB triggers a 5-second wait + single retry.

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/daniel/followup \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Jane Smith",
    "company": "Acme Corp",
    "deal_stage": "negotiation",
    "last_interaction": "Demo call Feb 15"
  }'
```

---

### Sarah — Content Generator

**Webhook:** `POST /webhook/sarah/content`

| Input | Type | Required | Description |
|---|---|---|---|
| `topic` | string | Yes | Content topic |
| `format` | string | No | `blog`, `email`, `social` (default: `blog`) |
| `target_audience` | string | No | Target audience |
| `tone` | string | No | Tone of voice (default: `professional`) |

**Enhanced Output:**
- `content`, `format`, `format_label`, `topic`, `tone`, `word_count`
- `seo_keywords` — Top 5 keywords by frequency (words > 5 chars)
- `reading_time_minutes` — Rounded to nearest 0.5 (word_count / 200)
- `format_metadata` — Format-specific:
  - blog: `h2_count`, `intro_paragraph`
  - email: `subject_line`, `cta_detected` (bool)
  - social: `character_count`, `platform_fit` (Twitter/LinkedIn/long-form)

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/sarah/content \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "AI automation reduces costs for agencies",
    "format": "email",
    "target_audience": "agency owners",
    "tone": "conversational"
  }'
```

---

### Andrew — Ops Report

**Webhook:** `POST /webhook/andrew/report`

| Input | Type | Required | Description |
|---|---|---|---|
| `client_id` | string | Yes | Client identifier |
| `report_type` | string | No | `weekly` or `monthly` |
| `include_costs` | boolean | No | Include cost breakdown (default: `true`) |

**Enhanced Output:**
- `report_markdown`, `total_cost`, `avg_margin`, `period`, `client_id`
- `pipeline_summary` — `{active_projects, stalled, completed}` from `/pipeline/dashboard`
- `health_status` — `{overall, score, alerts[]}` from `/clients/health`
- `data_sources` — List of successfully fetched sources (e.g. `["costs", "pipeline"]`)

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/andrew/report \
  -H "Content-Type: application/json" \
  -d '{"client_id": "acme-corp", "report_type": "weekly", "include_costs": true}'
```

---

### Rebecka — Meeting Prep

**Webhook:** `POST /webhook/rebecka/meeting`

| Input | Type | Required | Description |
|---|---|---|---|
| `client_name` | string | Yes | Client name |
| `meeting_type` | string | No | Type of meeting |
| `agenda_items` | string[] | No | Agenda items list |
| `attendees` | string[] | No | Attendee emails |

**Enhanced Output:**
- `meeting_brief`, `agenda_formatted`, `prep_notes`, `send_to`
- `calendar_block` — ICS-compatible calendar text (VCALENDAR/VEVENT)
- `pre_read` — Context-aware suggestions (e.g. "review" meetings get project status reminders)
- `follow_up_email_template` — Post-meeting email skeleton

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/rebecka/meeting \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "Acme Corp",
    "meeting_type": "quarterly review",
    "agenda_items": ["Q4 review", "Q1 planning"],
    "attendees": ["jane@acme.com"]
  }'
```

---

## Section 2 — Orchestration Workflows

### Full Project Pipeline

**Webhook:** `POST /webhook/project/pipeline`

Master orchestration workflow chaining 5 AMB endpoints.

| Input | Type | Required | Description |
|---|---|---|---|
| `customer_name` | string | Yes | Customer name |
| `original_request` | string | Yes | What the customer needs |
| `trigger_type` | string | Yes | Trigger type (webhook, schedule, etc.) |
| `output_action` | string | Yes | Expected output action |
| `trigger_description` | string | No | Trigger details |
| `processing_steps` | string[] | No | Processing steps |
| `expected_output` | string | No | Expected output format |

**Steps:**
1. Validate + generate project_id
2. POST `/plan` — Generate plan + extract confidence
3. If confidence > 0.6: POST `/verify` — Auto-verify blueprint
4. POST `/costs/track` — Cost estimate
5. POST `/persona/memory` — Store to memory

**Output:** `project_id`, `plan`, `verification`, `cost_estimate`, `next_stage`, `pipeline_status`, `ready_for_build`

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/project/pipeline \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "Demo Corp",
    "original_request": "Automate lead scoring from CRM",
    "trigger_type": "webhook",
    "output_action": "Return scored leads via API"
  }'
```

---

### Persona Selector

**Webhook:** `POST /webhook/persona/select`

Auto-routes requests to the correct persona based on department and urgency.

| Input | Type | Required | Description |
|---|---|---|---|
| `customer_name` | string | No | Customer name |
| `request_type` | string | No | Type of request |
| `urgency` | string | No | `low`, `medium`, `high` |
| `department` | string | No | `sales`, `marketing`, `ops`, `executive` |

**Routing Logic:**
- sales / "follow" → Daniel
- marketing / "content" → Sarah
- ops / "report" → Andrew
- high urgency / executive → Rebecka (override)

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/persona/select \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Acme", "department": "sales", "urgency": "high"}'
```

---

### Batch Briefing

**Webhook:** `POST /webhook/briefing/batch`

Generate briefings for multiple clients in one call.

| Input | Type | Required | Description |
|---|---|---|---|
| `client_ids` | string[] | Yes | Up to 5 client IDs |
| `briefing_type` | string | No | `daily` or `weekly` |

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/briefing/batch \
  -H "Content-Type: application/json" \
  -d '{"client_ids": ["client-a", "client-b"], "briefing_type": "daily"}'
```

---

### Alert Router

**Webhook:** `POST /webhook/alerts/route`

Routes alerts to the appropriate persona and posts to Slack.

| Input | Type | Required | Description |
|---|---|---|---|
| `alert_type` | string | Yes | `cost_alert`, `stall_alert`, `build_fail`, `client_health` |
| `severity` | string | No | `low`, `medium`, `high` |
| `project_id` | string | No | Related project |
| `message` | string | No | Alert details |

**Routing:**
- `cost_alert` + high → Daniel (recovery email)
- `stall_alert` → Rebecka (status update)
- `build_fail` → Andrew (incident report)
- `client_health` + high → Rebecka (client communication)

```bash
curl -X POST https://n8n-production-13ed.up.railway.app/webhook/alerts/route \
  -H "Content-Type: application/json" \
  -d '{"alert_type": "cost_alert", "severity": "high", "project_id": "proj-123", "message": "Budget exceeded"}'
```

---

## Section 3 — Scheduled Workflows

| Workflow | Schedule | Purpose |
|---|---|---|
| Pipeline Monitor | Every 1 hour | Check for stalled projects, alert via Slack |
| Cost Weekly Report | Monday 9am | Weekly cost summary to Slack |
| Knowledge Sync | Daily 6am | Health check, reindex, briefing, daily costs |
| Webhook Health Check | Every 30 min | Test all 6 webhook endpoints, alert on failure |

All scheduled workflows post to Slack via `$env.SLACK_WEBHOOK_URL`. If not set, the Slack step fails silently (onError: continueRegularOutput).

---

## Section 4 — Error Handling

### onError: continueRegularOutput
All HTTP Request nodes use `"onError": "continueRegularOutput"`. This means if AMB returns a non-2xx status (422, 500, 503), the workflow continues with the error response as data rather than crashing.

### Retry Logic (Daniel workflow)
If AMB returns HTTP 503 (service unavailable):
1. Error Check node detects `is_retryable: true`
2. Wait 5s Retry node sleeps for 5 seconds
3. POST Retry Daniel makes a second attempt
4. Transform Response handles whichever response succeeded

### Fallback Behavior (Andrew workflow)
The Andrew workflow fetches from 3 endpoints in parallel:
- `/costs/summary` — always available
- `/pipeline/dashboard` — may 404 (not yet deployed)
- `/clients/health` — may 404 (not yet deployed)

The Merge All Data node gracefully handles missing data and reports which sources were successfully fetched in `data_sources[]`.

---

## Importing All Workflows

### Via CLI
```bash
bash scripts/manage-workflows.sh sync
```

### Via API
```bash
API_KEY="your-n8n-api-key"
BASE="https://n8n-production-13ed.up.railway.app"

for wf in workflows/*.json; do
  ID=$(curl -s -X POST "$BASE/api/v1/workflows" \
    -H "X-N8N-API-KEY: $API_KEY" -H "Content-Type: application/json" \
    -d @"$wf" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))")
  curl -s -X POST "$BASE/api/v1/workflows/$ID/activate" -H "X-N8N-API-KEY: $API_KEY" > /dev/null
  echo "Imported + activated: $ID"
done
```
