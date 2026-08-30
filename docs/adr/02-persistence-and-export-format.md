# ADR: Persistence and export format

**Status:** Superseded for the on-disk layout by [ADR 20](20-the-app-holds-many-bars.md) and
[ADR 21](21-the-file-carries-one-bar.md) — one file per bar plus an index, not the single file
below. The format choice and the write discipline still stand as decided here.

## Context

Hundreds of recipes, tens of KB. [FR-DAT-1..5](../requirements.md): human-readable text, versioned, 
lossless. AI bulk-edit access point. Single-user, offline.

## Decision

**YAML over the alternatives below; export byte-identical to store; atomic, backed-up writes.**

- Export = file copy; import = validate, atomically replace.
- One schema: no internal-vs-external translation.
- YAML: comments, minimal noise, human/AI-friendly.
- Writes: atomic (temp → rename); rolling backups.
- All queries in-memory (search, filters, availability, optimizer); no query engine.

## Alternatives considered

- SQLite: adds migrations, query layer, export/import translator; solves unnecessary problems.
- JSON: equally simple, no comments, noisier.
- Custom text format: compact, hand-rolled parser, no tooling.

## Consequences

- YAML schema is public contract; versioned from day one.
- Every mutation rewrites the changed file (trivial at scale) — one bar's, or the index's
  ([ADR 21](21-the-file-carries-one-bar.md)).
- Strictly single-writer. Guest bar access read-only ([ADR 23](23-nothing-writes-a-guest-bar.md)).
- Scales to tens of thousands (≈5 MB, tens of ms).
