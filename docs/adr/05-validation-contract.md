# ADR: Validation contract and diagnostics

**Status:** Accepted

## Context

M5 gave the domain one rule set (FR-DAT-4) with two consumers named and four more coming: the
import report (M6), the vocabulary forms (M11/M12), the recipe form (M14). What an issue *is*
therefore has to be fixed before any of them is written — a diagnostic type is consumed
everywhere and changed nowhere cheaply.

The M5 shape was a path plus an English sentence. That is enough to render "line N: message",
and not enough for anything else: a form offering "add this ingredient?" on an unknown
reference can only match the sentence, and the wording becomes API. The entry points were also
asymmetric — `validateRecipe` checked a recipe's contents but not its name, and the
vocabularies had no single-entry check at all, so a form editing one entry had to validate a
whole candidate model and filter the result.

## Decision

**One issue type carrying path, kind and message; one validation entry point per editable
entity.**

- `ValidationIssue` is `(List<Object> path, ValidationIssueKind kind, String message)`. `path`
  addresses the violation in **data-format keys and indexes** (`['recipes', 0, 'lines', 2]`,
  `part_ml`, `made.times`), never Dart field names. `kind` is the machine-readable rule.
  `message` stays a ready-to-display English sentence — the pilot is English-only and every
  consumer needs a string.
- `ValidationIssueKind` also covers the findings the codec raises itself (`unsupportedFormat`,
  `malformedLine`, `malformedValue`), so the data layer reports through this type rather than
  introducing a second one.
- Four entry points: `validateModel` for a whole file, and `validateRecipe`,
  `validateIngredient`, `validateTag` for one entry. The single-entry forms take
  `other…Names` — every *other* entry's name — so a rename never collides with itself. Their
  paths are relative to the entry being checked, and empty for its name.
- Every rule has one implementation whichever entry point reaches it, and duplicate detection
  stays on the `duplicateNameIndexes` that `Model`'s constructor also uses.
- Issues come out in data-format order: settings, ingredients, tags, recipes, and within a list
  by entry index, every rule for one entry ahead of the next entry.

The resulting signatures are recorded in [components.md](../components.md#validation).

## Alternatives considered

- **A sealed `ValidationIssue` hierarchy**, one subclass per rule carrying its own payload.
  Most expressive, exhaustively switchable, and i18n-ready because no English lives in the
  domain. Rejected for the pilot: eleven classes, and each of the four consumers would format
  its own text for rules where they all want the same sentence. The enum can be widened into
  this later without disturbing the `path` convention.
- **Prose only, no kind** — string-matching in the form, or no per-rule affordance at all.
  Rejected: cheap to avoid now, expensive once four consumers read the messages.
- **Whole-model validation only**, forms building a candidate model and filtering issues by
  path prefix. No new API, and rename-versus-self falls out for free, but every form assembles
  a full model and translates model-relative paths back to its own fields.

## Consequences

- Adding a rule is one enum member plus its problem in one place; that member is the review
  checkpoint for "is this rule already covered elsewhere".
- The codec (M6) is the only place data-format paths bind to source positions — it resolves
  `path` against the parsed node tree to produce `SourcedIssue`. The domain needs no notion of
  YAML and the codec needs no second copy of the rules.
- The forms validate one entry in one call, and map an empty path to the name field.
- `message` is API in practice: consumers display it verbatim, so wording changes are
  user-visible. Behaviour switches on `kind`, never on the text.
- Adding i18n later means giving each `kind` a template and dropping `message`; the `kind`
  field is what keeps that from touching every call site.
