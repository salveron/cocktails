# ADR: Validation contract and diagnostics

**Status:** Accepted

## Context

M5 created rule set (FR-DAT-4) with six known consumers (M6, M11/M12, M14, plus two more). Diagnostic type consumed everywhere and expensive to change. Previous shape (path + English sentence) insufficient: forms need machine-readable rule to offer context-specific affordances (e.g., "add this ingredient?" on unknown reference); wording becomes API. Entry points were asymmetric: `validateRecipe` checked contents but not name; vocabularies had no single-entry check (forms had to validate whole candidate model and filter).

## Decision

**One issue type: path, kind, message. One entry point per editable entity.**

- `ValidationIssue` is `(List<Object> path, ValidationIssueKind kind, String message)`. `path` addresses violation in **data-format keys and indexes** (`['recipes', 0, 'lines', 2]`, `part_ml`, `made.times`), never Dart field names. `kind` is machine-readable rule. `message` is display-ready English sentence.
- `ValidationIssueKind` covers codec findings (`unsupportedFormat`, `malformedLine`, `malformedValue`); data layer reports through this type only.
- Four entry points: `validateModel` (whole file), `validateRecipe`, `validateIngredient`, `validateTag` (one entry). Single-entry calls take `otherNames` (every other entry's name) so rename never collides. Paths relative to entry; empty for its name.
- One implementation per rule regardless of entry point. Duplicate detection shared with `Model` constructor.
- Issues in data-format order: settings, ingredients, tags, recipes; within list by entry index.

Signatures in [components.md](../components.md#validation).

## Alternatives considered

- **Sealed hierarchy**, one subclass per rule with payload — most expressive, i18n-ready. Rejected: eleven classes, four consumers each format own text where all want same sentence.
- **Prose only** — string-matching or no per-rule affordance. Rejected: cheap now, expensive later.
- **Whole-model validation only** — forms build candidate model and filter by path prefix. No new API, rename-versus-self free. But every form assembles full model and translates paths.

## Consequences

- Adding rule: one enum member plus one problem statement. Member is review checkpoint for duplicate coverage.
- Codec (M6) only place data-format paths bind to source positions; resolves `path` against parse tree to produce `SourcedIssue`. Domain has no YAML knowledge.
- Forms validate one entry in one call; empty path maps to name field.
- `message` is API in practice; consumers display verbatim. Behavior switches on `kind`, never text.
- i18n later: give each `kind` a template, drop `message`. `kind` field keeps that from touching every call site.
