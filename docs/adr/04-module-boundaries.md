# ADR: Module boundaries and public surface

**Status:** Accepted

## Context

[Three layers](03-app-structure-and-state.md) are folders only; Dart's `_` privacy is file-scoped. No layer-private mechanism exists; shared helpers become app-public. Example: `duplicateNameIndexes` shared by model and validation; `optionalSuffix` shared for reserved-suffix check. File-scoped privacy also leaked wire-format knowledge: parser uses `Unit.name` as both parse and emit token. Commit `7a78015` renamed `StockLevel` members but could not reach reserved word `in`.

## Decision

**Each layer is barrel file over `src/` folder. Boundaries enforced by test. Enums carry wire tokens as fields.**

- `lib/<layer>/<layer>.dart` exports contract; rest in `lib/<layer>/src/`. Three visibility levels: `_name` (file), public but unexported (layer), exported (app). Shared domain internals in `src/helpers.dart` not re-exported.
- Dependencies point inward only (`ui → state → data → domain`); layer's barrel is only file another layer imports. `test/architecture_test.dart` reads imports and fails on violations.
- Every data-format enum carries token as field (`Unit.part('part')`, `StockLevel.in_('in')`); renaming member cannot change format; `in` collision disappears.

Structure and interfaces recorded in [components.md](../components.md).

## Alternatives considered

- **Flat files, no barrel** — no enforcement; moving files breaks cross-layer call sites.
- **`part` / `part of`** — gives compiler-enforced layer-private `_`, but part files cannot carry own imports and style is unusual in Flutter code.
- **Lint package** — proper static enforcement, but dependency plus plugin toolchain against deliberate dependency minimum. Twenty-line test does same job.

## Consequences

- No compiler enforcement within package; architecture test is the enforcement. Runs in CI.
- Adding file: two-line change (file + barrel export). Export line is review checkpoint for layer membership.
- Layers import one barrel each; domain internals reorganizable without touching consumers.
- Existing files move to `src/` and gain declared tokens before codec is written (M5a); format contract fixed before dependencies added.
