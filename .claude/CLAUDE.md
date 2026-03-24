# HackUSF 2026 — Project Instructions

## Project Overview

This is a hackathon project for **HackUSF 2026** (March 28-29, 2026).
Hackathon duration: 24 hours.
Challenge tracks: General, Google Cloud ADK, Oracle
Team members: _Run `/hackprep team` to populate_

## Session Start

At the start of every session, run `gh issue view 1 --json title,state,body -q '.title + "\nState: " + .state + "\n\n" + .body'` to load the current hackathon state from the tracking issue. This gives you the phase checklist, checkpoint timeline, team roster, and sponsor tools status. Do this before any other work.

## Commands

- `/hack` — Pick up your next task. Detects your identity, finds your highest-priority unblocked issue, ensures there's an approved plan, then executes it in a worktree.
- `/checkpoint` — Review progress against the timeline. Shows status dashboard, identifies risks, suggests scope cuts.

## Project Skills

These skills are loaded automatically and provide context about the hackathon:
- `hackathon-rules` — Parsed rules, scoring rubric, timeline, submission requirements
- `hackathon-sdlc` — Spec-driven development process for this hackathon

## Workflow

1. Run `/hack` to get your next assigned issue
2. A plan will be generated (or loaded) from docs/plans/
3. Implementation happens in a worktree branched from main
4. Follow TDD: write tests first, then implement
5. Create a PR when done — reference the plan file
6. Run `/hack` again for your next issue
7. Run `/checkpoint` periodically to check team progress

## Tech Stack

- Runtime: Python 3.10+
- Package manager: uv
- Framework: Google ADK (Agent Development Kit)
- LLM: Gemini 2.0 Flash (via Gemini API / Vertex AI)
- Protocol: A2A (Agent-to-Agent) for multi-agent communication
- Deployment: Google Cloud Run with `adk deploy cloud_run --with_ui`
- Testing: pytest
- State: GitHub Issues + Projects

## Important Rules

- **Plans before code.** No code without an approved plan in `docs/plans/`.
- **P0 before P1 before P2.** Always work on the highest-priority unblocked issue.
- **No new features after C5.** Final checkpoint is for polish, bug fixes, and submission only.
- **Commit frequently** with descriptive messages. Small, focused commits.
- **Plan format:** `docs/plans/YYYY-MM-DD-HHMM-<description>.md`
- **Branching:** Worktrees from main. PR back to main.
- **Tracking issue:** #1 is the single source of truth.

## Credentials

All credentials are in `.env` (gitignored). See `.env.example` for required vars.
For local dev: set `GOOGLE_API_KEY` (free from https://aistudio.google.com/apikey).
For deployment: switch to Vertex AI with `GOOGLE_GENAI_USE_VERTEXAI=TRUE`.

## Key Commands

- `./scripts/dev.sh` — Start ADK dev UI (all agents, http://localhost:8000)
- `./scripts/run-a2a.sh` — Start all agents as A2A servers + orchestrator UI
- `./scripts/verify-agents.sh` — Health check all running agents
- `./scripts/deploy.sh <PROJECT_ID>` — Deploy all agents to Cloud Run
- `uv run pytest` — Run tests
- `uv run adk web agents/` — ADK dev UI (manual)

## Scoring Rubric

| Criterion | Weight |
|-----------|--------|
| Originality/Innovation | 20% |
| Expertise | 20% |
| Functionality | 20% |
| Design | 20% |
| Technical Learning | 20% |

## Sponsor Tools

| Tool | Track | Notes |
|------|-------|-------|
| Google ADK | Google Cloud challenge | Agent Development Kit for multi-agent systems |
| Google A2A Protocol | Google Cloud challenge | Agent-to-Agent communication protocol |

## Quality Gates

- All PRs must reference a plan file and the tracking issue.
- Run `uv run pytest` before marking any task complete.
- Verify agents respond correctly via `adk web` or `scripts/verify-agents.sh`.
- Verification before completion: test the feature manually, check for edge cases.
