# tpm_s-kill_bot: Senior Technical PM Operating System for Claude Code

A one-command installable suite that makes Claude Code behave like a senior technical product manager in any repository: requirements discovery, architecture evaluation, QA definition, success metrics, fix planning, release management, documentation, roadmap tracking, feedback triage, and go-to-market strategy.

The suite is a CLAUDE.md router, ten interactive skills, four research subagents, ten slash commands, and a docs skeleton whose state files carry Linear-ready YAML frontmatter. It advises and records; it never blocks: work shipped without a plan is flagged `unplanned: true` and surfaced in the roadmap instead of refused.

## Install

From inside the target project:

```bash
curl -fsSL https://raw.githubusercontent.com/amansharma2910/tpm_s-kill_bot/main/install.sh | bash
```

Or from a local clone:

```bash
./install.sh /path/to/your/project
```

The project name is derived from the target directory's basename (spaces become hyphens; only letters, digits, dot, underscore, and hyphen survive; case is preserved) and applied everywhere the suite references it, including `docs/{project-name}/DOCUMENTATION.md`. Then restart your Claude Code session in the target: skills, agents, and commands load at session start.

## Options

| Option | Meaning |
|---|---|
| `target-dir` | Directory to install into (default: current directory) |
| `--name NAME` | Project name override; must already be in the allowed charset |
| `--date YYYY-MM-DD` | Date stamped into installed docs (default: today; used by tests) |
| `--force` | Replace differing config files, backing each up to `<path>.bak-<date>` first |
| `--dry-run` | Render and verify, report what would change, write nothing |
| `--self-test` | Maintainer mode: diff the embedded templates against this clone |
| `-h`, `--help` | Help |

Exit codes: 0 success, 1 usage or verification failure, 2 conflicts reported and not forced. The installer is never interactive, so it is safe under `curl | bash`.

## What gets installed

36 files: `CLAUDE.md`, ten `SKILL.md` files under `.claude/skills/`, four subagents under `.claude/agents/`, ten slash commands under `.claude/commands/`, and a `docs/` skeleton (roadmap, changelog, feedback log, user testing doc, an empty project documentation starter, and six `.gitkeep` placeholders). Every render passes nine embedded checks (frontmatter shape, name agreement, command wiring, line caps, no em dashes, no placeholder leakage) before a single byte lands in the target.

## Conflict policy

- Config files (`CLAUDE.md`, everything under `.claude/`): created if missing, reported `unchanged` if byte-identical, otherwise reported as a `conflict` and left untouched. `--force` moves the existing file to a dated backup and replaces it; backups are never overwritten.
- Docs state files (everything under `docs/`): created if missing, otherwise always `kept`, even under `--force`. Roadmaps, changelogs, and feedback logs are your project's state; there is no such thing as upgrading them.
- An existing `CLAUDE.md` deserves care: the suite's router replaces rather than composes (two routing tables misroute silently). Merge by hand, folding your project rules into the router, or let `--force` back yours up first.

Re-running the installer on an up-to-date project is a no-op (everything reports `unchanged` or `kept`), which also makes it the upgrade path: pull a newer install.sh and re-run; only changed config files surface as conflicts to review.

## Uninstall

The install report doubles as the manifest. From the target project:

```bash
rm -rf CLAUDE.md .claude/skills .claude/agents .claude/commands
```

Keep or remove `docs/` as you see fit; it holds your project's plans, roadmap, and logs, not suite machinery.

## Smoke test

After installing and restarting the session:

1. Restart the Claude Code session in the target repository (skills, agents, and commands all load at session start).
2. Request a small feature in plain words, for example "add a dark mode toggle". Expect: a one-line route announcement, then interview-mode's challenge step (restatement, right-problem question, simpler alternative, candidate non-goals), then a lettered MCQ batch of 3 to 5 questions ending with a free-text option.
3. Reply "skip the plan, just build it". Expect: the advisory fires exactly once, naming one specific risk in one sentence, then compliance. The resulting work is flagged `unplanned: true` and surfaces in roadmap.md's Unplanned Work section. It must not repeat the recommendation later in the session.
4. Confirm `docs/plans/` gained a plan whose frontmatter parses (if step 2 completed) and that `docs/roadmap.md` gained a parseable checkbox line.
5. Say "the toggle is broken, it does not persist". Expect routing to fix-mode with a one-line announcement citing the disambiguation heuristic, and an impact-analyzer dispatch.
6. Invoke `/interview add user avatars` to confirm command wiring end to end.

## Maintainers

`install.sh` is the package: every installed file lives inside it as a quoted heredoc (delimiter `TPM_FILE`), with `{{PROJECT_NAME}}` and `{{DATE}}` substituted at render time. This repo's own `CLAUDE.md`, `.claude/`, and `docs/` are the live reference install of the same suite.

The working rule: any edit to `CLAUDE.md`, anything under `.claude/`, or a docs seed must be mirrored into the matching heredoc in `install.sh`, and the drift gate must pass before committing:

```bash
./install.sh --self-test
```

The self-test renders with the pinned name and date, runs the nine embedded checks, verifies the file tree matches in both directions, and byte-compares the render against the live files. `CLAUDE.md` and `.claude/**` mismatches fail; docs seed mismatches warn (this repo's own roadmap and changelog may legitimately accumulate state); `docs/tpm_s-kill_bot/DOCUMENTATION.md` is excluded (targets receive a generic starter instead of this repo's self-describing doc).

Optional pre-commit hook:

```bash
printf '#!/bin/sh\nexec ./install.sh --self-test\n' > .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

Constraints to preserve when editing: no embedded file may contain a line consisting of exactly `TPM_FILE`; every frontmatter `description` stays a double-quoted single line; no em dash characters anywhere; the script stays bash 3.2 compatible (no `sed -i`, no associative arrays, printf only).
