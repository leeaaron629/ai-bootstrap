# Changelog

All notable changes to this project will follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and [Conventional Commits](https://www.conventionalcommits.org/).

## [0.1.0] - 2026-07-19

### Added
- `skills/eval-and-triage-issue` — cost/benefit triage skill with severity×cost matrix and 7 calibration examples
- `skills/auto-pr-resolve-feedback` — auto-resolve PR comments, commit, push, resolve threads
- `skills/review-and-learn` — review PR feedback and extract recurring patterns into new rules
- `rules/` — 7 topic rule files extracted from CLAUDE.md (preamble, security, pr-hygiene, git, coding, testing, collaboration)
- `scripts/build.py` — transforms canonical sources into Cursor-specific dist artifacts
- `install.sh` — POSIX install script (macOS + Linux) with `--harness`, `--type`, `--link`, `--dry-run`, `--uninstall`
- `install.ps1` — Windows PowerShell install script with equivalent flags
