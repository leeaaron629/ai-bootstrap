# ai-config

Portable AI config — skills, rules, and memories — for Claude Code and Cursor.
One repo, one install command, works on macOS, Linux, and Windows.

## Quick start

```bash
git clone <repo-url>
cd ai-config
./install.sh          # install everything into both harnesses (global)
```

On Windows:

```powershell
.\install.ps1
```

On your **dev machine**, use `--link` so edits in the repo go live in both harnesses immediately:

```bash
./install.sh --link
```

## What's included

### Skills (`skills/`)

Slash commands for Claude Code (`/<name>`) and Cursor (`/<name>`).

| Skill | What it does |
|---|---|
| `eval-and-triage-issue` | Cost/benefit triage of issues — severity × cost matrix, recommends fix now / defer / won't fix |
| `auto-pr-resolve-feedback` | Auto-fixes actionable PR comments, commits, pushes, resolves threads |
| `review-and-learn` | Reviews PR feedback and extracts recurring patterns into new rules |

### Rules (`rules/`)

Global coding standards installed into `~/.claude/CLAUDE.md` (Claude Code) or `.cursor/rules/` (Cursor).

| File | Topic |
|---|---|
| `00-preamble.md` | Intro + override note |
| `01-security.md` | Secret handling, anti-patterns, production guards |
| `02-pr-hygiene.md` | PR review, stale refs, feedback replies |
| `03-git.md` | Conventional Commits, branching strategy, release tags |
| `04-coding.md` | 16 functional-style coding rules |
| `05-testing.md` | Test pyramid, mocking, AAA, independence, naming |
| `06-collaboration.md` | Struggle communication, end-of-session review, efficiency defaults |

Rules are written into a **managed block** in `CLAUDE.md` between `<!-- BEGIN ai-config -->` / `<!-- END ai-config -->` markers. Content outside the markers is never touched.

### Memories (`memories/`)

Generic facts that should travel across machines. Empty by default — add `.md` files here with standard frontmatter (see [Adding a memory](#adding-a-memory)).

On install: copied into Claude Code's memory directory and rendered into a `known-facts.mdc` rule for Cursor.

## Install flags

```
--harness  claude|cursor|both     What to install into (default: both)
--type     skills|rules|memories|all  What to install (default: all)
--scope    global|project         Global or current project (default: global)
--skill    <name>                 Install only one skill
--link                            Symlink instead of copy (for dev machines)
--dry-run                         Print actions without making any changes
--uninstall                       Remove all installed files
```

**Examples:**

```bash
./install.sh --dry-run                        # preview everything
./install.sh --harness claude --type skills   # skills only into Claude Code
./install.sh --harness cursor                 # everything into Cursor only
./install.sh --type rules --dry-run           # preview rule install
./install.sh --uninstall                      # remove all installed files
./install.sh --skill eval-and-triage-issue    # one skill only
```

## Requirements

- **Python 3** — required only when `--harness cursor` or `--harness both` is used (runs `scripts/build.py` to generate Cursor-format files from the canonical sources)
- **bash** (install.sh) or **PowerShell 5.1+** (install.ps1)

## Cursor notes

- **Skills → commands**: installed globally to `~/.cursor/commands/`
- **Rules → rules**: Cursor has no global file-based rules directory. Rules install into `.cursor/rules/` in the current working directory. For truly global rules, add them via **Cursor Settings → Rules**.
- **Memories → known-facts**: rendered into `.cursor/rules/known-facts.mdc` alongside the other rules

## Adding a new skill

1. Create `skills/<name>/SKILL.md` following the standard frontmatter format
2. Run `./install.sh --skill <name>` to install it
3. Commit with `feat(skills): add <name>`

Minimum frontmatter:

```yaml
---
description: What this skill does — shown in the / menu
argument-hint: "[optional input hint]"
---
```

## Adding a rule

1. Create `rules/<nn>-<topic>.md` with frontmatter:

```yaml
---
title: My Rule Topic
harnesses: [claude, cursor]
cursor-always-apply: true
---

## My Rule Topic

- Rule one
- Rule two
```

2. Run `./install.sh --type rules` to apply
3. Commit with `feat(rules): add <topic>`

## Adding a memory

1. Create `memories/<name>.md` with standard Claude Code memory frontmatter:

```yaml
---
name: <kebab-slug>
description: One-line summary shown in MEMORY.md index
metadata:
  type: user|feedback|project|reference
---

Memory content here.
```

2. Run `./install.sh --type memories` to install
3. Commit with `feat(memories): add <name>`

## Versioning

Follows [Conventional Commits](https://www.conventionalcommits.org/) + semver. Version is in `VERSION` and tracked by git tags (`v0.1.0`, `v0.2.0`, etc.).

| Change | Bump |
|---|---|
| New skill, rule section, or memory | `feat` → minor |
| Fix to existing content | `fix` → patch |
| Breaking change to install interface | `!` → major |
