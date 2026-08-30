# ADR: The app holds many bars, one on show

**Status:** Accepted

## Context

FR-BAR-1 turns the one collection into any number of them, owned and guest alike, with one on show
and nothing crossing between. `Collection` was the whole database: the store loaded it, one provider held
it, every screen read it, every query took it. Something has to sit above it, and the choice decides
what a bar costs, how "nothing crosses" is enforced, and how much of the app moves.

NFR-2 sets the scale: tens of bars, hundreds of recipes each — thousands to tens of thousands of
recipes in total, megabytes of YAML — and reaching another bar has to be instant. FR-BAR-1 also says
names are labels: two bars may carry one, so a name cannot be a key.

## Decision

**`Shelf` above `Collection`: the record of every bar, which one is open, and that one's collection —
the only one resident.**

- `Collection` keeps its shape. It is one bar's contents; the app gains a level rather than
  rewriting one.
- A **record** is what a bar costs when it is not on show: id, name, mode, reading unit, offers,
  source, last refresh, when it last changed, and how much it holds kind by kind. The bar list reads
  the index and no collection at all.
- **Nothing crosses because there is nothing to cross to.** One `Collection` is in memory, every domain
  query takes it, and the store is the only route to another bar's bytes. This is a property of the
  design rather than a rule screens keep.
- **A bar carries an id, minted here and never shared.** Opaque, unique within the index, the store
  key and the way two same-named bars are told apart. Neither the device nor the reader has an
  identity of any kind (NFR-3, NFR-5).
- **One file per bar plus an index**, so a save touches one bar ([ADR 21](21-the-file-carries-one-bar.md)).
- **Switching bars rebuilds the screens**: the shell's subtree is keyed by the open bar, so search
  text, tag and base picks, open cards, the budget and the jump trail (ADR 19) go with the crossing.
  A narrowing of one bar's list is meaningless over another's.

## Alternatives considered

- **Every bar resident, `Collection` per bar in one map**: switching costs nothing and the bar list is
  free. Rejected on NFR-2 — startup would decode every file, and the memoised lookups every `Collection`
  builds would multiply by the number of bars. It also makes "nothing crosses" a discipline rather
  than a fact: a second collection would be one map lookup away from any query.
- **Name as the key, no id**: fewer parts, and the export could carry it. Refused by FR-BAR-1 —
  names are labels, and a rename would move a bar's file.
- **An id inside the exported file**: would let a refresh notice it was handed the wrong bar, and
  give the cloud way a natural address. Refused in [ADR 21](21-the-file-carries-one-bar.md): a copy
  that claims to be the original is worse than one that claims nothing.
- **Shelf in the state layer, not the domain**: it is app structure, not cocktails. Refused because
  its invariants are the kind `Collection`'s constructor already keeps, and the guest-bar refusal
  ([ADR 23](23-nothing-writes-a-guest-bar.md)) wants to be unit-testable without a device.

## Consequences

- The one writable provider becomes `ShelfController`; `collectionProvider` survives as a derived reading
  of the open bar's collection, which is what keeps every screen unchanged.
- A shelf may hold no open bar — first run before the migration, the last bar deleted, or the open
  one deleted with others still standing. The shell offers no destination then, and the bar list is
  what it shows: a first run is told from a cleared shelf by the index — absent versus present and
  listing none — so a device holding nothing is given a bar while a reader who deleted theirs is met
  by the list.
- Reaching another bar costs one file read and one decode, the work startup has always done.
- **A record is all the bar list may know**, which is what the list is built on: a card carries the
  name and answers with *counts* rather than contents ([ui-design.md](../ui-design.md#bars)). Reading
  every bar's file to fill the closed cards was weighed and refused on the same NFR-2 grounds as
  keeping them resident — tens of bars is the stated scale.
- **The summary lives on the record**: `holds` and `updated` are written by `Bar.summarised` and
  `Bar.refreshedAt` alone, and every route a collection takes ends in one of them, so the summary
  cannot be a step behind the contents it counts. A record carrying none is the one degraded state: an
  index written before summaries existed, which the startup load repairs by counting each such bar
  once, under the spinner it already draws, and never again. A bar whose file will not read keeps its
  absent summary rather than gaining one that says it holds nothing. The cost is paid where it is
  named — a collection edit now writes the index as well as the bar, one small file beside the large
  one already being written.
- The crossing is what taught the controller's write path to tell an edit from a load: a collection
  that changed because it came up from disk must not be written back, or every switch rotates the
  backups of a bar nobody touched ([components.md](../components.md#state-contracts)).
- The bar list is the first thing in the app above the destinations, and the first state that is not
  about one collection.
