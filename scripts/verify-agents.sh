#!/usr/bin/env bash
# scripts/verify-agents.sh
#
# Verify all local A2A agents are running and responding.
# Usage: ./scripts/verify-agents.sh

set -euo pipefail

echo "=== Verifying A2A Agents ==="

agents=(
  "Risk Assessment:8081"
  "Code Compliance:8082"
  "Hardening Advisor:8083"
)

all_ok=true

for entry in "${agents[@]}"; do
  name="${entry%%:*}"
  port="${entry##*:}"

  echo -n "  $name (:$port) ... "
  if curl -sf "http://localhost:$port/.well-known/agent-card.json" > /dev/null 2>&1; then
    echo "OK"
  else
    echo "FAILED"
    all_ok=false
  fi
done

echo -n "  Orchestrator (:8080) ... "
if curl -sf "http://localhost:8080" > /dev/null 2>&1; then
  echo "OK"
else
  echo "FAILED (may be using adk web instead of api_server)"
  all_ok=false
fi

echo ""
if $all_ok; then
  echo "All agents healthy."
else
  echo "Some agents are not responding. Run ./scripts/run-a2a.sh first."
  exit 1
fi
