---
description: Wrap a single interactive Claude session in its own isolated git worktree so you can run several sessions (one per terminal) against the same repo at once without their file edits colliding. Invoke once per terminal with the task; the skill moves the current session into a dedicated worktree + branch and works the task with full back-and-forth. Also provides cross-session modes — status (summarize every parallel task and its live git state), resume (re-enter an existing worktree), assemble (open one PR per branch OR merge cohesive branches into a single PR), and cleanup. Use for "work on <task> in a worktree", "isolate this task", "/worktree-task ...", running parallel terminals on one repo, or asking for the status of parallel tasks.
argument-hint: "[task description | status | resume <slug> | assemble | cleanup]"
---

# Worktree Task

Run several interactive Claude sessions against one repo at the same time —
one terminal per task — each isolated in its own git worktree and branch so
their edits never collide. At the end, decide whether each task becomes its own
PR or several cohesive tasks combine into one.

This skill does NOT spawn background agents. Each invocation sets up (or
inspects) worktrees; you and Claude then work each task interactively in its
own terminal.

## Invocation

```
/worktree-task <task description>     # start a task in a new worktree (default mode)
/worktree-task status                 # summarize all worktree-tasks + live git state
/worktree-task resume <slug>          # re-enter an existing worktree in this session
/worktree-task assemble               # open PRs: one per branch, or combine cohesive ones
/worktree-task cleanup                # remove worktrees whose branch is merged
```

The first word of the argument selects the mode (`status` / `resume` /
`assemble` / `cleanup`); anything else is treated as a task description for the
default **start** mode.

## PR grouping is a judgment call, not a flag

Which tasks belong in one PR is decided from what the user describes, not a CLI
option:

- If the user's description says (or implies) this task is part of a larger
  change with others — e.g. "refactor the parser; this goes with the bugfix and
  tests I'm running in the other terminals" — record that intent as a
  `pr_group`.
- If the description doesn't make grouping clear, **ask the user**: is this
  standalone (its own PR) or part of a combined PR with other tasks? Use their
  answer; don't guess silently.
- Keep a group cohesive — one coherent change (e.g. a refactor + its bugfix +
  its tests), never unrelated work bundled together.

## The registry

A small JSON registry tracks intent that git cannot know. Path:

```
~/.claude/worktree-tasks/<repo-name>.json
```

where `<repo-name>` is `basename` of `git rev-parse --show-toplevel`. Shape:

```json
{
  "tasks": [
    { "slug": "fix-parser-bug", "branch": "fix/parser-bug",
      "worktree": ".claude/worktrees/fix-parser-bug",
      "task": "fix null deref in claims parser", "pr_group": "claims-parser",
      "status": "active" }
  ]
}
```

Create the file (and `~/.claude/worktree-tasks/`) if missing. `status` is
`active` | `done`. `pr_group` is null for standalone tasks. **Never** read or
store PII/PHI in the registry — short task descriptions only.

Rule of thumb: the registry holds only human intent (`task`, `pr_group`).
Everything about current progress is derived live from git at query time, so it
can never go stale.

## Determining the default branch

Every mode compares against the repo's default branch — written `<default>`
below. **Never assume `main`**, and never use the local checkout's current
branch (the main checkout may be parked on any feature branch). Detect it:

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

If that prints nothing (origin/HEAD not set), fall back: try `origin/main`,
then `origin/master`, then ask the user. Worktrees are always branched from
`origin/<default>`, independent of where the main checkout is currently parked.

## Mode: start (default)

1. **Read the task** from the argument. If none given, ask for it in one line.
2. **Decide grouping.** From the description, determine whether this task is
   standalone or part of a combined PR (see "PR grouping" above). Ask the user
   if it isn't clear. Record the resulting `pr_group` (or null).
3. **Derive a slug / branch.** Check convention with `git branch -a`; default to
   `<type>/<short-slug>` (e.g. "fix the actionlint scan" → `fix/actionlint-scan`).
   Slug = kebab-case, no spaces. Ask only if you can't derive a sensible name.
