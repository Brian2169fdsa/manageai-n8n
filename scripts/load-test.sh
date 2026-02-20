#!/usr/bin/env bash
set -uo pipefail

# ManageAI n8n — Load Test
# Sends 10 concurrent requests to each of 4 persona webhooks (40 total)

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
CONCURRENCY=10
TIMEOUT=60
TMPDIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}ManageAI n8n — Load Test${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Target: $N8N_BASE"
echo "Concurrency: $CONCURRENCY per workflow"
echo "Total requests: $((CONCURRENCY * 4))"
echo ""

declare -A ENDPOINTS
ENDPOINTS["daniel"]='daniel/followup|{"customer_name":"LoadTest-{{i}}","company":"TestCo","deal_stage":"discovery"}'
ENDPOINTS["sarah"]='sarah/content|{"topic":"Load test content {{i}}","format":"blog"}'
ENDPOINTS["andrew"]='andrew/report|{"client_id":"load-test-{{i}}","report_type":"weekly"}'
ENDPOINTS["rebecka"]='rebecka/meeting|{"client_name":"LoadTest-{{i}}","meeting_type":"test"}'

total_start=$(date +%s)

send_request() {
  local name="$1"
  local path="$2"
  local payload="$3"
  local idx="$4"
  local outfile="$TMPDIR/${name}-${idx}.result"

  local start_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
    -X POST "$N8N_BASE/webhook/$path" \
    -H "Content-Type: application/json" \
    -d "$payload")
  local end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  local duration=$((end_ms - start_ms))

  echo "$http_code|$duration" > "$outfile"
}

# Launch all requests
for name in daniel sarah andrew rebecka; do
  IFS='|' read -r path payload_template <<< "${ENDPOINTS[$name]}"
  for i in $(seq 1 $CONCURRENCY); do
    payload="${payload_template//\{\{i\}\}/$i}"
    send_request "$name" "$path" "$payload" "$i" &
  done
done

echo -e "${YELLOW}Waiting for $((CONCURRENCY * 4)) requests to complete...${NC}"
wait
echo ""

total_end=$(date +%s)
total_time=$((total_end - total_start))

# Analyze results
echo -e "${CYAN}Results by Workflow${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-15s %-10s %-10s %-10s %-12s\n" "Workflow" "Success" "Failed" "Avg (ms)" "Total (ms)"
echo "─────────────────────────────────────────────────────"

grand_success=0
grand_fail=0
grand_total_ms=0

for name in daniel sarah andrew rebecka; do
  success=0
  failed=0
  total_ms=0
  count=0

  for i in $(seq 1 $CONCURRENCY); do
    result_file="$TMPDIR/${name}-${i}.result"
    if [ -f "$result_file" ]; then
      IFS='|' read -r code duration < "$result_file"
      total_ms=$((total_ms + duration))
      ((count++))
      if [ "$code" = "200" ]; then
        ((success++))
        ((grand_success++))
      else
        ((failed++))
        ((grand_fail++))
      fi
    else
      ((failed++))
      ((grand_fail++))
    fi
  done

  avg_ms=0
  [ "$count" -gt 0 ] && avg_ms=$((total_ms / count))
  grand_total_ms=$((grand_total_ms + total_ms))

  printf "%-15s ${GREEN}%-10s${NC} ${RED}%-10s${NC} %-10s %-12s\n" "$name" "$success" "$failed" "${avg_ms}ms" "${total_ms}ms"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

total_requests=$((grand_success + grand_fail))
success_rate=0
[ "$total_requests" -gt 0 ] && success_rate=$((grand_success * 100 / total_requests))
rps=0
[ "$total_time" -gt 0 ] && rps=$((total_requests / total_time))

echo ""
echo -e "${CYAN}Summary${NC}"
echo "  Total Requests:  $total_requests"
echo -e "  Successful:      ${GREEN}$grand_success${NC}"
echo -e "  Failed:          ${RED}$grand_fail${NC}"
echo "  Total Time:      ${total_time}s"
echo "  Req/Second:      ~${rps}"
echo "  Success Rate:    ${success_rate}%"

# Cleanup
rm -rf "$TMPDIR"

[ "$success_rate" -ge 90 ] && { echo -e "\n${GREEN}PASS — Success rate >= 90%${NC}"; exit 0; } || { echo -e "\n${RED}FAIL — Success rate < 90%${NC}"; exit 1; }
