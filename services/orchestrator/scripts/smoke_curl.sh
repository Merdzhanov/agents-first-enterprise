#!/usr/bin/env bash
# =============================================================================
# Enterprise Multi-Agent Fleet Engine — manual smoke test (curl)
#
# Usage:
#   1. Start the orchestrator (terminal 1):
#        cd services/orchestrator && .venv/bin/python -m uvicorn app.main:app --port 8000
#   2. Run this script (terminal 2):
#        bash services/orchestrator/scripts/smoke_curl.sh
#
# Env overrides:
#   BASE_URL   (default http://127.0.0.1:8000)
#   SESSION_ID (default session_smoke_$(date +%s))
#
# NOTE: The ADK Runner pipeline calls the real Dart node + Vertex AI unless
# DART_NODE_URL points at a stub and GOOGLE_GENAI_USE_VERTEXAI is unset.
# For a pure-LLM-free smoke run you can leave Vertex unconfigured: Planner
# falls back to deterministic templates.
# =============================================================================
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
SESSION_ID="${SESSION_ID:-session_smoke_$(date +%s)}"

step() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$1"; }

step "0. Health check"
curl -sf "$BASE_URL/health" | python3 -m json.tool

step "1. Trigger /fleet/discovery (ADK Runner mode) — expect awaiting_ceo_decision + RequestInput"
DISCOVERY=$(curl -sf -X POST "$BASE_URL/fleet/discovery" \
  -H 'Content-Type: application/json' \
  -d "{\"session_id\": \"$SESSION_ID\", \"raw_feed\": {}, \"use_adk_runner\": true}")
echo "$DISCOVERY" | python3 -m json.tool
echo "$DISCOVERY" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d.get('status') == 'awaiting_ceo_decision', f\"HITL pause missing: {d.get('status')}\"
ri = d.get('request_input') or {}
assert ri.get('state_key') == 'ceo_decision_gate', 'RequestInput state_key mismatch'
opts = [o.get('id') for o in ri.get('options', [])]
assert 'approve_idea_a' in opts and 'skip_implementation' in opts, f'options incomplete: {opts}'
print('✔ HITL pause validated: state_key=ceo_decision_gate, options=', opts)
"

step "2. Submit CEO decision → /fleet/ceo-decision (background resume)"
curl -sf -X POST "$BASE_URL/fleet/ceo-decision" \
  -H 'Content-Type: application/json' \
  -d "{\"session_id\": \"$SESSION_ID\", \"decision_choice\": \"approve_idea_a\", \"git_provider\": \"github\", \"use_adk_runner\": true}" \
  | python3 -m json.tool
echo "… background pipeline running. Poll session state until status=completed (or failed):"

step "3. Poll session state"
for i in $(seq 1 15); do
  STATE=$(curl -sf "$BASE_URL/fleet/session/$SESSION_ID")
  STATUS=$(echo "$STATE" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status'))")
  echo "  [$i] status=$STATUS"
  case "$STATUS" in
    completed|failed|skipped) break ;;
  esac
  sleep 3
done
echo "$STATE" | python3 -m json.tool

step "4. Execution traces"
curl -sf "$BASE_URL/fleet/session/$SESSION_ID/traces" | python3 -m json.tool

step "5. Final artifacts (git_repo + submission)"
curl -sf "$BASE_URL/fleet/session/$SESSION_ID/artifacts" | python3 -m json.tool

step "6. Scheduled discovery cycle (idempotency: second call must skip existing sessions)"
curl -sf -X POST "$BASE_URL/fleet/scheduled-discovery" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('proposals generated:', d.get('proposals_count'))
print('✔ scheduler ran — re-run this step; count should drop to 0 (duplicate guard works)')
"

step "7. Validation error path (invalid decision_choice → 422)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE_URL/fleet/ceo-decision" \
  -H 'Content-Type: application/json' \
  -d "{\"session_id\": \"$SESSION_ID\", \"decision_choice\": \"definitely_not_valid\", \"use_adk_runner\": true}")
echo "HTTP $CODE (expected 422)"

printf '\n\033[1;32mSmoke finished for session %s\033[0m\n' "$SESSION_ID"
