---
description: Check hackathon progress against the timeline — shows status dashboard, identifies risks, suggests scope cuts
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion
---

# /checkpoint — Progress Review

You are reviewing hackathon progress against the checkpoint timeline.

## Step 1: Read Tracking State

```bash
gh issue view 1 --json body --jq '.body'
```

Parse the tracking issue to extract:
- **Checkpoint Timeline** table (C0-C7 with target times)
- **Hacking start time** (C0 target time)
- **Phase Checklist** status

## Step 2: Compute Current Checkpoint

Determine the current time and compute elapsed hours since hacking started:

```bash
echo "Current time: $(date -u '+%Y-%m-%d %H:%M UTC')"
```

Compare elapsed time against the checkpoint timeline offsets to determine which checkpoint window you are in.

## Step 3: Check Issue Status

```bash
echo "=== P0 Issues ==="
gh issue list --state open --label P0 --json number,title,assignees

echo "=== P1 Issues ==="
gh issue list --state open --label P1 --json number,title,assignees

echo "=== P2 Issues ==="
gh issue list --state open --label P2 --json number,title,assignees

echo "=== Closed Issues ==="
gh issue list --state closed --json number,title,labels
```

## Step 4: Check PR Status

```bash
gh pr list --state open --json number,title,author,reviewDecision
gh pr list --state merged --json number,title
```

## Step 5: Status Dashboard

Present a dashboard using this format:

```
╔══════════════════════════════════════════════════════╗
║              HACKATHON STATUS — Checkpoint Cx        ║
╠══════════════════════════════════════════════════════╣
║ Elapsed:  Xh XXm / 24h total                        ║
║ Remaining: Xh XXm                                    ║
╠══════════════════════════════════════════════════════╣
║ P0 Issues:  X open / Y total     [GREEN/YELLOW/RED] ║
║ P1 Issues:  X open / Y total     [GREEN/YELLOW/RED] ║
║ P2 Issues:  X open / Y total     [GREEN/YELLOW/RED] ║
║ Open PRs:   X                    [GREEN/YELLOW/RED] ║
╠══════════════════════════════════════════════════════╣
║ Overall:    [GREEN/YELLOW/RED]                       ║
╚══════════════════════════════════════════════════════╝
```

Color rules:
- **GREEN**: On track. P0s done or in progress with time remaining.
- **YELLOW**: At risk. P0s behind schedule but recoverable with scope cuts.
- **RED**: Behind. P0s blocked or insufficient time to complete.

## Step 6: Scope Cut Recommendations (if behind)

If status is YELLOW or RED, suggest scope cuts following this protocol:

1. **Cut P-lagniappe first** — remove any nice-to-have items
2. **Cut P2 next** — close or deprioritize polish items
3. **Reduce P1 scope** — simplify P1 items to minimum viable versions
4. **Simplify P0 scope** — only as last resort, reduce P0 to bare minimum for demo

For each cut, explain what is lost and what is saved in time.

## Step 7: Update Tracking Issue

Add a checkpoint comment to the tracking issue:

```bash
gh issue comment 1 --body "## Checkpoint Cx — STATUS

**Elapsed:** Xh XXm
**P0:** X/Y complete
**P1:** X/Y complete
**P2:** X/Y complete
**Open PRs:** X

**Risks:** (list any)
**Scope cuts:** (list any decisions made)

**Next checkpoint:** Cx+1 at TIME"
```
