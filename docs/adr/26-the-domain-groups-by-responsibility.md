# ADR: The domain groups by what it is responsible for

**Status:** Accepted

## Context

`lib/domain/src/` was 13 files answering to no shared shape: `collection.dart` (592 lines) held
eight subjects — every entity, both its enums and its root, `Holding` and `summaryOf` though those
answer for `Bar` not `Collection`; `availability.dart` mixed recipe availability with ingredient
stock, two different questions read by two different callers; `shelf.dart` imported
`optimizer.dart` because `ShoppingSettings` was declared there though never read there, a value on
`Bar` owing its shape to a file that never asks about it; `shelf_validation.dart` imported all 518
lines of `validation.dart` to use three names it could have reached without the collection's own
rule set riding along. A file's size said nothing about what it was for.

## Decision

**Three folders under `domain/src/`, plus loose files for what more than one folder reads. A
one-way chain: `shelf/ → shopping/ → collection/ → loose`.**

- **`collection/`** — what one bar contains, and every question asked of it: the root and its
  vocabularies (`collection.dart`, `amount.dart`, `unit.dart`, `unit_sizes.dart`, `ingredient.dart`,
  `tag.dart`, `recipe.dart`, `recipe_line.dart`), and what is derived from them
  (`ingredient_stock.dart`, `recipe_availability.dart`, `recipe_discovery.dart`,
  `amount_scaling.dart`, `collection_edits.dart`, `collection_validation.dart`).
- **`shopping/`** — what the optimizer is asked, and what it answers: `shopping_settings.dart`
  (`ShoppingSettings`, `budgets`, `basketCounts`) and `optimizer.dart` (`Purchase`,
  `purchasesWithin`), which reads `collection/` for the gaps it searches but is read by nothing
  there.
- **`shelf/`** — how the device holds many bars, and shares them: `bar.dart` (`Bar`, `BarMode`,
  `BarContent`, `Holding`, `summaryOf`, `coherenceProblems` — the four kinds a collection is
  summed up by belong beside the record they summarise, not the collection they count), `shelf.dart`
  (`Shelf` and its two rules), `sharing.dart` (`Transport`, `BarSource`, `Offer`,
  `UnreachableReason`), `shelf_edits.dart`, `shelf_validation.dart`.
- **Loose at `domain/src/`**: `names.dart` (ADR 08's fold, read by all three folders), `tokens.dart`
  (`Tokened`, `enumFromToken`), `issues.dart` (`ValidationIssue`, `ValidationIssueKind`, `Problem`,
  `checkName`, `addProblems` — domain's most widely shared surface, now reachable without a
  collection's own rule set attached), `list_edits.dart`. **The rule for the loose four is a rule,
  not an exception list: a file read by two or more folders sits at `src/` root; a file read by one
  lives in that folder** — the same shape [ADR 25](25-the-ui-groups-by-subject.md) gives `ui/`,
  where `app.dart`, `theme.dart` and `wording.dart` sit loose above `screens/` and `widgets/`.
- **The chain is enforced, unlike `ui/`'s groups.** `shelf/` may import `shopping/` and
  `collection/`; `shopping/` may import `collection/` but not `shelf/`; `collection/` imports only
  the loose four. Acyclicity is a goal here where it was refused for `ui/` (ADR 25) because the
  chain already existed in substance — `Bar` was never going to be asked about by `Collection` —
  and leaving it unstated is what let `shelf.dart → optimizer.dart` stand for three milestones
  after `ShoppingSettings` stopped being read there.

### Two tests

1. Every file under `domain/src/` is loose or sits in `collection/`, `shopping/`, or `shelf/`.
2. No folder imports one later in the chain — `collection/` importing `shopping/` or `shelf/` is
   caught, as is `shopping/` importing `shelf/`.

The barrel (`domain/domain.dart`) is restated once against the tree rather than patched per file:
every new file gets one `export`, and several `hide` clauses drop out because the name they hid
now lives in a file the barrel simply does not export from at all — `isShortLine` and `canMake`
sit beside `stockOf`/`availabilityOf` in files that also carry public names, so the hide stays;
nothing hides a whole file, since every file here carries at least one name another layer or the
barrel's own tests read.

## Alternatives considered

- **Keep the flat 13 files, split only the two biggest (`collection.dart`, `validation.dart`).**
  Rejected: the misfiled pair (`Holding`/`summaryOf` in `collection.dart`, `ShoppingSettings` in
  `optimizer.dart`) survives either way, and a later reader still meets `shelf_validation.dart`
  importing 518 lines for three names.
- **One folder per file (25 folders of one file each).** Rejected: a folder that answers for
  nothing beyond its own file is a rename with extra steps, and the three-folder shape is what
  makes the one-way chain worth stating and testing.
- **Fold `shopping/` into `collection/`, since it only reads `collection/`.** Rejected: the
  optimizer answers a different question than the collection does — not "what is here" but "what
  would make more makeable" — and `Bar.shopping` being the shelf's own concern, not the
  collection's, is the fact the third folder keeps visible.

## Consequences

- `test/domain/` mirrors the tree, file for file — the same rule `components.md`'s testing section
  already states for every layer.
- A future domain file's home is answered by the same question `ui/`'s already is: what does this
  read, and what reads it back.
