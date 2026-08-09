# ADR: A list scrolls to a row by index

**Status:** Accepted

## Context

FR-DIS-5's random pick has to put the recipe it names under the eye. The shape chosen is that the
list opens that recipe's card and scrolls to it — the pick read on the same card as any other
recipe, so the recipe view keeps one home. Decided before the pick was built.

`ListView.builder` builds lazily: a row outside the viewport has no `BuildContext`, so
`Scrollable.ensureVisible` cannot reach it, and cards expand in place, so the rows have no uniform
height to compute an offset from. The app carries no scroll machinery at all today — no
`ScrollController`, no `GlobalKey`.

## Decision

**`VocabularyList` scrolls to row by index, on `scrollable_positioned_list` pinned exactly.**

- `ScrollablePositionedList.builder` replaces `ListView.builder` in one file; all four lists scroll alike.
- Screen reveals **name**, not index/offset. `_placed` (sort order) turns name to index; package types stay in `vocabulary_list.dart`.
- Ergonomic dependency (platform: `path_provider`, format: `yaml`, state: `riverpod`, lints). ADR 01 fixed stack, not additions; bar: *confined to one file, way out written down*.
- 0.3.8 three years old, touches sliver internals. **Pinned exactly** (not caret): quiet package needs no release stream; next one read before taken.
- Fallback recorded: if package breaks, float revealed row to front of `_placed`, scroll to nothing — few lines in `_place`, row leaves sorted position (worse reading, not broken), nothing outside `vocabulary_list.dart` changes.

## Alternatives considered

- **Float to front, no package**: free, reuses `_place`; but pick standing out of sort misreports order every time.
- **Estimate and settle**: guess offset, check post-frame, repeat. No dependency; convergence loop in shared widget, worst at list ends.
- **Dialog naming pick**: no scroll, but recipe view gains second home; closing leaves recipe off-screen.
- **Uniform rows (`itemExtent`)**: exact arithmetic free; breaks in-place card expansion recipes screen built on.

## Consequences

- A fifth dependency, and a bar for the sixth.
- All four lists change scroll implementation, though only the recipes reveal a row; scroll physics
  becomes the package's rather than `ListView`'s.
- `VocabularyList` gains the ability to reveal a name. The recipes screen learns no scrolling.
- **A reveal is by index only where the row is out of view.** A row the reader can already see is
  reached in pixels, off the last measurement the package took — so a reveal asked for in the same
  frame as a height change aims at where the row *was*, and a tall card shutting above it carries
  the row clean off the top of the list. The reveal therefore waits for the measurement that follows
  it: `ItemPositionsListener` firing is the signal that the rows have settled. A frame callback is
  not enough — the package registers its own during the frame, so it runs *after* anything scheduled
  before it.
- A test can no longer reach a row with `tester.scrollUntilVisible` on a bare finder: the list holds
  more than one `Scrollable`, so the finder is ambiguous. A row is reached by being revealed —
  which is what a reader does anyway.
- A dead package is a known, costed edit rather than a redesign.
