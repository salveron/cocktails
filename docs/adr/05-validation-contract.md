# ADR: Validation contract and diagnostics

**Status:** Accepted

## Context

Four consumers: the codec over a whole file, and the three forms that edit one entry. Diagnostic 
expensive to change. Previous (path + sentence) insufficient: forms need machine-readable kind 
(context-specific affordances). Entry points asymmetric.

## Decision

**One issue type: path, kind, message. One entry point per editable entity.**

- `ValidationIssue`: `(List<Object> path, ValidationIssueKind kind, String message)`. `path` uses 
  **data-format keys and indexes** (`['recipes', 0, 'lines', 2]`, `part_ml`, `source.at`), never Dart 
  names. `kind`: machine-readable. `message`: display-ready.
- `ValidationIssueKind` covers codec findings; data layer reports through this type only.
- Four entry points: `validateCollection` (whole file), `validateRecipe`, `validateIngredient`, `validateTag` 
  (one entry). Single-entry calls take `otherNames` so rename never collides. Paths relative; empty for name.
- One implementation per rule. Duplicate detection shared with `Collection` constructor.
- Issues in data-format order, whatever it comes to hold; within each section by index.

Signatures: [components.md](../components.md#validation).

## Alternatives considered

- Sealed hierarchy (one subclass per rule): expressive, i18n-ready. Rejected: eleven classes, 
  four consumers format own text for one sentence.
- Prose only: cheap now, expensive later.
- Whole-collection validation only: No new API, rename-versus-self free. But every form assembles full collection, 
  translates paths.

## Consequences

- Adding rule: one enum + one statement. Review checkpoint.
- Codec only place paths bind to source positions.
- Forms one call per entry; empty path = name field.
- `message` is API; behaviour switches on `kind`.
- i18n: template per `kind`, drop `message`.
