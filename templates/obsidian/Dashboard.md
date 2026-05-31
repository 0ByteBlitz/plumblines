# Plumblines Dashboard

Fallback dashboard for vaults using the **Dataview** community plugin instead of
the Bases core plugin. If you have Obsidian 1.9+ you can use `plumblines.base`
instead — it needs no plugin. These queries are vault-wide and
location-independent (they filter on the `record_type` property, not a folder
path), so they work wherever your memory tree lives.

## Change log

```dataview
TABLE trust, validation, valid_as_of_commit AS "valid as of"
WHERE record_type = "change"
SORT file.name DESC
```

## Needs attention

Records with low or declining trust, or failed validation.

```dataview
TABLE record_type AS type, trust, validation
WHERE trust = "needs-review" OR trust = "stale" OR validation = "failed"
SORT file.name DESC
```

## Decisions by trust

```dataview
TABLE trust, valid_as_of_commit AS "valid as of"
WHERE record_type = "decision"
SORT trust ASC, file.name DESC
```

## All records

```dataview
TABLE record_type AS type, trust, validation
WHERE record_type
SORT record_type ASC, file.name DESC
```
