#!/usr/bin/env bash
# scripts/deploy.sh
#
# Deploy all agents to Google Cloud Run.
# Usage: ./scripts/deploy.sh <PROJECT_ID>

set -euo pipefail

PROJECT_ID="${1:?Usage: ./scripts/deploy.sh <PROJECT_ID>}"
REGION="us-central1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "Deploying FireShield AI to Cloud Run..."
echo "Project: $PROJECT_ID | Region: $REGION"
echo ""

# Enable required APIs
echo "Enabling APIs..."
gcloud services enable run.googleapis.com aiplatform.googleapis.com --project="$PROJECT_ID"

# Deploy specialist agents first (orchestrator needs their URLs)
for agent in risk_assessment code_compliance hardening_advisor; do
  service_name="fireshield-${agent//_/-}"
  echo "Deploying $service_name..."
  gcloud run deploy "$service_name" \
    --source "agents/$agent" \
    --region "$REGION" \
    --project "$PROJECT_ID" \
    --allow-unauthenticated \
    --set-env-vars "GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_CLOUD_LOCATION=$REGION,GOOGLE_GENAI_USE_VERTEXAI=TRUE" \
    --quiet
  echo "  $service_name deployed."
done

# Get specialist URLs
RISK_URL=$(gcloud run services describe fireshield-risk-assessment --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')
COMPLIANCE_URL=$(gcloud run services describe fireshield-code-compliance --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')
HARDENING_URL=$(gcloud run services describe fireshield-hardening-advisor --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')

echo ""
echo "Specialist agent URLs:"
echo "  Risk Assessment: $RISK_URL"
echo "  Code Compliance: $COMPLIANCE_URL"
echo "  Hardening Advisor: $HARDENING_URL"

# Deploy orchestrator with UI
echo ""
echo "Deploying orchestrator with UI..."
uv run adk deploy cloud_run \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --service_name=fireshield-orchestrator \
  --with_ui \
  agents/orchestrator

ORCH_URL=$(gcloud run services describe fireshield-orchestrator --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)')

echo ""
echo "=== Deployment Complete ==="
echo "Orchestrator UI: $ORCH_URL"
echo ""
echo "Agent Cards:"
echo "  $RISK_URL/.well-known/agent-card.json"
echo "  $COMPLIANCE_URL/.well-known/agent-card.json"
echo "  $HARDENING_URL/.well-known/agent-card.json"
