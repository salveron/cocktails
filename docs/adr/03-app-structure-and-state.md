# ADR: App structure and state management

**Status:** Accepted

## Context

Many screens over shared in-memory model, dominated by derived state: per-recipe availability, filtered/grouped lists, optimizer results must update instantly when stock or recipes change (NFR-2). Maintainer is new to Flutter; state management is woven through every screen and the hardest thing to retrofit.

## Decision

**Three layers with Riverpod for state management.**

- **Domain** — pure Dart, no Flutter imports. Entities, availability computation, search/filter/grouping, optimizer, validation rules. Unit-testable without UI or device.
- **Data** — storage interface and YAML adapter (codec, atomic writes, backups). See [persistence ADR](02-persistence-and-export-format.md).
- **Presentation** — Flutter screens and widgets, read state exclusively through Riverpod providers.

Riverpod holds model in small set of state providers; derived state (availability, filtered views, optimizer output) is computed providers that cache and recompute automatically on input change.

## Alternatives considered

- **Provider package** — simpler, in maintenance mode; author recommends Riverpod as successor.
- **Bloc** — robust but ceremony-heavy; overkill for solo project this size.
- **setState / InheritedWidget** — no library; derived-state propagation becomes hand-maintained and error-prone.

## Consequences

- Riverpod is new concept; mitigated by being Flutter community default with good documentation and AI training.
- Pure-Dart domain layer: hardest logic (availability, optimizer, import validation) testable on dev machine with unit tests, no device.
- UI never touches model directly; every read through provider, every mutation through model-update methods that trigger persistence.
