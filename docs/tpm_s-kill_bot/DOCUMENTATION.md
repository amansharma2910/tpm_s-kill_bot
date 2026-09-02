# tpm_s-kill_bot Documentation

## Project Structure

- `CLAUDE.md`: session router. Role, mode routing, advisory gate, file ownership, data schemas, definition of done.
- `.claude/skills/`: ten TPM mode skills (interview-mode, architecture-mode, qa-mode, metrics-mode, fix-mode, release-mode, documentation-mode, roadmap-mode, feedback-triage, gtm-strategy), one directory with a SKILL.md each.
- `.claude/agents/`: four research subagents (repo-surveyor, impact-analyzer, doc-crawler, competitor-researcher).
- `.claude/commands/`: ten slash command aliases (/interview, /architect, /qa, /metrics, /fix, /release, /document, /roadmap, /triage, /gtm).
- `docs/`: file-based state. plans/, fixes/, adr/, metrics/, releases/ (with CHANGELOG.md), feedback/ (with feedback_log.md), features/, gtm/, roadmap.md, user_testing_documentation.md, and this file.
- `install.sh`: self-contained one-command installer that packages this entire suite for any repository, deriving the project name from the target directory. Every installed file is embedded in it; `./install.sh --self-test` verifies the embedded copies match this repo's live files.
- `README.md`: install instructions, conflict policy, smoke test, and maintainer rules.

## Third-Party Dependencies

None. The project is a Claude Code configuration: markdown files with YAML frontmatter. The runtime is Claude Code itself.

## Cross-Module Dependency Map

- CLAUDE.md routes user intent to the ten skills and defines the conventions every skill follows.
- Skill-to-subagent dispatch is one-to-one: architecture-mode uses repo-surveyor, fix-mode uses impact-analyzer, documentation-mode uses doc-crawler, gtm-strategy uses competitor-researcher. The other six skills dispatch no subagents.
- Each skill writes only its owned files (see CLAUDE.md's ownership matrix). roadmap-mode aggregates by reading the frontmatter of docs/plans/, docs/fixes/, and docs/metrics/.
- Slash commands are thin invokers; each names one skill.

## Setup and Run Instructions

1. Open this repository in Claude Code.
2. Restart the session after any change to `.claude/agents/` or `.claude/commands/` (skills hot-reload; agents and commands load at session start).
3. Make requests in plain language and CLAUDE.md routes them, or invoke a mode directly with its slash command.
4. To install this suite into another repository: `./install.sh /path/to/project`, or the curl one-liner in README.md once the repo is pushed to GitHub.

## Architectural Overview

Three layers over file-based state. CLAUDE.md (always loaded) routes intent and holds conventions. Skills run interactively in the main conversation and write state documents under docs/. Subagents do heavy, non-interactive research in isolated context and return one structured report each. Every state document carries Linear-ready YAML frontmatter (stable kebab-case slug, status enum, `linear_issue: null`) so a future sync can mirror files to Linear issues one to one. The system advises and records; it never blocks: unplanned work is flagged `unplanned: true` and surfaced in the roadmap rather than refused.
