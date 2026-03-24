# Research Report: Google A2A (Agent-to-Agent) Protocol

## TL;DR

A2A is a JSON-RPC 2.0 over HTTP/SSE open protocol (now at v1.0.0, Linux Foundation) that lets AI agents discover each other via Agent Cards and delegate tasks with a defined lifecycle. It is hackathon-friendly when used through the official `a2a-sdk` Python package or ADK's built-in `to_a2a()` wrapper — both have working examples, FastAPI/Starlette servers, and InMemory task stores requiring no infrastructure. The fastest path is: wrap your ADK agent with `to_a2a()`, deploy on Cloud Run with `$PORT`, done.

---

## 1. API Surface

### Protocol Foundation

A2A is JSON-RPC 2.0 over HTTP(S). As of v1.0.0 (released March 12, 2026), the protocol also supports gRPC and HTTP+JSON/REST bindings. The normative source is the protobuf file `specification/a2a.proto` in the A2A repo.

### Core JSON-RPC Methods

All methods use JSON-RPC 2.0 envelope (`jsonrpc`, `id`, `method`, `params`).

| Method | Description |
|---|---|
| `message/send` | Send a message, get back a completed Task (sync) |
| `message/stream` | Send a message, get SSE stream of events |
| `tasks/get` | Fetch current state of a task by ID |
| `tasks/list` | List tasks (paginated) |
| `tasks/cancel` | Cancel an in-progress task |
| `tasks/resubscribe` | Re-attach SSE stream to an existing task |
| `tasks/pushNotificationConfig/set` | Register a webhook for async notifications |
| `tasks/pushNotificationConfig/get` | Retrieve current webhook config |
| `agent/authenticatedExtendedCard` | Get full agent card (requires auth) |

### Message Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "analyze flood risk for Tampa"}],
      "messageId": "uuid-here",
      "contextId": "optional-conversation-id"
    }
  }
}
```

Response wraps a `Task` object:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "id": "task-uuid",
    "contextId": "conversation-uuid",
    "status": {"state": "completed"},
    "kind": "task",
    "artifacts": [...]
  }
}
```

### Task Lifecycle State Machine

States are defined in `TaskState` enum:

```
submitted -> working -> completed (terminal)
                     -> failed (terminal)
                     -> canceled (terminal)
                     -> rejected (terminal)
                     -> input-required (interrupted, resumes on next message)
                     -> auth-required (interrupted, client must re-auth)
```

- `submitted`: server acknowledged the task
- `working`: agent is actively processing
- `input-required`: agent needs clarification (multi-turn conversation)
- `auth-required`: agent needs the client to provide auth before continuing
- `completed/failed/canceled/rejected`: terminal, no further transitions

### Part Types

Messages are composed of `Part` objects:
- `{"kind": "text", "text": "..."}` — plain text
- `{"kind": "file", "file": {"uri": "...", "mimeType": "..."}}` — file reference
- `{"kind": "data", "data": {...}}` — structured JSON payload

### Error Codes (A2A-specific, beyond JSON-RPC standard)

| Error | Meaning |
|---|---|
| `TaskNotFoundError` | Invalid or expired task ID |
| `TaskNotCancelableError` | Task is already in terminal state |
| `PushNotificationNotSupportedError` | Agent Card lacks `pushNotifications: true` |
| `UnsupportedOperationError` | Method not implemented by this server |
| `ContentTypeNotSupportedError` | Sent a Part type the server can't handle |
| `VersionNotSupportedError` | Protocol version mismatch |
| `ExtensionSupportRequiredError` | Client missing a required extension |

### SDKs

| Language | Package | Maturity |
|---|---|---|
| Python | `pip install a2a-sdk` | Most mature; official; async-first |
| JavaScript | `npm install @a2a-js/sdk` | Official |
| Go | `go get github.com/a2aproject/a2a-go` | Official |
| Java | Maven artifact | Official |
| .NET | `dotnet add package A2A` | Official |

Python SDK is the most mature and best documented for the hackathon use case.

### Rate Limits

