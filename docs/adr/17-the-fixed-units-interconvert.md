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
implemented as is what ships. And the ratio is what the [amounts screen](../ui-design.md#amounts)
is *for*: the shape it edits is the shape readers will have files in.

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

- **Anchor ratio to part**: literal to FR-SET-1, smallest change. Rejected: three fixed units make second ratio dead weight under half readings; oz-written recipe unreadable for ml-pourer.
- **Store pair reader sees** (unit + two ratios typed): switching rewrites two stored numbers via division; bar round-trips subtly different; file records last look not what part is.
- **ADR 09 full** (ml equivalence on every entry): dash/barspoon convert too. Rejected: dash is gesture not measure; normalizing to 0.92 ml unwanted; nullable on every entry for 3. Additive later.
- **`convertible` flag on entry**: second concept for what names carry (ADR 09 rejected).
- **Two ratios anchored to part** (`part_ml`, `part_oz` skip ml anchor): degrees of freedom equivalent; file shape depends on what was special when written; ml→oz quotient of preferences not sizes.

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
