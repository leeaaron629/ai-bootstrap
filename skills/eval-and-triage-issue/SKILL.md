---
description: Evaluate and triage issues from a PR, raw text, JIRA, or GitHub — do a cost/benefit tradeoff on each (severity vs added complexity) and recommend fix now / defer / won't fix before touching any code.
argument-hint: "[PR link | issue text | JIRA key | repo issue URL]"
---

# Eval and Triage Issue

Given a source of issues (a PR link, raw issue text, a JIRA ticket, or GitHub repo issues), evaluate each one and produce a **tradeoff analysis**: weigh the value of fixing it against the complexity it adds to the codebase, then recommend an action. The goal is balance — fix what's worth fixing, and explicitly decline what isn't.

This skill **analyzes and recommends by default. It does not edit code** until the user picks which recommendations to act on.

## Core principle

Every fix has a cost. Adding code to handle a rare, harmless edge case can make the codebase worse, not better. But the same amount of code is clearly worth it if the edge case is frequent or dangerous. The job is to find the balance point for each issue, not to fix everything.

## Steps

### 1. Gather the issues

Identify the source from the input and collect the issue(s):

- **PR link** → `gh pr view <url> --json title,body,comments,reviews,files` and `gh pr diff <url>`. Treat review comments and failing checks as candidate issues.
- **Raw text** → parse the pasted text directly; each distinct problem is one issue.
- **JIRA key/link** (e.g. `PROJ-123`) → fetch via the JIRA MCP/CLI if available; otherwise ask the user to paste the ticket body.
- **GitHub repo issues** → `gh issue list` / `gh issue view <n> --json title,body,comments`.

If the source is ambiguous or you can't access it, say so and ask for the issue text directly rather than guessing.

Read enough of the relevant code to judge each issue accurately — grep/read the specific files involved before scoring. Do not score from the issue description alone if the code is reachable.

### 2. Score each issue on two axes

**Axis A — Severity = Frequency × Impact** (how much the issue matters)

| Frequency | Meaning |
|---|---|
| Constant | Happens on most/every run or for most users |
| Common | Happens regularly under normal use |
| Occasional | Happens under specific but realistic conditions |
| Rare | Requires an unusual combination of conditions |
| Theoretical | No known real-world trigger |

| Impact | Meaning |
|---|---|
| Critical | Data loss, security hole, corruption, crash, money/legal risk |
| High | Broken core feature, wrong results, blocked workflow |
| Medium | Degraded UX, recoverable error, confusing behavior |
| Low | Cosmetic, log noise, minor inconsistency |

**Axis B — Cost = complexity the fix adds** (NOT lines of code)

Lines of code are a weak proxy. Judge actual complexity:
- New abstractions, dependencies, or config surface
- New state, new branching/control-flow paths, new failure modes
- Increased coupling or blast radius
- Test and maintenance burden
- Cognitive load for the next reader

Rate cost as **Trivial / Low / Medium / High**. A localized one-liner is usually Trivial even if it fixes something real. A 50-line change that introduces a new caching layer is High even if each line is simple.

### 3. Apply the recommendation matrix

|                     | Trivial cost | Low cost | Medium cost | High cost |
|---------------------|--------------|----------|-------------|-----------|
| **Critical/High severity** | Fix now | Fix now | Fix now | Fix now — essential, but flag the complexity |
| **Medium severity**        | Fix now | Fix soon | Defer / discuss | Won't fix unless severity is rising |
| **Low severity**           | Quick win (fix if trivial) | Defer | Won't fix | Won't fix |

Recommendation vocabulary:
- **Fix now** — worth it; do it this pass.
- **Fix soon** — worth it but not urgent; track it.
- **Defer** — revisit if frequency/impact increases; not worth the complexity today.
- **Won't fix** — the complexity outweighs the benefit; state this explicitly so it's a decision, not an oversight.
- **Needs discussion** — genuine judgment call or missing context; surface the tradeoff and ask.

Override the matrix when warranted, but say why (e.g. "Defer despite Trivial cost — the fix masks a deeper bug we should address instead").

### 4. Present the triage report

For each issue, output:

```
### <short issue title>
- **Severity:** <Frequency> × <Impact> → <overall>
- **Cost:** <Trivial|Low|Medium|High> — <what makes it that, beyond LOC>
- **Recommendation:** <Fix now | Fix soon | Defer | Won't fix | Needs discussion>
- **Rationale:** <one or two sentences tying severity vs cost to the call>
- **Approach (if fixing):** <brief sketch of the minimal fix>
```

