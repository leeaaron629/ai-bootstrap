---
description: Review docs, runbooks, READMEs, and code comments for staleness and inconsistency — verifies every checkable claim against the current code and against the other docs, then reports what's wrong with evidence before changing anything. Use for "check the docs are up to date", "are the runbooks still accurate", "find stale comments", or "/doc-review ...".
argument-hint: "[path | glob | --diff [base]]  (default: whole repo)"
---

# Doc Review

Find places where the written word no longer matches reality: docs that describe code that has since changed, docs that contradict each other, and code comments that no longer describe the code beneath them.

This skill **reports by default. It does not edit anything** until the user picks which findings to fix.

## Core principle

**The code is the source of truth; docs are claims about it.** A finding is a specific claim plus the evidence that contradicts it. "This README looks old" is not a finding. "`README.md:42` says to run `make bootstrap`, but the Makefile has no `bootstrap` target (renamed to `setup` in `Makefile:12`)" is.

Only report what you have verified by opening the code. If you can't check a claim (it describes an external system, a dashboard, a production setting), put it under **Could not verify** rather than guessing either way.

## Steps

### 1. Determine scope

- **No argument** → the whole repo.
- **Path or glob** → only those docs / only comments in those source files. Still read whatever code and other docs they refer to.
- **`--diff [base]`** → docs and comments put at risk by the current changes: `git diff --name-only <base>...HEAD` (base defaults to the main branch) plus uncommitted changes. Review (a) docs and comments touched by the diff, and (b) any doc anywhere in the repo that mentions a file, symbol, command, flag, or config key the diff changed, renamed, or removed. (b) is the important half — a diff rarely breaks the doc it edits.

If not in a git repo, skip the git-based steps and work from the files alone.

### 2. Inventory what to review

**Documents** — find them, don't assume a layout:
- `README*`, `CONTRIBUTING*`, `CLAUDE.md`, `AGENTS.md`, `docs/`, `runbooks/`, `playbooks/`, `wiki/`, `*.md`, `*.mdx`, `*.rst`, `*.adoc`, `*.txt` in doc-like locations
- Operational text living outside docs: Makefile help text, CLI `--help` strings, PR/issue templates, comments in CI configs, Dockerfiles, and sample config files

**Code comments** — docstrings, block comments above functions/classes/modules, and inline comments that make a claim about behavior (`# retries 3 times`, `// must be called before init()`, `TODO: remove after v2 migration`).

**Exclude** (these are records of the past, not claims about the present):
- Changelogs, release notes, ADRs, dated design docs / RFCs, postmortems, meeting notes
- Vendored, generated, or third-party content (`node_modules/`, `vendor/`, build output, generated API docs)
- Never read `.env`, `.env.*`, `*.env`, key files, or anything under `secrets/` / `credentials/`. Verify environment variable claims against the code that reads the variable, not against env files.

An ADR or design doc is only in scope when a *live* doc cites it as the current behavior.

For a large repo, split the inventory by directory and review the groups with parallel subagents, giving each the claim types and finding format below; merge and de-duplicate their results, then do the cross-document pass (step 4) yourself, since it needs the whole picture.

### 3. Check each document and comment against the code

Read each doc and pull out every **checkable claim**. Then verify each one by finding the thing it refers to.

| Claim type | How to verify |
|---|---|
| File and directory paths | Does the path exist? Is it still what the doc says it is? |
| Commands, scripts, make/npm/task targets | Does the target or script exist with that name? Do the flags and arguments it shows still exist? |
| Function, class, module, endpoint, table, and column names | Grep for the symbol. Same name, same signature, same location? |
| Config keys, env vars, feature flags | Is the key still read by the code? Same name, same default, same accepted values? |
| Defaults, limits, timeouts, ports, retry counts, versions | Compare the stated number to the constant or config in the code |
| Supported versions and dependencies | Compare with the manifest and lockfile, CI matrix, Dockerfile base images |
| Described behavior ("X calls Y", "returns null when…", "runs nightly") | Read the code path and confirm it does that |
| Ordered procedures (setup guides, runbooks) | Walk the steps in order: does each step's precondition still hold after the previous one? Are steps missing that the code now requires? |
| Code samples and snippets | Would the sample work against the current API — imports, names, argument order? |
| Internal links and anchors | Does the target file and heading exist? |
| Architecture and directory-layout descriptions | Compare with the actual tree and module boundaries |

Also check the reverse direction for the main entry-point docs: is there something significant in the code that the doc **omits** and a reader following it would trip over — a new required env var, a new setup step, a new required service? Report omissions only when they would cause a reader to fail, not for every undocumented feature.

