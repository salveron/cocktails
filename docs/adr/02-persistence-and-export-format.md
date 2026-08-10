# ADR: Persistence and export format

**Status:** Accepted. Amended once the app held many bars ([ADR 20](20-the-app-holds-many-bars.md), 
[ADR 21](21-the-file-carries-one-bar.md)): one file per bar rather than one for everything, and 
"guest" below meant a second reader of the file, not FR-BAR-3's guest bar — that one is read-only 
for its own reasons ([ADR 23](23-nothing-writes-a-guest-bar.md)).

## Context

Hundreds of recipes, tens of KB. [FR-DAT-1..5](../requirements.md): human-readable text, versioned, 
lossless. AI bulk-edit access point. Single-user, offline.

## Decision

**Entire model in memory; persists as single YAML file; export byte-identical to store.**

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
- Every mutation rewrites whole file (trivial at scale).
- Strictly single-writer. Guest access read-only.
- Scales to tens of thousands (≈5 MB, tens of ms).