End with a summary table ordered by recommendation (Fix now first):

| Issue | Severity | Cost | Recommendation |
|---|---|---|---|

### 5. Offer to act

After the report, ask which items to act on. Only then apply fixes — smallest, most localized change that resolves each chosen issue. Do not expand scope beyond the agreed items.

## Worked examples

These calibrate the scoring. Match the *reasoning*, not the surface details.

### Example 1 — Rare + harmless → Defer (the 50-line trap)
Issue: "If the config file is hand-edited to contain a duplicate key while the process is mid-reload, the second value silently wins."
- **Severity:** Rare (manual edit during a reload window) × Low (one config value, recoverable on next clean load) → Low
- **Cost:** Medium — reload lock + duplicate-key detection + new error path (~50 lines, new failure mode)
- **Recommendation:** Defer
- **Rationale:** The complexity outweighs a bug almost no one will hit harmlessly. Revisit if reloads become frequent.

### Example 2 — Rare BUT dangerous → Fix now (same fix, opposite call)
Issue: "Same duplicate-key race, but the affected key is the auth token signing secret — the wrong value lets expired tokens validate."
- **Severity:** Rare × Critical (auth bypass) → Fix now
- **Cost:** Medium — identical ~50 lines to Example 1
- **Recommendation:** Fix now
- **Rationale:** Identical cost to Example 1, opposite call. Critical impact overrides low frequency. Flag the complexity for review, but ship it.

### Example 3 — Small + real → Fix now (the cheap win)
Issue: "Pagination off-by-one drops the last item when the total is an exact multiple of page size."
- **Severity:** Common (every exact-multiple result set) × Medium (missing data, but visible) → Fix now
- **Cost:** Trivial — a one-line `<=` vs `<` boundary fix, fully local
- **Recommendation:** Fix now
- **Rationale:** Trivial cost, real and frequent. No reason to defer.

### Example 4 — Medium + medium → Fix soon (the track-it middle)
Issue: "API returns 200 with an error body instead of a 4xx on validation failure; clients must special-case it."
- **Severity:** Common × Medium → Medium
- **Cost:** Medium — status code change is a soft API contract break; needs client coordination
- **Recommendation:** Fix soon
- **Rationale:** Worth doing, but coordinate the rollout rather than patch hastily.

### Example 5 — Low severity + high cost → Won't fix (explicit decline)
Issue: "Timestamps in logs use local time, not UTC; mildly confusing when correlating across regions."
- **Severity:** Occasional × Low → Low
- **Cost:** High — touches every log call site, new formatting layer, test churn
- **Recommendation:** Won't fix
- **Rationale:** A cosmetic-ish problem with a large blast radius. Decline explicitly so it's a decision, not an oversight.

### Example 6 — LOC ≠ complexity → Defer (few lines, high real cost)
Issue: "Retry logic could be made generic to cover three call sites instead of two."
- **Severity:** Occasional × Low → Low
- **Cost:** High despite ~15 lines — introduces a shared abstraction + coupling across modules
- **Recommendation:** Defer
- **Rationale:** Small diff, big conceptual cost. Premature abstraction for marginal gain — proof that LOC is not complexity.

### Example 7 — Unknown frequency → Needs discussion (missing context)
Issue: "In-memory cache has no eviction; could grow unbounded under sustained unique-key load."
- **Severity:** Unknown × High → can't score
- **Cost:** Medium — add LRU/TTL eviction
- **Recommendation:** Needs discussion
- **Rationale:** Whether this is Critical or Theoretical depends on real key cardinality, which we don't know. Ask before scoring.

## Notes

- Default to **less code**. When a fix and a non-fix are genuinely close, prefer not adding complexity and mark it Defer with a clear trigger for revisiting.
- Never silently skip an issue. Every input issue must appear in the report with a recommendation — "Won't fix" is a valid, explicit answer.
- Severity beats cost: a Critical issue gets fixed even at High cost, but call out the complexity so it can be reviewed.
- Don't pad a Trivial fix into a large one — if it's a one-liner, keep it a one-liner.
- When you lack the context to score accurately (unknown frequency, can't see the code), say so and mark it Needs discussion rather than guessing.
