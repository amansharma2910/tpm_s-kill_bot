#!/usr/bin/env bash
# install.sh: one-command installer for the TPM Operating System suite.
#
# Installs a senior technical PM operating system for Claude Code into a
# target project repository: CLAUDE.md router, 10 skills, 4 subagents,
# 10 slash commands, and a docs skeleton with Linear-ready frontmatter.
# The project name is derived from the target directory name and applied
# everywhere the suite references it.
#
# Usage:
#   ./install.sh [options] [target-dir]
#   curl -fsSL https://raw.githubusercontent.com/amansharma2910/tpm_s-kill_bot/main/install.sh | bash -s -- [options] [target-dir]
#
# Maintenance rules (see README.md, Maintainer section):
#   1. Embedded files use quoted heredocs with the delimiter TPM_FILE.
#      No embedded file may contain a line consisting of exactly TPM_FILE.
#   2. Any edit to CLAUDE.md, .claude/**, or a docs seed in this repo must
#      be mirrored in the matching heredoc below, and ./install.sh --self-test
#      must pass before committing.
#   3. Portability: bash 3.2 compatible (macOS default). No associative
#      arrays, no ${var,,}, no mapfile, no sed -i, no realpath, printf only,
#      never echo with escapes, bare mktemp -d, zero interactive reads.
#   4. No em dash characters anywhere in this script or its templates.

set -euo pipefail

TPM_SUITE_VERSION="0.1.0"

# Globals
TARGET_ARG=""
TARGET=""
PROJECT_NAME=""
NAME_OVERRIDE=""
DATE_OVERRIDE=""
STAMP_DATE=""
FORCE=0
DRY_RUN=0
SELF_TEST=0
STAGE=""
MANIFEST=""
CHECKS_PASSED=0
CHECKS_TOTAL=9

die() { printf 'install.sh: error: %s\n' "$1" >&2; exit 1; }
note() { printf '%s\n' "$1"; }
warn() { printf 'install.sh: warning: %s\n' "$1" >&2; }

cleanup() { if [ -n "$STAGE" ]; then rm -rf "$STAGE"; fi; }
trap cleanup EXIT

usage() {
  cat <<'TPM_USAGE'
install.sh: one-command installer for the TPM Operating System suite

Usage:
  install.sh [options] [target-dir]

  target-dir          directory to install into (default: current directory)

Options:
  --name NAME         project name override (default: basename of target-dir,
                      sanitized: spaces become hyphens, only letters, digits,
                      dot, underscore, hyphen survive, no leading dot or
                      hyphen, max 64 chars)
  --date YYYY-MM-DD   date stamped into installed docs (default: today)
  --force             replace differing config files, backing each one up to
                      <path>.bak-<date> first; docs state files are never
                      replaced
  --dry-run           render and verify, report what would change, write
                      nothing
  --self-test         maintainer mode: render with the pinned name and date,
                      then diff against this clone's live files
  -h, --help          show this help

Exit codes:
  0  success (including unchanged and kept files)
  1  usage or verification failure
  2  conflicts reported and not forced

Remote one-liner (after the repo is pushed):
  curl -fsSL https://raw.githubusercontent.com/amansharma2910/tpm_s-kill_bot/main/install.sh | bash -s -- [options] [target-dir]
TPM_USAGE
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --name)
        [ $# -ge 2 ] || die "--name requires a value"
        NAME_OVERRIDE="$2"; shift 2 ;;
      --date)
        [ $# -ge 2 ] || die "--date requires a value"
        case "$2" in
          [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) DATE_OVERRIDE="$2" ;;
          *) die "--date must be YYYY-MM-DD, got: $2" ;;
        esac
        shift 2 ;;
      --force) FORCE=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --self-test) SELF_TEST=1; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) die "unknown option: $1 (see --help)" ;;
      *)
        [ -z "$TARGET_ARG" ] || die "multiple target directories given: '$TARGET_ARG' and '$1'"
        TARGET_ARG="$1"; shift ;;
    esac
  done
}

# Sanitize a candidate project name. Guarantees the result contains only
# [A-Za-z0-9._-], has no leading dot or hyphen, and is at most 64 chars.
# The result can therefore never inject shell, glob, or path syntax.
sanitize_name() {
  n="$1"
  n="${n// /-}"
  n="$(printf '%s' "$n" | LC_ALL=C tr -cd 'A-Za-z0-9._-')"
  while :; do
    case "$n" in
      .*|-*) n="${n#?}" ;;
      *) break ;;
    esac
  done
  printf '%s' "${n:0:64}"
}

resolve_target_and_name() {
  if [ -z "$TARGET_ARG" ]; then TARGET_ARG="."; fi
  [ -d "$TARGET_ARG" ] || die "target directory does not exist: $TARGET_ARG"
  TARGET="$(cd "$TARGET_ARG" && pwd)"

  if [ -n "$NAME_OVERRIDE" ]; then
    PROJECT_NAME="$(sanitize_name "$NAME_OVERRIDE")"
    if [ -z "$PROJECT_NAME" ] || [ "$PROJECT_NAME" != "$NAME_OVERRIDE" ]; then
      die "--name '$NAME_OVERRIDE' is not valid; allowed: letters, digits, dot, underscore, hyphen (no leading dot or hyphen), max 64 chars"
    fi
  else
    raw_name="$(basename "$TARGET")"
    PROJECT_NAME="$(sanitize_name "$raw_name")"
    [ -n "$PROJECT_NAME" ] || die "could not derive a project name from directory '$raw_name'; pass --name NAME"
    if [ "$PROJECT_NAME" != "$raw_name" ]; then
      note "project name: $PROJECT_NAME (derived from directory name '$raw_name')"
    fi
  fi

  STAMP_DATE="${DATE_OVERRIDE:-$(date +%Y-%m-%d)}"
}

