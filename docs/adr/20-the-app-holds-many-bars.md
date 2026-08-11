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

- The collection type keeps its shape. It is one bar's contents; the app gains a level rather than
  rewriting one. **Amended:** it did not keep its name — see the alternative below.
- A **record** is what a bar costs when it is not on show: id, name, mode, reading unit, offers,
  source, last refresh. The bar list reads the index and no collection at all.
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
- **Rename `Model` to `Collection`**: honest, and `Bar.collection` of type `Collection` reads better
  than of type `Model`. Refused here as churn: the rename touches every layer, every test and half
  the documents to say what one sentence in [components.md](../components.md#the-shelf-and-the-bar)
  says. **Reversed before any of this was built.** The cost was the whole of the argument, and it
  only ever grew — Phases 7 to 10 each add code that would name the type. Against it stood the tiers
  the app now reads in: `Shelf`, `Bar`, `Model`, `Recipe`, three of them a thing in a bar and the
  fourth a thing in an architecture. The signatures above settled it: `BarPayload`, `withCollection`
  and `opening` were all written `Model collection` before a line of them existed, so the concept
  had taken the name already and only the type had not. Done as its own change, no behaviour
  touched, ahead of the milestone that would have doubled it.
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
- A shelf may hold no open bar — first run before the migration, or the last bar deleted. The shell
  offers no destination then, and the bar list is what it shows.
- Reaching another bar costs one file read and one decode, the work startup has always done.
- The bar list is the first thing in the app above the destinations, and the first state that is not
  about one collection.
