#!/usr/bin/env bash
set -euo pipefail

# ManageAI n8n Workflow Manager CLI v3
# Usage: bash scripts/manage-workflows.sh <command> [options]

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
N8N_API_KEY="${N8N_API_KEY:-}"
TIMEOUT=30
JSON_OUTPUT=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
  echo -e "${BOLD}ManageAI n8n Workflow Manager v3${NC}"
  echo ""
  echo "Usage: $0 <command> [options]"
  echo ""
  echo "Workflow Commands:"
  echo "  list                 List all workflows"
  echo "  status               Show all workflows with execution stats"
  echo "  import <file>        Import a workflow JSON file"
  echo "  activate <id>        Activate a workflow"
  echo "  deactivate <id>      Deactivate a workflow"
  echo "  delete <id>          Delete a workflow"
  echo "  sync                 Import all workflows from workflows/ directory"
  echo "  logs <workflow-id>   Show last 5 executions"
  echo "  export <workflow-id> Export workflow to workflows/exported-<id>.json"
  echo ""
  echo "Testing Commands:"
  echo "  test <webhook-path>  Test a webhook endpoint"
  echo "  health               Run health check on all webhooks"
  echo "  demo                 Run full demo with sample payloads"
  echo ""
  echo "v3 Commands:"
  echo "  registry             List all registered webhooks"
  echo "  errors [status]      List errors (optionally filter by open/resolved)"
  echo "  analytics            Show workflow analytics report"
  echo "  tenants              List all tenant configurations"
  echo "  route <tenant> <type> Route a request via tenant router"
  echo "  chain <p1,p2> <msg>  Chain personas sequentially"
  echo "  compare <message>    Compare all 4 persona responses"
  echo ""
  echo "Options:"
  echo "  --json               Output in JSON format"
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

