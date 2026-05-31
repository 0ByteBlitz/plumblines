---
record_type: change
id: 2026-05-31-parity-test-windows
valid_as_of_commit: 654607be13116d9446f500c49ad7544ccef5f045
depends_on:
  - test/cli.test.js
trust: verified
provenance:
  - { source: test/cli.test.js, trust: verified }
  - { source: cli/checks.js, trust: verified }
validation: passed
risks: see-body
followups: see-body
---

# Skip shell-parity test on Windows

## Metadata

Date: 2026-05-31
Agent: Claude (Opus 4.8)
Branch: main
Domain: tooling / tests

## Goal

Stop `test/cli.test.js` from failing during `npm publish` (`prepublishOnly`) on
a Windows dev machine, without weakening the Node↔shell gate-parity guarantee.

## Summary

The shell-parity assertions shell out to `bash`. On Windows, `bash` invoked from
cmd.exe/PowerShell resolves to **WSL bash**, which accesses the temp repo
through `/mnt/c` path translation and cannot read the `.agent_files` records —
so its "recorded" set is empty and it falsely reports a covered commit as
uncovered. The Node gate is correct; the divergence is a WSL-path artifact, not
gate drift. (Git Bash, which uses native paths, agrees with Node — but the test
can't reliably tell which bash it got.)

Fix: run the parity assertions only when `process.platform !== 'win32'`. CI runs
the suite on Linux, so parity is still enforced there on every push and PR. The
Node behavioural assertions continue to run on every platform. Also added an
`eq()` helper that prints the first diverging index on mismatch, which is what
pinned down the cause.

## Files Changed

| File | Change | Reason |
|---|---|---|
| `test/cli.test.js` | Gate parity block behind `platform !== 'win32'`; add `eq()` diff helper | Avoid WSL false-negative; better failure output |

## Behaviour Before

`npm publish` aborted on Windows because the parity assertion compared the Node
gate against a WSL bash that misread the repo.

## Behaviour After

The suite passes on Windows (parity skipped with a logged reason) and still
enforces byte-for-byte parity on Linux/CI.

## Validation Summary

Ran `node test/cli.test.js` under PowerShell (the path `npm` uses): ALL PASS,
parity skipped with reason. The Node behavioural assertions (init, clean gates,
trust-escalation detection, staleness detection) still run and pass.

## What Was Not Checked

- Linux parity could not be re-run on this Windows host; it is covered by the CI
  `test` job on `ubuntu-latest`. The gate sources (`cli/`) are unchanged since
  parity last verified byte-identical.

## State Update Needed?

- [x] No.

## Risks

- Parity is no longer checked locally on Windows; a future change to one gate
  implementation but not the other would only be caught in CI, not at
  Windows `prepublishOnly` time.

## Follow-ups

- Optional: probe whether the resolved `bash` can read the repo and run parity
  under Git Bash too, instead of skipping all of win32.

## Completion Check

- [x] Change record filled in
- [x] Validation recorded
- [x] Risks recorded
- [x] Follow-ups recorded
