# ADR: Technology stack

**Status:** Accepted

## Context

Single-user offline Android app ([requirements](../requirements.md)); vision includes desktop (Linux/Windows) later. Solo developer with Python background, working AI-assisted. Must scale to several hundred recipes with instant response (NFR-2). Stack must be open-source and free.

## Decision

**Flutter (Dart), targeting Android.**

- Open source, free, no paid tiers.
- One codebase extends to desktop with new build target; no rewrite needed.
- Largest cross-platform ecosystem and AI training corpus for AI-assisted non-mobile developer.
- Dart syntax near Python; garbage-collected, single-paradigm, batteries included.
- First-class offline; no server required.
- Declarative UI suits forms-lists-filters.

## Alternatives considered

- **Kotlin + Jetpack Compose** — Android-only; desktop needs Kotlin Multiplatform rewrite.
- **Kotlin Multiplatform** — covers desktop, but more complex for solo non-JVM developer.
- **React Native** — heavier toolchain, faster churn, weaker desktop story.
- **Python UI (Flet, Kivy)** — language match, but Android packaging immature, poor tooling/AI support.
- **PWA** — browser storage is evictable (unacceptable for only database copy); file sharing is second-class.

## Consequences

- Dart is new; mitigated by AI assistance and small codebase.
- Environment: Flutter SDK + Android toolchain on Linux; physical phone over USB for testing.
- Desktop addition is new target + layout adaptation, not new codebase.