# Render one embedded file into the staging tree.
# Usage: install_file <relative-path> <<'TPM_FILE' ... TPM_FILE
# The quoted delimiter means no expansion happens inside the heredoc, so
# $ARGUMENTS, backticks, and YAML survive byte for byte. $(cat) strips the
# single trailing newline every template ends with; printf '%s\n' restores
# exactly one. Manifest paths never contain whitespace (the sanitizer
# forbids it), so later unquoted for-loops over MANIFEST are safe.
install_file() {
  rel="$1"
  content="$(cat)"
  content="${content//"{{PROJECT_NAME}}"/$PROJECT_NAME}"
  content="${content//"{{DATE}}"/$STAMP_DATE}"
  case "$content" in
    *'{{'*) die "unsubstituted template token in $rel" ;;
  esac
  mkdir -p "$STAGE/$(dirname "$rel")"
  printf '%s\n' "$content" > "$STAGE/$rel"
  MANIFEST="$MANIFEST$rel
"
}

# Render one empty file (for .gitkeep placeholders).
install_empty() {
  rel="$1"
  mkdir -p "$STAGE/$(dirname "$rel")"
  printf '' > "$STAGE/$rel"
  MANIFEST="$MANIFEST$rel
"
}

render_all() {
  render_claude_md
  render_skills
  render_agents
  render_commands
  render_docs
}

