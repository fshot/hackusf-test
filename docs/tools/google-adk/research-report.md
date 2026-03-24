# Research Report: Google Agent Development Kit (ADK)

## TL;DR

Google ADK is a code-first, open-source Python/TypeScript/Go/Java framework for building multi-agent AI systems on top of Gemini (or other LLMs). It is highly hackathon-friendly: you can go from zero to a working multi-agent demo in under 30 minutes using the free Gemini API key from AI Studio plus the `adk web` dev UI. The fastest integration path is Python + Gemini API key (no GCP billing required for development) with the `adk a2a` server pattern for multi-agent wiring.

---

## 1. API Surface

### Core Abstractions

ADK does not expose a raw REST API you call directly. Instead it is a framework library whose agents run locally or on Cloud Run / Vertex AI Agent Engine. The agent exposes HTTP endpoints when you run `adk api_server` or `adk deploy cloud_run`.

**Built-in HTTP endpoints (when running `adk api_server` or deployed to Cloud Run):**

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/run` | POST | Single-turn agent invocation |
| `/run_sse` | POST | Streaming SSE agent invocation |
| `/apps/{app}/sessions` | GET/POST | Session management |
| `/apps/{app}/sessions/{id}` | GET/DELETE | Session CRUD |
| `/.well-known/agent-card.json` | GET | A2A agent discovery card |
| `/a2a/{agent_name}` | POST | A2A protocol task endpoint |

### SDKs

| SDK | Package | Maturity | Notes |
|-----|---------|---------|-------|
| Python | `google-adk` (PyPI) | Most mature | v1.27.3 as of Mar 23 2026; bi-weekly releases |
| TypeScript | `@google/adk` (npm) | Active but younger | v0.4.x; announced Dec 2025; requires Node 24.13+ |
| Go | `google/adk-go` (GitHub) | Active | `adkgo` CLI |
| Java | `google/adk-java` (GitHub) | Active | Spring Boot integration, Maven/Gradle |

**Python is the most mature SDK.** TypeScript is functional but the version is still 0.x, which signals API instability. Use Python unless the team has a strong TypeScript-first preference.

### Authentication

Two modes:

1. **Gemini Developer API (AI Studio key)** - simplest for hackathons
   - Get key at https://aistudio.google.com/apikey (instant, no billing)
   - Set `GOOGLE_API_KEY=<key>` and `GOOGLE_GENAI_USE_VERTEXAI=FALSE` in `.env`

2. **Vertex AI** - required for Cloud Run deployment with $50 credits
   - `GOOGLE_GENAI_USE_VERTEXAI=TRUE`
   - `GOOGLE_CLOUD_PROJECT=<project-id>`
   - `GOOGLE_CLOUD_LOCATION=us-central1`
   - Requires `gcloud auth application-default login`

### Rate Limits (Gemini API Free Tier - March 2026)

| Model | RPM | RPD | TPM |
|-------|-----|-----|-----|
| Gemini 2.5 Pro | 5 | 100 | 250,000 |
| Gemini 2.5 Flash | 10 | 250 | 250,000 |
| Gemini 2.5 Flash-Lite | 15 | 1,000 | 250,000 |

**Warning:** Free tier limits were cut 50-80% in December 2025. For a hackathon demo with multiple agents making sequential calls, Gemini 2.5 Flash-Lite (1,000 RPD) is the safe choice. For production-quality responses, use Gemini 2.0 Flash via Vertex AI ($0.15/1M input tokens, $0.60/1M output tokens) - very cheap under $50 credits.

### Vertex AI Pricing (for $50 credit math)

- Gemini 2.0 Flash: $0.15 / 1M input tokens, $0.60 / 1M output tokens
- Gemini 2.5 Flash: $0.30 / 1M input tokens, $2.50 / 1M output tokens
- Cloud Run: ~$0.40 / million requests + CPU time (very low for demo)
- **$50 comfortably covers a 24-hour hackathon demo** using Gemini 2.0 Flash

### Gotchas

- **TypeScript requires Node 24.13.0+** - this is newer than many LTS installs; verify with `node --version`
- **`adk web` is dev-only** - do not expose it as the production endpoint; use `adk api_server` or Cloud Run
- **All service methods are async as of v1.23.0** - if you followed old tutorials using synchronous session service calls, they will break
- **MCP tools in production require synchronous definition** in `agent.py` - async patterns used in dev won't work when deployed
- **TypeScript A2A support** is less documented than Python A2A - prefer Python for the A2A layer
- **Go MALFORMED_FUNCTION_CALL bug** - Gemini occasionally outputs Python-format function calls instead of JSON; known open issue in `adk-go`

---

## 2. Onboarding

### Signup Flow

**Path A: Gemini API key only (recommended for day-1 dev)**
1. Go to https://aistudio.google.com/apikey
2. Sign in with Google account
3. Click "Create API key"
4. Copy key - done. No billing, no approval gate, instant access.

**Path B: GCP project with $50 credits**
1. Redeem hackathon credit code at https://console.cloud.google.com/
2. Enable APIs: Vertex AI API, Cloud Run API, Secret Manager API
3. Run `gcloud auth login && gcloud auth application-default login`
4. Set project: `gcloud config set project <YOUR_PROJECT_ID>`

### Time to Access

- Gemini API key: under 2 minutes
- First working agent after `pip install google-adk`: under 15 minutes total
- Cloud Run deployment: 15-20 minutes additional

### Free Tier / Hackathon Credits

- Gemini API (AI Studio): free tier is sufficient for development and light demo traffic
- GCP $50 credits: more than sufficient for a 24-hour hackathon demo on Cloud Run + Vertex AI calls
- New GCP accounts also get $300 in free credits for 90 days (may stack with hackathon credits)

### Team Access

- One Gemini API key can be shared across the team (put it in a shared `.env`)
- One GCP project can have multiple IAM members - add each teammate via IAM console
- Each developer can also get their own free Gemini API key; there is no account linking requirement

---

## 3. Infrastructure as Code

### Terraform Provider

**Official provider:** `hashicorp/google` at https://registry.terraform.io/providers/hashicorp/google/latest

No ADK-specific Terraform provider exists. ADK agents are deployed as Cloud Run services or Vertex AI Agent Engine (Reasoning Engine) instances using the standard Google Cloud provider.

### Key Terraform Resources

| Resource | Purpose |
|----------|---------|
| `google_cloud_run_v2_service` | Deploy ADK agent as Cloud Run service |
| `google_vertex_ai_reasoning_engine` | Deploy to Agent Engine (managed runtime) |
| `google_project_service` | Enable required APIs |
| `google_service_account` | Service account for agents |
| `google_secret_manager_secret` | Store API keys securely |
| `google_secret_manager_secret_version` | Secret content |
| `google_secret_manager_secret_iam_member` | Grant Cloud Run access to secrets |

### Minimal `main.tf` for Cloud Run ADK Agent

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

variable "project_id" {}
variable "region" { default = "us-central1" }
variable "gemini_api_key" { sensitive = true }

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "vertex_api" {
  service            = "aiplatform.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Store API key in Secret Manager
resource "google_secret_manager_secret" "gemini_key" {
  secret_id = "GOOGLE_API_KEY"
  replication {
    auto {}
  }
  depends_on = [google_project_service.secretmanager_api]
}

resource "google_secret_manager_secret_version" "gemini_key_version" {
  secret      = google_secret_manager_secret.gemini_key.id
  secret_data = var.gemini_api_key
}

# Service account for Cloud Run
resource "google_service_account" "adk_agent_sa" {
  account_id   = "adk-agent-sa"
  display_name = "ADK Agent Service Account"
}

# Grant secret access
resource "google_secret_manager_secret_iam_member" "secret_access" {
  secret_id = google_secret_manager_secret.gemini_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.adk_agent_sa.email}"
}

# Cloud Run service (image built by `adk deploy cloud_run` or manually)
resource "google_cloud_run_v2_service" "adk_agent" {
  name     = "adk-hackathon-agent"
  location = var.region

  template {
    service_account = google_service_account.adk_agent_sa.email

    containers {
      image = "gcr.io/${var.project_id}/adk-hackathon-agent:latest"

      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "FALSE"
      }
      env {
        name = "GOOGLE_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.gemini_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  depends_on = [
    google_project_service.run_api,
    google_secret_manager_secret_iam_member.secret_access,
  ]
}

output "agent_url" {
  value = google_cloud_run_v2_service.adk_agent.uri
}
```

