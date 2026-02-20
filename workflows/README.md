# ManageAI n8n Workflow Library v3

34 production workflows for ManageAI: 4 personas, 5 Make.com bridge, 3 webhook registry, 4 error replay, 3 analytics, 2 multi-tenant, 3 advanced persona, 4 orchestration, 2 monitors, 2 scheduled reports, 2 legacy.

## Architecture

```
                    ┌─────────────────────────────┐
                    │      Webhook Ingress         │
                    │  /webhook/{path}             │
                    └──────────┬──────────────────┘
                               │
          ┌────────────────────┼─────────────────────┐
          │                    │                      │
    ┌─────▼─────┐     ┌──────▼──────┐      ┌───────▼───────┐
    │  Tenant    │     │  Persona    │      │  Direct       │
    │  Router    │     │  Selector   │      │  Webhook      │
    └─────┬─────┘     └──────┬──────┘      └───────┬───────┘
          │                  │                      │
          └──────────────────┼──────────────────────┘
                             │
     ┌───────────┬───────────┼───────────┬───────────┐
     │           │           │           │           │
  ┌──▼──┐   ┌──▼──┐   ┌───▼──┐   ┌───▼───┐   ┌──▼──────┐
  │Daniel│   │Sarah│   │Andrew│   │Rebecka│   │Make.com  │
  │Sales │   │Cont.│   │Ops   │   │Meeting│   │Bridge    │
  └──┬───┘   └──┬──┘   └──┬───┘   └──┬────┘   └──┬──────┘
     │          │          │          │            │
     └──────────┴──────────┴──────────┴────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼──────┐ ┌───▼────┐  ┌─────▼──────┐
        │  Analytics  │ │ Error  │  │  Registry  │
        │  Tracking   │ │ Queue  │  │  Storage   │
        └────────────┘ └────────┘  └────────────┘
```

## Workflow Categories

### Core Personas (4 workflows)

| Workflow | Webhook | Input | Output |
|----------|---------|-------|--------|
| Daniel - Sales Follow-Up | POST /webhook/daniel/followup | customer_name, deal_stage | report_markdown, recommended_template, priority |
| Sarah - Content Generator | POST /webhook/sarah/content | topic, format | report_markdown, seo_keywords, reading_time_minutes |
| Andrew - Ops Report | POST /webhook/andrew/report | client_id, report_type | report_markdown, period, generated_at |
| Rebecka - Meeting Prep | POST /webhook/rebecka/meeting | client_name, meeting_type | report_markdown, calendar_block, pre_read, follow_up_email_template |

### Orchestration (4 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Full Project Pipeline | POST /webhook/project/pipeline | 5-step: plan → verify → cost → memory → respond |
| Persona Selector | POST /webhook/persona/select | Routes by department/urgency to correct persona |
| Batch Briefing | POST /webhook/briefing/batch | Briefings for up to 5 clients |
| Alert Router | POST /webhook/alerts/route | Routes alerts by type to persona + Slack |

### Make.com Bridge (5 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Deploy Bridge | POST /webhook/makecom/deploy | Deploy scenario via AMB, advance pipeline |
| Status Checker | POST /webhook/makecom/status | Health scoring 0-100 with recommendations |
| Teardown | POST /webhook/makecom/teardown | Confirmed teardown with memory logging |
| Run Scenario | POST /webhook/makecom/run | Trigger scenario execution |
| Monitor All | POST /webhook/makecom/monitor | Aggregate health across all deployments |

### Webhook Registry (3 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Register | POST /webhook/registry/register | Register a webhook in static data |
| List | GET /webhook/registry/list | List all 29+ webhooks with metadata |
| Test | POST /webhook/registry/test | Test any webhook with default payloads |

### Error Replay System (4 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Capture | POST /webhook/errors/capture | Capture/classify errors, store in static data |
| List | GET /webhook/errors/list | List/filter errors with summary counts |
| Replay | POST /webhook/errors/replay | Replay single or batch failed errors |
| Resolve | POST /webhook/errors/resolve | Resolve with notes |

### Analytics Engine (3 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Usage Tracker | POST /webhook/analytics/usage | Track calls, tokens, errors per workflow/persona |
| Report | GET /webhook/analytics/report | Generate reports with error rates, trends |
| Cost | GET /webhook/analytics/cost | Combine AMB costs with local analytics |

### Multi-Tenant (2 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Tenant Router | POST /webhook/tenant/route | Route by tenant_id + request_type to persona |
| Tenant Config | POST /webhook/tenant/config | Get/list/validate tenant configurations |

Tenants: cornerstone (professional), sunstate (enterprise), demo (demo), default (standard).

### Advanced Persona (3 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Persona Chain | POST /webhook/persona/chain | Chain 1-3 personas sequentially |
| Persona Compare | POST /webhook/persona/compare | Compare 2 persona responses side-by-side |
| Persona Memory Sync | POST /webhook/persona/memory-sync | Sync persona feedback to context + memory |

### Scheduled Monitors (4 workflows)

| Workflow | Schedule | Description |
|----------|----------|-------------|
| Knowledge Sync | Daily 6am | Health check → reindex → briefing → costs → Slack |
| Pipeline Monitor | Hourly | Check stalled projects, AMB health, alert if needed |
| Cost Weekly Report | Monday 9am | Weekly cost report with WoW trend → Slack |
| Webhook Health Check | Every 30min | Test 8 webhook endpoints, alert on failure |

All scheduled workflows track run history in static data.

### Legacy (2 workflows)

| Workflow | Webhook | Description |
|----------|---------|-------------|
| Make Equivalent | POST /webhook/plan | Original AMB bridge from v1 |
| Ping/Pong Test | GET /webhook/ping | Simple health check |

## Error Handling

All HTTP nodes use `onError: "continueRegularOutput"` — errors are captured in the response, not thrown. Webhook workflows use `responseMode: "responseNode"` with `respondWith: "allIncomingItems"` for reliable responses.

## Static Data

Several workflows use `$getWorkflowStaticData('global')` for persistence:
- **Registry**: Webhook registrations
- **Error Queue**: Error entries (capped at 100)
- **Analytics**: Usage counters, token tracking
- **Scheduled workflows**: Run history, check counters, alert history

## Conventions

- Node IDs: `{prefix}-{purpose}` (e.g., `d1-webhook`, `a1-validate`)
- Webhook paths: `{category}/{action}` (e.g., `daniel/followup`, `errors/capture`)
- All persona HTTP calls include `message` field (required by AMB /persona/test)
- HTTP timeouts: 10-45s per call to stay under Railway's proxy limit
- Sequential HTTP chains only — parallel fan-out from Code nodes is unreliable
