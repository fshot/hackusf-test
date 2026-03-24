---
description: Pick up your next hackathon task — detects your identity, finds your highest-priority issue, checks for a plan, and executes
argument-hint: "[issue-number] — optionally specify an issue to work on"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Agent, Skill, AskUserQuestion, WebFetch, WebSearch, TaskCreate, TaskUpdate, TaskList
---

# /hack — Contributor Workflow

You are a hackathon contributor. Follow this workflow to pick up and execute your next task.

## Rules

- **Plans before code** — every issue needs a committed plan in `docs/plans/` before any implementation begins.
- **P0 before P1 before P2** — strict priority ordering. Never start a lower-priority issue while a higher one is unblocked and assigned to you.
- **One owner per issue** — do not take work already assigned to someone else.
- **Commit frequently** — small, incremental commits. Do not accumulate large uncommitted changes.
- **Reference the hackathon-sdlc project skill** for plan format, branching strategy, and quality gates.

## Step 1: Identify Yourself

```bash
MY_EMAIL=$(git config user.email)
echo "Current user: $MY_EMAIL"
```

Read tracking issue #1 to find the Team Roster table. Match your email or GitHub username to determine your identity and role.

## Step 2: Pick an Issue

If `$ARGUMENTS` contains an issue number, use that issue:

```bash
gh issue view $ARGUMENTS --json number,title,assignees,labels,body
```

Otherwise, find your highest-priority unblocked issue:

```bash
# Try P0 first, then P1, then P2
gh issue list --assignee @me --state open --label P0 --json number,title,labels
gh issue list --assignee @me --state open --label P1 --json number,title,labels
gh issue list --assignee @me --state open --label P2 --json number,title,labels
```

Pick the first issue from the highest available priority level. If no issues are assigned to you, report that and ask what to pick up.

## Step 3: Check for an Approved Plan

Look for a plan file referencing this issue:

```bash
grep -rl "issue.*#ISSUE_NUMBER" docs/plans/ 2>/dev/null
```

Also list recent plan files to check manually:

```bash
ls -la docs/plans/
```

### If no plan exists:

1. Use the hackathon-sdlc skill's plan template to generate a plan.
2. Save it to `docs/plans/YYYY-MM-DD-HHMM-<description>.md` using the current timestamp.
3. Commit the plan to main:
   ```bash
   git add docs/plans/
   git commit -m "docs(plan): plan for #ISSUE_NUMBER — DESCRIPTION"
   git push
   ```
4. Present the plan to the user and ask for approval before proceeding.

### If a plan exists:

Read the plan file and proceed to implementation.

## Step 4: Implement

1. Create a worktree from main:
   ```bash
   git worktree add ../hackusf-test-ISSUE_NUMBER -b feat/ISSUE_NUMBER-SLUG
   ```
2. Work in the worktree. Follow the plan step by step.
3. Commit frequently with messages referencing the issue number.
4. Run quality gates: lint, type-check, tests.

## Step 5: Create PR

```bash
cd ../hackusf-test-ISSUE_NUMBER
gh pr create --title "feat: DESCRIPTION (#ISSUE_NUMBER)" \
  --body "## Plan

See \`docs/plans/PLAN_FILENAME\`

Closes #ISSUE_NUMBER"
```

## Step 6: Loop

After the PR is created, tell the user:

> PR created. Run `/hack` to pick up your next issue.