### State Considerations

- Cloud Run service creation: fast (~30-60 seconds)
- Secret Manager secret creation: fast
- `google_vertex_ai_reasoning_engine` (Agent Engine): can take 5-10 minutes to provision; has eventual consistency delays on first deploy
- **Recommendation for hackathon:** Skip Terraform for initial deploy, use `adk deploy cloud_run` CLI directly. Add Terraform only if you need repeatable multi-service infrastructure.

---

## 4. Claude Ecosystem

### MCP Server Integration

ADK has **first-class MCP support** through the `MCPToolset` class. ADK agents can consume any MCP server as a toolset.

**Connecting to a local MCP server (stdio):**

```python
from google.adk.tools.mcp_tool import McpToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from mcp import StdioServerParameters

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='my_agent',
    instruction='You are a helpful agent.',
    tools=[
        McpToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='npx',
                    args=["-y", "@modelcontextprotocol/server-filesystem", "/data"],
                )
            )
        )
    ],
)
```

**Connecting to a remote MCP server (HTTP/SSE):**

```python
from google.adk.tools.mcp_tool.mcp_session_manager import SseConnectionParams

McpToolset(
    connection_params=SseConnectionParams(
        url="https://your-mcp-server.run.app/sse",
        headers={"Authorization": "Bearer your-token"}
    )
)
```

