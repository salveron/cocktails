# ADR: App structure and state management

**Status:** Accepted

## Context

Many screens, shared model. Derived state (availability, filters, optimizer) updates instant (NFR-2). 
Hardest retrofit point.

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

- Riverpod is new (mitigated by adoption, docs, AI).
- Pure-Dart domain: hard logic testable offline.
- UI reads via providers, mutates via model methods.
