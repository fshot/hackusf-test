# Google Agent Development Kit (ADK)

## What

Google ADK is an open-source Python framework for building multi-agent AI systems on Gemini. It provides agent abstractions, tool integration (including MCP), and the Agent-to-Agent (A2A) protocol for wiring agents together. We're using it because the Google Cloud challenge track requires ADK + A2A.

## Why

The hackathon challenge requires building "multi-agent ecosystems that solve Wicked Problems." ADK gives us:
- Multi-agent orchestration out of the box
- A2A protocol for agent-to-agent communication
- Built-in tools (google_search, code_execution)
- MCP support for external tool integration
- One-command deployment to Cloud Run with a built-in UI

## Setup

### 1. Get a Gemini API Key (2 min)

1. Go to https://aistudio.google.com/apikey
2. Sign in with Google → Create API key → Copy it
3. Add to `.env`:
   ```
   GOOGLE_API_KEY=your-key-here
   GOOGLE_GENAI_USE_VERTEXAI=FALSE
   ```

### 2. Install ADK

```bash
python -m venv .venv
source .venv/bin/activate
pip install google-adk[a2a]
```

### 3. (Later) Set Up GCP for Deployment

```bash
# Redeem $50 hackathon credits at console.cloud.google.com
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com aiplatform.googleapis.com
gcloud auth application-default login
```

Update `.env`:
```
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

## Quick Start

```bash
# Scaffold and run a test agent
adk create test_agent
echo 'GOOGLE_API_KEY=your-key' > .env
echo 'GOOGLE_GENAI_USE_VERTEXAI=FALSE' >> .env
adk web
# Open http://localhost:8000 → select test_agent → chat
```

## Links

- [ADK Documentation](https://google.github.io/adk-docs/)
- [ADK Python SDK (PyPI)](https://pypi.org/project/google-adk/)
- [ADK Samples](https://github.com/google/adk-samples)
- [A2A Protocol](https://a2a-protocol.org/latest/)
- [InstaVibe Codelab](https://codelabs.developers.google.com/instavibe-adk-multi-agents/instructions)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [GCP Console](https://console.cloud.google.com/)
- [GCP Status](https://status.cloud.google.com/)
