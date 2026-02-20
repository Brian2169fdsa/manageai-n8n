#!/usr/bin/env bash
set -euo pipefail

# ManageAI n8n Workflow Manager CLI v2
# Usage: bash scripts/manage-workflows.sh <command> [options]

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
N8N_API_KEY="${N8N_API_KEY:-}"
TIMEOUT=30
JSON_OUTPUT=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  echo "ManageAI n8n Workflow Manager v2"
  echo ""
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Commands:"
  echo "  list                 List all workflows"
  echo "  status               Show all workflows with execution stats"
  echo "  import <file>        Import a workflow JSON file"
  echo "  activate <id>        Activate a workflow"
  echo "  deactivate <id>      Deactivate a workflow"
  echo "  delete <id>          Delete a workflow"
  echo "  test <webhook-path>  Test a webhook endpoint"
  echo "  sync                 Import all workflows from workflows/ directory"
  echo "  logs <workflow-id>   Show last 5 executions"
  echo "  export <workflow-id> Export workflow to workflows/exported-<id>.json"
  echo "  health               Run health check on all webhooks"
  echo "  demo                 Run full demo with sample payloads"
  echo ""
  echo "Options:"
  echo "  --json               Output in JSON format (for list, status)"
  echo "  --timeout <secs>     Request timeout in seconds (default: 30)"
  echo ""
  echo "Environment:"
  echo "  N8N_BASE      n8n instance URL (default: https://n8n-production-13ed.up.railway.app)"
  echo "  N8N_API_KEY   n8n API key"
  exit 1
}

check_api_key() {
  if [ -z "$N8N_API_KEY" ]; then
    if [ -f /tmp/n8n-api-key.txt ]; then
      N8N_API_KEY=$(cat /tmp/n8n-api-key.txt | tr -d '\n')
    else
      echo -e "${RED}Error: N8N_API_KEY not set and /tmp/n8n-api-key.txt not found${NC}"
      exit 1
    fi
  fi
}

api_get() {
  curl -s --max-time "$TIMEOUT" -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE$1"
}

api_post() {
  curl -s --max-time "$TIMEOUT" -H "X-N8N-API-KEY: $N8N_API_KEY" -H "Content-Type: application/json" -X POST "$N8N_BASE$1" ${2:+-d "$2"}
}

api_delete() {
  curl -s --max-time "$TIMEOUT" -H "X-N8N-API-KEY: $N8N_API_KEY" -X DELETE "$N8N_BASE$1"
}

