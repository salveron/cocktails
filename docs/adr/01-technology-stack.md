# ADR: Technology stack

**Status:** Accepted

## Context

The pilot is a single-user, fully offline Android app ([requirements](../requirements.md)); the
vision names a PC/desktop app as a later direction. The maintainer is a solo developer with a
Python background — no head start in any mobile ecosystem — working with heavy AI assistance.
The app is a CRUD-and-lists product with one computed-heavy feature (the shopping optimizer)
and must feel instant at several hundred recipes (NFR-2). The maintainer requires the stack
to be open-source, free to use, and reusable in future projects.

## Decision

**Flutter (Dart), targeting Android in the pilot.**

- Fully open source (BSD-3-Clause, framework and Dart alike); the whole toolchain is free,
  with no paid tiers or gated features.

- One codebase later extends to Linux/Windows desktop by adding a build target, keeping the
  vision's desktop direction open without a rewrite.
- Largest cross-platform ecosystem and AI training corpus → best fit for AI-assisted
  development by a non-mobile developer.
- Dart is close enough to Python in feel (garbage-collected, single-paradigm, batteries
  included) to keep the human maintainable-by side realistic.
- First-class offline operation; no server-side anything required.
- Declarative widget UI suits a forms-lists-filters app.

## Alternatives considered

- **Native Android (Kotlin + Jetpack Compose)** — best per-platform fit, but Android-only;
  the desktop direction would demand a Kotlin Multiplatform rework or a second app.
- **Kotlin Multiplatform / Compose Multiplatform** — covers desktop, but younger tooling and
  more build complexity than a solo non-JVM developer should carry.
- **React Native / Expo** — viable, but heavier toolchain, faster ecosystem churn, weaker
  desktop story.
- **Python UI frameworks (Flet, Kivy, BeeWare)** — match the maintainer's language, but
  Android packaging is immature and tooling/AI support is thin; rejected on reliability.
- **PWA / local web app** — no install story needed, but browser storage is evictable
  (unacceptable for the only copy of the database) and platform file sharing (FR-DAT-1) is
  second-class; rejected on data-safety grounds.

## Consequences

- Dart is a new language for the maintainer; mitigated by AI assistance and the pilot's small
  surface.
- Development environment needs the Flutter SDK plus Android toolchain on Linux; a physical
  Android phone over USB suffices for testing (no emulator required).
- Desktop later means adding a target and adapting layouts — not a new codebase.
