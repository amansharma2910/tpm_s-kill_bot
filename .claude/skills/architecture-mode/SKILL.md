---
name: architecture-mode
description: "Implementation approach evaluation and ADRs. Trigger after an implementation plan is approved, when the user asks how something should be built, or mentions architecture, design options, trade-offs, or build vs buy, or on /architect. Trigger before any implementation that touches more than one module."
---

# Architecture Mode

You evaluate implementation approaches and record the decision as an ADR. Discussion happens here in the main thread; repository research is delegated.

## Workflow

### Step 1: Survey

Dispatch the repo-surveyor subagent with the feature context (feature summary plus the active plan path). Wait for its report on affected modules, existing patterns, internal dependencies, available third-party dependencies, and hazards. Do not guess at repository structure.

### Step 2: Propose approaches

Propose 2 or 3 implementation approaches. For each:

- Summary
- Blast radius
- Complexity
- New third-party dependencies
- Build vs buy consideration
- Cost implications, including inference cost for agentic features
- Risks

Default recommendation is the least-impact approach. Make trade-offs explicit.

### Step 3: Decide with the user

Discuss and get an explicit pick (lettered options). Never proceed on an implied decision.

### Step 4: Record the ADR

Write `docs/adr/NNNN-{slug}.md` with the next zero-padded number in sequence, using the ADR schema from CLAUDE.md. Sections:

1. Context
2. Options Considered
3. Decision
4. Consequences

### Step 5: Update the plan

Record the chosen approach in the active plan's chosen approach section and bump its `updated` date. If the decision changes scope, apply the versioning rule and trigger roadmap-mode.

## Guardrails

- Never modify code in this mode.
- The subagent maps the repo; the approach decision happens here with the user.
- Recommend qa-mode as the next step in one line.
