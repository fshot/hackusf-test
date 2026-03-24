---
name: google-adk
description: Integration guide for Google ADK. Auth patterns, API usage, Python examples, A2A protocol, MCP integration, and gotchas.
---

# Google Agent Development Kit (ADK)

## Authentication

Two modes — start with Gemini API key for dev, switch to Vertex AI for deployment.

### Development (Gemini API Key)

```bash
# .env
GOOGLE_API_KEY=your-key-from-aistudio
GOOGLE_GENAI_USE_VERTEXAI=FALSE
```

Get key instantly at https://aistudio.google.com/apikey (no billing required).

### Production (Vertex AI with $50 credits)

```bash
# .env
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

Requires: `gcloud auth application-default login`

## Core API Patterns

### 1. Create a Basic Agent

```python
from google.adk.agents import LlmAgent
from google.adk.tools import google_search

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='my_agent',
    description='What this agent does (used by orchestrators for delegation).',
    instruction='You are a helpful agent. Use google_search for current data.',
    tools=[google_search],
)
```

### 2. Multi-Agent with Sub-Agents

```python
from google.adk.agents import LlmAgent

data_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='data_agent',
    description='Fetches and interprets climate and disaster data.',
    instruction='Retrieve current data for a given location.',
    tools=[google_search],
)

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='orchestrator',
    instruction='Coordinate tasks. Delegate data fetching to data_agent.',
    sub_agents=[data_agent],
)
```

### 3. Expose Agent as A2A Server

```bash
pip install google-adk[a2a]
```

```python
# server.py
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from my_agent.agent import root_agent

a2a_app = to_a2a(root_agent, port=8001)
```

```bash
uvicorn my_agent.server:a2a_app --port 8001
# Or: adk api_server --a2a --port 8001 my_agent
```

### 4. Consume Remote A2A Agent

```python
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent, AGENT_CARD_WELL_KNOWN_PATH

remote = RemoteA2aAgent(
    name='climate_data_agent',
    description='Fetches climate data remotely.',
    agent_card=f'http://localhost:8001/a2a/climate_data_agent{AGENT_CARD_WELL_KNOWN_PATH}',
    use_legacy=False,
)

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='orchestrator',
    instruction='Coordinate analysis. Delegate to climate_data_agent.',
    sub_agents=[remote],
)
```

### 5. Use MCP Tools

```python
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from mcp import StdioServerParameters

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='my_agent',
    instruction='Use available tools.',
    tools=[
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='npx',
                    args=['-y', '@modelcontextprotocol/server-fetch'],
                )
            )
        )
    ],
)
```

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `RESOURCE_EXHAUSTED` | Rate limit hit | Switch to Vertex AI or use Flash-Lite model |
| `PERMISSION_DENIED` | Bad API key or missing IAM role | Check `GOOGLE_API_KEY` or run `gcloud auth application-default login` |
| `INVALID_ARGUMENT` | Wrong model name | Use `gemini-2.0-flash` (not `gemini-2.0-flash-001`) |
| Sync service errors | Old tutorial code | All service methods are async as of v1.23.0 |

## Gotchas

- **Python is the only production-ready SDK.** TypeScript is 0.x and requires Node 24.13+.
- **A2A is Python-only in practice.** TypeScript A2A exists but is poorly documented.
- **`adk web` is dev-only.** Deploy to Cloud Run for the live demo.
- **All service methods are async as of v1.23.0.** Tutorials before Jan 2026 may use sync patterns.
- **MCP tools in production require synchronous definition** in `agent.py`.
- **Avoid Cloud Spanner** — use Firestore (free tier) or in-memory state.

## Rate Limits

### Free Tier (Gemini API)

| Model | RPM | RPD |
|-------|-----|-----|
| Gemini 2.5 Pro | 5 | 100 |
| Gemini 2.5 Flash | 10 | 250 |
| Gemini 2.5 Flash-Lite | 15 | 1,000 |

### Vertex AI (with $50 credits)

- Gemini 2.0 Flash: $0.15/1M input, $0.60/1M output — $50 covers the full hackathon easily
- No RPD limits, generous RPM

**Strategy:** Dev with free Gemini API key → deploy with Vertex AI credits.

## CLI Quick Reference

| Command | Purpose |
|---------|---------|
| `adk create <name>` | Scaffold agent project |
| `adk web` | Dev UI at localhost:8000 |
| `adk run <agent_dir>` | Terminal chat |
| `adk api_server --a2a --port 800X <agent>` | A2A server |
| `adk deploy cloud_run --with_ui --project=X --region=Y <dir>` | Deploy to Cloud Run |

## Key Resources

- [ADK Docs](https://google.github.io/adk-docs/)
- [ADK Samples (26 agents)](https://github.com/google/adk-samples)
- [A2A Protocol Spec](https://a2a-protocol.org/latest/)
- [InstaVibe Codelab (multi-agent reference)](https://codelabs.developers.google.com/instavibe-adk-multi-agents/instructions)
