---
name: hackathon-sdlc
description: Spec-driven development process for hackathon projects. Covers plan format, branching strategy, priority enforcement, and quality gates.
---

# Hackathon SDLC

## Core Principle

No code without an approved plan. Plans committed before implementation.

## Plan Format

Every work item requires a plan file before implementation begins.

**Path:** `docs/plans/YYYY-MM-DD-HHMM-<description>.md`

**Template:**

```markdown
---
issue: "#<ISSUE_NUMBER>"
assignee: "<GITHUB_USERNAME>"
checkpoint: "<CHECKPOINT>"
priority: "<PRIORITY>"
---

# Plan: <TITLE>

## Goal

What this work item achieves and why it matters for the demo.

## Approach

Step-by-step implementation plan.

## Files to Create/Modify

- `path/to/file.ts` — description of changes

## Test Plan

- [ ] Unit tests for ...
- [ ] E2E test for ...
- [ ] Manual verification: ...

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
```

## Branching Strategy

1. Plan file is committed and pushed to `main`.
2. Create a worktree for implementation:
   ```bash
   git worktree add ../hackusf-test-<ISSUE_NUMBER> -b feat/<ISSUE_NUMBER>-<SLUG>
   ```
3. Implement in the worktree.
4. Create PR referencing the plan file and issue.
5. Merge to main after review.
6. Clean up worktree:
   ```bash
   git worktree remove ../hackusf-test-<ISSUE_NUMBER>
   ```

## Priority Enforcement

| Priority | Rule |
|----------|------|
| P0 | Must be done before C4. Demo breaks without this. |
| P1 | Do if P0s are on track. Bonus points or wow factor. |
| P2 | Only if time after P1s. Nice-to-have polish. |
| P-lagniappe | Only if C4 is green, 2-3hr max, zero guilt if cut. |

**Strict ordering:** P0 → P1 → P2 → P-lagniappe. Never start a lower priority while a higher priority is incomplete, unless blocked.

## Quality Gates

Before marking any task complete:

1. **Lint:** `pnpm lint` passes
2. **Type check:** `pnpm tsc --noEmit` passes
3. **Unit tests:** `pnpm test` passes
4. **E2E tests:** `pnpm test:e2e` passes (if applicable)
5. **Manual verification:** Feature works as described in the plan
6. **Edge cases:** Checked and handled

## Checkpoint Reviews

At each checkpoint (C0-C7), review:

- Are all tasks for this checkpoint complete?
- Are we on track for the next checkpoint?
- Do we need to cut scope?

**Scope cut protocol:**
1. List all incomplete P1+ items.
2. For each, ask: "Does the demo work without this?"
3. If yes, cut it. Move to P2 or close.
4. Update tracking issue with scope cut decisions.
5. Add comment to tracking issue explaining cuts.

## Commit Messages

Format: `type(scope): description (#issue)`

Types: `feat`, `fix`, `docs`, `test`, `infra`, `chore`
