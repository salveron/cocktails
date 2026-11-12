# ADR: A destination sends the reader to a named row on another

**Status:** Accepted.

## Context

Basket names recipes unlocked; reader wants what else each recipe is short of: 4 moves today (remember name, switch Recipes, search, open). Tap name on basket should make it 1 (FR-DIS-9). Recipe card names ingredients per line; reader wants that ingredient on Ingredients screen (aliases, tags, stock). Same move, different screens. Channel designed generally.

Nothing crosses destinations. `_Destination` and `_current` are private to `app.dart`; three screens sit side by side in `IndexedStack` and never speak. Only `EntryCardList` reveals a row: `RandomDraw.draw` answers a name, and `_reach` turns it into an index off `_placed` (ADR 13; keeps scroll package contained). Row must be on show: search, tag picks, base pick, order narrow or reorder. Reveal of an excluded row finds no index and silently does nothing.

## Decision

**One provider: request to reveal named row on named destination, consumed by serving screen.**

- Request: **destination + name** (never index, offset, widget, entity). Name is ADR 13 currency, all the list needs.
- **Name is nullable: a landing, not a jump.** Crossing into the loaded bar has a destination, no row (ui-design#bars). A missing name is the whole telling, no second flag: the shell clears the trail (reader chose the bar; nothing to return from); the serving screen keeps its narrowings (nothing named). `takeReveal` still answers `String?` and clears, so no screen changed.
- **Destinations module**: `lib/ui/destinations.dart` takes enum from `app.dart`, holds request provider. Same subject, same place; avoids circular import.
- Request **nullable, one-shot**: serving screen clears it; a later return does not re-reveal.
- **Shell watches only to switch destination**, learns nothing of row. `AppShell` becomes `Consumer` (whole change).
- **Serving screen resets narrowing to default before reveal**: tag picks, base pick, search text, order. Reader asked to see row, not why cannot. `EntryCardList` gains name-to-reveal input beside `draw`; both feed `_reveal`; reset is part of serving.
- **Row opened alone**, rest shut (like random pick). Jump is one answer, not pile.
- **Plain tap sends, no marking.** Long press (jump as secondary): refused. Reaching name is commonest thing reader wants, name-carrying rows lead nowhere else, tap free. Ripple is feedback. Arrow weighed and refused (slot carries tag dots, stock dots); label refused with long press.
- **Name crossing is entry's own**: line names ingredient by any spelling (ADR 10); sender resolves with `collection.spellingOf`. List finds rows by name; channel carrying spelling fails silently on unbuilt pairs.
- **Shell trail of destinations, back undoes jumps**: unwinds one by one; three rules: (a) only jumps record; bottom-bar tap clears (reader who chose has nothing to return from); (b) destination **at most once, never on-show** (bounds at 2 for 3 destinations; loop cannot accumulate); (c) Settings (above shell) popped by back as always.

## Alternatives considered

- **Sheet or pushed page**: no shell change, no coupling; screen behind stays. But recipe view gains second home (breaks one-home-per-fact); read-only copy drifts from source card. Weighed and rejected.
- **Shell owns request in State, passes down**: no provider; every destination takes ignored parameter; request threaded through shell's build to reach 1 of 3.
- **`GlobalKey` per screen, called direct**: fewest parts, worst coupling; one screen holds handle to another's `State`.
- **Report not reset**: narrowings stand, row off-show. Honest; feature fails exactly when wanted (reader narrowing due to many entries). Snackbar to clear: 2 taps for 1 ask.
- **Request names kind, shell maps to screen**: one indirection, buys nothing (one-to-one).

## Consequences

- 4th kind of presentation state: inter-screen request. Only one, cleared on delivery.
- `AppShell` no longer ignorant of children's wishes (still nothing of content). Destination enum moves to module both see.
- **Active search cleared by jump** (exception to query survival rule). Edit is within query (reader working); jump is outside (reader names). Order and tag picks clear too; jump always lands default.
- **Reveal + jump-home can pend same frame** (ADR 13 assumed impossible). Reset narrows marks list home; reveal waits. `_reach` orders: home first, returning early; reveal served next measurement. Behavior implicit, load-bearing, pinned by test.
- **`AppShell` gains history; back stops meaning "leave"**. Trail (destinations, not states) + `PopScope`. Weighed against no history (bottom bar is way back). Refused: jump is app moving reader; undo gesture shouldn't close.
- **Back restores place, not narrowings**. Reveal clears search/picks/order; return doesn't restore them; trail not state snapshot (refuses router). Softened: destinations stay alive, so the shopping screen keeps budget, switch and cards as left.
- **Arrival needs no signalling**: revealed row washes `secondaryContainer`→rest (FR-DIS-5, ADR 13); tap confirms via `InkWell`. Both free.
- **Line reaches per ingredient, not per line**: group offers several (ADR 11); line-wide target names first only. Each ingredient has own span/recognizer; measure, "or", mark stay inert (one place where part of line answers, part not).
- Channel general, must stay small. 3rd pair: 1 call site, no new type. Must not become router: reveal named row, no args/intent/history.

## Scope

Both pairs built at once (FR-DIS-9): a basket's recipes and ingredients, and a recipe line's ingredients. The Ingredients screen serves as the Recipes does; the shopping screen only ever sends. Nothing yet names a basket, which is ranked rather than named.