render_claude_md() {
  install_file "CLAUDE.md" <<'TPM_FILE'
# {{PROJECT_NAME}}: Senior Technical PM Operating System

## Role

You operate as a senior technical product manager. Defaults:

- Challenge requests before committing to them.
- Prefer evidence over assumption.
- Prefer least-impact changes: the smallest change that achieves the outcome.
- Make trade-offs explicit rather than silently choosing.
- State assumptions instead of silently making them.

## Mode routing

Whenever you auto-select a mode, announce it in one line with the reason, so the user can redirect you.

| Intent signal | Mode |
|---|---|
| New app, new feature, modification, or major refactor requested | interview-mode |
| "How should we build this", or an approved plan with no ADR yet | architecture-mode |
| Plan exists, tests and acceptance criteria not yet defined | qa-mode |
| Business objective defined but no measurement plan | metrics-mode |
| Something is broken, regressed, or behaving wrongly | fix-mode |
| Feature complete, user wants to ship, deploy, or release | release-mode |
| An implementation or fix task just completed | documentation-mode, then roadmap-mode (auto) |
| User relays feedback from users or design partners | feedback-triage |
| Competitors, positioning, launch strategy, messaging, ICP | gtm-strategy |

Disambiguation heuristic: restoring intended behavior routes to fix-mode; changing intended behavior routes to interview-mode. When ambiguous, pick one, announce the choice in one line with the reason, and let the user redirect.

### Auto-triggers

Run these without being asked. Everything else is a recommendation announced in one line.

1. interview-mode completes a plan: roadmap-mode registers the item.
2. An implementation task completes: documentation-mode, then roadmap-mode.
3. A fix is applied and verified: documentation-mode, then roadmap-mode.
4. A ship: release-mode sets the plan status to shipped and the tracking plan review_due, then roadmap-mode.
5. A scope change: bump the plan version, then roadmap-mode in the same session.
6. A post-launch review verdict: roadmap-mode.

gtm-strategy never auto-triggers. It runs only on user request or /gtm.

## Advisory gate

When the user asks for implementation without a current plan, recommend the relevant mode exactly once, state the specific risk of skipping it in one sentence, then comply with whatever the user decides. Never repeat the recommendation in the same session. Never refuse to proceed.

Work shipped without a plan gets `unplanned: true` in its frontmatter and appears in the Unplanned Work section of docs/roadmap.md. Drift is surfaced in review, not blocked at the door.

## File ownership

No mode writes outside its row. The footnote lists the only exceptions.

| Mode | Writes |
|---|---|
| interview-mode | docs/plans/* |
| architecture-mode | docs/adr/*, chosen approach section of the active plan |
| qa-mode | QA section of the active plan, docs/user_testing_documentation.md |
| metrics-mode | docs/metrics/* |
| fix-mode | docs/fixes/* |
| release-mode | docs/releases/* |
| documentation-mode | docs/{{PROJECT_NAME}}/DOCUMENTATION.md, docs/features/* |
| roadmap-mode | docs/roadmap.md |
| feedback-triage | docs/feedback/feedback_log.md |
| gtm-strategy | docs/gtm/* |

Sanctioned cross-writes, limited to lifecycle events: release-mode flips the active plan's status and the tracking plan's review_due at ship time; fix-mode flips its own fix plan statuses; feedback-triage appends an insight note to the ICP section of docs/gtm/gtm_strategy.md when that file already exists. Roadmap annotations always go through roadmap-mode. Only roadmap-mode ever touches docs/roadmap.md. documentation-mode only touches the project and feature docs named in its row.

## File conventions

Dates are YYYY-MM-DD, stamped with the actual date of the write. Slugs are kebab-case and stable for the life of the item. Keep `linear_issue: null` untouched.

**Implementation plan** (docs/plans/implementation_plan_{feature}_{version}.md)

```yaml
---
type: implementation_plan
feature: checkout-flow
version: 1
status: draft            # draft | approved | in_progress | shipped | superseded
unplanned: false
linear_issue: null
created: {{DATE}}
updated: {{DATE}}
---
```

Versioning: clarifications within the same scope update the file in place and bump `updated`. A scope change creates a new file with `version` incremented and sets the old file's status to `superseded`.

**Fix plan** (docs/fixes/fix_plan_{slug}.md)

```yaml
---
type: fix_plan
issue: payment-webhook-timeout
severity: high           # low | medium | high | critical
status: draft            # draft | approved | applied | verified
related_feature: checkout-flow
linear_issue: null
created: {{DATE}}
updated: {{DATE}}
---
```

**ADR** (docs/adr/NNNN-{slug}.md, zero-padded sequence)

```yaml
---
type: adr
id: 0001
status: proposed         # proposed | accepted | superseded
supersedes: null
related_feature: checkout-flow
created: {{DATE}}
---
```

**Tracking plan** (docs/metrics/{feature}_tracking_plan.md)

```yaml
---
type: tracking_plan
feature: checkout-flow
status: draft            # draft | instrumented | reviewed
review_due: null         # set at release time
linear_issue: null
created: {{DATE}}
updated: {{DATE}}
---
```

**Release checklist** (docs/releases/{feature}_release_checklist.md)

```yaml
---
type: release_checklist
feature: checkout-flow
status: draft            # draft | ready | released | rolled_back
linear_issue: null
created: {{DATE}}
updated: {{DATE}}
---
```

Roadmap items in docs/roadmap.md use this parseable line format:

```markdown
- [ ] checkout-flow: One-line description (plan: v2, status: in_progress)
```

## Cross-file consistency

- A scope change bumps the plan version and updates docs/roadmap.md in the same session.
- Shipping updates docs/releases/CHANGELOG.md, docs/roadmap.md, and the feature doc.
- An applied fix updates the related feature doc and docs/roadmap.md.
- If you change one file in a linked set and cannot update the others, say so explicitly.

## Definition of done

A feature is done when all of these hold:

1. Plan status is `shipped`, or the work is flagged `unplanned: true`.
2. QA acceptance criteria pass.
3. Tracking plan events are instrumented.
4. Docs are updated.
5. docs/releases/CHANGELOG.md has an entry.
6. docs/roadmap.md reflects reality.

## Linear extension point

Repo files are the source of truth today. Keep all frontmatter as valid YAML, keep slugs stable, keep `linear_issue: null` untouched. A future sync skill will mirror these files to Linear issues one to one; never restructure them in a way that breaks that mapping.

## Interaction and writing style

- Questions to the user: lettered multiple choice (A, B, C) with a final free-text option. Batch 3 to 5 questions per round, maximum 3 rounds per mode. Never interrogate one question at a time for trivia.
- Announce every auto-selected mode in one line with the reason.
- All generated documents: plain, concise, professional prose. Never use em dashes anywhere (prose, docs, diagrams, commit messages); use commas, colons, parentheses, or separate sentences instead.
- Prefer the smallest change that achieves the outcome; make trade-offs explicit.
TPM_FILE
}

render_skills() {
  install_file ".claude/skills/interview-mode/SKILL.md" <<'TPM_FILE'
---
name: interview-mode
description: "Requirements discovery for new apps, new features, modifications, and major refactors. Trigger whenever the user requests new functionality or a significant change, even phrased as 'build X', 'add Y', 'create Z', or 'we need W'. Also trigger on /interview. Do NOT trigger for bug reports, regressions, or 'X is broken': that is fix-mode (restoring intended behavior routes to fix-mode; changing intended behavior routes here)."
---

# Interview Mode

You run requirements discovery as a senior technical product manager. The output is a versioned implementation plan, never code.

## Workflow

### Step 1: Challenge

Before any questions, respond with a short sanity check (a few sentences, a senior PM gut check, not obstruction):

1. Restate the request in one paragraph.
2. Question whether it targets the right problem.
3. Name one simpler alternative if a credible one exists.
4. Propose candidate non-goals.

### Step 2: Discovery

Run discovery in lettered multiple choice batches (A, B, C, plus a final free-text option). Batch 3 to 5 questions per round, maximum 3 rounds. Skip anything already answered in the conversation or in existing docs. Cover:

- Target users and UX expectations
- Functional requirements
- Business objective and end goal
- Ideal inputs and outputs
- Success criteria
- Failure handling and fallbacks
- Constraints: performance, security, cost, compliance

### Step 3: Write the plan

Write `docs/plans/implementation_plan_{feature}_{version}.md` using the implementation plan schema from CLAUDE.md (status draft, unplanned false, linear_issue null, dates today). Sections:

1. Problem Statement
2. Business Objective and End Goal
3. Users and UX
4. Functional Requirements (MoSCoW prioritized: Must, Should, Could, Won't)
5. Non-Functional Requirements
6. Inputs and Outputs
7. Success Criteria
8. Failure Handling and Fallbacks
9. Non-Goals
10. Open Questions

Apply CLAUDE.md's versioning rule: in-scope clarifications update this file and bump `updated`; a scope change creates version n+1 and marks this file `superseded`.

### Step 4: Hand off

Trigger roadmap-mode to register the item in docs/roadmap.md. Recommend architecture-mode as the next step in one line.

## Guardrails

- Never write implementation code while this mode is active.
- If the request is trivially small (copy change, config flip), say so and offer to skip straight to implementation.
- When you self-select this mode, announce it in one line with the reason.
TPM_FILE

  install_file ".claude/skills/architecture-mode/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/qa-mode/SKILL.md" <<'TPM_FILE'
---
name: qa-mode
description: "Test and acceptance criteria definition. Trigger after a plan exists and before implementation, whenever the user mentions tests, test cases, QA, acceptance criteria, or edge cases, or on /qa."
---

# QA Mode

You turn the active implementation plan into testable acceptance criteria, automated test case definitions, and human QA instructions.

## Workflow

### Step 1: Derive candidates

Derive candidate test cases from the active plan: happy paths, edge cases, failure modes. Mark each candidate as an assumption until the user confirms it.

### Step 2: Confirm

Run one or two lettered MCQ rounds (3 to 5 questions each, free-text option last) covering:

- Which edge cases matter
- Priority order
- What counts as pass or fail

### Step 3: Update the plan

Append a QA section to the active implementation plan and bump its `updated` date:

1. Acceptance Criteria (numbered, individually testable)
2. Evaluation Criteria
3. Automated Test Cases (for the test suite)
4. Edge Cases to Handle

### Step 4: Human QA instructions

Create or update `docs/user_testing_documentation.md`: step-by-step manual test instructions for a human QA team, covering all significant end-to-end flows and per-feature workflows, ideal paths and edge cases, and the expected result of every step. Write for a tester who has never seen the codebase: name the screen or command, the exact action, and the observable result.

## Guardrails

- Do not write test code in this mode; define what the tests must prove.
- Acceptance criteria must be verifiable, not aspirational.
- Recommend metrics-mode as the next step in one line.
TPM_FILE

  install_file ".claude/skills/metrics-mode/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/fix-mode/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/release-mode/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/documentation-mode/SKILL.md" <<'TPM_FILE'
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

Update `docs/{{PROJECT_NAME}}/DOCUMENTATION.md`:

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

- Write only under docs/{{PROJECT_NAME}}/ and docs/features/.
- When this mode runs as part of the auto-chain, trigger roadmap-mode next.
TPM_FILE

  install_file ".claude/skills/roadmap-mode/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/feedback-triage/SKILL.md" <<'TPM_FILE'
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
TPM_FILE

  install_file ".claude/skills/gtm-strategy/SKILL.md" <<'TPM_FILE'
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
TPM_FILE
}

render_agents() {
  install_file ".claude/agents/repo-surveyor.md" <<'TPM_FILE'
---
name: repo-surveyor
description: "Read-only codebase survey for architecture planning. Use before proposing implementation approaches for a planned feature. Maps existing patterns, affected modules, and dependencies. Never modifies files."
tools: Read, Glob, Grep
model: inherit
---

You survey this repository for architecture planning. Given a feature description, identify:

1. Modules and files the feature would touch.
2. Existing patterns and conventions the implementation should follow, with file examples.
3. Internal cross-module dependencies in the affected area.
4. Third-party dependencies already available that could serve the feature.
5. Constraints or hazards: tight coupling, missing tests, deprecated paths.

Return one structured report with exactly these five headings:

## Affected Modules and Files
## Existing Patterns and Conventions
## Internal Dependencies
## Available Third-Party Dependencies
## Constraints and Hazards

Cite file paths for every claim. Do not propose an implementation approach; that decision happens in the main thread. Return only the report, not your working notes.
TPM_FILE

  install_file ".claude/agents/impact-analyzer.md" <<'TPM_FILE'
---
name: impact-analyzer
description: "Root cause and blast radius analysis for bugs and regressions. Use at the start of fix planning. Reads code, runs tests and git commands, never edits files."
tools: Read, Glob, Grep, Bash
model: inherit
---

You analyze defects. Given a symptom description, identify:

1. Root cause candidates ranked by likelihood, each with file-and-line evidence.
2. The dependency chain from the defect to user-facing behavior.
3. All files plausibly involved in a fix.
4. Blast radius: what else consumes the affected code paths.
5. Minimal-touch fix points.

You may run the test suite and read git history (log, blame, diff) for evidence. Never modify files, never commit, never run destructive or state-changing commands: treat Bash as read-only.

Return one structured report with exactly these five headings:

## Root Cause Candidates
## Dependency Chain to User-Facing Behavior
## Files Plausibly Involved
## Blast Radius
## Minimal-Touch Fix Points

Return only the report, not your working notes.
TPM_FILE

  install_file ".claude/agents/doc-crawler.md" <<'TPM_FILE'
---
name: doc-crawler
description: "Extracts documentation-ready summaries from recently changed code. Use after implementation or fixes, before updating project and feature docs. Read-only."
tools: Read, Glob, Grep, Bash
model: inherit
---

You prepare raw material for documentation. Given a scope (changed files, a feature area, or a diff range), extract:

1. Structural changes to the project layout.
2. New or changed public interfaces and contracts.
3. Third-party dependency changes, with versions.
4. Cross-module effects.
5. Anything in existing docs now contradicted by the code, with the doc file and section.

Use git diff and git log read-only as needed. Never modify files: treat Bash as read-only.

Return one structured report with exactly these five headings:

## Structural Changes
## Interface and Contract Changes
## Dependency Changes
## Cross-Module Effects
## Documentation Contradictions

Cite file paths for every claim. Return only the report, not your working notes.
TPM_FILE

  install_file ".claude/agents/competitor-researcher.md" <<'TPM_FILE'
---
name: competitor-researcher
description: "Deep web research on competitors for GTM strategy. Use when building or refreshing go-to-market strategy, competitive landscape, or positioning. Research only, no strategy decisions."
tools: WebSearch, WebFetch, Read
model: inherit
---

You research the competitive landscape. Given the product context, find direct and adjacent competitors and, for each: category, positioning paraphrased from their own words, pricing signals, recent activity in the last 12 months (launches, funding, notable content), apparent strengths, and apparent gaps relative to the given product context.

Prefer primary sources (their sites, changelogs, docs) over aggregators.

Return one report containing:

## Competitor Table

Columns: Competitor, Category, Positioning, Pricing Signals, Recent Activity, Strengths, Gaps.

## Market Observations

A short list.

Include source URLs for every factual claim. If web tools are unavailable or fail, say so explicitly at the top of the report and return whatever can be grounded without them. Do not draft positioning or messaging; that happens in the main thread with the user. Return only the report, not your working notes.
TPM_FILE
}

render_commands() {
  install_file ".claude/commands/interview.md" <<'TPM_FILE'
Run the interview-mode skill for the following request. Follow its workflow exactly, starting with the challenge step.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/architect.md" <<'TPM_FILE'
Run the architecture-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/qa.md" <<'TPM_FILE'
Run the qa-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/metrics.md" <<'TPM_FILE'
Run the metrics-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/fix.md" <<'TPM_FILE'
Run the fix-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/release.md" <<'TPM_FILE'
Run the release-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/document.md" <<'TPM_FILE'
Run the documentation-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/roadmap.md" <<'TPM_FILE'
Run the roadmap-mode skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/triage.md" <<'TPM_FILE'
Run the feedback-triage skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE

  install_file ".claude/commands/gtm.md" <<'TPM_FILE'
Run the gtm-strategy skill for the following request. Follow its workflow exactly.

Request: $ARGUMENTS
TPM_FILE
}

render_docs() {
  install_file "docs/roadmap.md" <<'TPM_FILE'
---
type: roadmap
created: {{DATE}}
updated: {{DATE}}
---

# Roadmap

## Milestones

None yet.

## Feature Checklist

None yet. Item format: `- [ ] {feature-slug}: One-line description (plan: v{n}, status: {status})`

## Business Objective Coverage

None yet. Populated from tracking plan verdicts.

## Unplanned Work

None. Items with `unplanned: true` in their frontmatter appear here.

## Next Up

None yet.
TPM_FILE

  install_file "docs/releases/CHANGELOG.md" <<'TPM_FILE'
# Changelog

All notable changes to this project are documented in this file.

The format follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/). Entries use the categories Added, Changed, Fixed, and Removed.

## [Unreleased]
TPM_FILE

  install_file "docs/feedback/feedback_log.md" <<'TPM_FILE'
# Feedback Log

Every relayed feedback item gets one row: the date received, who it came from, a short verbatim summary, its classification (bug, feature request, or insight), and the route taken (fix-mode, interview-mode, or roadmap and ICP annotation).

| Date | Source | Summary | Classification | Route |
|---|---|---|---|---|
TPM_FILE

  install_file "docs/user_testing_documentation.md" <<'TPM_FILE'
# User Testing Documentation

## How to Use This Document

This document contains step-by-step manual test instructions for human testers. You do not need to have seen the codebase. Each flow lists numbered steps giving the exact action to take and the observable result to expect. Report any step whose actual result differs from the expected result, quoting the flow name and step number.

## Flows

None yet. qa-mode adds flows here as features gain acceptance criteria.
TPM_FILE

  install_file "docs/$PROJECT_NAME/DOCUMENTATION.md" <<'TPM_FILE'
# {{PROJECT_NAME}} Documentation

## Project Structure

Not yet surveyed. Run /document to populate this section.

## Third-Party Dependencies

Not yet surveyed. Run /document to populate this section.

## Cross-Module Dependency Map

Not yet surveyed. Run /document to populate this section.

## Setup and Run Instructions

Not yet surveyed. Run /document to populate this section.

## Architectural Overview

Not yet surveyed. Run /document to populate this section.
TPM_FILE

  for keep_dir in plans fixes adr metrics features gtm; do
    install_empty "docs/$keep_dir/.gitkeep"
  done
}

VERIFY_FAILS=0
vfail() { printf 'install.sh: verify: FAIL: %s\n' "$1" >&2; VERIFY_FAILS=$((VERIFY_FAILS + 1)); }

# Nine embedded checks, run against the staging tree BEFORE anything touches
# the target, so a bad render can never half-install.
verify_stage() {
  VERIFY_FAILS=0
  CHECKS_PASSED=0

  # 1. Every manifest path was staged.
  pre=$VERIFY_FAILS
  for rel in $MANIFEST; do
    if [ ! -f "$STAGE/$rel" ]; then vfail "missing staged file: $rel"; fi
  done
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 2. Frontmatter opens at byte zero with name and description keys.
  pre=$VERIFY_FAILS
  for f in "$STAGE"/.claude/skills/*/SKILL.md "$STAGE"/.claude/agents/*.md; do
    if [ "$(head -1 "$f")" != "---" ]; then vfail "frontmatter not at byte zero: ${f#"$STAGE"/}"; fi
    grep -q '^name:' "$f" || vfail "missing name key: ${f#"$STAGE"/}"
    grep -q '^description:' "$f" || vfail "missing description key: ${f#"$STAGE"/}"
  done
  if [ "$(head -1 "$STAGE/docs/roadmap.md")" != "---" ]; then vfail "roadmap.md frontmatter not at byte zero"; fi
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 3. Every description is a double-quoted single-line string. An unquoted
  #    value containing colon-space breaks YAML and Claude Code then silently
  #    skips the file: the likeliest silent failure in the suite.
  pre=$VERIFY_FAILS
  for f in "$STAGE"/.claude/skills/*/SKILL.md "$STAGE"/.claude/agents/*.md; do
    grep -q '^description: ".*"$' "$f" || vfail "description not a double-quoted single line: ${f#"$STAGE"/}"
  done
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 4. Skill name equals its directory, agent name equals its filename,
  #    agent names unique.
  pre=$VERIFY_FAILS
  for f in "$STAGE"/.claude/skills/*/SKILL.md; do
    d="$(basename "$(dirname "$f")")"
    grep -q "^name: $d\$" "$f" || vfail "skill name/directory mismatch: $d"
  done
  for f in "$STAGE"/.claude/agents/*.md; do
    b="$(basename "$f" .md)"
    grep -q "^name: $b\$" "$f" || vfail "agent name/filename mismatch: $b"
  done
  dups="$(grep -h '^name:' "$STAGE"/.claude/agents/*.md | sort | uniq -d)"
  if [ -n "$dups" ]; then vfail "duplicate agent names: $dups"; fi
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 5. No em dashes anywhere in the rendered tree. The character is built at
  #    runtime so this script stays clean of it.
  pre=$VERIFY_FAILS
  EMDASH="$(printf '\342\200\224')"
  if grep -rn "$EMDASH" "$STAGE" > /dev/null 2>&1; then
    vfail "em dash found in staged files"
    grep -rln "$EMDASH" "$STAGE" >&2 || true
  fi
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 6. Command wiring: each skill description names its slash command, each
  #    command file names its skill and carries $ARGUMENTS.
  pre=$VERIFY_FAILS
  while read -r skill cmd; do
    if [ -z "$skill" ]; then continue; fi
    grep -q "^description: \".*$cmd" "$STAGE/.claude/skills/$skill/SKILL.md" \
      || vfail "$cmd missing from $skill description"
    cmdfile="$STAGE/.claude/commands/${cmd#/}.md"
    grep -q "$skill" "$cmdfile" || vfail "${cmd#/}.md does not name $skill"
    grep -q '\$ARGUMENTS' "$cmdfile" || vfail "${cmd#/}.md missing \$ARGUMENTS"
  done <<'TPM_WIRING'
interview-mode /interview
architecture-mode /architect
qa-mode /qa
metrics-mode /metrics
fix-mode /fix
release-mode /release
documentation-mode /document
roadmap-mode /roadmap
feedback-triage /triage
gtm-strategy /gtm
TPM_WIRING
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 7. CLAUDE.md line cap and section anchors.
  pre=$VERIFY_FAILS
  lines="$(wc -l < "$STAGE/CLAUDE.md")"
  if [ "$lines" -ge 250 ]; then vfail "CLAUDE.md is $lines lines (cap 250)"; fi
  for anchor in \
    'restoring intended behavior routes to fix-mode' \
    'unplanned: true' \
    'linear_issue: null' \
    '## Mode routing' \
    '## Advisory gate' \
    '## File ownership' \
    '## File conventions' \
    '## Definition of done' \
    '## Linear extension point'; do
    grep -q "$anchor" "$STAGE/CLAUDE.md" || vfail "CLAUDE.md anchor missing: $anchor"
  done
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 8. No template token or placeholder leakage.
  pre=$VERIFY_FAILS
  if grep -rn '{{' "$STAGE" > /dev/null 2>&1; then vfail "unsubstituted template token in staged files"; fi
  if grep -rn 'PROJECT_NAME' "$STAGE" > /dev/null 2>&1; then vfail "PROJECT_NAME placeholder leaked"; fi
  if grep -rn '{project_name}' "$STAGE" > /dev/null 2>&1; then vfail "{project_name} placeholder leaked"; fi
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  # 9. Name agreement: router, documentation-mode, and the docs directory all
  #    reference the same project name.
  pre=$VERIFY_FAILS
  grep -q "docs/$PROJECT_NAME/DOCUMENTATION.md" "$STAGE/CLAUDE.md" \
    || vfail "CLAUDE.md ownership row does not reference docs/$PROJECT_NAME/"
  grep -q "docs/$PROJECT_NAME/" "$STAGE/.claude/skills/documentation-mode/SKILL.md" \
    || vfail "documentation-mode does not reference docs/$PROJECT_NAME/"
  if [ ! -f "$STAGE/docs/$PROJECT_NAME/DOCUMENTATION.md" ]; then
    vfail "docs/$PROJECT_NAME/DOCUMENTATION.md was not staged"
  fi
  if [ "$VERIFY_FAILS" -eq "$pre" ]; then CHECKS_PASSED=$((CHECKS_PASSED + 1)); fi

  if [ "$VERIFY_FAILS" -gt 0 ]; then
    die "verification failed with $VERIFY_FAILS problem(s); nothing was installed"
  fi
}

# Reconciliation state
CREATED=""
UNCHANGED=""
KEPT=""
REPLACED=""
CONFLICTS=""
N_CREATED=0
N_UNCHANGED=0
N_KEPT=0
N_REPLACED=0
N_CONFLICTS=0

# Apply the staged tree to the target under the conflict policy.
# Class A config (CLAUDE.md, .claude/**): create, or report unchanged when
# byte-identical, or conflict; --force displaces the old file to a dated
# backup and replaces it. Class B state (docs/**): create if missing, kept
# otherwise, even under --force (roadmaps and changelogs are user state).
reconcile() {
  for rel in $MANIFEST; do
    src="$STAGE/$rel"
    dest="$TARGET/$rel"
    case "$rel" in
      docs/*) class="state" ;;
      *) class="config" ;;
    esac

    if [ ! -e "$dest" ]; then
      status="created"
      if [ "$DRY_RUN" -eq 0 ]; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
      fi
    elif cmp -s "$src" "$dest"; then
      status="unchanged"
    elif [ "$class" = "state" ]; then
      status="kept"
    elif [ "$FORCE" -eq 1 ]; then
      status="replaced"
      if [ "$DRY_RUN" -eq 0 ]; then
        bak="$dest.bak-$STAMP_DATE"
        n=2
        while [ -e "$bak" ]; do
          bak="$dest.bak-$STAMP_DATE-$n"
          n=$((n + 1))
        done
        mv "$dest" "$bak"
        cp "$src" "$dest"
      fi
    else
      status="conflict"
    fi

    case "$status" in
      created)   CREATED="$CREATED$rel
";   N_CREATED=$((N_CREATED + 1)) ;;
      unchanged) UNCHANGED="$UNCHANGED$rel
"; N_UNCHANGED=$((N_UNCHANGED + 1)) ;;
      kept)      KEPT="$KEPT$rel
";      N_KEPT=$((N_KEPT + 1)) ;;
      replaced)  REPLACED="$REPLACED$rel
";  N_REPLACED=$((N_REPLACED + 1)) ;;
      conflict)  CONFLICTS="$CONFLICTS$rel
";  N_CONFLICTS=$((N_CONFLICTS + 1)) ;;
    esac
  done

  # Renamed-target detection: another docs/*/DOCUMENTATION.md means an
  # earlier install under a different project name.
  if [ -d "$TARGET/docs" ]; then
    orphans="$(find "$TARGET/docs" -mindepth 2 -maxdepth 2 -name DOCUMENTATION.md 2>/dev/null | grep -v "/docs/$PROJECT_NAME/DOCUMENTATION.md\$" || true)"
    if [ -n "$orphans" ]; then
      warn "other project doc directories exist (target renamed since a previous install?):"
      printf '%s\n' "$orphans" >&2
    fi
  fi
}

