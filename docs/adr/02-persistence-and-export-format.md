# ADR: Persistence and export format

**Status:** Accepted

## Context

Pilot: hundreds of recipes, tens of KB. [FR-DAT-1..5](../requirements.md): export/import as one 
human-readable, versioned text file, lossless round-trip. Access point for AI-assisted bulk editing. 
Single-user, offline, no concurrent writers.

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

- YAML schema is public contract; versioned in architecture from day one.
- Every mutation rewrites whole file (trivial at scale).
- Persistence behind storage interface: domain/UI depend only on interface. Swapping to SQLite 
  touches one adapter.
- Strictly single-writer (owner's app). Read-only guest access as publishing. Multiple writers 
  would invalidate.
- Scalability: text-only scales to tens of thousands (≈5 MB, tens of ms load/write). Binary data 
  (photos) outside as referenced assets.
