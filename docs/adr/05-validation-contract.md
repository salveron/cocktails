# ADR: Validation contract and diagnostics

**Status:** Accepted

## Context

Rule set (FR-DAT-4) has six consumers (M6, M11/M12, M14, +2 more). Diagnostic type consumed everywhere, 
expensive to change. Previous shape (path + sentence) insufficient: forms need machine-readable rule for 
context-specific affordances (e.g., "add this ingredient?" on unknown ref); wording becomes API. Entry 
points asymmetric: `validateRecipe` checked contents not name; no single-entry vocabulary checks.

## Decision

**One issue type: path, kind, message. One entry point per editable entity.**

- `ValidationIssue`: `(List<Object> path, ValidationIssueKind kind, String message)`. `path` uses 
  **data-format keys and indexes** (`['recipes', 0, 'lines', 2]`, `part_ml`, `made.times`), never Dart 
  names. `kind`: machine-readable. `message`: display-ready.
- `ValidationIssueKind` covers codec findings; data layer reports through this type only.
- Four entry points: `validateModel` (whole file), `validateRecipe`, `validateIngredient`, `validateTag` 
  (one entry). Single-entry calls take `otherNames` so rename never collides. Paths relative; empty for name.
- One implementation per rule. Duplicate detection shared with `Model` constructor.
- Issues in data-format order: settings, ingredients, tags, recipes; within each by index.

Signatures: [components.md](../components.md#validation).

## Alternatives considered

- Sealed hierarchy (one subclass per rule): expressive, i18n-ready. Rejected: eleven classes, 
  four consumers format own text for one sentence.
- Prose only: cheap now, expensive later.
- Whole-model validation only: No new API, rename-versus-self free. But every form assembles full model, 
  translates paths.

## Consequences

- Adding rule: one enum member + one statement. Member is review checkpoint for coverage.
- Codec (M6) only place data-format paths bind to source positions. Domain has no YAML knowledge.
- Forms validate one entry in one call; empty path maps to name field.
- `message` is API; consumers display verbatim. Behavior switches on `kind`, never text.
- i18n later: give each `kind` a template, drop `message`. `kind` field keeps from touching call sites.
