# ADR: A destination sends the reader to a named row on another

**Status:** Accepted

## Context

A basket on the shopping screen names the recipes it unlocks, and the reader wants to know what else
one of them is short of. Today that answer is four moves away: remember the name, switch to Recipes,
type it into the search, open the card. Long-pressing the name on the basket is to make it one
(FR-DIS-9).

It is not the only such jump. An expanded recipe card names the bottles each line is built from, and
the same reader wants that bottle on the Inventory — to see its aliases, its tags, or to set its
stock. The same move, a different pair of screens. The channel is therefore designed for the pair in
general and built for the first pair only.

Nothing in the app crosses destinations. `_Destination` and `_current` are private to `app.dart`, so
no screen can ask for another; the three live side by side in an `IndexedStack` and never speak.
Revealing a row is `VocabularyList`'s alone and is driven only from inside it — `ListDraw.draw`
answers with a name and `_reach` turns it into an index off `_placed`
([ADR 13](13-lists-scroll-by-index.md)), which is what keeps the scroll package inside one file. A row
also has to be *on show* to be revealed at all: the search, the tag picks, the base pick and the
chosen order each narrow or reorder the list, and a reveal aimed at a row the narrowings exclude finds
no index and silently does nothing.

## Decision

**One provider carries a request to reveal a named row on a named destination, and is consumed by the
screen that serves it.**

- A request is **a destination and a name** — never an index, an offset, a widget or an entity. The
  name is the currency ADR 13 already chose, and a name is all a list needs to find its own row.
- **Destinations become a public module.** `lib/ui/destinations.dart` takes the enum out of
  `app.dart` and holds the request provider beside it: what destinations exist, and how one is asked
  for, being the same subject. `app.dart` would otherwise have to be imported by the screens it
  imports.
- The request is **nullable and one-shot**. The screen that serves it clears it, so returning to a
  destination later does not re-reveal what was read once.
- **The shell watches it only to switch destination**, and learns nothing else; it never hears which
  row. `AppShell` becomes a `Consumer`, which is the whole of the change to it.
- **The serving screen resets every narrowing to its default before revealing** — its own tag and base
  picks, and, inside `VocabularyList`, the search text and the chosen order. A reader who asked for a
  row asked to see it, not to be told why they cannot. `VocabularyList` gains a name to reveal as an
  input, alongside the `draw` that already produces one; both feed the one `_reveal` field, and
  resetting the search and the order is part of serving it, since neither is reachable from outside.
- **The row is opened alone**, the rest shutting, as a random pick does (FR-DIS-5): a jump is one
  answer rather than a pile of them.
- **The name crossing is the entry's own.** A recipe line names a bottle by any of its spellings
  ([ADR 10](10-ingredient-aliases.md)), so a sender resolves it — `model.bottleNamed` — before asking.
  A list finds its rows under their own names, and a channel carrying a spelling instead would fail
  silently on exactly the pair that is not built yet.
- **The shell remembers what a jump left, and the back gesture undoes it.** A trail of destinations —
  never of their states — with back claimed while it is not empty, so a chain of jumps unwinds one at a
  time and the app is left only once the reader is back where they started. Three rules keep it
  predictable: **only a jump records**, a bottom-bar tap clearing the trail, since a reader who chose
  where they are has nothing to return *from*; a destination stands in the trail **at most once and
  never the one on show**, which bounds it at two for three destinations, so a loop of jumps cannot
  accumulate one; and Settings, a route above the shell, is popped by back exactly as it always was.

## Alternatives considered

- **A sheet or a pushed page showing the row.** No shell change, no coupling, and the screen behind
  stays where it was — but the recipe view gains a second home, against *one home per fact*, and the
  read-only copy drifts from the card it was cut from. Weighed first and rejected on that.
- **The shell owns the request in `State` and passes it down.** No provider, but every destination
  then takes a parameter most of them ignore, and the request has to be threaded through the shell's
  own build to reach one screen out of three.
- **A `GlobalKey` per screen, called directly.** Fewest moving parts and the worst coupling: one
  screen would hold a handle to another screen's `State` and reach into it.
- **Report instead of reset.** Leave the narrowings standing and say the row is not on show. Honest,
  and it makes the feature fail exactly when it is most wanted — the reader is narrowing *because*
  they have a lot of entries. A snackbar offering to clear was weighed and dropped as two taps for
  the thing already asked for.
- **The request naming a kind rather than a destination**, the shell mapping kind to screen. One
  indirection more, and it buys nothing while the two are one-to-one.

## Consequences

- A fourth kind of state in the presentation layer: not model, not derived, not screen-local, but one
  screen's request of another. It is the only one, and it is cleared on delivery.
- `AppShell` is no longer ignorant of its children's wishes, though it still knows nothing of their
  content. `app.dart` loses the destination enum to a module both it and the screens can see.
- **An active search is cleared by a jump** — the one exception to the rule that a query survives
  what happens around it, including an edit that renames an entry out of it. The reasons differ: an
  edit is the reader working *within* the query, a jump is the reader naming a row *outside* it. The
  chosen order and the tag picks go the same way, so a jump always lands on a list in its default
  reading.
- **A reveal and a jump home can now be pending in the same frame**, which ADR 13 assumed impossible
  ("a draw is made over rows already on show, so the two never wait together"). Resetting the
  narrowings marks the list for home while the reveal waits. `_reach` already orders them — home
  first, returning early, the reveal served on the measurement that follows — so the behaviour falls
  out rather than being added, but it is now load-bearing and pinned by a test.
- **`AppShell` gains history, and back stops meaning "leave".** The trail is a second piece of shell
  state beside `_current`, and a `PopScope` around the destinations. It was weighed against having none
  — the bottom bar being a way back, and every destination staying alive with its state — and refused:
  a jump is the app moving the reader, and the gesture that undoes what the app did should not be the
  one that closes it.
- **Back restores the reader's place, not their narrowings.** Serving a reveal cleared the search, the
  picks and the order, and returning does not put them back; a trail carrying a snapshot of each
  screen's state is the router this decision refuses to become. Accepted, and softened by what the
  trail does not have to carry: the destinations are all alive, so the shopping screen is found with
  its budget, its switch and its open cards exactly as they were.
- **The arrival needs no signalling of its own.** The revealed row washes from `secondaryContainer`
  back to rest as a drawn one does (FR-DIS-5, [ADR 13](13-lists-scroll-by-index.md)), and the long
  press confirms itself through `InkWell`'s own feedback, which is what the made-history reset already
  rides on (FR-REC-6). Both come free of the channel.
- The channel is general and must stay small. A second pair costs one call site and no new type; what
  it must not become is a router — the request reveals a named row, and carries no arguments, no
  intent and no history.

## Scope

Built for the shopping screen's recipes first (FR-DIS-9). The recipe card's lines reaching the
Inventory is the second pair, planned separately: the same provider, one more call site, and the
inventory screen learning to serve.
