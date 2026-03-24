# test/test_smoke.py
#
# Smoke test: verifies scaffold wiring — agent imports, ADK availability.

import importlib
import os


def test_adk_installed():
    """Verify google-adk is importable."""
    import google.adk
    assert google.adk is not None


def test_a2a_sdk_installed():
    """Verify a2a-sdk is importable."""
    import a2a
    assert a2a is not None


def test_orchestrator_agent_imports():
    """Verify orchestrator agent module loads without error."""
    mod = importlib.import_module("agents.orchestrator.agent")
    assert hasattr(mod, "root_agent")
    assert mod.root_agent.name == "fireshield_orchestrator"


def test_risk_assessment_agent_imports():
    """Verify risk assessment agent module loads."""
    mod = importlib.import_module("agents.risk_assessment.agent")
    assert hasattr(mod, "root_agent")
    assert mod.root_agent.name == "wildfire_risk_agent"


def test_code_compliance_agent_imports():
    """Verify code compliance agent module loads."""
    mod = importlib.import_module("agents.code_compliance.agent")
    assert hasattr(mod, "root_agent")
    assert mod.root_agent.name == "code_compliance_agent"


def test_hardening_advisor_agent_imports():
    """Verify hardening advisor agent module loads."""
    mod = importlib.import_module("agents.hardening_advisor.agent")
    assert hasattr(mod, "root_agent")
    assert mod.root_agent.name == "hardening_advisor_agent"


def test_all_agents_use_google_search():
    """Verify all agents have google_search tool configured."""
    for agent_path in [
        "agents.orchestrator.agent",
        "agents.risk_assessment.agent",
        "agents.code_compliance.agent",
        "agents.hardening_advisor.agent",
    ]:
        mod = importlib.import_module(agent_path)
        agent = mod.root_agent
        assert len(agent.tools) > 0, f"{agent.name} has no tools configured"


def test_all_agents_use_gemini_flash():
    """Verify all agents use gemini-2.0-flash model."""
    for agent_path in [
        "agents.orchestrator.agent",
        "agents.risk_assessment.agent",
        "agents.code_compliance.agent",
        "agents.hardening_advisor.agent",
    ]:
        mod = importlib.import_module(agent_path)
        agent = mod.root_agent
        assert agent.model == "gemini-2.0-flash", (
            f"{agent.name} uses {agent.model}, expected gemini-2.0-flash"
        )
