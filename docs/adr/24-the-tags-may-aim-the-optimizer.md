# ADR: The tags may aim the optimizer rather than sift it

**Status:** Accepted

## Context

FR-DIS-10 as built: a tag pick sifts the answer. The optimizer runs once over the whole collection, and the chips keep the baskets where each pick is worn by some recipe the basket unlocks. The rank is bound before the sift, so the numbering gaps, and the gap says a chip is doing something.

That answers "of the best baskets overall, which shop for tiki?" A reader tapping a tag asks "which basket unlocks the most tiki recipes?", which the sift cannot reach: [ADR 15](15-the-optimizer-answers-with-the-best-few.md) keeps only the best few of each size, so a basket leading a niche category was cut before the chips saw it. That ADR named the cost and the answer: "re-running the search over the tagged recipes alone is the answer if it ever is not."

Both questions are wanted: a reader stocking a bar asks the first, one shopping for Saturday's tiki night the second.

## Decision

**`purchasesWithin` gains `scoring`: the recipe names that count toward a basket's yield.** Null is every recipe, which is today's answer exactly, and the two settings are indistinguishable until a chip is lit.

- **Everything downstream reads "yield"** and is untouched: the zero-yield hiding, the earns-its-place rule, the best-few shelves, the ranking. A basket unlocking no tagged recipe scores zero and is dropped by the existing rule.
- **Naming is untouched.** `unlocks` stays every recipe the basket closes, so the card, count and dots stand; tagged recipes gather at the top, marked as FR-DIS-10 already marks them.
- **The pool is unchanged**: it is the gaps' own ingredients either way, so the search costs what [ADR 16](16-the-optimizer-buys-what-is-running-low.md) already measured.
- **Picks read as a union here**: a basket is aimed at recipes wearing *any* of them. Sifting keeps its rule (each pick worn by some recipe unlocked), and the lists keep theirs (every pick worn, FR-DIS-3). A count is being maximised, and demanding one recipe wear every pick asks a far narrower question: two picks would routinely aim at nothing and empty a screen full under the other setting.
- **The numbering says which is in force.** Sifting binds the rank before it narrows, so it gaps; aiming scores the search itself, so it runs dense. Nothing else marks the mode, and nothing needs to.

### Where a way of looking is kept

On the bar's record, as one `ShoppingSettings` value beside `display`: the budget and the "low too" reading the screen opens on, ADR 15's `keptPerSize`, and whether an optional line is shoppable (FR-REC-3). Not in the collection: [ADR 21](21-the-file-carries-one-bar.md) put the reader's data on the record and the owner's in the file, and nothing about a way of looking reaches a file a stranger reads. Not app-wide either: FR-BAR-1's filter reaches no further than the bar it started in.

One value rather than five fields: `Bar` has three copy constructors that each name every field, and a fifth scalar is a fifth chance for one to go missing on a refresh.

## Alternatives considered

- **Re-search over the tagged recipes alone**, ADR 15's literal words. Cheaper, as the pool shrinks. Refused: a basket can only name what it was searched over, so one unlocking four tiki recipes and five others reports four, and the card is not what this change is about.
- **Re-rank the best few already found**: cheapest, no domain change. Refused: the basket leading a niche category is not in the list to be re-ranked, the reason ADR 15 gave against itself.
- **Replace sifting rather than join it**: one reading to explain, not two. Refused: the gapped numbering answers "and how good is this basket overall?", which aiming cannot say.
- **Every pick worn, the list rule** (FR-DIS-3): one home for the rule. Refused: it is the rule for keeping an entry, and this one scores a count.
- **A control on the shopping screen** rather than in Settings: closer to the chips it governs. Refused: the controls above the list already hold the budget and the switch, and a reader picks between these questions far less often than a budget.

## Consequences

- FR-DIS-10 gains the second reading and FR-SET-2 owns the setting. FR-REC-3 stops saying the optimizer never sees an optional line, and FR-DIS-6's `keptPerSize` becomes the reader's to raise: ADR 15's own relief, handed over.
- **The ranking sort moves off `Purchase`.** A basket's count is no longer the length of its named list, so kept records are sorted before naming. Ids index an A→Z pool, so the tie-break compares ids, and nothing is named just to be sorted, which drops a naming step the old sort paid for.
- The index gains its first preference *group*. A record without one reads as the defaults, so no migration runs and an older store stays legible.
- A guest bar cannot reach a setting the shopping screen reads: the destination is absent there (FR-BAR-4), and `Bar.shopping` is `ShoppingSettings?`, null on a guest and refused where one is found anyway ([ADR 21](21-the-file-carries-one-bar.md) amended). A guest's lack of an optimizer is a fact the record keeps, not one the UI merely hides. Its Settings row dims like the vocabularies' used to.
