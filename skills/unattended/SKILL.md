---
description: Run a task or execute an implementation plan autonomously, with no human in the loop. Front-loads every decision into a single upfront contract, then works an isolated git worktree + branch to completion — self-verifying (lint/test/build) in place of human review, proceeding with a documented best-guess assumption on reversible/low-risk decisions and halting-and-parking only on irreversible/high-risk ones. Ends by committing on the branch (default) or, with `--pr`, pushing and opening a DRAFT PR. Accepts an inline task, a path to a plan file in ~/.claude/plans/, or a plan already in the conversation. Use for "run this unattended", "execute this plan without supervision", "do this hands-off / while I'm away", or "/unattended ...".
argument-hint: "[task description | plan file path | 'the plan above'] [--pr]"
---

# Unattended

Execute a task or an implementation plan **without supervision**. The normal
workflow assumes a human is present at every gate — destructive-command
confirmation, issue-triage approval, the Post-Change Actions menu, session
wrap-up. Unattended removes that human, so this skill does two things instead:

1. **Front-loads every decision into one upfront contract** — the single, and
   only, interactive moment. After that, the run goes dark.
2. **Replaces human review with continuous self-verification** — the repo's own
   lint/test/build gates, plus a final self-review of the diff, stand in for the
   review you would otherwise do.

The defining rule: **once running, this skill does not ask questions.** Every
decision is resolved by the hybrid blocker policy (§6) — proceed on reversible,
park on irreversible — never by pausing for you.

## Invocation

```
/unattended <task | plan-file path | "the plan above">     # default: commit-and-stop
/unattended --pr <...>                                     # go through push + DRAFT PR
```

**Input sources** (all supported):
- **Inline description** — the argument text is the task.
- **Plan file** — a path (usually under `~/.claude/plans/`); read it and execute it.
- **Plan in conversation** — "the plan above" / a plan just produced in this session.

**End state** is selected by the `--pr` flag (or a trailing `pr` / `push` keyword);
absence means **commit-and-stop** on the branch. This is the only knob; everything
else is fixed by the contract.

## 1. The upfront contract — the ONLY interactive step

Before doing any work, confirm the contract with the user in **one exchange**, then
hand off to autonomous execution. State, concisely:

- **Task / plan** — restate the interpreted task, or load the plan file/conversation
  plan and echo its scope back so the user can catch a misread.
- **Success criteria** — how the run will know it's done (all plan steps checked off,
  tests green, build passes, the specific behavior works).
- **Verification gates** — the repo gates it detected and will run (see §5).
- **End state** — branch-and-stop (default) or push + draft PR (`--pr`), and the
  worktree/branch name it will use.
- **Autonomy boundaries** — one line: it will proceed-with-assumption on reversible
  calls and park irreversible ones, and will not ask again once running.

If the task is too ambiguous to even start safely — a bug with no repro, an API
change with no concrete consumer, a plan step whose intent can't be recovered — **ask
now**, using `AskUserQuestion`. This is the last chance. Ask only what genuinely
blocks starting; do not turn the contract into a design review. If nothing blocks
starting, state the contract and proceed without waiting.

## 2. Set up isolation (always a worktree)

Every run is isolated so the user's working tree is never touched.

1. **Detect the default branch** — never assume `main`:
   ```bash
   git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
   ```
   Fall back to `origin/main`, then `origin/master`. Call this `<default>`.
2. **Derive a slug** — kebab-case, from the task/plan (`<type>/<short-slug>`, e.g.
   `feat/unify-code-locations`). Collision-guard against `git worktree list`; append a
   disambiguator if the slug already exists.
3. **Enter the worktree** — `EnterWorktree` with `name = slug`. This creates a fresh
   worktree under `.claude/worktrees/` on a new branch off `origin/<default>` and
   switches the session into it.
4. **Confirm** in one line which worktree + branch the run is on.

## 3. Execute — the autonomous loop

- **Track the work** with `TaskCreate` — one task per plan section, or a sensible
  decomposition of an inline task. Mark `in_progress` / `completed` as you go so the
  user can watch progress live while away.
- **Search first** before writing code (Grep/Glob, or an Explore agent) — reuse
  existing patterns and utilities rather than adding new code.
- **Smallest scoped change** per step. Keep edits idiomatic to the surrounding code
  (naming, comments, structure). No speculative scope, no "while I'm here" refactors.
