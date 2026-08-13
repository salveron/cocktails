# ADR: Nothing writes a guest bar

**Status:** Accepted

## Context

FR-BAR-3/4: everything in a guest bar is its owner's, and the reader adds nothing of their own — not
a stock level, not a note, not a tag. Nothing that writes is *offered* rather than refused, and the
shopping optimizer is absent there rather than empty.

Every collection edit in the app goes through one notifier, which every screen already watches to
read. A rule saying "check the mode first" would be a rule sixteen call sites have to keep, and the
one that forgets is a silent corruption of someone else's collection — invisible until their next
refresh throws it away.

Not everything on that notifier is a collection edit, and the count is what separates them. Export
(FR-DAT-1), import (FR-DAT-3) and the reading unit (FR-SET-1) have **one call site each**, and each
is already settled by a requirement rather than by this decision: a guest bar exports like any other,
the reading unit is expressly the reader's on a guest bar as on their own (FR-BAR-3), and import is
"into an owned bar" in FR-DAT-3's own words — the same file becomes a *guest* bar by the other road
(FR-BAR-7) instead. Sixteen call sites need a structure; one call site needs a line.

The app has no compiler-enforced boundaries (ADR 04): Dart's privacy is file-scoped, and
`test/architecture_test.dart` is what stands in for a compiler.

## Decision

**Three enforcements, each cheap, at three different distances from the mistake.**

- **Domain.** `ShelfEdits.withCollection` throws `ArgumentError` on a guest bar — the programmer
  contract `Collection`'s own constructor already keeps for duplicate names. Every collection edit ends
  there, so there is no derivation that quietly succeeds.
- **State.** The write surface is not the controller. `barWriterProvider` answers a `BarWriter?`:
  every collection mutation, or null on a guest bar. A screen must hold a non-null writer before it
  can call anything, and the null it may get back is the same fact that hides the control — so the
  read-only rule and the "not offered rather than refused" rule are one check, not two. The null
  means "someone else's bar", never "not loaded yet": an edit made while the startup load is still
  in flight queues behind it as it always has.
- **Test.** `architecture_test.dart` gains a rule beside the boundary and dependency ones: no file
  under `ui/` names `editCollection`, the raw route behind the writer. A new screen that invents its
  own way to a collection fails CI rather than a refresh. The rule cannot be "off the notifier
  entirely" — export, import and the reading unit are deliberately reachable there — so it names the
  one method that writes a collection without asking whose it is.

The shell reads the same fact once more, for a different purpose: `Destination` is per bar, so a
guest bar has no shopping destination and the optimizer is never asked for one (FR-BAR-4).

## Alternatives considered

- **A check in the controller only**: one place, no new type. Refused for the sixteen — it turns
  every write into a runtime refusal, which is exactly the "refused rather than not offered" FR-BAR-4
  rules out, and gives the UI nothing to read to know whether to draw the control. Taken for the
  three one-site operations, where there is one control to hide and the requirement already says
  which way it goes.
- **A separate `OwnedBar` type carrying the collection, so a guest bar has no writable value at
  all**: the strongest of the options, genuinely compile-time. Refused as too much: every screen
  reads the collection and only some write it, so the read path would carry the split for the sake
  of the write path.
- **Each screen asks the mode**: the shape a first draft falls into. Refused as the rule sixteen
  places have to keep, and the one this ADR exists to avoid.
- **Hide it in the shell** — no guest bar ever reaches a writing screen: true today and false the
  first time a read-only screen gains an edit affordance.

## Consequences

- A guest bar's collection has exactly one writer, the refresh that replaces it whole, which is what
  makes the concurrency story of a refresh trivial: there is nothing for a late answer to lose
  ([components.md](../components.md#work-in-flight)).
- Screens that write become `null`-aware at one point each, which is the same line that decides
  whether to draw the control.
- Import sits with export on the data seam rather than on the writer ([ADR 18](18-data-crosses-the-edge-in-a-system-sheet.md)),
  so the one exchange stays one subject and `replaceOpen` refuses a guest bar itself. What draws or
  hides its row is M34's, reading the same `openBarProvider` mode every other control does.
- The architecture test grows from reading directives to reading a name in source. A small widening,
  and the same non-vacuity discipline applies: the new rule is exercised on constructed input.
- Vision's likes and dislikes would be a reader's datum about someone else's recipe, not an edit to
  their collection — so it would sit beside `display` on the bar record, kept across a refresh by
  the same mechanism, and this decision would hold. What it would move is
  [ADR 22](22-a-bar-travels-behind-one-seam.md)'s seam, which fetches and nothing else.
