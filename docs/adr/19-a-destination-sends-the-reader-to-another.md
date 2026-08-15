# ADR: A destination sends the reader to a named row on another

**Status:** Accepted. Amended on implementation: the gesture is a plain tap, and both pairs were
built at once.

## Context

Basket names recipes unlocked; reader wants to know what else recipe is short of — 4 moves today (remember name, switch Recipes, search, open). Tap name on basket should make it 1 (FR-DIS-9). Recipe card names bottles per line; reader wants that bottle on Inventory (aliases, tags, stock). Same move, different screens. Channel designed generally.

Nothing crosses destinations. `_Destination`, `_current` private to `app.dart`; three screens side by side in `IndexedStack`, never speak. Revealing row is `VocabularyList` alone; `ListDraw.draw` answers name, `_reach` turns to index off `_placed` (ADR 13; keeps scroll package contained). Row must be on-show to reveal: search, tag picks, base pick, order narrow/reorder; reveal of excluded row finds no index, silently does nothing.

## Decision

**One provider: request to reveal named row on named destination, consumed by serving screen.**

- Request: **destination + name** (never index, offset, widget, entity). Name is ADR 13 currency; name is all list needs.
- **Amended: name nullable — a landing, not a jump.** Crossing into the bar already loaded has a destination and no row (ui-design#bars). Missing name is the whole telling, no second flag: shell clears the trail instead of pushing to it (reader chose the bar; nothing to return from), serving screen keeps its narrowings (nothing was named). `takeReveal` still answers `String?` and still clears, so no screen changed.
- **Destinations module**: `lib/ui/destinations.dart` moves enum from `app.dart`, holds request provider. Same subject, same place; avoids circular import.
- Request **nullable, one-shot**: serving screen clears it; return to destination later does not re-reveal.
- **Shell watches only to switch destination**, learns nothing of row. `AppShell` becomes `Consumer` (whole change).
- **Serving screen resets narrowing to default before reveal**: tag picks, base pick, search text, order. Reader asked to see row, not why cannot. `VocabularyList` gains name-to-reveal input alongside `draw`; both feed `_reveal` field; reset is part of serving.
- **Row opened alone**, rest shut (like random pick). Jump is one answer not pile.
- **Plain tap sends, no marking**. Amended on implementation: long press drafted first (jump as secondary). It's not — reaching name is commonest thing reader wants; name-carrying rows lead nowhere else; tap free. Ripple is feedback. Arrow weighed/refused (slot carries tag dots, stock dots); label refused with long press.
- **Name crossing is entry's own**: line names bottle by any spelling (ADR 10), sender resolves with `collection.bottleNamed`. List finds rows by names; channel carrying spelling fails silently on unbuilt pairs.
- **Shell trail of destinations, back undoes jumps**: chain unwinds one-by-one; three rules: (a) only jump records; bottom-bar tap clears (reader who chose has nothing to return from); (b) destination **at most once, never on-show** (bounds at 2 for 3 destinations, loop cannot accumulate); (c) Settings (above shell) popped by back as always.

## Alternatives considered

- **Sheet or pushed page**: no shell change, no coupling; screen behind stays. But recipe view gains second home (breaks one-home-per-fact); read-only copy drifts from source card. Weighed/rejected.
- **Shell owns request in State, passes down**: no provider; every destination takes ignored parameter; request threaded through shell's build to reach 1 of 3.
- **`GlobalKey` per screen, called direct**: fewest parts, worst coupling; one screen holds handle to another's `State`.
- **Report not reset**: narrowings stand, row off-show. Honest; feature fails exactly when wanted (reader narrowing due to many entries). Snackbar to clear: 2 taps for 1 ask.
- **Request names kind, shell maps to screen**: one indirection, buys nothing (one-to-one).

## Consequences

- 4th kind of presentation state: inter-screen request. Only one, cleared on delivery.
- `AppShell` no longer ignorant of children's wishes (still nothing of content). Destination enum moves to module both see.
- **Active search cleared by jump** (exception to query survival rule). Edit is within query (reader working); jump is outside (reader names). Order and tag picks clear too; jump always lands default.
- **Reveal + jump-home can pend same frame** (ADR 13 assumed impossible). Reset narrows marks list home; reveal waits. `_reach` orders: home first returning early, reveal served next measurement. Behavior implicit, load-bearing, pinned by test.
- **`AppShell` gains history; back stops meaning "leave"**. Trail (destinations, not states) + `PopScope`. Weighed against no history (bottom bar is way back). Refused: jump is app moving reader; undo gesture shouldn't close.
- **Back restores place, not narrowings**. Reveal clears search/picks/order; return doesn't restore; trail not state snapshot (refuses router). Softened: destinations alive, shopping screen found with budget/switch/cards as left.
- **Arrival needs no signalling**: revealed row washes `secondaryContainer`→rest (FR-DIS-5, ADR 13); tap confirms via `InkWell`. Both free.
- **Line reaches per bottle, not per line**: group offers several (ADR 11); line-wide target names first only. Each bottle own span/recognizer; measure, "or", mark stay inert (one place where part of line answers, part not).
- Channel general, must stay small. 3rd pair: 1 call site, no new type. Must not become router — reveal named row, no args/intent/history.

## Scope

Both pairs were built at once (FR-DIS-9): a basket's recipes and its bottles, and a recipe line's
bottles.
The Inventory serves as the Recipes does, and the shopping screen only ever sends — nothing yet
names a basket, a basket being ranked rather than named.
