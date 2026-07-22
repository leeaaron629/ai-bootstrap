---
description: Review PR feedback, fix actionable items, then extract recurring mistake patterns and propose new global or project-level rules.
---

# Review PR and Learn

Review all feedback on the current PR, address actionable items, and extract recurring patterns to propose new global or project-level rules.

## Steps

### Phase 1 — Address Feedback

Follow all steps from the `address-pr-feedback` skill to fix, commit, push, and reply on the PR.

### Phase 2 — Pattern Extraction

After addressing feedback, analyze the full set of comments (including already-resolved ones from this PR and any prior PRs you have context on) and look for recurring mistake patterns:

Ask yourself:
- Was the same class of issue flagged more than once? (e.g., mutable image tags, stale help text, missing doc updates)
- Is there a rule that, if it existed earlier, would have prevented this issue at write time?
- Is there a check that could be added to `make lint` or CI to catch this automatically?

### Phase 3 — Propose New Rules

For each pattern found, propose one of:

**A. A new global rule** (applies to all projects) → candidate for `~/.claude/CLAUDE.md`
**B. A new project rule** (specific to this repo) → candidate for `./CLAUDE.md`
**C. A lint/CI check** → suggest a ruff rule, pre-commit hook, or CI step that would catch the issue automatically

Format each proposal as:

```
PATTERN: <what the mistake was>
RULE: <the rule in plain language>
SCOPE: global | project
ACTION: add to ~/.claude/CLAUDE.md | add to ./CLAUDE.md | add lint check
```

Present these proposals to the user and ask for approval before writing anything.

### Phase 4 — Apply Approved Rules

For each approved proposal, follow the correct format below depending on the output type.

---

#### Creating a new skill (recommended)

Use the skills directory structure — preferred over the legacy commands format:

```
~/.claude/skills/<skill-name>/
└── SKILL.md        # must be uppercase
```

**Minimal `SKILL.md`:**
```markdown
---
description: What this skill does and when to use it — shown in the / menu
---

# Skill Title

One paragraph summary of what the skill does and when to use it.

## Steps

1. **Step one** — description
2. **Step two** — description

## Notes

- Constraints, edge cases, or important caveats.
```

**Full `SKILL.md` with all supported frontmatter fields:**
```markdown
---
name: skill-name               # optional — defaults to directory name
description: ...               # recommended — used by Claude to decide when to apply
argument-hint: "[issue-number]" # optional — shown in / autocomplete
allowed-tools: Read, Bash      # optional — tools allowed without permission prompts
user-invocable: false          # optional — hide from / menu (Claude can still invoke)
disable-model-invocation: true # optional — prevent Claude auto-invoking (user-only)
context: fork                  # optional — run in isolated subagent context
---
```

Rules:
- Directory name becomes the slash command name (e.g. `fix-flaky-tests/` → `/fix-flaky-tests`)
- `name` in frontmatter overrides the directory name if provided
- Place in `~/.claude/skills/` for global skills, `.claude/skills/` for project-only

---

#### Adding a rule to a CLAUDE.md

Append under the most relevant existing `## <Topic> Rules` section, or create a new one:

```markdown
## <Topic> Rules

- **<Rule title in bold>.** <One to two sentences — specific enough to be mechanically applied.>
```

Check both `~/.claude/CLAUDE.md` and `./CLAUDE.md` for duplicates before adding.

---

#### Updating the changelog (`~/.claude/changelog.md`)

Prepend a new entry at the top of the file, above all existing entries:

```markdown
## YYYY-MM-DD

### <Title of the change>
**Description:** <What was added or changed.>
**Why:** <The concrete mistake or pattern that motivated this change.>

---
```

---

After writing all approved changes, report back to the user with a summary of exactly what was created or modified and where.

## Notes

- Do not add rules that duplicate what is already in CLAUDE.md files.
- Keep rules actionable and specific — avoid vague guidance like "write good code."
- Prefer rules that can be mechanically verified (e.g., "never use :latest") over subjective ones.
- Always include at least a `description` in frontmatter — without it the skill won't appear usefully in the `/` menu.
- This skill is most valuable when run after a PR is reviewed and before it is merged.