4. **Collision guard.** Read the registry and `git worktree list`. If the slug
   already exists, append a short disambiguator or ask. Two terminals must never
   target the same worktree.
5. **Record intent** in the registry (slug, branch, worktree path, task,
   pr_group, `status: active`) BEFORE entering the worktree.
6. **Enter the worktree.** Call `EnterWorktree` with `name` = slug. This creates
   a fresh worktree under `.claude/worktrees/` on a new branch (based on
   `origin/<default>`) and switches this session into it.
7. **Confirm in one line** which worktree + branch this session is on, plus the
   PR group if any, so the user can tell terminals apart.
8. **Work the task** normally — plan, edit, run, iterate. Use `TaskCreate` for
   multi-step work. Commit on the branch when done; do not push unless asked or
   until `assemble`.

## Mode: status

Run from any terminal. Combine the registry (intent) with live git state. Do
NOT rely on stored progress — compute it:

- `git worktree list` → which worktrees exist + paths.
- Per branch: `git rev-list --count origin/<default>..<branch>` → commits ahead.
- Per worktree: `git -C <path> status --porcelain` → clean vs dirty.
- Last commit subject per branch: `git log -1 --format=%s <branch>`.
- Merged? `git branch --merged origin/<default>` → mark done / cleanable.

Print grouped by `pr_group` (those that will become one PR) then standalone
tasks:

```
claims-parser  (→ 1 combined PR)
  fix/parser-bug         2 commits   clean    "fix null deref"
  refactor/parser        3 commits   dirty    "extract tokenizer"
standalone
  chore/bump-module      1 commit    clean    "bump ephemeral-core to v2.0.3"  [merged → cleanup]
```

Keep output PII-safe (counts, branch names, your own commit subjects only).

## Mode: resume <slug>

Re-enter an existing worktree in this session so you can continue a task in a
fresh terminal. Look up the slug in the registry / `git worktree list`, then
call `EnterWorktree` with `path` = that worktree's path. Confirm the branch,
then continue working.

## Mode: assemble

Turn finished work into PRs. **Guide the user on grouping; if unsure, ask — then
assemble for them.**

1. **Propose the plan.** Read the registry and live git state. Lay out which
   tasks you'll open as standalone PRs and which you'll combine into a single PR,
   based on recorded `pr_group` and your judgment of cohesion. If any grouping is
   unclear, ask the user to confirm before doing anything.
2. **Standalone task → its own PR.** Ensure it's committed,
   `git push -u origin <branch>`, then `gh pr create` — one PR.
3. **Cohesive set → one combined PR.**
   a. Create the integration branch off the default:
      `git switch -c <group> origin/<default>` (reuse if it exists).
   b. Merge each member branch: `git merge --no-ff <branch>` for each. If a merge
      conflicts (grouped tasks touched the same lines), stop and resolve with the
      user — isolation prevents collisions while editing, not when combining.
   c. `git push -u origin <group>` and open **one** PR covering the combined change.
4. **Conventions.** Write a meaningful PR body summarizing the combined change.
   After a PR is opened, mark the relevant registry entries `done`.

## Mode: cleanup

List worktrees whose branch is already merged into the default
(`git branch --merged origin/<default>`). For each, confirm and remove: use
`ExitWorktree` (`remove`) for the current session's worktree, else
`git worktree remove <path>` and delete the merged branch. Update the registry.

## Notes

- Worktrees share one `.git` object store: a commit on any branch is instantly
  visible to all worktrees, so no pushing is needed *between* them — only when
  opening PRs.
- Git refuses to check out the same branch in two worktrees; that's the
  guarantee that keeps concurrent sessions from colliding.
- Worktrees under `.claude/worktrees/` auto-clean if unchanged; branches persist
  after you leave, so commits/PRs survive closing the terminal.
- Each session must derive a distinct slug, or two terminals will fight over one
  worktree. Naming from the task usually guarantees this; the collision guard in
  start mode is the backstop.
