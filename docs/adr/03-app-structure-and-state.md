# ADR: App structure and state management

**Status:** Accepted

## Context

The app is many screens over one shared in-memory model, dominated by derived state:
per-recipe availability, filtered and grouped lists, and optimizer results must all update
instantly when stock or recipes change (NFR-2). The single maintainer is new to Flutter and
works AI-assisted; whatever manages state will be woven through every screen and is the
hardest thing to retrofit.

## Decision

**Three layers, with Riverpod as the state-management library.**

- **Domain (pure Dart, no Flutter imports)** — entities, the availability computation,
  search/filter/grouping, the shopping optimizer, and validation rules. Unit-testable
  without any UI or device.
- **Data** — the storage interface and its YAML file adapter (codec, atomic writes, backups),
  per the [persistence ADR](02-persistence-and-export-format.md).
- **Presentation** — Flutter screens and widgets, reading state exclusively through Riverpod
  providers.

Riverpod holds the model in a small set of state providers; everything derived (availability,
filtered views, optimizer output) is computed providers that cache and recompute automatically
when their inputs change. This maps one-to-one onto the requirements' "computed" language and
keeps recomputation correct without manual wiring.

## Alternatives considered

- **Provider package** — simpler, but in maintenance mode; its author recommends Riverpod as
  the successor.
- **Bloc** — robust but ceremony-heavy (events/states per feature); overkill for a solo
  project of this size.
- **setState / InheritedWidget only** — no library, but derived-state propagation becomes
  hand-maintained and error-prone as screens multiply.

## Consequences

- Riverpod is one more concept to learn; mitigated by its position as the current Flutter
  community default with a large documentation and AI-training corpus.
- The pure-Dart domain layer means the app's hardest logic (availability, optimizer, import
  validation) is testable on the dev machine with plain unit tests, no device involved.
- UI never touches the model directly; every read goes through a provider, every mutation
  through a small set of model-update methods that also trigger persistence.
