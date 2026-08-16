# ADR: A line may name more than one ingredient

**Status:** Accepted

## Context

Recipes often work with any one of several ingredients — cognac or vodka, lemon or lime. The pilot ruled
substitutions out, so such a recipe was written twice or written wrong. Reversing that is a product
decision; how it is written is this one. Decided before substitutions were built.

## Decision

**A recipe line names one or more ingredients; any one of them on hand makes the line.**

- `RecipeLine.ingredients` is `List<String>`, never empty; no singular accessor.
- Separator is `/` — `1 part cognac / vodka (base)`. Split after unit and mark decided; mark governs group.
- `/` reserved from all ingredient spellings (name, alias) to prevent ambiguity.
- Cards display "or", file holds `/`.
- Availability: `stockOfLine` (best of group). Line missing only if all alternatives missing.
- Card dims unavailable alternatives only while some exist; stock dot consistent.
- Every alternative resolves like any name: aliases, case-fold, canonical storage, rename, delete blocking (ADR 08, 10).
- Duplicate alternatives reported.
- `format` stays `1`.

## Alternatives considered

- ` or ` separator: reserved English word from every ingredient name (heavier than punctuation).
- Conditional split (tail names no ingredient): adding ingredients silently changes meaning; needs vocabulary.
- `substitutes:` on ingredient: global choice, wrong per-recipe (ADR 06 moved base to line).
- Amount per alternative: second measure to scale/convert; notes field covers this.
- `List.unmodifiable`: breaks `const` constructor and grammar tests.

## Consequences

- Substitutions leave the out-of-pilot list; FR-REC-9 new, Ingredient and Availability amended.
- `ValidationIssueKind` gains `separatorInName` and `duplicateAlternative`.
- A file holding `/` in an ingredient spelling is refused, with the reason and the line.
- `displayRecipeLine` becomes `displayMeasure` — the body it returned transformed nothing, and a
  card writes its own now. `formatLineBody` is private again.
- **Base-spirit browsing** must decide whether a group marked `(base)` files its recipe under every
  alternative spirit (FR-DIS-4) — dissolved by [ADR 12](12-base-spirit-narrows.md), which makes
  base a predicate: a group matches under every alternative it names.
- **The optimizer** must count a group as satisfied by any one purchase (FR-DIS-6) — which
  reshaped its search rather than adjusting it: what a missing recipe needs stops being one set of
  ingredients and becomes a choice between several, so the ways of making it are the cross product over
  the lines it is short of ([ADR 15](15-the-optimizer-answers-with-the-best-few.md)).
