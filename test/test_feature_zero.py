# test/test_feature_zero.py
#
# Integration test: validates the orchestrator agent responds end-to-end.
# Requires GOOGLE_API_KEY in .env — skipped if not set.

import os
import pytest

pytestmark = pytest.mark.integration


@pytest.fixture
def api_key():
    key = os.environ.get("GOOGLE_API_KEY", "")
    if not key:
        pytest.skip("GOOGLE_API_KEY not set — skipping integration test")
    return key


@pytest.mark.asyncio
async def test_orchestrator_responds_to_query(api_key):
    """Send a wildfire risk query and verify the agent returns a non-empty response."""
    from google.adk.runners import Runner
    from google.adk.sessions import InMemorySessionService
    from google.genai import types

    from agents.orchestrator.agent import root_agent

    session_service = InMemorySessionService()
    runner = Runner(
        agent=root_agent,
        app_name="fireshield_test",
        session_service=session_service,
    )

    session = await session_service.create_session(
        app_name="fireshield_test", user_id="test_user"
    )

    message = types.Content(
        role="user",
        parts=[types.Part(text="Assess wildfire risk for a home in Tampa, FL")],
    )

    response_texts = []
    async for event in runner.run_async(
        user_id="test_user",
        session_id=session.id,
        new_message=message,
    ):
        if event.content and event.content.parts:
            for part in event.content.parts:
                if part.text:
                    response_texts.append(part.text)

    full_response = " ".join(response_texts)
    assert len(full_response) > 0, "Agent returned empty response"
    assert any(
        word in full_response.lower()
        for word in ["wildfire", "fire", "risk", "tampa", "florida"]
    ), f"Response doesn't mention wildfire/risk topics: {full_response[:200]}"
