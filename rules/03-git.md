---
title: Git & Versioning Rules (Conventional Commits)
harnesses: [claude, cursor]
cursor-always-apply: true
---

## Git & Versioning Rules (Conventional Commits)

All commit messages, PR titles, and release tags must follow the [Conventional Commits v1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification.

### Commit Grouping Strategy

- **One logical change per commit.** A commit should represent a single cohesive unit of work — something that could be described with one Conventional Commits type and a clear description.
- **Separate unrelated changes into different commits.** If unstaged changes span multiple concerns (e.g., a bug fix and a refactor and a dependency bump), stage and commit them separately, each with the appropriate type.
- **Before committing a large set of unstaged changes**, run `git diff` and analyze the changes first. Group them into logical units, then commit each group in sequence — do not blindly `git add -A` and commit everything at once.
- A good test: if a commit message requires "and" to describe what it does, it probably should be two commits.

### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

- The description must immediately follow the `type:` or `type(scope):` prefix.
- Body is separated from the description by one blank line.
- Footers are separated from the body (or description if no body) by one blank line.

### Types and SemVer Mapping

| Type | When to use | SemVer impact |
|---|---|---|
| `feat` | New feature | MINOR bump |
| `fix` | Bug fix | PATCH bump |
| `perf` | Performance improvement | PATCH bump |
| `refactor` | Code change that is neither a fix nor feature | none |
| `docs` | Documentation only | none |
| `style` | Formatting, whitespace, no logic change | none |
| `test` | Adding or updating tests | none |
| `build` | Build system or dependency changes | none |
| `ci` | CI/CD config changes | none |
| `chore` | Maintenance tasks not fitting other types | none |

### Breaking Changes → MAJOR bump

Use either or both:
1. Append `!` before the colon: `feat(api)!: remove deprecated endpoint`
2. Add a `BREAKING CHANGE:` footer (must be uppercase):

```
feat(auth)!: replace session tokens with JWTs

BREAKING CHANGE: session-based auth endpoints removed; clients must migrate to /auth/token
```

### Scope

- Optional. Use a noun describing the affected area: `feat(parser):`, `fix(db):`, `ci(docker):`
- Keep scopes consistent within a project.

### PR Titles

- PR titles must follow the same `type(scope): description` format as commit messages.
- The PR title becomes the squash-merge commit message, so it must be spec-compliant.

### Branching Strategy (GitHub Flow)

Follow GitHub Flow: `main` is always releasable. All work happens on short-lived branches cut from `main`, merged back via PR, then deleted.

**Branch naming must mirror the Conventional Commits type:**

```
feat/<short-description>       # new feature
fix/<short-description>        # bug fix
chore/<short-description>      # maintenance, deps, tooling
docs/<short-description>       # documentation only
refactor/<short-description>   # no behavior change
hotfix/<short-description>     # urgent fix, merges directly to main
release/vMAJOR.MINOR.PATCH     # optional release hardening branch
```

- Use kebab-case for the description (e.g., `feat/user-auth`, `fix/login-timeout`)
- Branches should be short-lived — days, not weeks. A long-lived branch is a signal the work should be split into smaller PRs.
- Delete branches after merging.
- Never commit directly to `main` except for trivial single-line fixes with no review needed.

### Release Tags

- Tags must follow `vMAJOR.MINOR.PATCH` (e.g., `v1.4.2`).
- Bump rules derived from commits since last tag:
  - Any `BREAKING CHANGE` or `!` → bump MAJOR, reset MINOR and PATCH to 0
  - Any `feat` (non-breaking) → bump MINOR, reset PATCH to 0
  - Any `fix` or `perf` (non-breaking) → bump PATCH only
  - `refactor`, `docs`, `style`, `test`, `build`, `ci`, `chore` → no version bump (unless combined with the above)
- Do not create release tags manually without confirming the correct next version based on the above rules.