No rate limits on the A2A protocol itself — it is a protocol spec, not a hosted service. Limits are imposed by whatever LLM/infrastructure backs your agents (e.g., Gemini API quotas on GCP).

### Authentication Between Agents

The Agent Card declares auth requirements. Supported schemes:
- API key (header or query param)
- Bearer token (OAuth 2.0 / JWT)
- HTTP Basic
- Mutual TLS (mTLS)

For push notifications, the server authenticates to the client's webhook using OAuth 2.0 client credentials grant, Bearer JWT, HMAC signature, or API key. The server publishes public keys at a JWKS endpoint for token verification.

---

## 2. Onboarding

### What You Actually Need

A2A is a protocol, not a SaaS product. There is no sign-up, no API key for A2A itself. What you need:

1. A Python environment (3.10+)
2. `uv add a2a-sdk` or `pip install google-adk[a2a]`
3. An LLM API key (Gemini, OpenAI, etc.) for your actual agent logic

### Time to First Successful A2A Call

- With ADK `to_a2a()` wrapper: ~15 minutes from scratch
- With raw `a2a-sdk`: ~30–45 minutes to implement `AgentExecutor` and server

### Hackathon Credits

The A2A protocol itself costs nothing. You pay for:
- Cloud Run compute (minimal for a demo — free tier covers 2M requests/month, 360K GB-seconds/month)
- Gemini API calls via your $50 GCP credits

### Team Access

One GCP project shared by the team is sufficient. No per-developer A2A credentials needed.

---

## 3. Infrastructure as Code

### Terraform Provider

There is no dedicated Terraform provider for A2A — it is a protocol, not a cloud resource. You deploy A2A agents as Cloud Run services using the standard Google Cloud Terraform provider (`hashicorp/google`).

### Minimal `main.tf` for A2A on Cloud Run

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {}
variable "image" {}       # e.g. gcr.io/PROJECT/disaster-agent:latest
variable "agent_name" {}  # e.g. "disaster-response-agent"

