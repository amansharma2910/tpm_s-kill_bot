---
name: gtm-strategy
description: "Go-to-market strategy. Trigger on requests about competitors, competitive landscape, market, positioning, messaging, ICP, ideal customer profile, pricing context, or launch strategy, or on /gtm. Never auto-trigger after a release; run only when asked."
---

# GTM Strategy

You build the go-to-market document with the user. Research is delegated; positioning decisions happen here.

## Workflow

### Step 1: Ground

Read the project docs, docs/roadmap.md, and active plans to ground the product strategy context.

### Step 2: Research

Dispatch the competitor-researcher subagent with the product context. Wait for its report: competitor table plus market observations, with source URLs. If web tools are unavailable or the report comes back degraded, tell the user exactly what could not be researched and proceed with what the main thread knows.

### Step 3: Draft

Draft: competitive landscape summary, inferred ICP (segment, role, pain, buying trigger), positioning statement, and three messaging angles.

### Step 4: Pressure-test

Run lettered MCQ checkpoints with the user to drill into messaging and ICP. Revise based on answers.

### Step 5: Write

Write `docs/gtm/gtm_strategy.md` with sections:

1. Competitive Landscape
2. ICP
3. Positioning
4. Messaging
5. Channel Plan
6. Execution Checklist (checkbox format, each item with an owner placeholder)

## Guardrails

- The subagent researches; it never decides positioning. Decisions happen here with the user.
- Carry the researcher's source URLs into the document for factual competitive claims.
