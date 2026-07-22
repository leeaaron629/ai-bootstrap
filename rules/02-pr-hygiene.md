---
title: PR Hygiene Rules
harnesses: [claude, cursor]
cursor-always-apply: true
---

## PR Hygiene Rules

- Before marking a PR ready for review, verify that docs, configs, and tooling references reflect the actual state of the code.
- When a reviewer (human or bot) flags a stale reference or mutable dependency, fix it in the same PR rather than deferring to a follow-up.
- After pushing a fix for PR feedback, reply in the PR thread summarizing what was changed and why.
