# ADR: Module boundaries and public surface

**Status:** Accepted

## Context

Three layers are folders only; Dart `_` is file-scoped. No layer-private mechanism; shared helpers 
become app-public. File-scoped privacy leaked wire-format knowledge: parser used `Unit.name` as token; 
renaming `StockLevel` members couldn't reach reserved word `in`.

## Decision

**Each layer: barrel file over `src/` folder. Boundaries enforced by test. Enums carry tokens as fields.**

- `lib/<layer>/<layer>.dart` exports contract; rest in `src/`. Three visibility: `_name` (file), 
  public unexported (layer), exported (app). Shared domain internals in `src/helpers.dart`, not re-exported.
- Dependencies inward only (`ui → state → data → domain`). Layer's barrel is only import. 
  `test/architecture_test.dart` enforces via imports/exports.
- Every enum carries token as field (`Unit.part('part')`, `StockLevel.in_('in')`); renaming cannot 
  change format.

Structure, interfaces in [components.md](../components.md).

## Alternatives considered

- Flat files: no enforcement; moving files breaks cross-layer calls.
- `part`/`part of`: compiler enforcement but unusual in Flutter; part files can't carry imports.
- Lint package: static enforcement but plugin toolchain + dependency against deliberate minimum.

## Consequences

- No compiler enforcement; architecture test is enforcement (runs in CI).
- Adding file: two-line change (file + export). Export line is layer-membership checkpoint.
- Layers import one barrel each; internals reorganizable without touching consumers.
- Files move to `src/`, gain declared tokens before codec written (M5a); format contract fixed before 
  dependencies.
