# ADR: Persistence and export format

**Status:** Accepted

## Context

Pilot database (several hundred recipes) is tens of kilobytes. [FR-DAT-1..5](../requirements.md): export/import everything as one human-readable, versioned text file with lossless round-trip, serving as the access point for AI-assisted bulk editing. Single-user, offline, no concurrent writers.

## Decision

**Entire model in memory; persists as single YAML file; export file byte-identical to store.**

- Export = file copy; import = validate, atomically replace. Lossless round-trip by construction.
- One schema: no internal-vs-external translation layer.
- YAML: comments, minimal noise, human/AI-friendly. Implicit-type pitfalls neutralized by validating import on every load.
- Writes: atomic (temp file → rename); rolling backups for recovery.
- All queries (search, filters, availability, optimizer) are in-memory operations; no query engine needed.

## Alternatives considered

- **SQLite** — default mobile choice, but adds migrations, query layer, export/import translator; solves scale/concurrency problems this app doesn't have.
- **JSON** — equally simple, no comments, noisier to edit.
- **Custom text format** — compact, demands hand-rolled parser, forfeits tooling.

## Consequences

- YAML schema is the public contract; versioned and specified in architecture doc from day one.
- Every mutation rewrites whole file; trivial at this scale and the backup rotation point.
- Persistence behind storage interface: domain and UI depend only on interface, never YAML. Swapping store (e.g. to SQLite) touches one adapter.
- Strictly single-writer: owner's app only. Read-only guest access as publishing or snapshot service. Multiple writers (collaborative edit) would invalidate this; export file is migration path out.
- Scalability: text-only scales to tens of thousands of records (≈5 MB, tens of ms load/write). Binary data (future photos) lives outside as referenced assets.
