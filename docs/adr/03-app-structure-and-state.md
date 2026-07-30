# ADR: App structure and state management

**Status:** Accepted

## Context

Many screens over shared model; derived state (availability, filtered/grouped lists, optimizer results) 
must update instantly (NFR-2). Maintainer new to Flutter; state management is hardest retrofit point.

## Decision

**Three layers with Riverpod for state management.**

- **Domain**: pure Dart. Entities, availability, search/filter/grouping, optimizer, validation. 
  Unit-testable without device.
- **Data**: storage interface + YAML adapter. See [persistence ADR](02-persistence-and-export-format.md).
- **Presentation**: Flutter screens/widgets, read through Riverpod providers.

Riverpod holds model in state providers; derived state (availability, filtered views, optimizer) 
in computed providers that cache and recompute on input change.

## Alternatives considered

- Provider: simpler, in maintenance mode; author recommends Riverpod.
- Bloc: robust but ceremony-heavy; overkill.
- setState/InheritedWidget: no library; hand-maintained derived state, error-prone.

## Consequences

- Riverpod is new concept (mitigated by community adoption, documentation, AI training).
- Pure-Dart domain: hardest logic (availability, optimizer, validation) testable on dev machine, no device.
- UI never touches model directly; reads through providers, mutations through model-update methods.
