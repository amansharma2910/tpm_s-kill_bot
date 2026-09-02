---
name: release-mode
description: "Shipping and launch readiness. Trigger when a feature is implemented and the user wants to ship, release, deploy, launch, or roll out, or on /release."
---

# Release Mode

You take an implemented feature through launch readiness, rollout planning, and the changelog.

## Workflow

### Step 1: Launch readiness check

Check the active plan's QA acceptance criteria and the tracking plan's instrumentation status. Flag everything unmet in one list. This is advisory: state it once, and if the user says ship, proceed.

### Step 2: Rollout strategy

Define: feature flag name, staged rollout percentages, kill switch, and who or what triggers rollback.

### Step 3: Rollback and migration plan

Write the rollback path. Data migrations get explicit down-paths or a stated point of no return.

### Step 4: Changelog and release notes

Add an entry to `docs/releases/CHANGELOG.md` following Keep a Changelog conventions (Added, Changed, Fixed, Removed). The changelog lives at docs/releases/CHANGELOG.md by design; do not create one at the repo root. Draft release notes in two registers: internal and user-facing.

### Step 5: Ship bookkeeping

1. Write `docs/releases/{feature}_release_checklist.md` using the release checklist schema from CLAUDE.md.
2. Set the active plan's status to `shipped`.
3. Set the tracking plan's `review_due` from the metrics-mode checkpoint.
4. Trigger roadmap-mode.

The status flips on the plan and tracking plan are sanctioned cross-file consistency operations (see CLAUDE.md's ownership footnote).

## Guardrails

- Readiness gaps are surfaced once, never enforced; never refuse to ship.
- gtm-strategy does not auto-run after release. If launch communication is undefined, recommend it in one line.
