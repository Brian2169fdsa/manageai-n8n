#!/usr/bin/env bash
set -uo pipefail

# ManageAI n8n — Test All Webhooks
# Runs all 6 webhook workflow tests in parallel

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
TIMEOUT=45
TMPDIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}ManageAI n8n — Webhook Test Suite${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Target: $N8N_BASE"
echo ""

test_webhook() {
  local name="$1"
  local path="$2"
  local payload="$3"
  local expected_fields="$4"
  local outfile="$TMPDIR/$name.json"
  local statusfile="$TMPDIR/$name.status"

  local http_code
  http_code=$(curl -s -o "$outfile" -w "%{http_code}" --max-time "$TIMEOUT" \
    -X POST "$N8N_BASE/webhook/$path" \
    -H "Content-Type: application/json" \
    -d "$payload")

  local status="FAIL"
  local missing=""

  if [ "$http_code" = "200" ]; then
    # Check expected fields
    local all_found=true
    for field in $expected_fields; do
      if ! python3 -c "import json; d=json.load(open('$outfile')); items=d if isinstance(d,list) else [d]; assert any('$field' in item for item in items)" 2>/dev/null; then
        all_found=false
        missing="$missing $field"
      fi
    done
    [ "$all_found" = true ] && status="PASS"
  fi

  echo "$status|$http_code|$missing" > "$statusfile"
}

# Launch all 6 tests in parallel
test_webhook "daniel" "daniel/followup" \
  '{"customer_name":"TestBot","company":"Acme","deal_stage":"negotiation","last_interaction":"Demo call"}' \
  "follow_up_message next_action deal_stage recommended_template crm_update_needed priority" &

test_webhook "sarah" "sarah/content" \
  '{"topic":"AI automation for testing","format":"blog","target_audience":"developers","tone":"technical"}' \
  "content format word_count seo_keywords reading_time_minutes format_metadata" &

test_webhook "andrew" "andrew/report" \
  '{"client_id":"test-client","report_type":"weekly","include_costs":true}' \
  "report_markdown total_cost period pipeline_summary health_status data_sources" &

test_webhook "rebecka" "rebecka/meeting" \
  '{"client_name":"TestCorp","meeting_type":"quarterly review","agenda_items":["Review","Planning"],"attendees":["a@b.com"]}' \
  "meeting_brief agenda_formatted calendar_block pre_read follow_up_email_template" &

test_webhook "pipeline" "project/pipeline" \
  '{"customer_name":"TestCorp","original_request":"Automate testing","trigger_type":"webhook","output_action":"Return results"}' \
  "project_id plan verification cost_estimate pipeline_status" &

test_webhook "selector" "persona/select" \
  '{"customer_name":"TestCorp","request_type":"content creation","department":"marketing","urgency":"medium"}' \
  "selected_persona persona_reason response" &

# Wait for all
wait

# Collect and print results
echo ""
printf "%-20s %-8s %-12s %s\n" "Workflow" "Status" "HTTP Code" "Missing Fields"
echo "──────────────────────────────────────────────────────────────────"

pass_count=0
fail_count=0

for name in daniel sarah andrew rebecka pipeline selector; do
  if [ -f "$TMPDIR/$name.status" ]; then
    IFS='|' read -r status http_code missing < "$TMPDIR/$name.status"
    if [ "$status" = "PASS" ]; then
      printf "%-20s ${GREEN}%-8s${NC} %-12s\n" "$name" "$status" "$http_code"
      ((pass_count++))
    else
      printf "%-20s ${RED}%-8s${NC} %-12s %s\n" "$name" "$status" "$http_code" "$missing"
      ((fail_count++))
    fi
  else
    printf "%-20s ${RED}%-8s${NC} %-12s\n" "$name" "TIMEOUT" "---"
    ((fail_count++))
  fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Results: ${GREEN}$pass_count passed${NC}, ${RED}$fail_count failed${NC} out of 6"

# Cleanup
rm -rf "$TMPDIR"

[ "$fail_count" -eq 0 ] && exit 0 || exit 1