resource "google_cloud_run_v2_service" "a2a_agent" {
  name     = var.agent_name
  location = "us-central1"

  template {
    containers {
      image = var.image

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }
      env {
        name  = "PORT"
        value = "8080"
      }

      ports {
        container_port = 8080
      }
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Allow unauthenticated (for hackathon inter-agent calls)
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = google_cloud_run_v2_service.a2a_agent.project
  location = google_cloud_run_v2_service.a2a_agent.location
  name     = google_cloud_run_v2_service.a2a_agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "agent_url" {
  value = google_cloud_run_v2_service.a2a_agent.uri
}

output "agent_card_url" {
  value = "${google_cloud_run_v2_service.a2a_agent.uri}/.well-known/agent-card.json"
}
```

### State Considerations

- Cloud Run services deploy in ~1–2 minutes
- On first deploy, container image must already exist in a registry — build and push before `terraform apply`
- For hackathon: build with `gcloud builds submit`, deploy with Terraform or just `gcloud run deploy --source .` (skips Terraform entirely)

### Recommended IaC Approach for Hackathon

Skip Terraform. Use `gcloud run deploy --source .` — it builds, pushes, and deploys in one command. Faster than writing and applying Terraform under time pressure.

---

## 4. Claude Ecosystem

### MCP Servers for A2A

Two notable MCP servers that bridge Claude to A2A agents:

**A2A-MCP-Server** (GitHub: `GongRzhe/A2A-MCP-Server`):
- Lets Claude Desktop or any MCP client register, list, and call A2A agents
- Install: `uvx a2a-mcp-server` or via Smithery
- Gives Claude tools: `register_agent`, `send_message`, `get_task_result`, `list_agents`, `cancel_task`
- Claude config:
  ```json
  {"mcpServers": {"a2a": {"command": "uvx", "args": ["a2a-mcp-server"]}}}
  ```

**MCP_A2A** (GitHub: `regismesquita/MCP_A2A`):
- Lightweight Python bridge, zero boilerplate, rapid prototyping focus

### Community Resources

- `ai-boost/awesome-a2a` — curated list of A2A agents, tools, servers, and clients
- `pab1it0/awesome-a2a` — fork with additional entries
- DeepLearning.AI free course: "A2A: The Agent2Agent Protocol"
- `holtskinner/A2AWalkthrough` — step-by-step walkthrough, basis for DeepLearning.AI course

### Prompt Patterns for Claude + A2A

When using Claude to orchestrate A2A agents (via the MCP bridge or programmatically):
- Provide the Agent Card JSON so Claude understands agent capabilities
- Ask Claude to reason about which agent skill best matches a subtask
- Use structured output (`data` Part type) for Claude to parse agent responses reliably
- For multi-agent chains: give Claude the full task graph and let it choose delegation order

---

## 5. CLI Tools

### Official CLI

No dedicated A2A CLI exists. The primary tooling is:

**Agent Inspector** (referenced in a2a-python SDK):
- Web-based testing UI for A2A agents
- Inspect agent cards, send test messages, view task state transitions
- Run against a local server during development

**gcloud CLI** (for deployment):
```bash
gcloud run deploy my-agent --source . --region us-central1 --allow-unauthenticated
```

**uvicorn** (for local server):
```bash
uvicorn agent:app --host 0.0.0.0 --port 8080
```

### OpenAPI / Protobuf Spec

The normative spec is a Protobuf file: `specification/a2a.proto` in `github.com/a2aproject/A2A`.

There is no published OpenAPI 3.0 YAML, but the JSON-RPC over HTTP binding is well-documented. The `a2a-sdk` Python package provides fully-typed Pydantic models for all request/response types — use those instead of code-generating a client.

### Typed Python Client (No Generation Needed)

```python
from a2a.client import A2AClient
from a2a.types import SendMessageRequest, MessageSendParams, Message, TextPart

async with A2AClient.create("http://agent-url") as client:
    request = SendMessageRequest(
        id="req-1",
        params=MessageSendParams(
            message=Message(
                role="user",
                parts=[TextPart(text="analyze this")]
            )
        )
    )
    response = await client.send_message(request)
```

---

## 6. Integration Shortcuts

### Pre-built ADK Integration (Fastest Path)

ADK has built-in A2A support. One function call exposes any ADK agent as an A2A server:

```python
from google.adk.a2a.utils.agent_to_a2a import to_a2a

a2a_app = to_a2a(root_agent, port=8080)
# Run with: uvicorn module:a2a_app --host 0.0.0.0 --port 8080
```

This auto-generates the Agent Card from the ADK agent configuration and mounts all A2A routes.

### Pydantic AI FastA2A (ADK-Independent)

If you need a non-ADK agent:
```bash
uv add fasta2a
# or: uv add "pydantic-ai-slim[a2a]"
```

```python
from pydantic_ai import Agent
agent = Agent('google-gla:gemini-2.0-flash', instructions='...')
app = agent.to_a2a()
# uvicorn agent:app --host 0.0.0.0 --port 8080
```

### Raw a2a-sdk Server (Maximum Control)

```python
# Install: uv add "a2a-sdk[http-server]"
import uvicorn
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore
from a2a.types import AgentCapabilities, AgentCard, AgentSkill

class MyAgentExecutor(AgentExecutor):
    async def execute(self, context: RequestContext, event_queue: EventQueue) -> None:
        result = await my_agent.run(context.get_user_input())
        await event_queue.enqueue_event(new_agent_text_message(result))

    async def cancel(self, context: RequestContext, event_queue: EventQueue) -> None:
        raise Exception("cancel not supported")

skill = AgentSkill(
    id='disaster_analysis',
    name='Disaster Risk Analysis',
    description='Analyzes disaster risk factors for a given location',
    tags=['disaster', 'risk', 'climate'],
    examples=['What is the flood risk for Tampa, FL?'],
)

agent_card = AgentCard(
    name='Disaster Response Agent',
    description='Analyzes and coordinates disaster response',
    url='https://my-agent-url.run.app/',
    version='1.0.0',
    default_input_modes=['text'],
    default_output_modes=['text'],
    capabilities=AgentCapabilities(streaming=True),
    skills=[skill],
)

request_handler = DefaultRequestHandler(
    agent_executor=MyAgentExecutor(),
    task_store=InMemoryTaskStore(),
)

server = A2AStarletteApplication(
    agent_card=agent_card,
    http_handler=request_handler,
)

if __name__ == '__main__':
    uvicorn.run(server.build(), host='0.0.0.0', port=8080)
```

### Example Projects / Reference Implementations

| Resource | What it shows |
|---|---|
| `a2aproject/a2a-samples` (GitHub) | Official samples: helloworld, currency agent, multi-agent |
| `holtskinner/A2AWalkthrough` (GitHub) | Step-by-step tutorial, healthcare concierge example |
| Google Codelabs: `intro-a2a-purchasing-concierge` | Cloud Run + Agent Engine multi-framework deployment |
| Google Codelabs: `codelabs/currency-agent` | MCP + ADK + A2A triangle |
| DeepLearning.AI "A2A: The Agent2Agent Protocol" | Free video course |

### Agent Card Discovery — Accessing at Runtime

```python
import httpx

async def discover_agent(base_url: str) -> dict:
    async with httpx.AsyncClient() as client:
        resp = await client.get(f"{base_url}/.well-known/agent-card.json")
        return resp.json()
```

---

## Hackathon Quick Start

### Zero to Working Multi-Agent System in ~45 Minutes

**Step 1: Install dependencies (2 min)**
```bash
uv add "google-adk[a2a]" a2a-sdk uvicorn httpx
```

**Step 2: Write your first A2A agent (10 min)**

Create `agents/climate_agent/agent.py`:
```python
from google.adk.agents import Agent
from google.adk.a2a.utils.agent_to_a2a import to_a2a

root_agent = Agent(
    model='gemini-2.0-flash',
    name='climate_risk_agent',
    description='Analyzes climate risk and provides recommendations',
    instruction="""You analyze climate risk for locations.
    Given a location, provide flood risk, heat risk, and recommended actions.""",
)

app = to_a2a(root_agent, port=8081)
```

**Step 3: Run the agent locally (1 min)**
```bash
uvicorn agents.climate_agent.agent:app --host 0.0.0.0 --port 8081
```

**Step 4: Verify Agent Card (1 min)**
```bash
curl http://localhost:8081/.well-known/agent-card.json | python -m json.tool
```

**Step 5: Write your orchestrator agent that calls it (10 min)**

Create `agents/orchestrator/agent.py`:
```python
from google.adk.agents import Agent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from a2a.client import A2AClient
from a2a.types import SendMessageRequest, MessageSendParams, Message, TextPart
import asyncio, uuid

async def call_climate_agent(query: str) -> str:
    async with A2AClient.create("http://localhost:8081") as client:
        req = SendMessageRequest(
            id=str(uuid.uuid4()),
            params=MessageSendParams(
                message=Message(
                    role="user",
                    parts=[TextPart(text=query)]
                )
            )
        )
        resp = await client.send_message(req)
        # Extract text from completed task artifacts
        return resp.result.artifacts[0].parts[0].text if resp.result.artifacts else "No result"

root_agent = Agent(
    model='gemini-2.0-flash',
    name='disaster_orchestrator',
    description='Coordinates disaster response across specialist agents',
    instruction="""You coordinate disaster response by delegating to specialist agents.
    For climate analysis tasks, use the climate risk agent.""",
    # Register call_climate_agent as a tool
)

app = to_a2a(root_agent, port=8080)
```

**Step 6: Deploy both agents to Cloud Run (5 min each)**
```bash
# From each agent directory:
gcloud run deploy climate-agent \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_API_KEY=$GEMINI_KEY

gcloud run deploy disaster-orchestrator \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_API_KEY=$GEMINI_KEY,CLIMATE_AGENT_URL=<climate-agent-url>
```

**Step 7: Test the full system (2 min)**
```bash
curl -X POST https://disaster-orchestrator-url/message/send \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"message/send","params":{"message":{"role":"user","parts":[{"kind":"text","text":"Assess disaster risk for Tampa, FL"}],"messageId":"test-1"}}}'
```

**Agent Card URL pattern** after deployment:
```
https://<service-name>-<hash>-uc.a.run.app/.well-known/agent-card.json
```

---

## A2A vs MCP — Quick Reference

| Dimension | A2A | MCP |
|---|---|---|
| What connects | Agent to Agent | Agent to Tool/Resource |
| Communication style | Peer-to-peer, stateful tasks | Client-server, stateless function calls |
| State management | Built-in task lifecycle | None |
| Discovery | Agent Card at `/.well-known/` | Tool list from server |
| Streaming | SSE (Server-Sent Events) | SSE or stdio |
| Use when | Delegating to another autonomous AI agent | Calling APIs, databases, file systems |
| Originator | Google / Linux Foundation | Anthropic |

In practice for your hackathon: use MCP for tool integrations (GCP APIs, databases, external data), use A2A for agent-to-agent delegation (orchestrator calling specialist agents).

---

## Multi-Agent Topology Patterns

### Hub-and-Spoke (Recommended for Hackathon)

```
User Request
    |
    v
[Orchestrator Agent] (ADK, port 8080)
    |          |          |
    v          v          v
[Climate   [Health    [Equity
 Agent]     Agent]     Agent]
 :8081      :8082      :8083
```

- Predictable, governable, easy to debug
- Orchestrator discovers specialists via their Agent Cards
- Each specialist can be built with a different framework
- Best default for 24-hour hackathon — simple to reason about

### Hierarchical (for more complex domains)

```
[Meta-Orchestrator]
   |           |
[Regional   [Regional
 Coordinator]  Coordinator]
   |               |
[Local Agents] [Local Agents]
```

- Useful when you have geographic or domain subdivisions
- Each coordinator is itself an A2A server and client
- Higher complexity — use only if your problem domain demands it

### Mesh (avoid for hackathon)

- Any agent can call any other agent directly
- Hard to debug, easy to create circular dependencies
- Reserve for production systems with proper governance

---

## Red Flags

**Ecosystem momentum concern**: As of September 2025, a reputable technical blog noted that A2A "has quietly faded into the background" while MCP gained developer mindshare. However, the HackUSF challenge explicitly requires A2A, so this is irrelevant to your decision — just understand you are implementing a less-adopted protocol.

**No InMemory persistence across restarts**: `InMemoryTaskStore` loses all tasks on server restart. For a demo this is fine; for a judge testing your system after a deploy, make sure to either use persistent storage or design tests that start fresh.

**Agent Card URL must be externally accessible**: The `url` field in AgentCard must be the public Cloud Run URL, not localhost. If you hardcode localhost in the AgentCard and deploy to Cloud Run, inter-agent discovery breaks silently.

**`to_a2a()` auto-generates a minimal Agent Card**: The auto-generated card from ADK's `to_a2a()` may have a generic description. Override it with a custom `AgentCard` object if you want accurate capability declarations for discovery.

**Streaming requires explicit capability declaration**: If you set `capabilities=AgentCapabilities(streaming=False)` or omit it, clients cannot use `message/stream`. Declare `streaming=True` from the start.

**Push notifications require HTTPS webhooks**: For demos this is hard to test locally. Use `message/send` (polling) or `message/stream` (SSE) instead — push notifications are only needed for multi-hour tasks, not demo-scale.

**gRPC support is v0.3+ only**: The Python SDK's gRPC extra (`a2a-sdk[grpc]`) is available, but the JSON-RPC/HTTP binding is simpler and sufficient for hackathon use.

**A2A v1.0.0 vs v0.3 breaking changes**: The official Python SDK on PyPI (`a2a-sdk`) targets v1.0.0. The ADK integration (`google-adk[a2a]`) may target an earlier version. Verify both use compatible method names — specifically, `message/send` (v1.0) vs older `tasks/send` naming from earlier drafts.

**Task artifacts vs messages**: Agents return results either as `Message` objects (conversational) or `Artifact` objects (generated outputs). Know which your executor produces so your client parses correctly.

---

## Recommended Approach

For the hackathon, use the ADK `to_a2a()` wrapper for all agents. This gives you A2A compliance with zero protocol boilerplate — you write only the agent logic. Structure your system as hub-and-spoke: one orchestrator agent (ADK) that receives user requests and delegates to 2–3 specialist agents (one per focus domain, e.g., ClimateRiskAgent, HealthImpactAgent, DisasterCoordinationAgent).

Deploy each agent as a Cloud Run service with `gcloud run deploy --source .` — skip Terraform unless you already have it templated from another research report. After each deploy, verify the Agent Card is accessible at `/.well-known/agent-card.json` and hardcode that URL into your orchestrator's environment variables.

For the demo, use `message/send` (synchronous polling) rather than SSE streaming — it is simpler to debug and sufficient for a judge interaction. If you have time and want to show off real-time capability, add `message/stream` to one agent as a stretch goal.

Use the `a2a-sdk` Python types (`AgentCard`, `AgentSkill`, `Message`, `TextPart`, etc.) for all data construction — they are Pydantic-based, fully typed, and enforce the protocol schema, catching mistakes at dev time rather than at demo time.

---

Sources:
- [Agent2Agent Protocol GitHub (a2aproject/A2A)](https://github.com/a2aproject/A2A)
- [A2A Protocol Official Site](https://a2a-protocol.org/latest/)
- [A2A Protocol Specification](https://a2a-protocol.org/latest/specification/)
- [A2A Python SDK (a2a-python)](https://github.com/a2aproject/a2a-python)
- [A2A Samples Repository](https://github.com/a2aproject/a2a-samples)
- [Google Announcing A2A - Developers Blog](https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/)
- [A2A Protocol Upgrade Blog Post](https://cloud.google.com/blog/products/ai-machine-learning/agent2agent-protocol-is-getting-an-upgrade/)
- [ADK A2A Quickstart - Exposing an Agent](https://google.github.io/adk-docs/a2a/quickstart-exposing/)
- [A2A and MCP Comparison (Official)](https://a2a-protocol.org/latest/topics/a2a-and-mcp/)
- [A2A Streaming and Async Operations](https://a2a-protocol.org/latest/topics/streaming-and-async/)
- [A2A Agent Skills and Card Tutorial](https://a2a-protocol.org/latest/tutorials/python/3-agent-skills-and-card/)
- [A2A AgentExecutor Tutorial](https://a2a-protocol.org/latest/tutorials/python/4-agent-executor/)
- [Pydantic AI FastA2A](https://ai.pydantic.dev/a2a/)
- [A2A-MCP-Server (GongRzhe)](https://github.com/GongRzhe/A2A-MCP-Server)
- [Awesome A2A (ai-boost)](https://github.com/ai-boost/awesome-a2a)
- [Google Codelabs: Purchasing Concierge A2A](https://codelabs.developers.google.com/intro-a2a-purchasing-concierge)
- [Google Codelabs: Currency Agent (MCP+ADK+A2A)](https://codelabs.developers.google.com/codelabs/currency-agent)
- [DeepLearning.AI A2A Course](https://www.deeplearning.ai/short-courses/a2a-the-agent2agent-protocol/)
- [A2AWalkthrough (holtskinner)](https://github.com/holtskinner/A2AWalkthrough)
- [What happened to Google's A2A? (fka.dev)](https://blog.fka.dev/blog/2025-09-11-what-happened-to-googles-a2a/)
- [A2A vs MCP - Merge.dev](https://www.merge.dev/blog/mcp-vs-a2a)
- [Hub-and-Spoke A2A Topology (Medium)](https://medium.com/@ratneshyadav_26063/bot-to-bot-centralized-hub-and-spoke-multi-agent-topology-part-2-using-google-a2a-22ac5e08f797)
- [A2A Protocol Security Guide (Semgrep)](https://semgrep.dev/blog/2025/a-security-engineers-guide-to-the-a2a-protocol/)
- [Amazon Bedrock A2A Protocol Contract](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-a2a-protocol-contract.html)
- [HuggingFace A2A Protocol Explained](https://huggingface.co/blog/1bo/a2a-protocol-explained)
