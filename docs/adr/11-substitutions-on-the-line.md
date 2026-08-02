# ADR: A line may name more than one bottle

**Status:** Accepted

## Context

Recipes often work with any one of several bottles — cognac or vodka, lemon or lime. The pilot ruled
substitutions out, so such a recipe was written twice or written wrong. Reversing that is a product
decision; how it is written is this one. Decided before M18a.

## Decision

**A recipe line names one or more bottles; any one of them on hand makes the line.**

- `RecipeLine.ingredients` is a `List<String>`, never empty. No singular accessor: a getter
  returning the first would silently drop the rest at every caller that has not thought about a
  group.
- **The separator is `/`, spaced or not** — `1 part cognac / vodka (base)`. The tail splits
  lexically, after the unit is decided and after the mark is taken off, so the mark governs the
  group, one amount and one unit measure it, and what a line means never depends on what the bar
  holds.
- **`/` is reserved from every ingredient spelling**, name and alias alike, beside the mark suffixes
  already barred there. Without it `sweet / dry vermouth` would have two readings.
- **Cards read "or", the file reads `/`.** The separator is grammar, the card is prose. The form
  fills its fields from the canonical line, so what is typed is what is re-edited.
- **Availability takes the best of the group** — `stockOfLine`, the one home the card's dimming
  reads too. In beats low beats out; a line is missing only when every alternative is.
- **A card dims what the bar cannot supply, and only while it can supply something.** Where a group
  has nothing, none dims and the stock dot carries it, as a single bottle does — so the dot never
  contradicts the availability chip.
- Every alternative resolves as any name resolves: aliases, case, canonical storage, rename
  propagation and delete blocking each fan out over the list (ADR 08, ADR 10).
- Naming one bottle twice on a line is reported, not silently collapsed.
- `format` stays `1`.

## Alternatives considered

- ` or ` as the separator: reads best in the file, but reserves an English word from every bottle
  name — a far heavier rule than one punctuation mark, for a file only a card reads aloud.
- Splitting only where the whole tail names no bottle: adding a bottle would silently change what
  existing recipes mean, and the parser would need the ingredient vocabulary it deliberately does
  not take.
- A `substitutes:` list on the ingredient entry: makes the choice global, when "cognac or vodka" is
  true of one recipe and wrong for the next — the reason base moved onto the line (ADR 06).
- An amount per alternative (`1 part cognac / 2 parts vodka`): a second measure to scale, convert
  and validate, for a case the notes field already covers.
- `List.unmodifiable` on the field, as `Ingredient.aliases` has: it would cost the `const`
  constructor the line grammar and its tests lean on throughout.

## Consequences

- Substitutions leave the out-of-pilot list; FR-REC-9 new, Ingredient and Availability amended.
- `ValidationIssueKind` gains `separatorInName` and `duplicateAlternative`.
- A file holding `/` in an ingredient spelling is refused, with the reason and the line.
- `displayRecipeLine` becomes `displayMeasure` — the body it returned transformed nothing, and a
  card writes its own now. `formatLineBody` is private again.
- **M19** must decide whether a group marked `(base)` files its recipe under every alternative
  spirit (FR-DIS-4) — dissolved by [ADR 12](12-base-spirit-narrows.md), which makes base a
  predicate: a group matches under every alternative it names.
- **M21**'s optimizer must count a group as satisfied by any one purchase (FR-DIS-6).
