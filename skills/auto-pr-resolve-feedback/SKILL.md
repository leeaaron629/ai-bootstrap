---
description: Auto-resolve PR feedback for the current branch — fixes actionable comments, commits each fix, pushes, and resolves the thread.
---

# Auto PR Resolve Feedback

Processes all unresolved, actionable PR comments for the current branch: applies fixes, creates commits, pushes, and resolves threads — so the PR stays clean without manual intervention.

## Invocation

Run directly for a one-shot pass:

```
/auto-pr-resolve-feedback
```

To keep it running automatically, use the `loop` skill after the first run (the skill will remind you):

```
/loop 15m /auto-pr-resolve-feedback
```

## Steps

### 1. Find the active PR

```bash
gh pr list --head $(git branch --show-current) --json number,url,state
```

If no open PR is found, report that and stop.

### 2. Fetch all unresolved feedback

- Top-level PR comments: `gh pr view <number> --json comments`
- Inline review comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments`
- PR reviews: `gh pr view <number> --json reviews`

Filter out:
- Comments already marked resolved (GitHub `isMinimized: true` or containing `✅ Addressed` in the reply thread)
- Bot walkthrough/summary comments (e.g. CodeRabbit summaries, Dependabot)

If there are zero unresolved actionable items, report that clearly and stop for this cycle.

### 3. Classify each comment by confidence

- **High confidence** — stale text, wrong reference, clear syntax/style fix, missing import, obvious typo: fix immediately without asking.
- **Low confidence** — architectural change, behavior change, version pinning with unknown latest, security-sensitive: skip and surface to the user with a note.

### 4. For each high-confidence actionable item

1. Read the referenced file and line range.
2. Apply the fix using the Edit tool.
3. Commit the fix immediately with:
   ```
   Fix PR feedback: <one-line description of what was fixed>

   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
   ```
   Commit per logical fix — do not batch unrelated fixes into one commit.
4. Push the branch.
5. Resolve the thread by replying on the comment with:
   ```
   ✅ Addressed in <short commit SHA> — <one-line summary of what was changed>.
   ```
   Use: `gh api repos/{owner}/{repo}/pulls/comments/<comment_id>/replies -f body="..."`
   Then minimize/resolve the thread if the API supports it:
   `gh api graphql -f query='mutation { minimizeComment(input: {subjectId: "<node_id>", classifier: RESOLVED}) { minimizedComment { isMinimized } } }'`

### 5. Post a top-level PR summary comment

After processing all items for this cycle, post a single top-level comment on the PR summarizing the run:

```
gh pr comment <number> --body "..."
```

Format:
```
**Auto-resolved (<timestamp>):**
- ✅ Fixed: <one-line description> → `<file>:<line>` → commit `<short SHA>`
- ⏭️ Skipped: <one-line description> — <reason: low confidence / not actionable>
```

If there were zero actionable items, post:
```
**Auto-resolve check (<timestamp>):** No unresolved actionable comments found.
```

### 6. Report back to the user

Mirror the same summary locally so the user sees it in the terminal without having to open GitHub.

Then suggest running on a loop:

```
To keep this running automatically every 10 minutes, run:
  /loop 15m /auto-pr-resolve-feedback
```

## Notes

- Only reply and resolve threads for comments that were **actually fixed in this run** — never resolve threads speculatively.
- Never amend existing commits — always create a new commit per fix.
- Never force-push.
- If a fix requires a version number you are not confident about (e.g., pinning a Docker image tag), skip it and flag it to the user.
- This skill is safe to run concurrently with normal development — it only touches files referenced in PR comments.
