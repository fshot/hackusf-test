# Google A2A (Agent-to-Agent) Protocol

## What

A2A is an open protocol (v1.0.0, Linux Foundation) that enables AI agents to discover each other and delegate tasks using JSON-RPC 2.0 over HTTP/SSE. It defines Agent Cards for discovery, a task lifecycle state machine, and message formats for multi-turn conversations between autonomous agents. We're using it because the Google Cloud challenge track requires ADK + A2A.

## Why

The hackathon challenge requires "multi-agent ecosystems." A2A provides the communication layer between our specialist agents (climate, health, disaster response) and the orchestrator. While ADK handles agent logic, A2A handles agent-to-agent wiring — discovery, delegation, and result collection.

## Setup

A2A is a protocol, not a SaaS product — no sign-up needed.

### 1. Install Dependencies

```bash
# A2A support comes with ADK
pip install google-adk[a2a]

# Or standalone SDK for custom servers
pip install a2a-sdk[http-server]
```

### 2. No Additional Credentials Needed

A2A itself requires no API keys. Your agents use Gemini API keys (already configured from ADK setup) for their LLM calls.

## Quick Start

```bash
# Create a simple A2A agent
cat > agent.py << 'EOF'
from google.adk.agents import LlmAgent
from google.adk.a2a.utils.agent_to_a2a import to_a2a

root_agent = LlmAgent(
    model='gemini-2.0-flash',
    name='test_agent',
    description='A test A2A agent',
    instruction='You are a helpful test agent.',
)
app = to_a2a(root_agent, port=8081)
EOF

# Run it
uvicorn agent:app --host 0.0.0.0 --port 8081

# In another terminal, verify Agent Card:
curl http://localhost:8081/.well-known/agent-card.json | python -m json.tool

# Send a test message:
curl -X POST http://localhost:8081 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"message/send","params":{"message":{"role":"user","parts":[{"kind":"text","text":"Hello!"}],"messageId":"test-1"}}}'
```

## Links

- [A2A Protocol Spec](https://a2a-protocol.org/latest/)
- [A2A GitHub](https://github.com/a2aproject/A2A)
- [A2A Python SDK](https://github.com/a2aproject/a2a-python)
- [A2A Samples](https://github.com/a2aproject/a2a-samples)
- [ADK A2A Quickstart](https://google.github.io/adk-docs/a2a/quickstart-exposing/)
- [A2A vs MCP](https://a2a-protocol.org/latest/topics/a2a-and-mcp/)
- [DeepLearning.AI A2A Course](https://www.deeplearning.ai/short-courses/a2a-the-agent2agent-protocol/)
