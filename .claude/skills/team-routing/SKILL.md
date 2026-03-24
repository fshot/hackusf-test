---
name: team-routing
description: Task assignment heuristics based on team member strengths, availability, and tool familiarity. Used by other skills to pick the right assignee.
---

# Team Routing

## Current User Detection

Detect who is running Claude Code right now:

```bash
git config user.email
```

Match the email against the roster below to identify the current user.

## Team Roster

| GitHub | Display Name | Strengths (ranked) | Gaps | Known Tools | Hours Available | Comms | Dev Env |
|--------|-------------|---------------------|------|-------------|-----------------|-------|---------|
| @fshot | fshot | 1. Claude Code, 2. AWS, 3. GCP, 4. GitHub/DevOps, 5. Multitasking | None specified | AWS, GCP, GitHub, Claude Code, Docker, VS Code | 24 | Slack: fshot | macOS, VS Code, Docker, Claude Code |

## Assignment Heuristics

With a single team member, all tasks are assigned to @fshot. The heuristics below apply if the team grows.

### 1. Match by Strength

Assign the task to the team member whose **top-ranked strength** best matches the task's primary skill requirement. Prefer a #1-ranked strength over a #3-ranked strength on another member.

### 2. Spread Tool Ownership

If a task involves a specific sponsor tool (e.g., Google ADK), prefer the member who listed it in **Known Tools**. If multiple members know the tool, prefer the one with fewer tool-ownership assignments so far.

### 3. Respect Availability

Never assign to a member who has already been assigned more hours of work than their **Hours Available**. Track running totals. If a member is approaching their limit, prefer someone with more headroom.

### 4. Pair on Gaps

If a task falls in a member's **Gaps** area but they need to learn it, assign them as a **secondary** with a stronger member as **primary**. The primary implements; the secondary reviews and learns.

### 5. Single Owner

Every task has exactly **one owner** (the assignee on the GitHub issue). Pairing is encouraged, but one person is accountable for completion.

### 6. Tiebreaker

If multiple members are equally qualified, prefer:
1. The member with more available hours remaining
2. The member who has completed fewer tasks so far (balance workload)
3. The current user (minimize context-switching overhead)

## Usage

Other skills reference this skill when they need to assign work. Example:

> "Based on the team-routing heuristics, this task should go to **@fshot** (sole team member, 24 hours available)."
