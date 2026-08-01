# Requirements — pilot

Single-user mobile app (Android); no accounts, sharing. Direction: [vision.md](vision.md).

## Concepts

| Concept | Definition |
|---|---|
| Ingredient | Generic name ("bourbon", "lemon juice") from user-managed vocabulary (recipes, inventory). Optional ingredient tags. No brands, hierarchy, substitutions. |
| Base spirit | Spirit recipe is built on — marked on recipe line, not ingredient (bottle is base *in recipe* only, never by itself). Recipe may mark multiple. |
| Stock level | Per ingredient: **in stock**, **running low**, **out** (default). |
| Tag | Coloured label from user vocabulary (interest/style/category; replaces Telegram emojis). Two vocabularies: recipe tags, ingredient tags ([ADR 07](adr/07-tag-colour.md)); optional both sides. |
| Unit | What a line measures in ("part", "dash"), from a user-managed vocabulary carrying a plural each ([ADR 09](adr/09-units-are-a-vocabulary.md)); part and ml are fixed members. |
| Recipe | Name + lines + tags + notes + made-history (last date, count). |
| Availability | Per recipe, required lines only: **makeable** (all in), **makeable-low** (none out, ≥1 low), **missing** (≥1 out). First two = **can-make**. |

Names unique within kind, ignoring case — "Gin" and "gin" are one name ([ADR 08](adr/08-names-ignore-case.md)).
Two tag vocabularies separate, so one name may exist in both (different meanings).

## Functional requirements

### Recipes

- **FR-REC-1** Create, edit, and delete recipes through structured forms.
- **FR-REC-2** An ingredient line is amount + unit + ingredient, the unit drawn from the managed
  vocabulary of FR-VOC-5 — **part** is the default, so a line may leave it out. An amount may be a
  range ("1.5–2") and may be written in either spelling; an amount other than exactly 1 reads in
  the plural. Every recipe carries at least one line that is not optional, so availability always
  judges something.
- **FR-REC-3** An ingredient line may be marked optional: it displays with the recipe but
  is excluded from the availability computation (and thus from the shopping optimizer).
- **FR-REC-4** A recipe carries any number of tags, chosen from the tag vocabulary.
- **FR-REC-5** A recipe carries one free-text notes field — in the pilot the home for
  preparation steps, techniques, glassware, and garnish, all unformalized.
- **FR-REC-6** A "made it" action stamps the current date and increments a times-made
  counter; the recipe shows both. The last stamp can be taken back, and the history can be
  reset to never-made — miscounts are correctable, since nothing else can lower the count.
- **FR-REC-7** The recipe view can scale ingredient amounts ×2/×3/×4, and can read one open
  recipe on its own in the other display unit, without moving the global toggle (FR-SET-1). Display only:
  range ends scale together, and the reading is forgotten when the recipe is closed.
- **FR-REC-8** An ingredient line may be marked as a base spirit of the recipe; the mark can
  be cleared. The two line marks are mutually exclusive — a base line cannot be optional.

### Vocabularies

- **FR-VOC-1** Add, rename (propagates), delete ingredients and either tag vocabulary; deletion blocked 
  while referenced (recipe for ingredient/recipe tag; ingredient for ingredient tag).
- **FR-VOC-3** Every tag carries colour from fixed palette (chosen on create, changeable, shown 
  everywhere). Palette holds no green/amber/red (signal stock/availability, [ADR 07](adr/07-tag-colour.md)).
- **FR-VOC-4** Ingredients tagged from own vocabulary (separate from recipe tags). Tag for ingredients 
  never offered on recipe, vice versa. Both managed on one screen, tab each.
- **FR-VOC-5** Measurement units are a vocabulary of their own ([ADR 09](adr/09-units-are-a-vocabulary.md)),
  managed from Settings: add, rename (propagates to every line), delete (blocked while a line uses
  it), and a plural per unit — left empty where it reads like the name ("ml", "oz"). Seeded with
  part, ml, oz, dash, barspoon, drop, piece. **part** and **ml** cannot be renamed or deleted: the
  ratio and the display toggle are anchored to them (FR-SET-1); their plurals are editable.

FR-VOC-2 left for FR-REC-8 in [ADR 06](adr/06-base-spirit-on-the-line.md); its number stays
empty so no reference to it can mean two things.

### Inventory

- **FR-INV-1** Inventory lists all ingredients with stock level, searchable by name.
- **FR-INV-2** Stock level toggles with single tap per ingredient.
- **FR-INV-3** Inventory shows ingredient tags in colour; can filter by them (combines with name search).

### Discovery

- **FR-DIS-1** Recipe list shows availability at glance (makeable-low distinct from makeable). Recipe 
  view marks each line running low/out.
- **FR-DIS-2** Recipes searchable by name.
- **FR-DIS-3** List filterable by tag(s), ingredient(s) (any, not base only), availability; filters combine.
- **FR-DIS-4** Browse grouped by base spirit (recipe under each base mark; unmarked form ungrouped tail).
- **FR-DIS-5** Random pick suggests one can-make recipe respecting active filters.
- **FR-DIS-6** Shopping optimizer: budget **N** (select 1–3); evaluates combos of ≤N out-of-stock 
  ingredients; reports recipes becoming can-make per combo (ranked by count). Zero-yield hidden.
- **FR-DIS-7** Optimizer lists running-low ingredients as restock reminders.
- **FR-DIS-8** Every list — recipes, inventory, both tag vocabularies — can be read in more than
  one order: by name, and by the signal its rows carry (availability, stock level, tag colour).
  Picking the order in force reads the list backwards, so "missing first" and Z→A need no entries
  of their own. Recipes open on availability and the inventory on stock, both tag vocabularies on
  name; the choice is not kept between runs. Rows keep their places while one of them is edited,
  so a bottle never moves under the tap that changed it (FR-INV-2).

### Settings

- **FR-SET-1** Global ratio (ml per part). Toggle switches part-based amounts between parts/ml; 
  other units display as entered. One open recipe may be read in the other unit (FR-REC-7); the 
  toggle is where that choice is made for all of them. The two units it names are the fixed ones
  of FR-VOC-5, so the ratio can never lose what it converts between.

### Data exchange

- **FR-DAT-1** Single action exports all data (vocabularies, stock, recipes, line marks, made-history, 
  settings) to one text file; shareable via platform file sharing.
- **FR-DAT-2** Export file is human-readable, self-describing (editable without app, by person or AI); 
  carries format version.
- **FR-DAT-3** Single action imports file, **replacing entire database**. Requires explicit confirmation; 
  auto-exports current state beforehand (previous state recoverable).
- **FR-DAT-4** Import validates before applying. On structural/referential error (unknown ingredient, 
  duplicate name, malformed amount, unsupported version): nothing changed; app reports what and where.
- **FR-DAT-5** Export/import round-trip losslessly (export, import unmodified, export again = identical).

## Non-functional requirements

- **NFR-1** Phone-only; frequent actions (look up recipe, toggle stock, "made it") ≤ few taps.
- **NFR-2** Hundreds of recipes: instant (no perceptible lag in lists, search, filters, optimizer at N=3).
- **NFR-3** Single user, no account/login.
- **NFR-4** Fully offline.

## Out of pilot scope

See [vision.md](vision.md#future-directions):

- Guest access/publishing.
- PC/desktop app.
- In-app Telegram parsing (migration via FR-DAT-3 outside app).
- Formalized prep (ordered steps, technique vocab, filtering).
- Non-base grouping.
- Almost-makeable view (missing exactly one ingredient).
- Glassware/garnish fields, photo per recipe.
- Substitutions, hierarchy, quantity-level stock.
