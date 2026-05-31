# Security

## Reporting a vulnerability

Please report security issues privately via GitHub Security Advisories
("Report a vulnerability" on the repository's Security tab) rather than a public
issue. We'll acknowledge and work a fix before any public disclosure.

## Supply-chain posture

The 2025–2026 npm attacks (Shai-Hulud, and the 2026 wave hitting Axios,
@bitwarden/cli, SAP, TanStack, and node-ipc) almost all worked by compromising a
**maintainer account, CI token, or a dependency's install script** — not the
target's own source. plumblines is built to minimise every one of those
surfaces.

### What we publish
- **Zero runtime dependencies.** Nothing is pulled in at install time, so there
  is no transitive package to be trojanised. This is a deliberate constraint —
  the CLI uses Node built-ins only.
- **No lifecycle scripts.** The package defines no `preinstall`/`install`/
  `postinstall` hooks, so `npm install plumblines` executes no code. Installing
  with `--ignore-scripts` changes nothing here.
- **Explicit `files` allow-list.** Only `cli/`, `templates/`, `skills/`,
  `scripts/`, `docs/`, README, and LICENSE ship. The framework's own
  `.agent_files/` memory and the tests are never published.

### How we publish
- **OIDC trusted publishing only.** Releases go out from
  `.github/workflows/release.yml` using short-lived, workflow-scoped OIDC
  credentials — there is **no long-lived `NPM_TOKEN`** stored in the repo or CI
  for an attacker to steal or phish.
- **Provenance** is generated automatically under trusted publishing, so
  consumers can verify each release is linked to this repo and commit.
- **Staged + 2FA-gated publishing.** The npm package is configured so a human
  maintainer must approve each release with WebAuthn 2FA before it goes live.
- **Hardened workflow.** Default-deny `permissions`, third-party actions pinned
  to commit SHAs (a moved tag was part of several 2026 compromises), an
  `environment` approval gate, and a tag/version match check.

## Verifying a release as a consumer

```bash
npm view plumblines                 # inspect version, dist-tags, maintainers
npm audit signatures                # verify the published provenance/signatures
```

Pinning to an exact version and waiting a short "cooldown" before adopting a
brand-new release are cheap, effective defences against a freshly compromised
version.

## If you fork or extend

Keep it dependency-free if you can. If you must add a dependency, commit a
lockfile, install with `npm ci --ignore-scripts`, pin exact versions, and run
`npm audit` in CI. Treat the package manager as an untrusted execution engine.