cmd_list() {
  check_api_key
  local result
  result=$(api_get "/api/v1/workflows")

  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
    return
  fi

  echo -e "${CYAN}ManageAI n8n Workflows${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-18s %-35s %-8s\n" "ID" "Name" "Active"
  echo "──────────────────────────────────────────────────────────────────"
  echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('data', []):
    active = '${GREEN}Yes${NC}' if w.get('active') else '${RED}No${NC}'
    print(f\"{w['id']:<18} {w['name']:<35} {active}\")
" 2>/dev/null || echo "Failed to parse response"
}

cmd_status() {
  check_api_key
  local result
  result=$(api_get "/api/v1/workflows")

  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
out = []
for w in data.get('data', []):
    out.append({'id': w['id'], 'name': w['name'], 'active': w.get('active', False)})
print(json.dumps(out, indent=2))
" 2>/dev/null || echo "$result"
    return
  fi

  echo -e "${CYAN}ManageAI n8n Workflow Status${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-18s %-32s %-8s %-12s\n" "ID" "Name" "Active" "Updated"
  echo "──────────────────────────────────────────────────────────────────────────"
  echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('data', []):
    active = 'Yes' if w.get('active') else 'No'
    updated = w.get('updatedAt', 'N/A')[:10]
    print(f\"{w['id']:<18} {w['name'][:31]:<32} {active:<8} {updated}\")
" 2>/dev/null || echo "Failed to parse response"
}

cmd_import() {
  check_api_key
  local file="$1"
  if [ ! -f "$file" ]; then
    echo -e "${RED}Error: File not found: $file${NC}"
    exit 1
  fi
  local result
  result=$(curl -s --max-time "$TIMEOUT" -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H "Content-Type: application/json" -X POST "$N8N_BASE/api/v1/workflows" -d @"$file")
  local wf_id
  wf_id=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
  echo -e "${GREEN}Imported:${NC} $wf_id from $file"
  echo "$wf_id"
}

cmd_activate() {
  check_api_key
  local id="$1"
  api_post "/api/v1/workflows/$id/activate" > /dev/null
  echo -e "${GREEN}Activated:${NC} $id"
}

cmd_deactivate() {
  check_api_key
  local id="$1"
  api_post "/api/v1/workflows/$id/deactivate" > /dev/null
  echo -e "${YELLOW}Deactivated:${NC} $id"
}

cmd_delete() {
  check_api_key
  local id="$1"
  api_delete "/api/v1/workflows/$id" > /dev/null
  echo -e "${RED}Deleted:${NC} $id"
}

cmd_test() {
  check_api_key
  local path="$1"
  local payload="${2:-{}}"
  local start_time=$(date +%s%N 2>/dev/null || date +%s)
  local result
  result=$(curl -s --max-time "$TIMEOUT" -w "\n%{http_code}" -X POST "$N8N_BASE/webhook/$path" \
    -H "Content-Type: application/json" -d "$payload")
  local http_code
  http_code=$(echo "$result" | tail -1)
  local body
  body=$(echo "$result" | head -n -1)

  if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}PASS${NC} — $path (HTTP $http_code)"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
  else
    echo -e "${RED}FAIL${NC} — $path (HTTP $http_code)"
    echo "$body"
  fi
}

cmd_sync() {
  check_api_key
  local wf_dir="${2:-workflows}"
  echo -e "${CYAN}Syncing workflows from $wf_dir/${NC}"

  for file in "$wf_dir"/*.json; do
    [ -f "$file" ] || continue
    local name
    name=$(python3 -c "import json; print(json.load(open('$file')).get('name','?'))" 2>/dev/null)
    echo -n "  $name... "

    # Delete existing by name match
    local existing
    existing=$(api_get "/api/v1/workflows" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data.get('data', []):
    if w['name'] == '$name':
        print(w['id'])
" 2>/dev/null)
    for old_id in $existing; do
      api_delete "/api/v1/workflows/$old_id" > /dev/null
    done

    local new_id
    new_id=$(curl -s --max-time "$TIMEOUT" -H "X-N8N-API-KEY: $N8N_API_KEY" \
      -H "Content-Type: application/json" -X POST "$N8N_BASE/api/v1/workflows" -d @"$file" \
      | python3 -c "import json,sys; print(json.load(sys.stdin).get('id','?'))" 2>/dev/null)
    api_post "/api/v1/workflows/$new_id/activate" > /dev/null
    echo -e "${GREEN}$new_id${NC}"
  done
  echo -e "${GREEN}Sync complete${NC}"
}

cmd_logs() {
  check_api_key
  local wf_id="$1"
  local result
  result=$(api_get "/api/v1/executions?workflowId=$wf_id&limit=5")

  echo -e "${CYAN}Last 5 Executions for $wf_id${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
execs = data.get('data', [])
if not execs:
    print('  No executions found')
else:
    for e in execs[:5]:
        status = e.get('status', 'unknown')
        started = e.get('startedAt', 'N/A')[:19]
        eid = e.get('id', '?')
        print(f'  {eid}  {status:<12} {started}')
" 2>/dev/null || echo "Failed to parse response"
}

cmd_export() {
  check_api_key
  local wf_id="$1"
  local outfile="workflows/exported-${wf_id}.json"
  local result
  result=$(api_get "/api/v1/workflows/$wf_id")
  echo "$result" | python3 -m json.tool > "$outfile" 2>/dev/null
  echo -e "${GREEN}Exported:${NC} $outfile"
}

cmd_health() {
  echo -e "${CYAN}Running Webhook Health Checks${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local endpoints=(
    "daniel/followup|{\"customer_name\":\"HealthCheck\",\"deal_stage\":\"discovery\"}"
    "sarah/content|{\"topic\":\"Health check\",\"format\":\"blog\"}"
    "andrew/report|{\"client_id\":\"health-check\",\"report_type\":\"weekly\"}"
    "rebecka/meeting|{\"client_name\":\"HealthCheck\",\"meeting_type\":\"test\"}"
    "project/pipeline|{\"customer_name\":\"HealthCheck\",\"original_request\":\"test\",\"trigger_type\":\"webhook\",\"output_action\":\"test\"}"
    "persona/select|{\"customer_name\":\"HealthCheck\",\"department\":\"ops\",\"urgency\":\"low\"}"
  )

  local pass=0
  local fail=0
  for ep in "${endpoints[@]}"; do
    IFS='|' read -r path payload <<< "$ep"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 45 -X POST "$N8N_BASE/webhook/$path" \
      -H "Content-Type: application/json" -d "$payload")
    if [ "$code" = "200" ]; then
      echo -e "  ${GREEN}PASS${NC}  $path (HTTP $code)"
      ((pass++))
    else
      echo -e "  ${RED}FAIL${NC}  $path (HTTP $code)"
      ((fail++))
    fi
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "Results: ${GREEN}$pass passed${NC}, ${RED}$fail failed${NC}"
}

cmd_demo() {
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   ManageAI n8n Workflow Demo v2      ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
  echo ""

  # Health check
  echo -e "${YELLOW}[1/7] Health Check${NC}"
  local hcode
  hcode=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$N8N_BASE/healthz")
  [ "$hcode" = "200" ] && echo -e "  ${GREEN}PASS${NC} — n8n is healthy" || echo -e "  ${RED}FAIL${NC} — HTTP $hcode"
  echo ""

  # Daniel
  echo -e "${YELLOW}[2/7] Daniel — Sales Follow-Up${NC}"
  curl -s --max-time 45 -X POST "$N8N_BASE/webhook/daniel/followup" \
    -H "Content-Type: application/json" \
    -d '{"customer_name":"Demo Corp","company":"Acme Inc","deal_stage":"negotiation"}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  # Sarah
  echo -e "${YELLOW}[3/7] Sarah — Content Generator${NC}"
  curl -s --max-time 45 -X POST "$N8N_BASE/webhook/sarah/content" \
    -H "Content-Type: application/json" \
    -d '{"topic":"AI automation for SMBs","format":"email","target_audience":"agency owners","tone":"conversational"}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  # Andrew
  echo -e "${YELLOW}[4/7] Andrew — Ops Report${NC}"
  curl -s --max-time 45 -X POST "$N8N_BASE/webhook/andrew/report" \
    -H "Content-Type: application/json" \
    -d '{"client_id":"demo-client-1","report_type":"weekly"}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  # Rebecka
  echo -e "${YELLOW}[5/7] Rebecka — Meeting Prep${NC}"
  curl -s --max-time 45 -X POST "$N8N_BASE/webhook/rebecka/meeting" \
    -H "Content-Type: application/json" \
    -d '{"client_name":"TechCorp","meeting_type":"quarterly review","agenda_items":["Q4 review","Q1 planning"],"attendees":["jane@techcorp.com"]}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  # Pipeline
  echo -e "${YELLOW}[6/7] Full Project Pipeline${NC}"
  curl -s --max-time 120 -X POST "$N8N_BASE/webhook/project/pipeline" \
    -H "Content-Type: application/json" \
    -d '{"customer_name":"Demo Corp","original_request":"Automate lead scoring from CRM","trigger_type":"webhook","output_action":"Return scored leads via API"}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  # Persona Selector
  echo -e "${YELLOW}[7/7] Persona Selector${NC}"
  curl -s --max-time 45 -X POST "$N8N_BASE/webhook/persona/select" \
    -H "Content-Type: application/json" \
    -d '{"customer_name":"Demo Corp","request_type":"follow up","department":"sales","urgency":"high"}' \
    | python3 -m json.tool 2>/dev/null
  echo ""

  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}Demo complete!${NC}"
}

# Parse global options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=true; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) break ;;
  esac
done

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
  list)       cmd_list ;;
  status)     cmd_status ;;
  import)     cmd_import "$1" ;;
  activate)   cmd_activate "$1" ;;
  deactivate) cmd_deactivate "$1" ;;
  delete)     cmd_delete "$1" ;;
  test)       cmd_test "$1" "${2:-{}}" ;;
  sync)       cmd_sync "$@" ;;
  logs)       cmd_logs "$1" ;;
  export)     cmd_export "$1" ;;
  health)     cmd_health ;;
  demo)       cmd_demo ;;
  *)          usage ;;
esac
