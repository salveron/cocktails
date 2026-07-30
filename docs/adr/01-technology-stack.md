# ADR: Technology stack

**Status:** Accepted

## Context

Single-user offline Android app; vision includes desktop later. Solo developer, Python background, 
AI-assisted. Scale: hundreds of recipes, instant response (NFR-2). Open-source, free.

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

- Dart is new (mitigated by AI assistance, small codebase).
- Environment: Flutter SDK + Android toolchain on Linux; physical phone over USB.
- Desktop: new target + layout, not new codebase.
