# ADR: The app holds many bars, one on show

**Status:** Accepted

## Context

FR-BAR-1 turns the one collection into any number, owned and guest alike, one on show, nothing crossing between. `Collection` was the whole database: loaded by the store, held by one provider, read by every screen and query.

NFR-2 sets the scale: tens of bars, hundreds of recipes each (thousands to tens of thousands in total, megabytes of YAML); reaching another bar must be instant. FR-BAR-1 also says names are labels: a guest bar may carry any, so a name cannot be a key.

## Decision

**`Shelf` above `Collection`: the record of every bar, which one is open, and that one's collection, the only one resident.**

- `Collection` keeps its shape (one bar's contents); the app gains a level, not a rewrite.
- A **record** is what a bar costs when not on show: id, name, mode, reading unit, offers, source, last refresh, when it last changed, and how much it holds kind by kind.
- **Nothing crosses because there is nothing to cross to.** One `Collection` is in memory, every domain query takes it, and the store is the only route to another bar's bytes.
- **A bar carries an id, minted here, never shared.** Opaque, unique within the index: the store key, and how same-named bars are told apart. Neither device nor reader has an identity of any kind (NFR-3, NFR-5).
- **One file per bar plus an index**, so a save touches one bar ([ADR 21](21-the-file-carries-one-bar.md)).
- **Switching bars rebuilds the screens**: the shell subtree is keyed by the open bar, so search text, picks, open cards, the budget and the jump trail (ADR 19) reset. One bar's narrowing is meaningless over another's.

## Alternatives considered

- **Every bar resident, `Collection` per bar in one map**: switching and the bar list are free. Rejected on NFR-2: startup would decode every file, and memoised lookups multiply by bar count. It also makes "nothing crosses" a discipline, not a fact: a second collection is one map lookup from any query.
- **Name as key, no id**: fewer parts; export could carry it. Refused by FR-BAR-1: names are labels, and a rename would move a bar's file.
- **Id inside the exported file**: lets a refresh notice the wrong bar; gives the cloud way a natural address. Refused in [ADR 21](21-the-file-carries-one-bar.md): a copy claiming to be the original is worse than one claiming nothing.
- **Shelf in the state layer, not the domain**: app structure, not cocktails. Refused: its invariants are the kind `Collection`'s constructor already keeps, and the guest-bar refusal ([ADR 23](23-nothing-writes-a-guest-bar.md)) must be unit-testable without a device.

## Consequences

- The writable provider becomes `ShelfController`; `collectionProvider` survives as a derived reading of the open bar's collection, so no screen changes.
- A shelf may hold no open bar (first run before migration, last bar deleted, or open one deleted with others standing): the shell offers no destination and the bar list shows. The index tells a first run from a cleared shelf (absent versus present and listing none): an empty device is given a bar; a reader who deleted theirs meets the list.
- Reaching another bar costs one file read and one decode, the work startup always did.
- **A record is all the bar list may know**: a card carries the name and answers with *counts*, not contents ([ui-design.md](../ui-design.md#bars)). Reading every file for the closed cards was refused on the same NFR-2 grounds: tens of bars is the stated scale.
- **The summary lives on the record**: `holds` and `updated` are written only by `Bar.summarised` and `Bar.refreshedAt`, and every route a collection takes ends in one, so the summary cannot lag its contents. The one degraded state is a record carrying none (an index written before summaries existed): startup repairs it by counting each such bar once, under the spinner already drawn, never again. A bar whose file will not read keeps its absent summary, not one saying it holds nothing. Cost: a collection edit writes the index as well as the bar, one small file beside the large one.
- The crossing taught the controller's write path to tell an edit from a load: a collection that changed by coming up from disk must not be written back, or every switch rotates the backups of a bar nobody touched ([components.md](../components.md#state-contracts)).
- The bar list is the first thing above the destinations, and the first state not about one collection.