ADK can also be used as an MCP server host via FastMCP.

### Using Claude with ADK

ADK is model-agnostic. You can configure it to use Claude (via Vertex AI or Anthropic API) instead of Gemini:

```python
from google.adk.agents import LlmAgent

agent = LlmAgent(
    model='claude-3-5-sonnet@20241022',  # Vertex AI hosted Claude
    name='my_agent',
    instruction='...',
    tools=[...]
)
```

### Official Codelabs Covering Claude + ADK + MCP

- "Google's Agent Stack in Action: ADK, A2A, MCP on Google Cloud" - https://codelabs.developers.google.com/instavibe-adk-multi-agents/instructions
  - Builds 4 agents: Event Planner, Social Profiling, Platform Interaction, Orchestrator
  - Shows full ADK + MCP + A2A + Cloud Run + Cloud Spanner stack
  - Best single reference for multi-agent architecture

- "Getting Started with MCP, ADK and A2A" - https://codelabs.developers.google.com/codelabs/currency-agent

### Community MCP Servers Worth Knowing

- `@modelcontextprotocol/server-filesystem` - file access
- `@modelcontextprotocol/server-fetch` - web fetch
- Google Cloud Generative Media MCP tools (Imagen, Veo) for climate/disaster visualization

---

## 5. CLI Tools

### Official ADK CLI

Installed automatically with `pip install google-adk` (Python) or used via `npx adk` (TypeScript).

**Key commands:**

| Command | Purpose |
|---------|---------|
| `adk create <name>` | Scaffold a new agent project |
| `adk run <agent_dir>` | Interactive terminal session |
| `adk web` | Launch dev UI at localhost:8000 |
| `adk api_server` | Start local HTTP API server |
| `adk api_server --a2a --port 8001 <agent>` | Start as A2A server |
| `adk deploy cloud_run --project=X --region=Y <agent_dir>` | Deploy to Cloud Run |
| `adk deploy cloud_run --with_ui` | Deploy with web UI included |
| `adk eval` | Run evaluation suite |

