---
name: google-a2a
description: Integration guide for Google A2A Protocol. Agent Cards, task lifecycle, message format, Python examples, and multi-agent topology patterns.
---

# Google A2A (Agent-to-Agent) Protocol

## Overview

A2A is a JSON-RPC 2.0 over HTTP/SSE protocol (v1.0.0, Linux Foundation) for agent-to-agent communication. Agents discover each other via Agent Cards and delegate tasks with a defined lifecycle. Use A2A between agents; use MCP for agent-to-tool connections.

## Authentication

A2A itself requires no credentials — it's a protocol spec. Auth between agents is declared in the Agent Card:

```python
# Agent Card auth declaration (optional for hackathon)
from a2a.types import AgentCard, AgentCapabilities, AgentSkill

agent_card = AgentCard(
    name='Climate Risk Agent',
    description='Analyzes climate risk for locations',
    url='https://your-cloud-run-url.run.app/',  # MUST be public URL, never localhost
    version='1.0.0',
    default_input_modes=['text'],
    default_output_modes=['text'],
    capabilities=AgentCapabilities(streaming=True),
    skills=[AgentSkill(
        id='climate_analysis',
        name='Climate Risk Analysis',
        description='Analyzes flood, heat, and storm risk',
        tags=['climate', 'disaster', 'risk'],
        examples=['What is the flood risk for Tampa, FL?'],
    )],
)
```

## Core API Patterns

### 1. Expose an ADK Agent as A2A Server (Fastest)

```python
from google.adk.agents import LlmAgent
from google.adk.a2a.utils.agent_to_a2a import to_a2a

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='climate_agent',
    description='Analyzes climate risk for locations',
    instruction='Analyze climate risk. Provide flood, heat, and storm risk assessments.',
)

app = to_a2a(root_agent, port=8081)
# Run: uvicorn module:app --host 0.0.0.0 --port 8081
```

### 2. Send a Message to an A2A Agent (Client)

```python
from a2a.client import A2AClient
from a2a.types import SendMessageRequest, MessageSendParams, Message, TextPart
import uuid

async with A2AClient.create("http://localhost:8081") as client:
    request = SendMessageRequest(
        id=str(uuid.uuid4()),
        params=MessageSendParams(
            message=Message(
                role="user",
                parts=[TextPart(text="Assess flood risk for Tampa, FL")]
            )
        )
    )
    response = await client.send_message(request)
    # response.result is a Task with artifacts
    text = response.result.artifacts[0].parts[0].text
```

### 3. Discover an Agent via Agent Card

```python
import httpx

async with httpx.AsyncClient() as client:
    resp = await client.get("http://localhost:8081/.well-known/agent-card.json")
    card = resp.json()
    print(card['name'], card['skills'])
```

### 4. Raw A2A Server (Without ADK)

```python
from a2a.server.apps import A2AStarletteApplication
from a2a.server.request_handlers import DefaultRequestHandler
from a2a.server.tasks import InMemoryTaskStore

class MyExecutor(AgentExecutor):
    async def execute(self, context, event_queue):
        user_input = context.get_user_input()
        result = await my_logic(user_input)
        await event_queue.enqueue_event(new_agent_text_message(result))

    async def cancel(self, context, event_queue):
        raise Exception("cancel not supported")

handler = DefaultRequestHandler(
    agent_executor=MyExecutor(),
    task_store=InMemoryTaskStore(),
)
server = A2AStarletteApplication(agent_card=agent_card, http_handler=handler)
app = server.build()
# Run: uvicorn module:app --host 0.0.0.0 --port 8080
```

### 5. Wire Orchestrator to Remote A2A Agents (ADK)

```python
from google.adk.agents import LlmAgent
from google.adk.agents.remote_a2a_agent import RemoteA2aAgent, AGENT_CARD_WELL_KNOWN_PATH

climate = RemoteA2aAgent(
    name='climate_agent',
    description='Analyzes climate risk remotely',
    agent_card=f'http://localhost:8081/a2a/climate_agent{AGENT_CARD_WELL_KNOWN_PATH}',
    use_legacy=False,
)

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='orchestrator',
    instruction='Coordinate disaster response. Delegate climate analysis to climate_agent.',
    sub_agents=[climate],
)
```

## Task Lifecycle State Machine

```
submitted → working → completed (terminal)
                    → failed (terminal)
                    → canceled (terminal)
                    → rejected (terminal)
                    → input-required (resumes on next message)
                    → auth-required (client must re-auth)
```

## JSON-RPC Methods

| Method | Purpose |
|--------|---------|
| `message/send` | Synchronous request/response (use for demos) |
| `message/stream` | SSE streaming (stretch goal) |
| `tasks/get` | Check task status by ID |
| `tasks/cancel` | Cancel in-progress task |

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `TaskNotFoundError` | Invalid/expired task ID | Check task ID, tasks lost on restart with InMemoryTaskStore |
| `ContentTypeNotSupportedError` | Wrong Part type sent | Use `TextPart` for text, `DataPart` for JSON |
| `UnsupportedOperationError` | Method not implemented | Check Agent Card capabilities |
| Connection refused | Agent not running | Verify `uvicorn` is up on the right port |
| Empty artifacts | Executor didn't enqueue results | Check `event_queue.enqueue_event()` call |

## Gotchas

- **Agent Card `url` must be the public URL** — never localhost. Hardcode Cloud Run URLs after deploy.
- **`InMemoryTaskStore` loses all state on restart** — design demos to start fresh.
- **Declare `streaming=True`** in capabilities from the start, even if you only use `message/send`.
- **`to_a2a()` auto-generates a minimal Agent Card** — override with custom card for accurate skill declarations.
- **v1.0.0 method names differ from early drafts** — use `message/send` not `tasks/send`.
- **Verify `google-adk[a2a]` and `a2a-sdk` target the same protocol version.**
- **Use `message/send` for demos** — push notifications require HTTPS webhooks.

## A2A vs MCP Quick Reference

| | A2A | MCP |
|--|-----|-----|
| Connects | Agent ↔ Agent | Agent → Tool |
| State | Stateful task lifecycle | Stateless function calls |
| Discovery | Agent Card at `/.well-known/` | Tool list from server |
| Use when | Delegating to another AI agent | Calling APIs, databases, files |

## Recommended Topology: Hub-and-Spoke

```
User → [Orchestrator :8080]
           ├→ [Climate Agent :8081]
           ├→ [Health Agent :8082]
           └→ [Response Agent :8083]
```

- Predictable, easy to debug under time pressure
- Each agent is a Cloud Run service
- Orchestrator discovers specialists via Agent Cards

## Key Resources

- [A2A Protocol Spec](https://a2a-protocol.org/latest/)
- [A2A GitHub (Linux Foundation)](https://github.com/a2aproject/A2A)
- [A2A Python SDK](https://github.com/a2aproject/a2a-python)
- [A2A Samples](https://github.com/a2aproject/a2a-samples)
- [ADK A2A Quickstart](https://google.github.io/adk-docs/a2a/quickstart-exposing/)
- [A2A vs MCP (official)](https://a2a-protocol.org/latest/topics/a2a-and-mcp/)
- [DeepLearning.AI A2A Course (free)](https://www.deeplearning.ai/short-courses/a2a-the-agent2agent-protocol/)
