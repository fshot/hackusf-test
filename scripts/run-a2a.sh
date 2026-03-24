#!/usr/bin/env bash
# scripts/run-a2a.sh
#
# Start all specialist agents as A2A servers + orchestrator with dev UI.
# Usage: ./scripts/run-a2a.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Source .env
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ -z "${GOOGLE_API_KEY:-}" ]; then
  echo "ERROR: GOOGLE_API_KEY is not set."
  exit 1
fi

cleanup() {
  echo "Shutting down agents..."
  kill $(jobs -p) 2>/dev/null || true
  wait 2>/dev/null
  echo "All agents stopped."
}
trap cleanup EXIT

echo "Starting A2A specialist agents..."

# Start specialist agents in background
uv run adk api_server --a2a --port 8081 agents/risk_assessment &
echo "  Risk Assessment Agent → :8081"

uv run adk api_server --a2a --port 8082 agents/code_compliance &
echo "  Code Compliance Agent → :8082"

uv run adk api_server --a2a --port 8083 agents/hardening_advisor &
echo "  Hardening Advisor Agent → :8083"

# Wait for agents to start
sleep 3

echo ""
echo "Starting Orchestrator with dev UI..."
echo "  Orchestrator → http://localhost:8080"
echo ""

uv run adk web --port 8080 agents/orchestrator

# Wait for all background jobs
wait
