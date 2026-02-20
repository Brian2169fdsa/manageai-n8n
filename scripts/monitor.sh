#!/usr/bin/env bash
set -uo pipefail

# ManageAI n8n — Live Monitor Dashboard
# Usage: bash scripts/monitor.sh [--once] [--interval 60]

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
N8N_API_KEY="${N8N_API_KEY:-$(cat /tmp/n8n-api-key.txt 2>/dev/null | tr -d '\n')}"
AMB_BASE="https://agenticmakebuilder-production.up.railway.app"

ONCE=false
INTERVAL=60

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) ONCE=true; shift ;;
    --interval) INTERVAL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

check_endpoint() {
  local url="$1"
  local method="${2:-GET}"
  local payload="${3:-}"
  local start_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)

  local code
  if [ "$method" = "GET" ]; then
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url")
  else
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 -X POST "$url" \
      -H "Content-Type: application/json" -d "$payload")
  fi

  local end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  local duration=$((end_ms - start_ms))

  if [ "$code" = "200" ]; then
    echo -e "  ${GREEN}UP${NC}   ${duration}ms  $url"
  else
    echo -e "  ${RED}DOWN${NC} ${duration}ms  $url (HTTP $code)"
  fi
}

render_dashboard() {
  clear
  echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}${BOLD}║          ManageAI n8n — Live Monitor v3                ║${NC}"
  echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
  echo -e "${DIM}  $(date '+%Y-%m-%d %H:%M:%S')  |  Refresh: ${INTERVAL}s  |  Ctrl+C to exit${NC}"
  echo ""

  # Section 1: Infrastructure
  echo -e "${YELLOW}Infrastructure${NC}"
  echo "──────────────────────────────────────────────────"
  check_endpoint "$N8N_BASE/healthz"
  check_endpoint "$AMB_BASE/health"
  echo ""

  # Section 2: Workflow Count
  echo -e "${YELLOW}Workflows${NC}"
  echo "──────────────────────────────────────────────────"
  if [ -n "$N8N_API_KEY" ]; then
    local wf_result
    wf_result=$(curl -s --max-time 10 -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE/api/v1/workflows" 2>/dev/null)
    python3 -c "
import json,sys
data=json.loads('''$wf_result''')
wfs=data.get('data',[])
active=sum(1 for w in wfs if w.get('active'))
print(f'  Total: {len(wfs)} | Active: {active} | Inactive: {len(wfs)-active}')
" 2>/dev/null || echo "  (parse error)"
  else
    echo "  (no API key — set N8N_API_KEY)"
  fi
  echo ""

  # Section 3: Core Persona Webhooks
  echo -e "${YELLOW}Persona Webhooks${NC}"
  echo "──────────────────────────────────────────────────"
  check_endpoint "$N8N_BASE/webhook/daniel/followup" POST '{"customer_name":"Monitor","deal_stage":"test","health_check":true}'
  check_endpoint "$N8N_BASE/webhook/sarah/content" POST '{"topic":"Monitor test","format":"blog","health_check":true}'
  check_endpoint "$N8N_BASE/webhook/andrew/report" POST '{"client_id":"monitor","report_type":"weekly","health_check":true}'
  check_endpoint "$N8N_BASE/webhook/rebecka/meeting" POST '{"client_name":"Monitor","meeting_type":"test","health_check":true}'
  echo ""

  # Section 4: Orchestration Webhooks
  echo -e "${YELLOW}Orchestration${NC}"
  echo "──────────────────────────────────────────────────"
  check_endpoint "$N8N_BASE/webhook/project/pipeline" POST '{"customer_name":"Monitor","original_request":"test","trigger_type":"webhook","output_action":"test","health_check":true}'
  check_endpoint "$N8N_BASE/webhook/persona/select" POST '{"customer_name":"Monitor","department":"ops","urgency":"low","health_check":true}'
  check_endpoint "$N8N_BASE/webhook/tenant/route" POST '{"tenant_id":"demo","request_type":"test","payload":{"customer_name":"Monitor"}}'
  echo ""

  # Section 5: Platform Services
  echo -e "${YELLOW}Platform Services${NC}"
  echo "──────────────────────────────────────────────────"
  check_endpoint "$N8N_BASE/webhook/registry/list" GET
  check_endpoint "$N8N_BASE/webhook/tenant/config" POST '{"tenant_id":"demo","action":"get"}'
  check_endpoint "$N8N_BASE/webhook/analytics/report" GET
  echo ""

  echo -e "${DIM}──────────────────────────────────────────────────${NC}"
}

if [ "$ONCE" = true ]; then
  render_dashboard
else
  while true; do
    render_dashboard
    sleep "$INTERVAL"
  done
fi
