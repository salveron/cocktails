# ADR: The optimizer answers with the best few

**Status:** Accepted

## Context

FR-DIS-6: purchases of ≤N ingredients unlocking most missing recipes, ranked. Requirement does not specify count to report; "all of them" proved expensive. Measured on 400 recipes / 120 ingredients at N=3: search 43 ms, naming 35,000 baskets ~320 ms (7× search cost). Cost grows cubic with ingredient pool; useful answer ~20 rows. First cut building all baskets before ranking: 6.8 s.

## Decision

**`purchasesWithin` returns best `most` baskets per size, `most` default 25.**

- Baskets weighed by recipe count during search, named only if returned: 75 objects at N=3 instead of 35,000.
- **Per size, not overall**: global cap fills with large baskets, buries cheap wins. Per-size keeps best of each; screen free to read as ranked list or section per size.
- **Basket must beat smaller selves**: else carrying passenger (`gin` + `campari` unlocking same as `gin`). Sub-basket recipes always subset; equal counts = equal answers. Subsumes weaker rule; zero-yield cannot beat parts.

## Alternatives considered

- **Return every basket**: honest reading, first implementation. 320 of 364 ms spent on answers never shown; cubic growth term.
- **Single global cap**: cheaper, simpler; forecloses section-per-size presentation.
- **Rank by recipes/ingredient**: surfaces cheap wins flat; stops answering "which three ingredients?" question.
- **Search gaps' unions only**: half smaller (35,196 of 62,268 subsets); 1.4 s cost vs 43 ms scan.

## Consequences

- 400 recipes at N=3 answers in **~140 ms**, from 6.8 s. The performance test pins a regression
  guard rather than a stopwatch, since CI machines vary.
- `most` is a parameter, so a screen wanting a longer list asks for one. The default is the domain's
  guess at what a phone can show, not a limit on what the search can find.
- The optimizer no longer promises *every* purchase worth making, only the best few of each size.
  Anything that needs the whole space — a "surprise me" over purchases, say — must raise `most`
  and pay for it.
- The best few are all a screen can narrow. The shopping tag filter (FR-DIS-10) sifts this list rather
  than the search behind it, so a basket cut here for ranking poorly overall is offered under no tag it
  would have led — a niche category can read empty while a good basket for it exists. `most` is the
  relief, and re-running the search over the tagged recipes alone is the answer if it ever is not.
- Cost still grows with the cube of the pool of out-of-stock ingredients, not with the recipe count. A
  collection short of far more ingredients than this one will cost more, and the budget selector is the
  relief: N=1 is linear and N=2 quadratic.
