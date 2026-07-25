# ADR: Persistence and export format

**Status:** Accepted

## Context

The full database — vocabularies, stock levels, recipes with made-history, settings — is a few
tens of kilobytes at the pilot's several-hundred-recipe scale. [FR-DAT-1..5](../requirements.md)
require export/import of everything as one human-readable, self-describing, versioned text
file with a lossless round-trip, serving as the single external access point for AI-assisted
bulk editing. The app is single-user and offline; no concurrent writers exist.

## Decision

**The entire model lives in memory; it persists as a single YAML file, and that file is
byte-identical to the export format.**

- Export = share a copy of the store file; import = validate a candidate file, then atomically
  replace the store. FR-DAT-5's lossless round-trip holds by construction.
- One schema to define, document, and version — no internal-vs-external translation layer.
- YAML over JSON: supports comments, minimal syntactic noise, best for hand- and AI-editing;
  its implicit-typing pitfalls are neutralized by the validating import path every load goes
  through.
- Writes are atomic (write temp file, then rename); every save keeps a small set of rolling
  backups so a corrupted write or bad bulk edit is always recoverable.
- All queries — search, filters, availability, the optimizer — are plain in-memory operations
  over the model; no query engine needed to meet NFR-2.

## Alternatives considered

- **SQLite (drift/sqflite)** — the default mobile choice, but adds migrations, a query layer,
  and a separate export/import translator whose losslessness must then be tested; solves
  scale and concurrency problems this app does not have.
- **JSON store** — equally simple, but no comments and noisier to hand-edit; weaker fit for
  the file's role as the human/AI editing surface.
- **Custom text format** (Telegram-like terse lines) — maximally compact but demands a
  hand-rolled parser and forfeits ecosystem tooling; the terse feel can instead inform the
  YAML schema's ingredient-line style.

## Consequences

- The YAML schema is the app's most stable public contract; it gets a precise specification
  (in the architecture doc) and a format version from day one.
- Every mutation rewrites the whole file — trivial at this scale, and the natural point to
  rotate backups.
- Persistence is isolated behind a storage interface: domain and UI code depend only on that
  interface, never on YAML or file paths. Swapping the store (e.g. to SQLite if guests ever
  write data) touches one adapter, with the export file as the data migration vehicle.
- The model is strictly single-writer: the owner's app is the only thing that mutates the
  store. Future read-only guest access fits as publishing — a rendered snapshot of the file,
  or a service loading the same file to serve reads. Only multiple *writers* (collaborative
  editing) would invalidate this design; the export file is the migration path out if so.
- Scalability bound: text-only data scales to tens of thousands of records (≈5 MB, tens of
  milliseconds to load or rewrite) — orders of magnitude above a personal collection. Binary
  data (future photos) lives outside the file as referenced assets, never inline.
