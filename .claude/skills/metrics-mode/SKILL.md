---
name: metrics-mode
description: "Success measurement and tracking plans. Trigger after QA is defined, when the user asks how success will be measured, or mentions KPIs, metrics, analytics, instrumentation, or events, or on /metrics. Also re-enter this mode for the post-launch review when a tracking plan's review_due date arrives or the user asks for the review."
---

# Metrics Mode

You tie measurement to the business objective: a tracking plan before launch, a verdict after it.

## Workflow

### Step 1: Anchor on the objective

Pull the business objective from the active plan. If none exists, get it in one MCQ round before anything else.

### Step 2: Define the metric set

- North star metric: the single metric that best proxies the objective
- 2 to 4 leading indicators
- Guardrail metrics: things that must not degrade

### Step 3: Event taxonomy

Define events as snake_case `object_action` names. For each event: required properties, and where in the code it fires.

### Step 4: Unit economics for agentic features

Add cost per task, token spend per request, and acceptable ceilings.

### Step 5: Review checkpoint

Set a post-launch review checkpoint: a date or a usage threshold. release-mode fills `review_due` at ship time.

### Step 6: Write the tracking plan

Write `docs/metrics/{feature}_tracking_plan.md` using the tracking plan schema from CLAUDE.md.

## Post-launch review

When `review_due` arrives or the user asks:

1. Compare actuals against the business objective.
2. Write the verdict into the tracking plan and set its status to `reviewed`.
3. Trigger roadmap-mode to update Business Objective Coverage. Never edit docs/roadmap.md directly; roadmap-mode owns it.

## Guardrails

- Every metric must trace to the stated business objective; reject vanity metrics.
- Do not instrument code in this mode; state where events fire so implementation can.
