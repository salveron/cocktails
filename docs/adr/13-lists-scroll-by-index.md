# ADR: A list scrolls to a row by index

**Status:** Accepted

## Context

FR-DIS-5's random pick has to put the recipe it names under the eye. The shape chosen is that the
list opens that recipe's card and scrolls to it — the pick read on the same card as any other
recipe, so the recipe view keeps one home. Decided before M20.

`ListView.builder` builds lazily: a row outside the viewport has no `BuildContext`, so
`Scrollable.ensureVisible` cannot reach it, and cards expand in place, so the rows have no uniform
height to compute an offset from. The app carries no scroll machinery at all today — no
`ScrollController`, no `GlobalKey`.

## Decision

**`VocabularyList` scrolls to a row by index, on `scrollable_positioned_list`.**

- `ScrollablePositionedList.builder` replaces `ListView.builder` in the one file, so all four lists
  scroll alike rather than the recipes carrying a second implementation.
- A screen asks to reveal a **name**, never an index and never an offset. `_placed` is already the
  one home for the order rows stand in, so it is what turns a name into an index; the package's
  types stay inside `vocabulary_list.dart`.
- The dependency is ergonomic, not structural — the first of its kind, the others being platform
  (`path_provider`), format (`yaml`), state (`flutter_riverpod`) and lints. ADR 01 fixed the stack,
  not what may be added to it; the bar this sets is *confined to one file, with the way out
  written down*.
- Dormancy is the risk taken: 0.3.8 is three years old and touches sliver internals, though
  google.dev-published and widely used. Verified against the current Flutter before adoption — a
  far-off index across variable-height rows, jumped to and animated back. **Pinned exactly**, not
  by caret: a package this quiet has no stream of releases to keep up with, so the next one — if it
  comes — is read before it is taken, rather than resolving into a build unnoticed.
- **The way out is recorded rather than rediscovered.** If the package breaks unfixed, float the
  revealed row to the front of `_placed` and scroll to nothing: a few lines in `_place`, which
  already holds rows against the sort. The row then leaves its sorted position — a worse reading,
  not a broken one — and nothing outside `vocabulary_list.dart` changes.

## Alternatives considered

- **Float the row to the front, no package.** The fallback above, weighed first: it costs nothing
  and reuses `_place`, but a pick standing out of its sorted position misreports the order the user
  asked for, every time rather than only after a breakage.
- **Estimate and settle.** Jump to a guessed offset, check post-frame whether the row built, repeat.
  No dependency, but a convergence loop inside the widget three screens rest on, worst at the ends
  of the list and awkward to reason about.
- **A dialog naming the pick.** No scrolling at all — but the recipe view gains a second home, and
  closing the dialog leaves the recipe it named nowhere on screen.
- **Uniform rows (`itemExtent`).** Makes the arithmetic exact for free, and costs the in-place card
  expansion the recipes screen is built on.

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
