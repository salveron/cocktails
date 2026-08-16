# ADR: The tags may aim the optimizer rather than sift it

**Status:** Accepted

## Context

FR-DIS-10 as built: a tag pick sifts the answer. The optimizer runs once over the whole collection,
and the chips keep the baskets where each pick is worn by some recipe the basket unlocks. The rank
is bound before the sift, so the numbering on show gaps, and the gap is what says a chip is doing
something.

That answers "of the best baskets overall, which shop for tiki?" — and it is not the question a
reader taps a tag to ask. They mean "which basket unlocks the most tiki recipes?", which the sift
cannot reach: [ADR 15](15-the-optimizer-answers-with-the-best-few.md) keeps only the best few of
each size, so the basket that would lead a niche category was cut before the chips ever saw it. That
ADR named the cost and named the answer — "re-running the search over the tagged recipes alone is
the answer if it ever is not."

Both questions are wanted. A reader stocking a bar asks the first; a reader shopping for Saturday's
tiki night asks the second. So the answer is a setting, not a replacement.

## Decision

**`purchasesWithin` gains `scoring`: the recipe names that count toward a basket's yield.** Null is
every recipe, which is today's answer exactly.

- **Everything downstream already reads "yield"** and is untouched: the zero-yield hiding, the
  earns-its-place rule, the best-few shelves, the ranking. A basket unlocking no tagged recipe
  scores zero and is dropped by the rule that was already there.
- **Naming is untouched.** `unlocks` stays every recipe the basket closes, so the card, its count
  and its dots stand as they are — the tagged recipes simply gather at the top of the list, marked
  the way FR-DIS-10 already marks them.
- **The pool is unchanged**, being the gaps' own ingredients either way, so the search costs the
  reading [ADR 16](16-the-optimizer-buys-what-is-running-low.md) already measured.
- **Picks read as a union here**: a basket is aimed at the recipes wearing *any* of them. Sifting
  keeps its own rule — each pick worn by some recipe unlocked — and the lists keep theirs, every
  pick worn (FR-DIS-3). A count is being maximised, and demanding one recipe wear every pick asks a
  far narrower question: two picks would routinely aim at nothing and empty a screen that was full
  under the other setting.
- **The numbering says which is in force.** Sifting binds the rank before it narrows, so it gaps;
  aiming scores the search itself, so it runs dense. Nothing else marks the mode, and nothing needs
  to.

### Where a way of looking is kept

On the bar's record, as one `Shopping` value beside `display` — with the budget and the "low too"
reading the screen opens on, ADR 15's `most`, and whether an optional line is shoppable (FR-REC-3).
Not in the collection: [ADR 21](21-the-file-carries-one-bar.md) put the reader's data on the record
and the owner's in the file, and nothing about a way of looking reaches a file a stranger reads. Not
app-wide either — FR-BAR-1 has a filter reach no further than the bar it started in.

One value rather than five fields: `Bar` has three copy constructors that each name every field, and
a fifth scalar is a fifth chance for one to go missing on a refresh.

## Alternatives considered

- **Re-search over the tagged recipes alone**, ADR 15's literal words. The pool shrinks with the
  recipe set, so it is *cheaper* than what was decided. Refused: a basket can then only name what it
  was searched over, so one unlocking four tiki recipes and five others reports four — and the card
  is not what this change is about.
- **Re-rank the best few already found**: cheapest, no domain change at all. Refused for the reason
  ADR 15 gave against itself — the basket that would lead a niche category is not in the list to be
  re-ranked.
- **Replace sifting rather than join it**: one reading to explain instead of two. Refused: the
  gapped numbering answers "and how good is this basket overall?", which aiming cannot say.
- **Every pick worn, the list rule** (FR-DIS-3): one home for the rule. Refused above — it is the
  rule for keeping an entry, and this is a rule for scoring a count.
- **A control on the shopping screen** rather than in Settings: closer to the chips it governs.
  Refused: the row of controls above the list is already what the budget and the switch spend, and
  a reader picks between these two questions far less often than they pick a budget.

## Consequences

- FR-DIS-10 gains the second reading and FR-SET-2 owns the setting. FR-REC-3 stops saying the
  optimizer never sees an optional line, and FR-DIS-6's `most` becomes the reader's to raise —
  which is ADR 15's own relief, handed over.
- **The ranking sort moves off `Purchase`.** The count that ranks a basket is no longer the length
  of the list it is named with, so the kept records are sorted before they are named. Ids index an
  A→Z pool, so the A→Z tie-break compares ids and nothing is named in order to be sorted — which
  also drops a naming step the old sort paid for.
- Aiming with nothing picked is today's answer: the scoring set is every recipe, and the two
  settings are indistinguishable until a chip is lit.
- The index gains its first preference *group*. A record without one reads as the defaults, so no
  migration runs and a store written by an older build stays legible.
- A setting the shopping screen reads is a setting a guest bar cannot reach, the destination being
  absent there (FR-BAR-4). Its Settings row dims like the vocabularies' used to.
