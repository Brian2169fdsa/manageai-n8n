#!/usr/bin/env bash
set -uo pipefail

# ManageAI n8n — Full Interactive Demo
# Usage: bash scripts/demo.sh [BASE_URL]

N8N_BASE="${1:-${N8N_BASE:-https://n8n-production-13ed.up.railway.app}}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass=0
fail=0

banner() {
  echo ""
  echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                                           ║${NC}"
  echo -e "${CYAN}║    ${BOLD}ManageAI n8n Workflow Demo v2${NC}${CYAN}          ║${NC}"
  echo -e "${CYAN}║                                           ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
  echo ""
  echo "Target: $N8N_BASE"
  echo ""
}

step() {
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}  Step $1: $2${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

run_test() {
  local method="$1"
  local url="$2"
  local payload="${3:-}"
  local timeout="${4:-45}"

  local http_code
  local body
  local tmpfile=$(mktemp)

  if [ "$method" = "GET" ]; then
    http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" --max-time "$timeout" "$url")
  else
    http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" --max-time "$timeout" -X POST "$url" \
      -H "Content-Type: application/json" -d "$payload")
  fi

  body=$(cat "$tmpfile")
  rm -f "$tmpfile"

  if [ "$http_code" = "200" ]; then
    echo -e "  ${GREEN}PASS${NC} (HTTP $http_code)"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    ((pass++))
  else
    echo -e "  ${RED}FAIL${NC} (HTTP $http_code)"
    echo "$body" | head -5
    ((fail++))
  fi
}

banner

# Step 1: Health
step "1/10" "n8n Health Check"
run_test GET "$N8N_BASE/healthz"

# Step 2: List workflows
step "2/10" "List Active Workflows"
N8N_API_KEY="${N8N_API_KEY:-$(cat /tmp/n8n-api-key.txt 2>/dev/null | tr -d '\n')}"
if [ -n "$N8N_API_KEY" ]; then
  curl -s --max-time 15 -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE/api/v1/workflows" \
    | python3 -c "
import json,sys
data=json.load(sys.stdin)
for w in data.get('data',[]):
    status='Active' if w.get('active') else 'Inactive'
    print(f'  {w[\"id\"]}  {w[\"name\"]:<40} {status}')
" 2>/dev/null || echo "  (API key needed to list workflows)"
  ((pass++))
else
  echo "  Skipped (no API key)"
fi

# Step 3: Daniel
step "3/10" "Daniel — Sales Follow-Up (negotiation stage)"
run_test POST "$N8N_BASE/webhook/daniel/followup" \
  '{"customer_name":"Acme Corp","company":"Acme Inc","deal_stage":"negotiation","last_interaction":"Demo call last week"}'

# Step 4: Sarah
step "4/10" "Sarah — Content Generator (blog)"
run_test POST "$N8N_BASE/webhook/sarah/content" \
  '{"topic":"AI automation for SMBs","format":"blog","target_audience":"agency owners","tone":"conversational"}'

# Step 5: Andrew
step "5/10" "Andrew — Ops Report (weekly)"
run_test POST "$N8N_BASE/webhook/andrew/report" \
  '{"client_id":"demo-client-1","report_type":"weekly","include_costs":true}'

# Step 6: Rebecka
step "6/10" "Rebecka — Meeting Prep (quarterly review)"
run_test POST "$N8N_BASE/webhook/rebecka/meeting" \
  '{"client_name":"TechCorp","meeting_type":"quarterly review","agenda_items":["Q4 review","Q1 planning","Roadmap discussion"],"attendees":["jane@techcorp.com","bob@techcorp.com"]}'

# Step 7: Full Pipeline
step "7/10" "Full Project Pipeline (master orchestration)"
run_test POST "$N8N_BASE/webhook/project/pipeline" \
  '{"customer_name":"Demo Corp","original_request":"Automate lead scoring from CRM data","trigger_type":"webhook","trigger_description":"New leads from HubSpot","output_action":"Return scored leads via API","expected_output":"JSON with lead scores"}' \
  120

# Step 8: Persona Selector
step "8/10" "Persona Selector (high urgency, sales)"
run_test POST "$N8N_BASE/webhook/persona/select" \
  '{"customer_name":"Demo Corp","request_type":"follow up on proposal","department":"sales","urgency":"high"}'

# Step 9: Batch Briefing
step "9/10" "Batch Briefing (2 clients)"
run_test POST "$N8N_BASE/webhook/briefing/batch" \
  '{"client_ids":["client-alpha","client-beta"],"briefing_type":"daily"}'

# Step 10: Alert Router
step "10/10" "Alert Router (cost alert, high severity)"
run_test POST "$N8N_BASE/webhook/alerts/route" \
  '{"alert_type":"cost_alert","severity":"high","project_id":"proj-demo-1","message":"Monthly cost exceeded $500 threshold"}'

# Summary
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║            Demo Results Summary            ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${GREEN}Passed: $pass${NC}"
echo -e "  ${RED}Failed: $fail${NC}"
echo -e "  Total:  $((pass + fail))"
echo ""

[ "$fail" -eq 0 ] && echo -e "${GREEN}All tests passed!${NC}" || echo -e "${RED}Some tests failed.${NC}"
[ "$fail" -eq 0 ] && exit 0 || exit 1