group_counts() {
  list="$1"
  for prefix in "CLAUDE.md" ".claude/skills/" ".claude/agents/" ".claude/commands/" "docs/"; do
    c=0
    for rel in $list; do
      case "$rel" in "$prefix"*) c=$((c + 1)) ;; esac
    done
    if [ "$c" -gt 0 ]; then printf '      %-18s %d file(s)\n' "$prefix" "$c"; fi
  done
}

print_list() {
  for rel in $1; do printf '      %s\n' "$rel"; done
}

report() {
  printf '\nTPM Operating System installer v%s\n' "$TPM_SUITE_VERSION"
  printf '  project name : %s\n' "$PROJECT_NAME"
  printf '  target       : %s\n' "$TARGET"
  printf '  date stamp   : %s\n' "$STAMP_DATE"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  mode         : dry run (nothing was written)\n'
  fi
  printf '\n'

  printf '  created    %3d\n' "$N_CREATED"
  if [ "$N_CREATED" -gt 0 ]; then group_counts "$CREATED"; fi
  printf '  unchanged  %3d\n' "$N_UNCHANGED"
  printf '  kept       %3d  (docs state files are never overwritten)\n' "$N_KEPT"
  if [ "$N_KEPT" -gt 0 ]; then print_list "$KEPT"; fi
  if [ "$N_REPLACED" -gt 0 ]; then
    printf '  replaced   %3d  (originals backed up to <path>.bak-%s)\n' "$N_REPLACED" "$STAMP_DATE"
    print_list "$REPLACED"
  fi
  printf '  conflicts  %3d\n' "$N_CONFLICTS"
  if [ "$N_CONFLICTS" -gt 0 ]; then print_list "$CONFLICTS"; fi

  if [ "$N_CONFLICTS" -gt 0 ]; then
    printf '\nConflicts: existing files were left untouched. CLAUDE.md holds your\n'
    printf 'project instructions; the suite router replaces rather than merges, so\n'
    printf 'merge by hand, or re-run with --force to back each conflicting file up\n'
    printf 'to <path>.bak-%s and replace it.\n' "$STAMP_DATE"
  fi

  printf '\nVerification: %d/%d embedded checks passed against the rendered tree.\n' "$CHECKS_PASSED" "$CHECKS_TOTAL"
  printf '\nRestart required: skills, agents, and commands load at session start.\n'
  printf 'Restart your Claude Code session in %s before first use.\n' "$TARGET"
  printf '\nSmoke test:\n'
  printf '  1. Ask for a small feature in plain words ("add a dark mode toggle").\n'
  printf '     Expect a one-line route announcement, then interview-mode'"'"'s challenge step.\n'
  printf '  2. Run /interview add user avatars to confirm command wiring.\n'
  printf '  3. Confirm docs/plans/ gained a plan and docs/roadmap.md a checkbox line.\n'
}

