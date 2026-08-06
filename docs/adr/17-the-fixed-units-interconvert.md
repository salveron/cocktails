# ADR: The fixed units interconvert

**Status:** Accepted

## Context

FR-SET-1 gave the pilot one ratio — ml per part — and a toggle between two readings.
[ADR 09](09-units-are-a-vocabulary.md) fixed `part` and `ml` for exactly that reason, kept
`Settings.display` two-valued, and rejected an ml equivalence on every vocabulary entry as "a bigger
feature than the one asked for, and additive later".

Later is now, but not the whole of it. A collection is written in whatever its sources used — parts
here, ml there, oz in anything American — while the reader has one unit they pour in. Today only a
part moves, and only into ml, so an oz-written recipe stays oz for a reader who owns a ml jigger.

Two things settle this now rather than after the pilot. The global half of FR-SET-1 has never
worked — every card hard-codes `part` regardless of the setting, so whatever the toggle is
implemented as is what ships. And the ratio is what the M23 screen is *for*: the shape it edits is
the shape readers will have files in.

## Decision

**Three fixed units — `part`, `ml`, `oz` — carry sizes, and a line measured in any of them reads in
the one the reader picked.**

- **`oz` joins the fixed units.** No rename, no delete, plural still editable, as `part` and `ml`
  already stand (FR-VOC-5).
- **Settings hold a size in ml per convertible unit**: `part_ml` as today, `oz_ml` new. `ml` is the
  anchor and carries no key — its size is 1 by definition. Additive: every file written before this
  loads unchanged and `format` stays `1`.
- **`Settings.display` names one of the three.** ADR 09's two-valued enum is amended, not its
  reasoning: it still chooses among the fixed units rather than across the vocabulary.
- **`displayMeasure` converts between the three.** Dash, barspoon, drop, piece and anything the
  reader adds print as entered. The rule: *the three fixed units read in the one you picked,
  everything else as entered.*
- **The reader sets ratios; the file stores sizes.** The screen shows the two ratios running *from*
  the global unit — `part→ml` and `part→oz` under part, `ml→part` and `ml→oz` under ml — derived
  from the stored sizes. Picking another unit recomputes the pair from what is entered; no stored
  number is rewritten by the pick, so the recompute is exact and cannot drift.
- **Both ratios are editable, though only one is a preference.** What a part is worth is the
  reader's; what an ounce is worth is a constant, defaulting to the US fluid ounce. It stays
  editable because a bar working to a 30 ml jigger calls that jigger an ounce, and the app should
  not argue.

## Alternatives considered

- **Keep the ratio anchored to part.** The smallest change, and literal to FR-SET-1. Rejected: with
  three fixed units the second ratio would be dead weight under half the readings, and an oz-written
  recipe would still be unreadable to a reader who pours in ml.
- **Store the pair the reader sees** — the global unit and its two ratios, as typed. Rejected:
  switching the unit would rewrite two stored numbers through a division, so a bar round-tripped
  through the picker would come back subtly different, and the file would record what the reader
  last looked at rather than what a part is.
- **ADR 09's full version — an ml equivalence on every unit entry.** Dash and barspoon convert too.
  Rejected: a dash is a gesture, not a measure anyone wants normalised to 0.92 ml, and it hangs a
  nullable number on every entry to serve three of them. Still additive later, on the same terms.
- **A `convertible` flag on the vocabulary entry** rather than three fixed names. Rejected as ADR 09
  rejected it: a second concept carrying a fact the names already carry.
- **Two ratios both anchored to part** (`part_ml`, `part_oz`), skipping the ml anchor. Equivalent in
  degrees of freedom, but it makes the file's shape depend on which unit happened to be special when
  it was written, and ml→oz would be a quotient of two preferences rather than of two sizes.

## Consequences

- FR-SET-1 is rewritten — ratios plural, three units, one rule for what converts. FR-VOC-5 gains
  `oz` among the fixed.
- `validateModel` refuses a units section without `oz`, exactly as it already does for the other
  two: a hand-edited file that dropped it is reported, not repaired.
- A card's resting reading becomes the settings', not `part`. The recipe card's own scale-and-unit
  view (FR-REC-7) therefore marks itself only where it *departs* from the global reading — "(part)"
  under an ml setting is as much a transform as "(ml)" was under a part one.
- Conversion is display-only, as it has always been. Nothing writes a converted amount: the file,
  the form and the line grammar all go on in the unit as entered.
- `displayMeasure` rounds to 2 decimals, so 1 part reads as 1.01 oz at the defaults. Exactness lives
  in the stored sizes; a reader who wants round numbers sets the ratio that gives them.
- FR-DAT-5 is unaffected — one new scalar key, emitted and read like the one beside it.
