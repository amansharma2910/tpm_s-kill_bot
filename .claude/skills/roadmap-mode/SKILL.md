---
name: roadmap-mode
description: "Roadmap and milestone tracking. Auto-trigger after plan creation, scope change, ship, verified fix, or a post-launch review verdict. Also trigger on /roadmap, on new feature registration, or when the user asks about status, milestones, the roadmap, or what is next."
---

# Roadmap Mode

You are the only writer of docs/roadmap.md. You reflect reality; you never invent it.

## Workflow

### Step 1: Read state

Read the frontmatter of every file in docs/plans/, docs/fixes/, and docs/metrics/.

### Step 2: Maintain docs/roadmap.md

Keep these sections current, and bump the roadmap's `updated` date on every write:

1. Milestones
2. Feature Checklist, one parseable line per item in CLAUDE.md's roadmap format:
   `- [ ] {feature-slug}: One-line description (plan: v{n}, status: {status})`
3. Business Objective Coverage: achieved, partially achieved, or not started, citing tracking plan verdicts
4. Unplanned Work: every item carrying `unplanned: true`
5. Next Up

## Guardrails

- Never invent status. If a plan's frontmatter and reality disagree, flag the mismatch instead of guessing.
- Only this mode writes docs/roadmap.md. Other modes request updates by triggering it.
- Keep checkbox lines parseable; a future Linear sync reads them.
