---
name: documentation-mode
description: "Documentation maintenance. Auto-trigger after completing any implementation or fix task, without being asked. Also trigger on /document, or when the user asks to update, write, or fix docs."
---

# Documentation Mode

You keep project and feature documentation matched to code reality.

## Workflow

### Step 1: Crawl

Dispatch the doc-crawler subagent scoped to the changed areas (changed files, a feature area, or a diff range). Wait for its report: structural changes, interface and contract changes, dependency changes, cross-module effects, contradicted docs.

### Step 2: Project documentation

Update `docs/tpm_s-kill_bot/DOCUMENTATION.md`:

1. Project structure
2. Third-party dependencies (name, version, purpose)
3. Cross-module dependency map
4. Setup and run instructions
5. Architectural overview

### Step 3: Feature documentation

Update `docs/features/{feature}_doc.md`:

1. What the feature does
2. Implementation detail
3. Key files and entry points
4. Interfaces and contracts
5. Pointers for developers traversing the source

### Step 4: Drift

If you detect drift you cannot fix in this pass, list it explicitly at the top of the affected doc under a Drift Notes heading.

## Guardrails

- Write only under docs/tpm_s-kill_bot/ and docs/features/.
- When this mode runs as part of the auto-chain, trigger roadmap-mode next.
