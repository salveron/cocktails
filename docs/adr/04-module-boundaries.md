# ADR: Module boundaries and public surface

**Status:** Accepted

## Context

The [three layers](03-app-structure-and-state.md) are folders, nothing more: any file can
import any other, and Dart's `_` privacy is scoped to a *library*, which in this codebase means
a single file. Sharing anything between two files of one layer therefore makes it public to
the whole app. After M3–M5 this has already happened twice — `duplicateNameIndexes` exists as
public API only so validation can reuse the model's helper, and `optionalSuffix` only so
validation can check the reserved suffix. Neither is meant for the UI.

The same file-scoped boundary pushes wire-format knowledge outward: the line parser uses
`Unit.name` as both the parse and the emit token, so a Dart identifier is the file format.
Commit `7a78015` renamed `StockLevel`'s members to chase the on-disk spelling rather than
declaring it, and still could not reach `in` because it is a reserved word.

Twenty-one milestones remain, three of them adding whole layers. The convention chosen now is
the one every later file follows.

## Decision

**Each layer is a barrel file over a `src/` folder, boundaries are enforced by a test, and
wire tokens are declared on the enums.**

- `lib/<layer>/<layer>.dart` exports the layer's contract; everything else lives in
  `lib/<layer>/src/`. Three visibility levels result: `_name` (file), public but unexported
  (layer), exported (app). Shared domain internals get a `src/helpers.dart` that the barrel
  does not export.
- Dependencies point inward only — `ui → state → data → domain` — and a layer's barrel is the
  only file another layer may reach. `test/architecture_test.dart` reads the dependency
  directives under `lib/` and fails on violations, including the "no Flutter in the domain"
  rule that is currently true only by luck.
- Every enum that appears in the data format carries its token as a field
  (`Unit.part('part')`, `StockLevel.in_('in')`), so renaming a member cannot change the file
  format and the `in` collision disappears.

The resulting structure and interfaces are recorded in [components.md](../components.md).

## Alternatives considered

- **Flat files, no barrel** (the status quo) — nothing to maintain, but there is no way to mark
  anything layer-private, and every consumer imports concrete file paths, so moving a file
  breaks call sites across layers.
- **One library per layer using `part` / `part of`** — the only option giving real compiler-
  enforced `_` privacy across a layer. Rejected: part files cannot carry their own imports, so
  the whole layer shares one import list, and the style is unusual enough in Flutter code to
  cost more in unfamiliarity than it returns.
- **A lint package** (`custom_lint`, `dart_code_metrics`) — proper static enforcement of import
  rules, but it is a dependency plus a plugin toolchain, against the deliberate dependency
  minimum in the [architecture](../architecture.md#technology-stack). A twenty-line test does
  the same job with what is already installed.

## Consequences

- Dart gives no compiler enforcement of these boundaries inside one package, so the
  architecture test *is* the enforcement. It runs in CI with everything else.
- Adding a domain file is a two-line change: the file, plus one export in the barrel. That
  export line is the review checkpoint for "does this belong outside the layer".
- Other layers import one barrel each, so domain internals can be reorganised without touching
  a single consumer.
- The existing domain files move under `src/` and gain declared tokens before the codec is
  written (M5a), so the format contract is fixed in one place before anything depends on it.