webhook_post() {
  curl -s --max-time "$TIMEOUT" -X POST "$N8N_BASE/webhook/$1" \
    -H "Content-Type: application/json" -d "$2"
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
  printf "%-18s %-40s %-8s\n" "ID" "Name" "Active"
  echo "──────────────────────────────────────────────────────────────────"
  echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
wfs = data.get('data', [])
for w in sorted(wfs, key=lambda x: x['name']):
    active = 'Yes' if w.get('active') else 'No'
    print(f\"{w['id']:<18} {w['name'][:39]:<40} {active}\")
print(f'\nTotal: {len(wfs)} workflows')
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
  printf "%-18s %-35s %-8s %-12s\n" "ID" "Name" "Active" "Updated"
  echo "──────────────────────────────────────────────────────────────────────────"
  echo "$result" | python3 -c "
import json, sys
data = json.load(sys.stdin)
wfs = data.get('data', [])
for w in sorted(wfs, key=lambda x: x['name']):
    active = 'Yes' if w.get('active') else 'No'
    updated = w.get('updatedAt', 'N/A')[:10]
    print(f\"{w['id']:<18} {w['name'][:34]:<35} {active:<8} {updated}\")
print(f'\nTotal: {len(wfs)} workflows')
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
  local path="$1"
  local payload="${2:-{}}"
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
  local wf_dir="${1:-workflows}"
  echo -e "${CYAN}Syncing workflows from $wf_dir/${NC}"
  echo ""
  local imported=0
  local failed=0

  for file in "$wf_dir"/*.json; do
    [ -f "$file" ] || continue
    local name
    name=$(python3 -c "import json; print(json.load(open('$file')).get('name','?'))" 2>/dev/null)
    echo -n "  $name... "

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

    if [ "$new_id" != "?" ] && [ -n "$new_id" ]; then
      api_post "/api/v1/workflows/$new_id/activate" > /dev/null
      echo -e "${GREEN}$new_id${NC}"
      ((imported++))
    else
      echo -e "${RED}FAILED${NC}"
      ((failed++))
    fi
  done

  echo ""
  echo -e "${GREEN}Sync complete:${NC} $imported imported, $failed failed"
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
  echo -e "${CYAN}Running Webhook Health Checks (v3 — 25 endpoints)${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local endpoints=(
    "daniel/followup|{\"customer_name\":\"HealthCheck\",\"deal_stage\":\"discovery\"}"
    "sarah/content|{\"topic\":\"Health check\",\"format\":\"blog\"}"
    "andrew/report|{\"client_id\":\"health-check\",\"report_type\":\"weekly\"}"
    "rebecka/meeting|{\"client_name\":\"HealthCheck\",\"meeting_type\":\"test\"}"
    "project/pipeline|{\"customer_name\":\"HealthCheck\",\"original_request\":\"test\",\"trigger_type\":\"webhook\",\"output_action\":\"test\"}"
    "persona/select|{\"customer_name\":\"HealthCheck\",\"department\":\"ops\",\"urgency\":\"low\"}"
    "makecom/deploy|{\"project_id\":\"health\",\"scenario_name\":\"test\",\"modules\":[\"http\"]}"
    "makecom/status|{\"scenario_id\":\"health-check\"}"
    "makecom/teardown|{\"scenario_id\":\"health-check\",\"confirm\":false}"
    "makecom/run|{\"scenario_id\":\"health-check\"}"
    "makecom/monitor|{}"
    "registry/register|{\"path\":\"test/health\",\"name\":\"Health Test\",\"method\":\"POST\"}"
    "registry/test|{\"webhook_path\":\"daniel/followup\"}"
    "errors/capture|{\"workflow_name\":\"HealthCheck\",\"error_message\":\"test\",\"severity\":\"low\"}"
    "errors/resolve|{\"error_id\":\"health-check-test\"}"
    "analytics/usage|{\"workflow_name\":\"HealthCheck\",\"persona\":\"system\",\"tokens_used\":0}"
    "tenant/route|{\"tenant_id\":\"demo\",\"request_type\":\"test\",\"payload\":{\"customer_name\":\"HealthCheck\"}}"
    "tenant/config|{\"tenant_id\":\"demo\",\"action\":\"get\"}"
    "persona/chain|{\"chain\":[\"daniel\"],\"initial_payload\":{\"customer_name\":\"HealthCheck\",\"deal_stage\":\"test\"}}"
    "persona/compare|{\"message\":\"Health check test\"}"
    "persona/memory-sync|{\"persona\":\"daniel\",\"client_id\":\"health\",\"interaction_summary\":\"test\"}"
    "briefing/batch|{\"client_ids\":[\"health\"],\"briefing_type\":\"daily\"}"
    "alerts/route|{\"alert_type\":\"test\",\"severity\":\"low\",\"project_id\":\"health\",\"message\":\"test\"}"
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
  echo -e "Results: ${GREEN}$pass passed${NC}, ${RED}$fail failed${NC} out of ${#endpoints[@]}"
}

cmd_registry() {
  echo -e "${CYAN}Webhook Registry${NC}"
  local result
  result=$(curl -s --max-time "$TIMEOUT" "$N8N_BASE/webhook/registry/list")
  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  else
    echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
webhooks=data.get('webhooks',[])
print(f'Total: {len(webhooks)} webhooks')
print()
for w in webhooks:
    print(f'  {w[\"method\"]:>4} /webhook/{w[\"path\"]:<35} {w[\"name\"]}')
" 2>/dev/null || echo "$result"
  fi
}

cmd_errors() {
  local status_filter="${1:-}"
  echo -e "${CYAN}Error Queue${NC}"
  local url="$N8N_BASE/webhook/errors/list"
  if [ -n "$status_filter" ]; then
    url="$url?status=$status_filter"
  fi
  local result
  result=$(curl -s --max-time "$TIMEOUT" "$url")
  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  else
    echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
errors=data.get('errors',[])
summary=data.get('summary',{})
print(f'Total: {summary.get(\"total\",len(errors))} | Open: {summary.get(\"open\",\"?\")} | Resolved: {summary.get(\"resolved\",\"?\")}')
print()
for e in errors[:20]:
    print(f'  [{e.get(\"severity\",\"?\"):>8}] {e.get(\"error_id\",\"?\"):<20} {e.get(\"workflow_name\",\"?\"):<25} {e.get(\"status\",\"?\")}')
" 2>/dev/null || echo "$result"
  fi
}

cmd_analytics() {
  echo -e "${CYAN}Workflow Analytics Report${NC}"
  local result
  result=$(curl -s --max-time "$TIMEOUT" "$N8N_BASE/webhook/analytics/report")
  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  else
    echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
print(f'Total Calls: {data.get(\"total_calls\",0)}')
print(f'Total Errors: {data.get(\"total_errors\",0)}')
print(f'Error Rate: {data.get(\"error_rate\",\"N/A\")}')
print(f'Total Tokens: {data.get(\"total_tokens\",0)}')
print(f'Most Used: {data.get(\"most_used_workflow\",\"N/A\")}')
print(f'Most Active Persona: {data.get(\"most_active_persona\",\"N/A\")}')
" 2>/dev/null || echo "$result"
  fi
}

cmd_tenants() {
  echo -e "${CYAN}Tenant Configurations${NC}"
  local result
  result=$(webhook_post "tenant/config" '{"tenant_id":"any","action":"list"}')
  if [ "$JSON_OUTPUT" = true ]; then
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  else
    echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
tenants=data.get('tenants',[])
print(f'Total: {data.get(\"total\",len(tenants))} tenants')
print()
for t in tenants:
    print(f'  {t[\"tenant_id\"]:<15} tier={t[\"tier\"]:<14} default={t[\"default_persona\"]}')
" 2>/dev/null || echo "$result"
  fi
}

cmd_route() {
  local tenant="$1"
  local req_type="$2"
  local payload="${3:-{}}"
  echo -e "${CYAN}Routing: $tenant / $req_type${NC}"
  local result
  result=$(webhook_post "tenant/route" "{\"tenant_id\":\"$tenant\",\"request_type\":\"$req_type\",\"payload\":$payload}")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_chain() {
  local personas="$1"
  local message="$2"
  IFS=',' read -ra persona_arr <<< "$personas"
  local chain_json
  chain_json=$(python3 -c "import json; print(json.dumps('$personas'.split(',')))" 2>/dev/null)
  echo -e "${CYAN}Chaining: $personas${NC}"
  local result
  result=$(webhook_post "persona/chain" "{\"chain\":$chain_json,\"initial_payload\":{\"customer_name\":\"CLI\",\"topic\":\"$message\",\"client_id\":\"cli\",\"client_name\":\"CLI\"}}")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_compare() {
  local message="$1"
  echo -e "${CYAN}Comparing all personas for: $message${NC}"
  local result
  result=$(webhook_post "persona/compare" "{\"message\":\"$message\"}")
  echo "$result" | python3 -c "
import json,sys
data=json.load(sys.stdin)
comp=data.get('comparison',{})
print(f'Most Detailed: {comp.get(\"most_detailed\",\"?\")}'  )
print(f'Shortest: {comp.get(\"shortest\",\"?\")}')
print()
for p in ['daniel','sarah','andrew','rebecka']:
    wc=comp.get('word_counts',{}).get(p,0)
    rl=comp.get('response_lengths',{}).get(p,0)
    print(f'  {p:<10} {wc:>5} words  ({rl} chars)')
" 2>/dev/null || echo "$result"
}

cmd_demo() {
  echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║   ManageAI n8n Workflow Demo v3      ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
  echo ""
  echo "Run: bash scripts/demo.sh"
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
  registry)   cmd_registry ;;
  errors)     cmd_errors "${1:-}" ;;
  analytics)  cmd_analytics ;;
  tenants)    cmd_tenants ;;
  route)      cmd_route "$1" "$2" "${3:-{}}" ;;
  chain)      cmd_chain "$1" "$2" ;;
  compare)    cmd_compare "$1" ;;
  *)          usage ;;
esac
