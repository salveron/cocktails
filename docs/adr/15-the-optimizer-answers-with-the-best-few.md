# ADR: The optimizer answers with the best few

**Status:** Accepted

## Context

FR-DIS-6: purchases of ≤N ingredients unlocking most missing recipes, ranked. The requirement sets no count; "all of them" proved expensive. Measured on 400 recipes / 120 ingredients at N=3: search 43 ms, naming 35,000 baskets ~320 ms (7× search cost). Cost grows cubic with the ingredient pool; a useful answer is ~20 rows. Building all baskets before ranking: 6.8 s.

## Decision

**`purchasesWithin` returns best `keptPerSize` baskets per size, `keptPerSize` default 25.**

- Baskets weighed by recipe count in search, named only if returned: 75 objects at N=3, not 35,000.
- **Per size, not overall**: a global cap fills with large baskets and buries cheap wins; per size keeps the best of each, shown as one ranked list or a section per size.
- **Basket must beat smaller selves**: else it carries a passenger (`gin` + `campari` unlocking the same as `gin`). Sub-basket recipes always subset, so equal counts mean equal answers; subsumes weaker rule: zero-yield cannot beat parts.

## Alternatives considered

- **Return every basket**: honest reading; 320 of 364 ms spent on answers never shown; cubic growth.
- **Single global cap**: cheaper, simpler; forecloses section-per-size presentation.
- **Rank by recipes/ingredient**: surfaces cheap wins flat; stops answering "which three ingredients?"
- **Search gaps' unions only**: half smaller (35,196 of 62,268 subsets); 1.4 s cost vs 43 ms scan.

## Consequences

- 400 recipes at N=3 answer in **~140 ms**, down from 6.8 s. The performance test pins a regression guard, not a stopwatch, since CI machines vary.
- `keptPerSize` is a parameter; a screen wanting more asks for it. The default is the domain's guess at what a phone shows, not a limit on what search finds.
- Only the best few per size are promised, not *every* purchase worth making; whole-space needs (a "surprise me", say) must raise `keptPerSize` and pay.
- The best few are all a screen can narrow. The shopping tag filter (FR-DIS-10) sifts this list, not the search, so a basket cut for ranking poorly overall is offered under no tag it would have led: a niche category can read empty while a good basket exists. `keptPerSize` is the relief; re-running the search over tagged recipes alone is the answer if it is not.
- Cost grows with the cube of the out-of-stock pool, not recipe count; a collection short of far more ingredients costs more. The budget selector is the relief: N=1 linear, N=2 quadratic.
