# Changelog

All notable changes to this project will follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Conventional Commits](https://www.conventionalcommits.org/).

## [Unreleased]

### Added
- `skills/unattended` — execute a task or plan with no human in the loop, front-loading decisions into one upfront contract and self-verifying via repo gates
- `skills/fan-out-code` — dispatch code-fix issues to parallel subagents, grouping tasks that touch the same files to avoid edit conflicts
- `skills/worktree-task` — isolate an interactive session in its own git worktree/branch to run several terminals against one repo without collisions
- `skills/doc-review` — verify docs, runbooks, READMEs, and code comments against current code and each other, reporting staleness with evidence before editing
- `skills/todo` — draft one or many work-item documents and update their state (TODO → DONE), as portable markdown that maps onto JIRA, GitHub Issues, or any tracker

### Fixed
- Memory install no longer rewrites an existing `MEMORY.md` when the repo ships no memories (was clobbering hand-curated indexes)
- Cursor rules/memories are skipped under `--scope global` instead of being written into the current working directory
- Rule rendering preserves backslashes (via awk `ENVIRON` / PowerShell `MatchEvaluator`) and body `---` dividers
- Windows memory-path slug flagged as unverified with a runtime hint to check the resolved path

### Changed
- `install.sh` routes all copy/symlink operations through the `copy_or_link` helper (removes a fragile `&& … || …` pattern)
- `.gitignore` now ignores generated `.cursor/` output

## [0.1.0] - 2026-07-19

### Added
- `skills/eval-and-triage-issue` — cost/benefit triage skill with severity×cost matrix and 7 calibration examples
- `skills/auto-pr-resolve-feedback` — auto-resolve PR comments, commit, push, resolve threads
- `skills/review-and-learn` — review PR feedback and extract recurring patterns into new rules
- `rules/` — 7 topic rule files extracted from CLAUDE.md (preamble, security, pr-hygiene, git, coding, testing, collaboration)
- `scripts/build.py` — transforms canonical sources into Cursor-specific dist artifacts
- `install.sh` — POSIX install script (macOS + Linux) with `--harness`, `--type`, `--link`, `--dry-run`, `--uninstall`
- `install.ps1` — Windows PowerShell install script with equivalent flags
