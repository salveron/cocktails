# ADR: Tag colour as a palette token

**Status:** Accepted

## Context

The tag screen renders each tag name as a coloured chip, the colour chosen when the tag is
created and shown everywhere the tag appears. That makes colour user data: it has to persist,
which puts it in the YAML schema — the public contract of
[ADR 02](02-persistence-and-export-format.md). Decided before M12 builds the screen and before
M13/M14 render tags inside recipes, which would otherwise be built for the colourless shape.

## Decision

**A tag carries a colour, stored as a token from a closed palette.**

- `enum TagColor { teal('teal'), indigo('indigo'), plum('plum'), rose('rose'), sand('sand'),
  slate('slate'), neutral('neutral') }` — declared wire tokens, like every other enum in the
  format.
- `Tag.color` defaults to `TagColor.neutral`. The tag entry becomes a mapping,
  `{name: sour, color: teal}`, with `color` omitted when neutral — the entry shape and
  default-omission rule ingredient entries already use.
- Recipe tag references stay a flow list of names: the colour lives with the tag, once.
- The palette avoids green, amber and red, which stock (FR-INV-1) and availability (FR-DIS-1)
  already spend on meaning; a colour on screen keeps one meaning.
- Token → swatch is a UI mapping. The domain names no Flutter colour, and both themes get
  their own pair.
- `format` stays `1`, on [ADR 06](06-base-spirit-on-the-line.md)'s grounds: the schema is
  unreleased, and the one live store file carries `tags: []`.

## Alternatives considered

- **A free hex string** — every value legal, so the palette stops being one: nothing prevents a
  colour illegible on dark, and validation has no set to check against.
- **Colour derived from the name** (hash into the palette) — no schema change and no picker,
  but a rename silently repaints the tag and the choice is never the user's.
- **Scheme roles as the palette** (`primaryContainer` and friends) — theme-correct for free,
  but derived from the seed: moving the seed repaints every existing tag, and the roles collide
  with the stock chips — the defect just fixed on the inventory screen.
- **Colour kept outside the model**, in a settings map keyed by tag name — splits one fact
  across two homes, and the entries orphan on every rename and delete.

## Consequences

- Requirements gain FR-VOC-3. FR-VOC-2 stays retired by ADR 06 rather than reused, so no
  reference to it can mean two things.
- `withTagRenamed` must carry the colour across — a rename that dropped it is silent data loss.
- The shared name dialog gains an optional palette row; the ingredient screens pass none.
- Files written before this carry `tags: [sour, classic]` as strings and are rejected as shape
  errors, hand-edited to mappings as ADR 06's leftovers were.
- Every later tag surface — recipe view (M13), form (M14), filters (M18) — shows the colour,
  reading the one token → swatch map in `ui/`.
- The seven tokens are a closed set: an eighth is a schema change, and dropping one breaks
  files that use it.
