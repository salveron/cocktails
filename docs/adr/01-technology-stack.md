# ADR: Technology stack

**Status:** Accepted

## Context

Offline Android app, desktop later. Solo + AI. Hundreds of recipes, instant (NFR-2). Open-source.

## Decision

**Flutter (Dart), targeting Android.**

- Open source, free.
- One codebase → desktop (new build target, no rewrite).
- Largest cross-platform ecosystem, AI training corpus.
- Dart ≈ Python; GC, single-paradigm, batteries included.
- First-class offline.
- Declarative UI suits forms-lists-filters.

## Alternatives considered

- Kotlin + Jetpack Compose: Android-only; desktop needs rewrite.
- Kotlin Multiplatform: desktop covered but complex for non-JVM solo developer.
- React Native: heavier, faster churn, weaker desktop.
- Python UI (Flet, Kivy): language match but Android immature, poor tooling.
- PWA: evictable storage (unacceptable for only DB copy); file sharing second-class.

## Consequences

- Dart is new (mitigated by AI, small codebase).
- Desktop: new target + layout only.
