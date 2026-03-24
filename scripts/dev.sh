#!/usr/bin/env bash
# scripts/dev.sh
#
# Start the ADK dev UI with all agents available.
# Usage: ./scripts/dev.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Source .env if it exists
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

# Verify GOOGLE_API_KEY is set
if [ -z "${GOOGLE_API_KEY:-}" ]; then
  echo "ERROR: GOOGLE_API_KEY is not set."
  echo "Get one at: https://aistudio.google.com/apikey"
  echo "Then add to .env: GOOGLE_API_KEY=your-key-here"
  exit 1
fi

echo "Starting ADK dev UI at http://localhost:8000"
echo "Available agents:"
for agent_dir in agents/*/; do
  agent_name=$(basename "$agent_dir")
  echo "  - $agent_name"
done
echo ""

exec uv run adk web --port 8000 agents/
