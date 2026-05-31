# Using Plumblines in Obsidian

Plumblines records are plain Markdown with YAML frontmatter — the exact data
model Obsidian reads. With no schema changes, every record's `record_type`,
`trust`, `valid_as_of_commit`, and `validation` become queryable **Properties**,
and the bundled dashboards turn them into filterable tables.

## The one thing you must handle: the dot folder

Obsidian **ignores any file or folder whose name starts with a dot**, so a vault
opened at your project root will not show `.agent_files/` at all. Pick one fix:

| Option | How | Best when |
|---|---|---|
| **Open the memory tree as its own vault** | In Obsidian: *Open folder as vault* → select `.agent_files/`. The dot-hiding rule applies to items *inside* a vault, not the vault's own root folder, so its contents show. | You already have `.agent_files/`. Zero plugins. |
| **Use a non-dot directory** | Set `agent_dir=agent_files` (or `docs/agent-memory`) in `.plumblines`, then run the scaffolder. A project-root vault then sees it natively. | Adopting Plumblines fresh, or you want one vault over the whole repo. |
| **Show Hidden Files plugin** | Install the community plugin and toggle visibility. | You must keep the dot and the project-root vault. |

The middle option is the cleanest because the `agent_dir` config already makes
the directory name a one-liner — no plugin, one vault for the whole project.

## Frontmatter → Properties

No conversion needed. A change record's frontmatter:

```yaml
record_type: change
trust: verified
validation: passed
valid_as_of_commit: 8e345db...
```

shows up in Obsidian's Properties panel and is filterable in Bases/Dataview as
`note.record_type`, `note.trust`, etc. Treat the frontmatter as the contract:
keep these fields accurate and the dashboards stay correct for free.

## Dashboards

Two equivalent dashboards ship under `templates/obsidian/` (the `--obsidian`
scaffolder flag copies them into `<agent_dir>/dashboards/`):

- **`plumblines.base`** — uses the **Bases** core plugin (Obsidian 1.9+, no
  install). Open it and switch between the *Change log*, *Needs attention*,
  *Decisions*, and *All records* views.
- **`Dashboard.md`** — the same views as **Dataview** queries, for vaults that
  use that community plugin instead. The queries are vault-wide and
  location-independent, so they work wherever the memory tree lives.

Use one or the other; you don't need both.

## Wikilinks and the graph

Plumblines already encourages linking related records. In Obsidian, writing a
record id as a `[[wikilink]]` (for example linking a change record back to the
decision it implements) lights up backlinks and the graph view, giving you a
visual map of how decisions, state, and changes connect. The `provenance` and
`depends_on` fields are natural candidates to express as links.

## What Obsidian does *not* replace

The same rule as everywhere else in Plumblines: Obsidian is a nicer lens on the
memory layer, not the source of truth. It does not run the gates — keep using
`scripts/check-staleness.sh` and `scripts/check-completeness.sh` (in CI or a
hook) to enforce coverage and trust. Obsidian helps a human *read and triage*
what those gates flag.

## Committing the vault config

If you open `.agent_files/` as a vault, Obsidian writes an `.obsidian/` config
folder inside it. Add `.agent_files/.obsidian/` to `.gitignore` unless your team
deliberately wants to share view layouts and plugin settings.