**TypeScript equivalents use `npx adk` instead of `adk`.**

### Agent Starter Pack CLI

```bash
# Install uv first
curl -LsSf https://astral.sh/uv/install.sh | sh

# Create a new project with CI/CD and Terraform scaffolding
uvx agent-starter-pack create my-agent

# Enhance an existing ADK project for Agent Engine deployment
uvx agent-starter-pack enhance --adk -d agent_engine
```

Available templates: `adk`, `adk_ts`, `adk_go`, `adk_java`, `adk_a2a`, `agentic_rag`, `adk_live`, `langgraph`

### OpenAPI Spec

No published OpenAPI spec for the ADK framework itself. The local API server (`adk api_server`) exposes endpoints but does not auto-generate an OpenAPI doc. The A2A protocol has its own schema at https://a2a-protocol.org/latest/.

---

## 6. Integration Shortcuts

### Fastest Starter Templates

**Option 1: Agent Starter Pack with A2A template (recommended for this hackathon)**
```bash
uvx agent-starter-pack create my-hackathon-agent
# Select: adk_a2a template
```
This gives you Python + ADK + A2A + Terraform + CI/CD scaffolding pre-wired.

**Option 2: Manual from official samples**
```bash
git clone https://github.com/google/adk-samples
# Browse: python/agents/ for 26 sample agents
```

**Option 3: InstaVibe Codelab reference architecture**
- URL: https://codelabs.developers.google.com/instavibe-adk-multi-agents/instructions
- 4-agent system with ADK + MCP + A2A fully wired; best architectural reference

### Example Apps and Repos

| Repo | Description |
|------|-------------|
| https://github.com/google/adk-samples | 26 Python agents, 1 TypeScript agent, 2 Java agents |
| https://github.com/google/adk-python | Python SDK source + contributing samples |
| https://github.com/google/adk-js | TypeScript SDK source |
| https://github.com/a2aproject/A2A | A2A protocol spec and samples |
| https://github.com/Sri-Krishna-V/awesome-adk-agents | Community curated ADK agent collection |

### Pre-built Google Tools (useful for hackathon domains)

ADK includes built-in tools:
- `google_search` - live web search (grounded)
- `code_execution` - run Python code sandbox
- `vertex_ai_search` - search your data
- `BigQueryTool` - query datasets

For climate/health/disaster:
- NOAA public datasets available via BigQuery
- CDC health data available via BigQuery Public Data
- FEMA disaster declarations dataset in BigQuery

### Multi-Agent Architecture Pattern for the Hackathon

The hackathon theme "wicked problems" maps well to this topology:

```
Orchestrator Agent (root)
├── Data Collector Agent  (fetches climate/health/disaster data)
│   └── Tool: BigQuery or external API
├── Analysis Agent        (processes and identifies patterns)
│   └── Tool: code_execution
├── Recommendation Agent  (proposes interventions)
│   └── Tool: google_search
└── Report Agent          (formats output for humans)
    └── Tool: file write / MCP filesystem
```

Wire the first three as A2A servers; the root orchestrates them.

---

## Hackathon Quick Start

### Zero to Working Multi-Agent System (Target: 30 minutes)

**Step 1: Get a Gemini API key (2 min)**
```
Open: https://aistudio.google.com/apikey
Sign in -> Create API key -> Copy it
```

**Step 2: Install ADK (2 min)**
```bash
python -m venv .venv
source .venv/bin/activate   # macOS/Linux
pip install google-adk
```

**Step 3: Scaffold the project (1 min)**
```bash
adk create orchestrator_agent
cd orchestrator_agent
echo 'GOOGLE_API_KEY=<YOUR_KEY_HERE>' >> .env
echo 'GOOGLE_GENAI_USE_VERTEXAI=FALSE' >> .env
```