- **Commit strategy**: one logical change per commit. Do **not** commit after each
  fix-test attempt — iterate (fix → test → fix → pass) and commit **once** per logical
  unit.

## 4. Self-verification replaces human review

Run gates **continuously** — after each logical unit and before every commit — not
just at the end. There is no human to catch a regression, so the gates must.

- **Detect gates once** during the contract, in priority order:
  - `Makefile` present → `make format && make lint && make test`
  - else JS/TS (`package.json`) → `npm run lint && npm run typecheck && npm test`
  - else Python → `ruff`/`black` + `pytest`
  - `.github/workflows/**` touched → `actionlint`
  - `*.md` touched → `markdownlint`
- If the **plan has its own Verification section**, run those steps too.
- **Final self-review** before finishing: re-read the full diff for bugs, unhandled
  edge cases, and leftover debug code. This stands in for the "Check for bugs"
  Post-Change Action you can't be asked about.

A gate that fails is not a stopping point on its own — fix and re-run, up to a bounded
number of attempts (§6). A gate that keeps failing becomes a parked item.

## 5. Hybrid blocker policy — the heart of the skill

Every decision the run would normally surface is sorted into one of two buckets.

**Proceed-with-assumption (reversible / low-risk)** — pick the best-supported default,
**log the assumption** (for the final report), and keep going:
- naming, internal file/module structure, test layout;
- choosing between two equivalent libraries already in the repo;
- borderline hygiene calls (apply the `eval-and-triage-issue` severity/cost rubric);
- ambiguous-but-recoverable plan wording where one reading is clearly most likely.

**Halt-and-park (irreversible / high-risk)** — do **not** guess; record why + what's
needed to unblock, then continue with other independent steps and surface it in the
report:
- anything on the Absolute-never list (§6a);
- schema or data migrations;
- deleting or overwriting files the run did not create;
- changing a public API or external contract without a clear spec;
- a verification gate still failing after a bounded number of fix attempts (default 3);
- a plan step whose intent can't be recovered and would be costly to undo.

Judgment rubric: apply the `eval-and-triage-issue` meta-principles. Never invent work to look
busy, never pad scope, never YAGNI-dismiss real hygiene (trust-boundary validation,
observability, tests-as-tripwires).

### 5a. Absolute-never list (overrides every flag, even `--pr`)

- **No real PII/PHI** in any output, commit, log, or artifact; **no production access**.
- **No `git push --force`**; never push to `<default>`; PRs open as **draft** only.
- **No committing secrets/credentials**; never delete the user's uncommitted work.
- **No irreversible external side effects** — prod deploys, data deletion, sending
  mail/messages/notifications — regardless of the end-state flag. These always park.

## 6. End state

- **Default — commit-and-stop.** Ensure everything is committed on the branch. Do
  **not** push. Report readiness and give the exact `git push -u origin <branch>` and
  PR command for the user to run when they return.
- **`--pr`.** `git push -u origin <branch>`, then `gh pr create --draft` with a body
  containing: what was done, the **assumptions log**, **parked items**, and
  verification results. Follow the PR conventions: title
  `<type>: <description> [<TICKET-ID | no ticket>]` (extract the ticket from the
  branch if present). Draft status keeps a human on the merge gate.

## 7. Final report (always)

Regardless of end state, finish with a structured summary the user reads on return:

- **Outcome marker** — ✅ Fixed / ⚠️ Partial / ❌ Blocked.
- **Completed** — steps done, with commit SHAs.
- **Parked** — steps not done, each with the reason and what's needed to unblock.
- **Assumptions log** — every reversible decision made without asking.
- **Verification** — which gates ran and their pass/fail results.
- **Next command** — worktree/branch name and the exact push/PR command, or how to
  resume (`/worktree-task resume <slug>`).

## Anti-patterns

- **Asking a question mid-run.** Defeats "unattended." Resolve via §5, or park it.
- **Guessing on an irreversible action** instead of parking it.
- **Skipping verification** because "the change is obviously fine" — no human will catch it.
- **Committing after every fix attempt** instead of once per logical unit.
- **Padding scope or inventing findings** to look thorough.
- **Pushing, opening a non-draft PR, or touching `<default>`.**
- **Leaving assumptions or parked items out of the final report** — the report is how
  the user recovers the context they missed by being away.
