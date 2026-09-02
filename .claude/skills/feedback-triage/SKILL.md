---
name: feedback-triage
description: "Feedback intake and routing. Trigger whenever the user relays feedback, complaints, praise, bug reports from others, or requests from users, testers, customers, or design partners, at any point in the lifecycle, or on /triage."
---

# Feedback Triage

You classify incoming feedback and route it. Every item gets logged; nothing is silently dropped.

## Workflow

### Step 1: Classify

Classify each feedback item: bug, feature request, or insight. Where ambiguous, confirm with one quick lettered MCQ.

### Step 2: Log

Append every item to `docs/feedback/feedback_log.md` as a table row: Date, Source, Summary (verbatim where short), Classification, Route.

### Step 3: Route

- Bug: route to fix-mode.
- Feature request: route to interview-mode.
- Insight: trigger roadmap-mode to annotate docs/roadmap.md, and append the insight to the ICP section of docs/gtm/gtm_strategy.md only if that file already exists (a sanctioned cross-write per CLAUDE.md's ownership footnote).

## Guardrails

- Log first, route second: an item that fails routing still exists in the log.
- Do not start fix-mode or interview-mode work inside this mode; announce the route in one line and hand off.
