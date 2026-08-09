# ADR: App structure and state management

**Status:** Accepted. Amended once the lists were built: search and filtering turned out to be
presentation, and grouping left the domain's vocabulary
([ADR 12](12-base-spirit-narrows.md)).

## Context

Many screens, shared model. Derived state (availability, filters, optimizer) updates instant (NFR-2). 
Hardest retrofit point.

## Decision

**Three layers with Riverpod for state management.**

- **Domain**: pure Dart. Entities, availability, discovery, optimizer, validation. 
  Unit-testable without device.
- **Data**: storage interface + YAML adapter. See [persistence ADR](02-persistence-and-export-format.md).
- **Presentation**: Flutter screens/widgets, read through Riverpod providers.

Riverpod holds model in state providers; derived state (availability, optimizer) in computed 
providers that cache and recompute on input change. Search, filter and order narrow a list where 
it is drawn — widget state, not a provider, nothing model-derived reading them 
([components.md](../components.md#state-contracts)).

## Alternatives considered

- Provider: simpler, in maintenance mode; author recommends Riverpod.
- Bloc: robust but ceremony-heavy; overkill.
- setState/InheritedWidget: no library; hand-maintained derived state, error-prone.

## Consequences

- Riverpod is new (mitigated by adoption, docs, AI).
- Pure-Dart domain: hard logic testable offline.
- UI reads via providers, mutates via model methods.