**Step 4: Write your first agent (`orchestrator_agent/agent.py`)**
```python
from google.adk.agents import LlmAgent
from google.adk.tools import google_search

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='disaster_response_orchestrator',
    description='Coordinates disaster response information agents.',
    instruction="""You are a disaster response coordinator.
    Use google_search to find current disaster alerts,
    health risks, and climate data for the specified region.
    Summarize actionable recommendations.""",
    tools=[google_search],
)
```

**Step 5: Test locally (1 min)**
```bash
# From parent directory
adk web
# Open http://localhost:8000 -> select orchestrator_agent -> chat
```

**Step 6: Add a second specialized agent and wire with A2A**

Install A2A extras:
```bash
pip install google-adk[a2a]
```

Create `data_agent/agent.py`:
```python
from google.adk.agents import LlmAgent
from google.adk.tools import google_search

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='climate_data_agent',
    description='Fetches and interprets climate and disaster data.',
    instruction='Retrieve current climate data and disaster alerts for a given location.',
    tools=[google_search],
)
```

Expose data_agent as A2A server:
```python
# data_agent/server.py
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from data_agent.agent import root_agent

a2a_app = to_a2a(root_agent, port=8001)
```

```bash
uvicorn data_agent.server:a2a_app --port 8001 &
```

Consume in orchestrator:
```python
# orchestrator_agent/agent.py
from google.adk.agents import LlmAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent, AGENT_CARD_WELL_KNOWN_PATH

climate_agent = RemoteA2aAgent(
    name='climate_data_agent',
    description='Fetches climate and disaster data remotely.',
    agent_card=f'http://localhost:8001/a2a/climate_data_agent{AGENT_CARD_WELL_KNOWN_PATH}',
    use_legacy=False,
)

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='orchestrator',
    instruction='Coordinate climate data analysis. Delegate data fetching to climate_data_agent.',
    sub_agents=[climate_agent],
)
```

**Step 7: Deploy to Cloud Run (15 min, requires GCP project)**
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com aiplatform.googleapis.com

adk deploy cloud_run \
  --project=YOUR_PROJECT_ID \
  --region=us-central1 \
  --service_name=hackathon-orchestrator \
  --with_ui \
  ./orchestrator_agent
```

**Step 8: Test deployed agent**
```bash
export APP_URL=$(gcloud run services describe hackathon-orchestrator \
  --region=us-central1 --format='value(status.url)')

curl -X POST $APP_URL/run \
  -H "Content-Type: application/json" \
  -d '{"app_name":"orchestrator_agent","user_id":"demo","session_id":"s1",
       "new_message":{"role":"user","parts":[{"text":"What are current climate risks in Florida?"}]}}'
