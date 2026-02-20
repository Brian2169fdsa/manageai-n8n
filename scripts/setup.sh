#!/usr/bin/env bash
set -euo pipefail

# ManageAI n8n — Initial Setup Script
# Usage: bash scripts/setup.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}${BOLD}ManageAI n8n Platform — Setup v3${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check prerequisites
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

command -v curl >/dev/null 2>&1 || { echo -e "${RED}curl not found${NC}"; exit 1; }
echo -e "  ${GREEN}curl${NC} found"

command -v python3 >/dev/null 2>&1 || { echo -e "${RED}python3 not found${NC}"; exit 1; }
echo -e "  ${GREEN}python3${NC} found"

command -v docker >/dev/null 2>&1 && echo -e "  ${GREEN}docker${NC} found" || echo -e "  ${YELLOW}docker${NC} not found (optional — needed for local dev)"

command -v git >/dev/null 2>&1 || { echo -e "${RED}git not found${NC}"; exit 1; }
echo -e "  ${GREEN}git${NC} found"

echo ""

# Step 2: Check environment
echo -e "${YELLOW}[2/6] Checking environment...${NC}"

N8N_BASE="${N8N_BASE:-https://n8n-production-13ed.up.railway.app}"
echo "  N8N_BASE=$N8N_BASE"

if [ -n "${N8N_API_KEY:-}" ]; then
  echo -e "  N8N_API_KEY=${GREEN}set${NC}"
elif [ -f /tmp/n8n-api-key.txt ]; then
  N8N_API_KEY=$(cat /tmp/n8n-api-key.txt | tr -d '\n')
  echo -e "  N8N_API_KEY=${GREEN}loaded from /tmp/n8n-api-key.txt${NC}"
else
  echo -e "  N8N_API_KEY=${RED}NOT SET${NC}"
  echo ""
  echo "  To set your API key:"
  echo "    export N8N_API_KEY='your-api-key'"
  echo "    # or"
  echo "    echo 'your-api-key' > /tmp/n8n-api-key.txt"
  echo ""
fi

echo ""

# Step 3: Test connectivity
echo -e "${YELLOW}[3/6] Testing connectivity...${NC}"

n8n_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$N8N_BASE/healthz" 2>/dev/null || echo "000")
if [ "$n8n_health" = "200" ]; then
  echo -e "  n8n:  ${GREEN}UP${NC} (HTTP $n8n_health)"
else
  echo -e "  n8n:  ${RED}DOWN${NC} (HTTP $n8n_health)"
fi

AMB_BASE="https://agenticmakebuilder-production.up.railway.app"
amb_health=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$AMB_BASE/health" 2>/dev/null || echo "000")
if [ "$amb_health" = "200" ]; then
  echo -e "  AMB:  ${GREEN}UP${NC} (HTTP $amb_health)"
else
  echo -e "  AMB:  ${RED}DOWN${NC} (HTTP $amb_health)"
fi

echo ""

# Step 4: Validate API access
echo -e "${YELLOW}[4/6] Validating API access...${NC}"

if [ -n "${N8N_API_KEY:-}" ]; then
  wf_count=$(curl -s --max-time 10 -H "X-N8N-API-KEY: $N8N_API_KEY" "$N8N_BASE/api/v1/workflows" 2>/dev/null \
    | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "error")
  if [ "$wf_count" != "error" ]; then
    echo -e "  API access: ${GREEN}OK${NC} ($wf_count workflows found)"
  else
    echo -e "  API access: ${RED}FAILED${NC} (check your API key)"
  fi
else
  echo -e "  ${YELLOW}Skipped${NC} (no API key)"
fi

echo ""

# Step 5: Check workflow files
echo -e "${YELLOW}[5/6] Checking workflow files...${NC}"

wf_dir="workflows"
if [ -d "$wf_dir" ]; then
  wf_files=$(ls "$wf_dir"/*.json 2>/dev/null | wc -l | tr -d ' ')
  echo -e "  ${GREEN}$wf_files${NC} workflow JSON files found in $wf_dir/"

  # Categorize
  personas=$(ls "$wf_dir"/{daniel,sarah,andrew,rebecka}*.json 2>/dev/null | wc -l | tr -d ' ')
  makecom=$(ls "$wf_dir"/makecom*.json 2>/dev/null | wc -l | tr -d ' ')
  scheduled=$(python3 -c "
import json, glob
count=0
for f in glob.glob('$wf_dir/*.json'):
    try:
        data=json.load(open(f))
        for n in data.get('nodes',[]):
            if 'scheduleTrigger' in n.get('type',''):
                count+=1; break
    except: pass
print(count)
" 2>/dev/null || echo "?")
  echo "    Persona workflows: $personas"
  echo "    Make.com bridge:   $makecom"
  echo "    Scheduled:         $scheduled"
else
  echo -e "  ${RED}workflows/ directory not found${NC}"
fi

echo ""

# Step 6: Summary
echo -e "${YELLOW}[6/6] Setup Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

issues=0
[ "$n8n_health" != "200" ] && { echo -e "  ${RED}! n8n is not reachable${NC}"; ((issues++)); }
[ "$amb_health" != "200" ] && { echo -e "  ${RED}! AMB is not reachable${NC}"; ((issues++)); }
[ -z "${N8N_API_KEY:-}" ] && { echo -e "  ${YELLOW}! No API key configured${NC}"; ((issues++)); }

if [ "$issues" -eq 0 ]; then
  echo -e "  ${GREEN}All checks passed!${NC}"
  echo ""
  echo "  Quick start commands:"
  echo "    bash scripts/manage-workflows.sh list       # List all workflows"
  echo "    bash scripts/manage-workflows.sh sync       # Import & activate all"
  echo "    bash scripts/manage-workflows.sh health     # Test all webhooks"
  echo "    bash scripts/demo.sh                        # Run full demo"
  echo "    bash scripts/monitor.sh --once              # Run monitor once"
else
  echo ""
  echo -e "  ${YELLOW}$issues issue(s) found — resolve before proceeding${NC}"
fi

echo ""
