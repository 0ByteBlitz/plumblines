---
name: plumblines-change
description: Author a compliant Plumblines change record after modifying a codebase that uses .agent_files. Creates the record under local/changes/ with correct frontmatter (valid_as_of_commit, depends_on, trust, provenance) and verifies the completeness gate passes. Use after making code changes in a Plumblines project, or when a user asks to "record this change", "log a change record", or "satisfy the Plumblines completion gate".
---

# Plumblines: author a change record

A code change in a Plumblines project is not complete until a change record
exists. This skill produces one that passes `scripts/check-completeness.sh`.

## When this applies

- You changed source files in a repo that has `.agent_files/`.
- Skip only if no files changed — then say so explicitly; no record is needed.

## Step 1 — gather the facts

- `git rev-parse HEAD` → the commit the record is valid as of.
- `git diff --name-only <base>..HEAD` → the touched files (these become
  `depends_on` and the "Touched Files" section).
- What you actually read while making the change → the `provenance` inputs.

## Step 2 — write the record

Copy `<agent_dir>/templates/change.md` (or the framework `templates/change.md`)
to:

```
<agent_dir>/local/changes/YYYY-MM-DD-short-description.md
```

Fill the frontmatter precisely — the gate parses it, not the prose:

```yaml
---
record_type: change
id: 2026-05-31-short-description
valid_as_of_commit: <full HEAD sha>
depends_on:
  - <each touched / depended-on file>
trust: <see rule below>
provenance:
  - { source: <file you inspected>, trust: verified }
  - { source: PROJECT_STATE.md,     trust: inferred }
validation: passed | failed | none
risks: see-body
followups: see-body
---
```

**Trust rule (enforced):** a record's `trust` must not exceed the lowest trust
among its provenance inputs. If any input is `assumed`, the record cannot be
`verified`. Trust order: `verified` > `inferred` > `assumed`. Use
`needs-review` when unsure — it is exempt from the escalation check.

Then fill the body: goal, summary, before/after behaviour, validation
performed, what you did **not** check, risks, and follow-ups. Be honest about
gaps — the gate checks existence and trust, not accuracy, so accuracy is on you.

## Step 3 — verify the gate

```
bash scripts/check-completeness.sh <base-ref> HEAD
```

Expect: coverage passes (your commit now has a record) and provenance passes
(no trust escalation). If coverage still flags your commit, the record's
`valid_as_of_commit` does not match the commit SHA — fix it. If provenance
fails, lower the record's `trust` to match its weakest input.

## Step 4 — compaction check

If `local/changes/` now holds ~10 or more records, suggest compacting older
ones into `<agent_dir>/compacted/` using `templates/compaction.md`, then
updating `PROJECT_STATE.md`.
