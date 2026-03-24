# Contributing to HackUSF 2026

> **You do NOT need any special Claude Code plugins installed** — all commands and skills are included in this repo's `.claude/` directory.

## Getting Started

Clone the repo, run `claude` in the project root, then type `/hack` to pick up your first task.

```bash
gh repo clone fshot/hackusf-test
cd hackusf-test
pnpm install
cp .env.example .env
# Fill in credential values — see "Credential Setup" below
claude
# Then type: /hack
```

## Prerequisites

- [ ] Node.js 20+
- [ ] pnpm 9+
- [ ] GitHub CLI (`gh`) authenticated
- [ ] Terraform 1.5+ (if using IaC)
- [ ] Docker (for LocalStack)
- [ ] Claude Code CLI

## Workflow

1. Check the tracking issue (#1) for current phase and priorities.
2. Run `/hack` in Claude Code to pick up your next task.
3. Claude generates a plan file in `docs/plans/` — review and approve it.
4. Claude implements in a worktree, creates a PR.
5. Review the PR, merge to main.

## Credential Setup

### GitHub PAT

1. Go to https://github.com/settings/tokens?type=beta
2. Generate token with: Contents, Issues, Pull requests, Projects (Read/Write)
3. Scope to this repository only
4. Set 7-day expiry
5. Add to `.env` as `GITHUB_TOKEN`

### Google Cloud (for ADK challenge track)

1. Create a GCP project or use hackathon-provided credits ($50)
2. Enable required APIs (Agent Builder, etc.)
3. Create a service account key
4. Add to `.env`:
   - `GOOGLE_CLOUD_PROJECT=your-project-id`
   - `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json`

## Config Validation

Run this to verify all credentials are working:

```bash
source .env

echo "--- GitHub ---"
gh api user --jq '.login'

echo "--- Google Cloud ---"
gcloud auth print-access-token 2>/dev/null && echo "OK" || echo "Not configured (may not be needed yet)"
```

## Project Structure

```
├── .claude/
│   ├── CLAUDE.md              # Project instructions for Claude
│   ├── commands/              # /hack, /checkpoint commands
│   ├── agents/                # tool-researcher agent
│   └── skills/                # hackathon-rules, hackathon-sdlc
├── docs/
│   ├── plans/                 # Timestamped plan files
│   └── tools/                 # Per-tool integration docs
├── infra/                     # Terraform root module
├── src/                       # Application source code
├── test/
│   ├── e2e/                   # Playwright E2E tests
│   └── fixtures/
│       └── expected-violations/  # Ground truth for validation
├── .env.example               # Required environment variables
├── .gitignore
└── CONTRIBUTING.md
```
