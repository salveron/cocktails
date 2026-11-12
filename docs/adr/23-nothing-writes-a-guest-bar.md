# ADR: Nothing writes a guest bar

**Status:** Accepted

## Context

FR-BAR-3/4: everything in a guest bar is its owner's; the reader adds nothing of their own (no stock level, note or tag). Nothing that writes is *offered* rather than refused, and the shopping optimizer is absent there, not empty.

Every collection edit goes through one notifier that every screen already watches. A rule saying "check the mode first" would bind sixteen call sites, and the one that forgets silently corrupts someone else's collection until their next refresh discards it.

Not everything on that notifier is a collection edit; the call-site count separates them. Export (FR-DAT-1), import (FR-DAT-3) and the reading unit (FR-SET-1) have **one call site each**, and a requirement settles each rather than this decision: a guest bar exports like any other; the reading unit, and since [ADR 21](21-the-file-carries-one-bar.md) the bar's name, is the reader's on a guest bar as on their own (FR-BAR-3); import is "into an owned bar" in FR-DAT-3's own words, the file becoming a *guest* bar by the other road (FR-BAR-7). Sixteen call sites need a structure; one needs a line.

The app has no compiler-enforced boundaries (ADR 04): Dart's privacy is file-scoped, so `test/architecture_test.dart` stands in for a compiler.

## Decision

**Three enforcements, each cheap, at three different distances from the mistake.**

- **Domain.** `ShelfEdits.withCollection` throws `ArgumentError` on a guest bar, the programmer contract `Collection`'s constructor already keeps for duplicate names. Every collection edit ends there, so no derivation quietly succeeds.
- **State.** The write surface is not the controller. `barWriterProvider` answers a `BarWriter?`: every collection mutation, or null on a guest bar. A screen must hold a non-null writer to call anything, and the same null hides the control, so the read-only rule and the "not offered rather than refused" rule are one check, not two. The null means "someone else's bar", never "not loaded yet": an edit made during the startup load queues behind it.
- **Test.** `architecture_test.dart` gains a rule beside the boundary and dependency ones: no file under `ui/` names `editCollection`, the raw route behind the writer. A new screen inventing its own route fails CI, not a refresh. The rule cannot be "off the notifier entirely", since export, import and the reading unit are deliberately reachable there; it names the one method that writes a collection without asking whose it is.

The shell reads the same fact for another purpose: `Destination` is per bar, so a guest bar has no shopping destination and the optimizer is never asked for one (FR-BAR-4).

## Alternatives considered

- **A check in the controller only**: one place, no new type. Refused for the sixteen: every write becomes a runtime refusal, which is the "refused rather than not offered" FR-BAR-4 rules out, and the UI has nothing to read when drawing the control. Taken for the three one-site operations, where there is one control to hide and the requirement already says which way it goes.
- **A separate `OwnedBar` type carrying the collection**, so a guest bar has no writable value at all: the strongest option, and compile-time. Refused: every screen reads the collection and only some write it, so the read path would carry a split only the write path needs.
- **Each screen asks the mode**: the shape a first draft falls into. Refused: the rule sixteen places must keep, the one this ADR exists to avoid.
- **Hide it in the shell**: no guest bar ever reaches a writing screen. True today, false the first time a read-only screen gains an edit affordance.

## Consequences

- A guest bar's collection has one writer, the refresh that replaces it whole, so a refresh's concurrency is trivial: nothing is there for a late answer to lose ([components.md](../components.md#work-in-flight)).
- Writing screens are `null`-aware at one point each.
- **The read-only screen arrived**, the case the fourth alternative was refused for: tags, units and amounts open on a guest bar and read there (FR-BAR-4). This decision did not move to allow it; the same null blocks the write and hides the control, so each of the three grew one `writable`, spent on what it draws.
- Import sits with export on the data seam, not the writer ([ADR 18](18-data-crosses-the-edge-in-a-system-sheet.md)), so the exchange stays one subject and `replaceOpen` refuses a guest bar itself. Its row reads the same `openBarProvider` mode as every other control.
- The architecture test grows from reading directives to reading a name in source: a small widening, under the same non-vacuity discipline, so the new rule is exercised on constructed input.
- Vision's likes and dislikes, a reader's datum about someone else's recipe rather than an edit to their collection, would sit beside `display` on the bar record, kept across a refresh by the same mechanism, and this decision would hold. The bar's own name went that way ([ADR 21](21-the-file-carries-one-bar.md)): a reader's datum about someone else's bar, renamed through `renameBar` like any other bar's and unreachable from the refresh that replaces the contents. What it would move is [ADR 22](22-a-bar-travels-behind-one-seam.md)'s seam, which fetches and nothing else.