# Maintainer drift gate: render with the pinned name and date, then diff
# against this clone's live files. FAIL tier: CLAUDE.md and .claude/** must
# be byte-identical. WARN tier: docs seeds (live repo state may legitimately
# diverge once this repo is used as a working install). Excluded entirely:
# docs/tpm_s-kill_bot/DOCUMENTATION.md (self-describing here; targets get
# the generic starter instead).
self_test() {
  if [ ! -f "$0" ]; then
    die "self-test requires a local clone (run ./install.sh --self-test)"
  fi
  SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ ! -f "$SOURCE_DIR/CLAUDE.md" ]; then
    die "self-test: $SOURCE_DIR does not look like the suite repo (CLAUDE.md missing)"
  fi

  PROJECT_NAME="tpm_s-kill_bot"
  STAMP_DATE="$(grep '^created:' "$SOURCE_DIR/docs/roadmap.md" | awk '{print $2}')"
  if [ -z "$STAMP_DATE" ]; then
    die "self-test: could not read the pinned date from docs/roadmap.md"
  fi
  note "self-test: name=$PROJECT_NAME date=$STAMP_DATE source=$SOURCE_DIR"

  STAGE="$(mktemp -d)"
  render_all
  verify_stage
  note "self-test: verify_stage passed ($CHECKS_PASSED/$CHECKS_TOTAL checks)"

  st_fails=0
  st_warns=0

  # Tree symmetry, both directions.
  printf '%s' "$MANIFEST" | LC_ALL=C sort > "$STAGE/.manifest"
  (cd "$SOURCE_DIR" && find CLAUDE.md .claude docs -type f) \
    | grep -v '\.DS_Store' | grep -v 'settings\.local\.json' \
    | LC_ALL=C sort > "$STAGE/.actual"
  extra_live="$(comm -13 "$STAGE/.manifest" "$STAGE/.actual")"
  missing_live="$(comm -23 "$STAGE/.manifest" "$STAGE/.actual")"
  if [ -n "$extra_live" ]; then
    printf 'self-test: FAIL: live files not embedded in the installer:\n%s\n' "$extra_live" >&2
    st_fails=$((st_fails + 1))
  fi
  if [ -n "$missing_live" ]; then
    printf 'self-test: FAIL: embedded files missing from the live repo:\n%s\n' "$missing_live" >&2
    st_fails=$((st_fails + 1))
  fi

  # Byte comparison in two tiers.
  for rel in $MANIFEST; do
    if [ "$rel" = "docs/tpm_s-kill_bot/DOCUMENTATION.md" ]; then continue; fi
    if [ ! -f "$SOURCE_DIR/$rel" ]; then continue; fi
    if cmp -s "$STAGE/$rel" "$SOURCE_DIR/$rel"; then continue; fi
    case "$rel" in
      docs/*)
        printf 'self-test: WARN: docs seed differs from live file (live state may have diverged): %s\n' "$rel"
        st_warns=$((st_warns + 1)) ;;
      *)
        printf 'self-test: FAIL: embedded config differs from live file: %s\n' "$rel" >&2
        diff -u "$SOURCE_DIR/$rel" "$STAGE/$rel" | head -40 >&2 || true
        st_fails=$((st_fails + 1)) ;;
    esac
  done

  if [ "$st_fails" -gt 0 ]; then
    printf 'self-test summary: FAIL (%d failure(s), %d warning(s))\n' "$st_fails" "$st_warns" >&2
    exit 1
  fi
  printf 'self-test summary: PASS (%d warning(s))\n' "$st_warns"
}

main() {
  parse_args "$@"
  if [ "$SELF_TEST" -eq 1 ]; then
    self_test
    exit 0
  fi
  resolve_target_and_name
  STAGE="$(mktemp -d)"
  render_all
  verify_stage
  reconcile
  report
  if [ "$N_CONFLICTS" -gt 0 ]; then
    exit 2
  fi
}

main "$@"
