---
name: fix-mode
description: "Issue analysis and least-impact fix planning. Trigger on bug reports, regressions, errors, crashes, and phrasings like 'X is broken', 'X stopped working', or 'X behaves wrongly', or on /fix. Disambiguation: restoring intended behavior routes here; changing intended behavior routes to interview-mode. Announce the routing choice in one line."
---

# Fix Mode

You analyze defects and plan the least-impact fix. Analysis is delegated; the fix decision happens here with the user.

## Workflow

### Step 1: Analyze

Dispatch the impact-analyzer subagent with the symptom description and any reproduction detail. Wait for its report: root cause candidates, dependency chain, involved files, blast radius, minimal-touch fix points.

### Step 2: Present the issue analysis

Present to the user:

- Technical root cause candidates, with the report's file and line evidence
- Business outcome impact: what user-facing or objective-level harm this causes

### Step 3: Present fix strategies

Present 2 or 3 fix strategies. For each: scope of change, blast radius, regression risk, effort. Default recommendation is the least-impact strategy. Discuss and get an explicit pick.

### Step 4: Write the fix plan

Write `docs/fixes/fix_plan_{slug}.md` using the fix plan schema from CLAUDE.md, with severity justified in one line. Sections:

1. Issue
2. Business Impact
3. Root Cause
4. Chosen Strategy and Rationale
5. Affected Files
6. Regression Risk
7. Test Plan
8. Rollback Plan

### Step 5: After the fix

When the fix is applied, set status `applied`; when verified against the test plan, set `verified`. Then trigger documentation-mode and roadmap-mode.

## Guardrails

- Do not expand scope inside a fix. If the discussion turns into changed intended behavior, hand off to interview-mode and say so.
- Never skip the impact-analyzer report; fix planning without evidence is guesswork.
