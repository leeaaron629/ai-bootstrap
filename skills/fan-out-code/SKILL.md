---
description: Dispatch a list of code-fix issues or tasks to parallel subagents, grouping items that touch the same files into one agent to avoid edit conflicts. Accepts issues from conversation context, a file, PR feedback, or inline list. Each agent works its group, verifies, and reports back.
argument-hint: "[issue list | file path | PR url | 'the issues above']"
---

# Fan Out Code

Fan out a set of code-fix issues or tasks to parallel subagents. The key intelligence:
tasks that modify overlapping files get assigned to the **same** agent so
edits never conflict.

## Invocation

```
/fan-out-code                          # use issues already in conversation
/fan-out-code the findings above       # use a report from earlier in the session
/fan-out-code path/to/issues.md        # read issues from a file
/fan-out-code <PR url>                 # pull issues from PR review comments
```

## Steps

### 1. Collect the task list

Identify the source and extract a numbered list of discrete tasks. Each task
needs at minimum: a short title and what to change. Sources:

- **Conversation context** — a tiered report, review findings, or ad-hoc list
  already discussed. Parse each item.
- **File** — read the file, extract items.
- **PR** — `gh pr view <url> --json comments,reviews` + `gh api repos/{owner}/{repo}/pulls/{number}/comments`.
  Each unresolved actionable comment is one task.
- **Inline** — the argument itself is a newline- or semicolon-separated list.

If the input is ambiguous, ask once for clarification, then proceed.

### 2. Determine file targets per task

For each task, figure out which files it will touch. Two strategies, pick the
faster one that works:

- **Explicit** — the task names files or paths directly (e.g., "fix README.md
  line 42"). Use those.
- **Search** — grep/glob for the symbols, functions, or patterns the task
  references. List the files that would need edits.

Output a map: `task # -> [file1, file2, ...]`

### 3. Group by file overlap (branch-aware)

Partition tasks into groups where no two groups share any file **on the same
branch**. Tasks that touch the same file(s) must land in the same group.

**Branch-first rule:** if tasks target different git branches, partition by
branch first — tasks on different branches are never in the same group, even
if they touch the same filename. Each branch-group gets its own agent with
`isolation: "worktree"` so parallel agents don't race on `git checkout`.

Algorithm:
1. Partition tasks by target branch (default: current branch if not specified).
2. Within each branch partition, start with each task in its own group.
3. For each pair of groups (same branch), if their file sets intersect, merge.
4. Repeat until no groups overlap within any branch.

This is union-find over file sets, scoped per branch. The result: N groups
with disjoint file targets within each branch, safe to run in parallel.

Display the grouping to the user before launching:

```
Group 1 (branch: main, files: src/auth.py, src/auth_test.py):
  - #3: Fix token expiry check
  - #7: Add auth error logging

Group 2 (branch: main, files: README.md):
  - #1: Update install instructions

Group 3 (branch: feat/charts, files: charts/values.yaml, charts/_helpers.tpl):
  - #2: Remove unused helper
  - #5: Fix default port value
```

If all tasks land in one group (everything overlaps on one branch), say so —
it runs as a single sequential agent, which is correct.

### 4. Fan out agents

Launch one `Agent` per group in a **single message** so they run concurrently.

Each agent prompt includes:
- The full list of tasks assigned to it, with file paths and descriptions.
- The target branch (if applicable) — the agent should `git checkout <branch>`
  as its first action.
- Instruction to apply fixes via `Edit` (not wholesale file rewrites).
- Instruction to verify after all edits: run the repo's lint/test/build if
  available, or at minimum confirm the edited files are syntactically valid.
- Instruction to report back: which tasks succeeded, which failed and why.

**Isolation:** when tasks span multiple branches, pass `isolation: "worktree"`
on each Agent call so agents get their own working directory and don't race on
`git checkout`. When all tasks are on the current branch (or no branch
switching is needed), worktree isolation is unnecessary — file-set
disjointness is sufficient.

### 5. Collect results

After all agents complete, compile a summary:

```
| # | Task                        | Status | Notes              |
|---|-----------------------------|--------|--------------------|
| 1 | Update install instructions | Done   |                    |
| 3 | Fix token expiry check      | Done   |                    |
| 5 | Fix default port value      | Failed | helm template broke |
```

If any task failed, report why and ask the user how to proceed (retry, skip,
or fix manually).

### 6. Commit (if requested)

Do not auto-commit. After reporting results, ask whether to commit. If yes:

- Group committed changes by conventional-commit type (fix, docs, refactor,
  etc.).
- If all changes are one type, one commit. If mixed, offer to split into
  multiple commits by type or do one combined commit.
- Stage only files the agents touched.

## Edge cases

- **Single task** — skip grouping, just do it directly. No agent overhead for
  one item.
- **All tasks overlap** — one agent handles everything sequentially. Say so
  upfront.
- **Task with unknown file targets** — ask the user, or assign it to its own
  solo group (safe: it can only conflict with itself).
- **Agent fails mid-group** — partial results are kept. The agent reports
  which tasks in its group succeeded before the failure.

## Anti-patterns

- Don't fan out a single task into multiple agents. One task = one agent max.
- Don't guess file targets without grepping. A wrong guess puts tasks in
  separate agents that then conflict.
- Don't auto-commit without asking.
- Don't launch agents that need results from other agents — fan-out is for
  independent work only. Sequential dependencies stay in one group.
