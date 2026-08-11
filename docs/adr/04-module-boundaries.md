# ADR: Module boundaries and public surface

**Status:** Accepted

## Context

Dart `_` file-scoped only. Shared helpers become app-public. File privacy leaked wire-format 
(parser used `Unit.name` as token; renaming broke format).

## Decision

**Each layer: barrel file over `src/` folder. Boundaries enforced by test. Enums carry tokens as fields.**

- `lib/<layer>/<layer>.dart` exports contract; rest in `src/`. Three visibility: `_name` (file), 
  public unexported (layer), exported (app). Shared domain internals in `src/names.dart`, not re-exported.
- Dependencies inward only (`ui → state → data → domain`). Layer's barrel is only import. 
  `test/architecture_test.dart` enforces via imports/exports.
- Every enum carries token as field (`FixedUnit.part('part')`, `StockLevel.in_('in')`); renaming 
  cannot change format.

Structure, interfaces in [components.md](../components.md).

## Alternatives considered

- Flat files: no enforcement; moving files breaks cross-layer calls.
- `part`/`part of`: compiler enforcement but unusual in Flutter; part files can't carry imports.
- Lint package: static enforcement but plugin toolchain + dependency against deliberate minimum.

## Consequences

- No compiler enforcement; architecture test in CI.
- Add file: two lines (file + export). Export is checkpoint.
- Tokens declared before the codec reads them; format contract fixed before dependencies.
