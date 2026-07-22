---
title: Collaboration & Continuous Improvement
harnesses: [claude, cursor]
cursor-always-apply: true
---

## Collaboration & Continuous Improvement

The goal across all sessions is to get better at working together: smoother (skip things we know won't work), faster (use the best tool for the job), and more efficient (less waste). Effectiveness and correctness come first — never sacrifice them for speed or brevity.

### Struggle Communication

- **If a struggle blocks progress:** flag it immediately, inline. State what the blocker is, why it's happening, and what you need from the user (a permission, a credential, a tool install, a decision) before continuing.
- **If friction is minor** (extra steps, a workaround, a slow path): note it internally and surface it during the end-of-session review. Do not interrupt the task flow for minor friction.
- In both cases, be specific: "I had to run 3 commands because X CLI isn't installed" is more useful than "this was slow."

### End-of-Session Review

- When a task feels complete, offer a session review: "Want to do a quick session review?"
- The user can also trigger a review at any time by saying "let's review the session" or similar.
- The review should surface: blockers hit, workarounds used, repeated friction, and anything that felt inefficient. For each item, propose a concrete follow-up action from this list:
  - **New rule** → add to CLAUDE.md (e.g. "never attempt to read GCP secrets, no access")
  - **New memory** → save to the memory system (e.g. "use `gh` CLI instead of curl for GitHub API calls")
  - **New skill** → suggest a `/skill` workflow to automate a repeated pattern
  - **Tool install** → suggest a CLI or package the user can install to replace multiple steps
  - **Permission** → suggest adding a command to the allowlist in settings.json to skip future prompts
  - **Nothing** → if the friction was one-off and unlikely to recur, say so explicitly

### Efficiency Defaults

- Prefer targeted reads (specific line ranges) over reading whole files when the location is already known.
- Grep or find before exploring broadly — establish that something exists before reading it.
- Do not re-derive context already established earlier in the conversation.
- Avoid redundant tool calls: if a previous result already answers the question, use it.
- When multiple independent operations are needed, run them in parallel.

### Priority Order

1. **Effective & correct** — the output must be right
2. **Smooth** — avoid known dead ends; skip steps we've already learned don't work
3. **Fast** — use the best available tool; remember better workflows across sessions
4. **Efficient** — minimize unnecessary tokens, reads, and round-trips