**For code comments specifically**, a comment is stale when:
- It describes behavior the code beneath it no longer has (parameters, return values, thrown errors, side effects, ordering requirements)
- A docstring's parameter list, types, or return description doesn't match the signature
- It refers to a name that no longer exists (a renamed function, a removed flag, a deleted file)
- A `TODO` / `FIXME` / `HACK` is conditional on something that has already happened ("remove once X ships", "temporary until v2") or references a closed ticket
- It is commented-out code that the surrounding code has moved past

**Use git to find leads, not to make findings.** When a doc hasn't been touched in a long time but the code it describes has changed heavily, that is where to look hardest:

```bash
git log -1 --format=%cs -- <doc>                 # when the doc last changed
git log --oneline --since=<that date> -- <paths the doc describes>
```

Age alone is never a finding — an old doc about stable code is fine. A lead only becomes a finding once you identify the specific claim that is now wrong. `git log -S'<old name>'` is useful for confirming when and why something was renamed or removed.

### 4. Check the documents against each other

Once every doc has been read, compare what they say about the same subject:

- **Contradictions** — two docs giving different values for the same thing: a different command for the same task, a different port, a different required version, a different order of steps, different ownership or escalation contacts
- **Diverged duplicates** — the same procedure copied into two places where one copy was updated and the other wasn't
- **Terminology drift** — one thing called by different names across docs (or one name used for two things) to the point a reader could be misled; ignore harmless wording variation
- **Broken cross-references** — a doc pointing to a section, file, or doc that has moved or says something different now

For each conflict, settle it against the code where possible and say which doc is right. When the code can't settle it (a process, a policy, an owner), don't pick a winner — report both sides and mark it **Needs decision**.

### 5. Rate and report

Severity is about what happens to someone who trusts the text:

| Severity | Meaning |
|---|---|
| **High** | Following it causes harm or a dead end: a runbook step that fails or does the wrong thing during an incident, a command that no longer exists, a destructive instruction that is now wrong, security guidance that's out of date |
| **Medium** | Misleading but recoverable: wrong default, renamed symbol, a comment describing behavior the function no longer has, docs contradicting each other |
| **Low** | Minor drift: a dead internal link, an outdated but harmless example, an obsolete TODO |

Runbooks and setup guides get the benefit of the doubt upward — they are read under pressure and followed literally.

Report each finding as:

```
### <short title>
- **Where:** `<file>:<line>`
- **Says:** "<the claim, quoted>"
- **Actually:** <what the code or the other doc says> — `<file>:<line>`
- **Type:** Stale vs code | Contradicts another doc | Stale comment | Omission | Broken reference
- **Severity:** High | Medium | Low
- **Suggested fix:** <the corrected text, or "delete", or "Needs decision: <the question>">
```

Order findings by severity, then end with:

1. A summary table — `| # | Location | Problem | Type | Severity |`
2. **Could not verify** — claims about things outside the repo, listed so the user can check them
3. **Reviewed and clean** — one line naming what was checked and found accurate, so the user knows the coverage (a short report should mean "the docs are good", not "little was checked")

If nothing is wrong, say so plainly and state what was covered.

### 6. Offer to fix

Ask which findings to fix. Then:

- **Fix the docs to match the code, never the code to match the docs.** If a mismatch looks like the *code* is the thing that's wrong (the doc describes the intended behavior and the code regressed), stop and flag it as a possible bug rather than editing either side.
- Make the smallest edit that makes the text true. Don't rewrite, restructure, or restyle surrounding prose.
- For a stale comment that only restated what the code does, delete it rather than rewriting it. Rewrite only comments that carry a reason the code can't express.
- For diverged duplicates, prefer making one copy canonical and having the other link to it over fixing both in place — but propose this, don't do it unasked.
- Leave **Needs decision** items alone until the user answers.
- Commit doc fixes as `docs:` commits, grouped by logical change; comment-only changes in source files are also `docs:`.

## Notes

- Not in scope: grammar, spelling, tone, formatting, or whether more documentation should exist. This skill checks truth and agreement, not quality.
- Quote the claim and cite the contradicting line for every finding. A finding without both is a suspicion — verify it or drop it.
- Don't report the same root cause many times. If a rename broke twelve references, report it once with all twelve locations.
- A doc that is deliberately aspirational (a roadmap, a "planned" section) is not stale for describing things that don't exist yet — only flag it if it presents the plan as current behavior.