```

---

## Red Flags

1. **TypeScript Node version requirement.** `@google/adk` requires Node 24.13+. Many machines run Node 20 LTS. Check with `node --version` before committing to TypeScript. Upgrading Node mid-hackathon is a time sink.

2. **Free tier RPD limits are tight for multi-agent demos.** With Gemini 2.5 Flash at 250 RPD, a 4-agent pipeline where each turn calls 2-3 agents will hit the daily limit in ~60 demo runs. Switch to Vertex AI (with GCP credits) as soon as the app works end-to-end.

3. **A2A Python-only in practice.** The A2A quickstart consuming guide is Python-only in the official ADK docs. TypeScript A2A support exists but is less documented. Do not plan a TypeScript-only multi-agent system unless you have time to debug undocumented edge cases.

4. **`adk web` is not a production server.** Judges accessing a live URL need Cloud Run, not your laptop running `adk web`. Budget 15-20 minutes for the Cloud Run deploy.

5. **Services are all async as of v1.23.0.** Tutorials older than January 2026 may use synchronous service patterns that now throw errors. Check the date on any tutorial you copy from.

6. **InstaVibe codelab uses Cloud Spanner** (expensive if credits run out). Avoid Spanner for the hackathon - use Cloud Firestore (free tier: 50,000 reads/day) or in-memory state instead.

7. **Agent Starter Pack is for deployment scaffolding, not the agent itself.** It adds Terraform, CI/CD pipelines, and test scaffolding. Useful but adds file structure complexity. Understand what it does before running it.

---

## Recommended Approach

**Use Python ADK + Gemini 2.0 Flash + A2A + Cloud Run.**

1. Start development using the Gemini Developer API key (free, instant). This keeps you unblocked while any GCP credit issues are sorted.

2. Build 2-3 specialized agents (not 5+) with clear, distinct responsibilities matching the chosen problem domain (recommend: Disaster Response - clearest data sources, most compelling demo).

3. Wire agents together using A2A with local ports during development (`adk api_server --a2a --port 800X`), then deploy each as a separate Cloud Run service.

4. Use `google_search` as the primary tool - it is built-in, grounded, and requires no external API setup.

5. Add one MCP server if time permits - `@modelcontextprotocol/server-fetch` for pulling live data from public APIs (FEMA, NOAA, CDC).

6. Deploy to Cloud Run using `adk deploy cloud_run --with_ui` for the demo. The dev UI gives judges a polished interface without frontend work.

7. Keep Terraform minimal - use it only for the GCP project API enablement and service accounts. Use the `adk deploy` CLI for the actual Cloud Run deploys.

**Suggested agent split for a disaster response system:**
- `intake_agent`: accepts user queries, classifies urgency and location
- `data_agent`: fetches FEMA/NOAA/CDC data for the location
- `response_agent`: generates actionable recommendations and resource links
- Root orchestrator coordinates all three via A2A

This is a concrete, demonstrable multi-agent system that maps directly to the "Self-Healing World" and "Wicked Problems" framing of the challenge.

---

## Sources

- [Google ADK Official Documentation](https://google.github.io/adk-docs/)
- [ADK Python SDK - PyPI](https://pypi.org/project/google-adk/)
- [ADK TypeScript SDK - npm](https://www.npmjs.com/package/@google/adk)
- [ADK Python GitHub](https://github.com/google/adk-python)
- [ADK TypeScript GitHub](https://github.com/google/adk-js)
- [ADK Sample Agents](https://github.com/google/adk-samples)
- [A2A Protocol Documentation](https://google.github.io/adk-docs/a2a/)
- [A2A Protocol Spec](https://a2a-protocol.org/latest/)
- [A2A GitHub (Linux Foundation)](https://github.com/a2aproject/A2A)
- [ADK Quickstart](https://google.github.io/adk-docs/get-started/quickstart/)
- [ADK TypeScript Quickstart](https://google.github.io/adk-docs/get-started/typescript/)
- [MCP Tools in ADK](https://google.github.io/adk-docs/tools-custom/mcp-tools/)
- [Cloud Run Deployment](https://google.github.io/adk-docs/deploy/cloud-run/)
- [ADK CLI Reference](https://google.github.io/adk-docs/runtime/command-line/)
- [Agent Starter Pack](https://google.github.io/adk-docs/deploy/agent-engine/asp/)
- [InstaVibe Codelab (ADK+A2A+MCP)](https://codelabs.developers.google.com/instavibe-adk-multi-agents/instructions)
- [MCP+ADK+A2A Getting Started Codelab](https://codelabs.developers.google.com/codelabs/currency-agent)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/generative-ai/pricing)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [Terraform google_vertex_ai_reasoning_engine](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/vertex_ai_reasoning_engine)
- [ADK Hackathon with Google Cloud (2025 Devpost)](https://googlecloudmultiagents.devpost.com/)
- [Agent Starter Pack Templates](https://googlecloudplatform.github.io/agent-starter-pack/agents/overview.html)
