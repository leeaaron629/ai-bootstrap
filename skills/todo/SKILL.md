---
name: todo
description: >
  Fast work-item documentation. Turns a description or pasted notes into
  one or many todo documents using the Motivation / Task / Notes /
  Acceptance Criteria template, and updates a document's state (TODO,
  IN PROGRESS, BLOCKED, DONE, CANCELLED). Storage-agnostic: outputs
  plain markdown that maps onto JIRA, GitHub Issues, or any other place
  the user keeps todos. Use for "/todo", "add a todo", "log this work",
  "mark this done", "start this", or pasting notes to turn into work items.
argument-hint: "[description | notes | <state verb> [path] [reason]]"
---

# /todo: document work and its state

Produce a document describing a piece of work and its current state.
Speed beats polish: draft from what the user gave and output it. Where
the document is kept is up to the user.

## Commands

Detect intent from the arguments. Anything that isn't a state change
is treated as **create**.

| Intent | Examples |
|---|---|
| Create | `/todo fix the login timeout`, pasted notes, `/todo` (no args) |
| Change state | `/todo start` with a pasted document, `/todo done path/to/item.md`, `/todo blocked waiting on infra` |

## States

| State | Meaning | Verb aliases |
|---|---|---|
| `TODO` | Captured, not started | `reopen`, `todo` |
| `IN PROGRESS` | Actively being worked | `start`, `wip` |
| `BLOCKED` | Can't proceed. A reason is required | `block`, `blocked` |
| `DONE` | Acceptance criteria met | `done`, `finish`, `close` |
| `CANCELLED` | Won't do. A reason is required | `cancel`, `drop` |

Any transition is allowed. If the user asks for `BLOCKED` or
`CANCELLED` without giving a reason, ask for one in a single line.
It's the most useful thing to record.

## Create workflow

### 1. Single or batch?

Read the input. These signals mean **multiple** items: several
distinct titles, a numbered list of separate initiatives, different
owners or estimates per item, or repeated `Goal:` / `Problem:`
headers. One cohesive problem means **single**. Pasting detail
doesn't mean it's a batch.

If you're under 80% confident, say what you think you see in one line
and ask. Otherwise state your read and continue.

### 2. Draft, don't interrogate

Fill the template from whatever the user provided. Skip
one-question-at-a-time unless the input is too thin to draft from
(for example a bare title with no context). In that case ask for
Motivation and Task together in one message.

- Leave a section out instead of padding it. Notes and AC can be
  empty.
- **Never invent identifiers**: no fake repo paths, ticket keys,
  bucket names or links. If one would help, put
  `- TODO: link <thing>` in Notes.
- Title: imperative, under 70 characters, one verb. If it needs "and",
  suggest splitting it.
- Default state is `TODO`. If the user says they're already on it,
  use `IN PROGRESS`.

### 3. Output

Emit each document in its own fenced `markdown` block, using the
[document format](#document-format). For a batch, put a numbered list
of titles and states first so the user can edit by number ("2: change
AC to ...").

## State change workflow

1. Get the document. It's either pasted in the conversation or given
   as a file path. If neither, ask for it.
2. Update `status` and `updated` in the frontmatter, then append
   `- <date> <OLD> → <NEW>: <reason>` to `## Log`.
3. When moving to `DONE`, show the AC checklist. If any boxes are
   unchecked, ask in one line: "Tick all AC as met? (yes / which)".
   Don't block on it.
4. If the document came from a file path, edit that file in place.
   If it was pasted, output the updated document.
5. Report in one line: `<title> IN PROGRESS → DONE`.

## Document format

```markdown
---
title: Fix login timeout on SSO redirect
status: TODO
type: Task
priority: Medium
assignee:
labels: []
created: 2026-10-14
updated: 2026-10-14
---

**Motivation:**
<1-3 sentences on WHY>

**Task:**
<3-8 sentences on WHAT needs to be done>

**Notes:**
- <links, repos, buckets, references, estimates>

**Acceptance Criteria:**
- [ ] <observable outcome>
- [ ] <observable outcome>

## Log
- 2026-10-14 created [TODO]
```

- Omit empty body sections and empty optional frontmatter fields.
- `status` in the frontmatter is the single source of truth. `## Log`
  is history only, so never derive state from it.
- Keep any extra frontmatter the user added (for example an `id`
  from their own tracker) unchanged.

## Mapping to trackers

Use this when the user says where the todo will live.

| Field | JIRA | GitHub Issues |
|---|---|---|
| `title` | Summary | Title |
| Body sections | Description | Body (AC renders as a task list) |
| `status` | Workflow status | `TODO`/`IN PROGRESS`/`BLOCKED`: open, plus a status label. `DONE`: closed as completed. `CANCELLED`: closed as not planned |
| `type`, `priority` | Issue Type, Priority | Labels (e.g. `priority: medium`) |
| `assignee`, `labels` | Assignee, Labels | Assignee, Labels |
| `## Log` entries | Comments | Comments |

Store the tracker's key (for example `id: PROJ-123`) as extra
frontmatter. Only create or update tracker items when the user asks.

## Guardrails

- **No PII/PHI in documents.** They're durable and shared. If the
  input contains names, contact details, government or account IDs,
  health information or similar, stop, don't repeat the values, and ask
  the user to redact them.
- **No secrets** in document bodies or Notes.
- Only change state, assignee or priority when the user asks.

## Principles

- **Fast:** one draft, output, done. Accept "use what you have" or
  "best guess" at any point.
- **Honest:** leave blanks rather than padding or inventing.
- **Portable:** plain markdown with frontmatter, readable by people
  and by any tool.
