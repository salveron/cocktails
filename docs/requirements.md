# Requirements — pilot

Single-user mobile app (Android); no accounts, sharing. Direction: [vision.md](vision.md).

## Concepts

| Concept | Definition |
|---|---|
| Ingredient | Generic name ("bourbon", "lemon juice") from user-managed vocabulary (recipes, inventory). Optional ingredient tags. No brands, no hierarchy. Substitution is per line, not per bottle (FR-REC-9). |
| Base spirit | Spirit recipe is built on — marked on recipe line, not ingredient (bottle is base *in recipe* only, never by itself). Recipe may mark multiple. |
| Stock level | Per ingredient: **in stock**, **running low**, **out** (default). |
| Tag | Coloured label from user vocabulary (interest/style/category; replaces Telegram emojis). Two vocabularies: recipe tags, ingredient tags ([ADR 07](adr/07-tag-colour.md)); optional both sides. |
| Unit | What a line measures in ("part", "dash"), from a user-managed vocabulary carrying a plural each ([ADR 09](adr/09-units-are-a-vocabulary.md)); part and ml are fixed members. |
| Recipe | Name + lines + tags + notes + made-history (last date, count). |
| Availability | Per recipe, required lines only: **makeable** (all in), **makeable-low** (none out, ≥1 low), **missing** (≥1 out). A line stands at its best-stocked alternative (FR-REC-9). First two = **can-make**. |

Names unique within kind, ignoring case ([ADR 08](adr/08-names-ignore-case.md)). 
Ingredient vocabulary covers aliases too (FR-VOC-6): every spelling names one bottle. 
Two tag vocabularies separate; one name may exist in both (different meanings).

## Functional requirements

### Recipes

- **FR-REC-1** Create, edit, and delete recipes through structured forms.
- **FR-REC-2** Ingredient line: amount + unit + ingredient. Unit from FR-VOC-5; **part** default, 
  omittable. Amount may be range ("1.5–2"); plural for amounts ≠ 1. ≥1 non-optional line required 
  (availability judges something).
- **FR-REC-3** Line may be optional: displays but excluded from availability and optimizer.
- **FR-REC-4** A recipe carries any number of tags, chosen from the tag vocabulary.
- **FR-REC-5** A recipe carries one free-text notes field — in the pilot the home for
  preparation steps, techniques, glassware, and garnish, all unformalized.
- **FR-REC-6** "Made it" action stamps date and increments counter (shown on recipe). 
  Last stamp reversible; history resetable to never-made.
- **FR-REC-7** Recipe view scales ×2/×3/×4 and reads one open recipe in other unit without 
  global toggle change (FR-SET-1). Display-only; range ends scale together; forgotten on close.
- **FR-REC-8** Line may mark as base spirit (clearable). Base and optional mutually exclusive.
- **FR-REC-9** Line may offer alternatives — bottles interchangeable *in that recipe* 
  ([ADR 11](adr/11-substitutions-on-the-line.md)): one amount, one unit, one mark govern the group. 
  Any one on hand makes the line; only when all are out is it missing. Cards read them as prose, 
  dimming what the bar lacks while it holds something.

### Vocabularies

- **FR-VOC-1** Add, rename (propagates), delete ingredients/tags; deletion blocked while referenced. 
  Ingredient entry includes aliases (FR-VOC-6), settled in same edit.
- **FR-VOC-3** Every tag carries colour from fixed palette (chosen on create, changeable, shown 
  everywhere). Palette holds no green/amber/red (signal stock/availability, [ADR 07](adr/07-tag-colour.md)).
- **FR-VOC-4** Ingredients tagged from own vocabulary (separate from recipe tags). Tag for ingredients 
  never offered on recipe, vice versa. Both managed on one screen, tab each.
- **FR-VOC-5** Measurement units are a vocabulary of their own ([ADR 09](adr/09-units-are-a-vocabulary.md)),
  managed from Settings: add, rename (propagates to every line), delete (blocked while a line uses
  it), and a plural per unit — left empty where it reads like the name ("ml", "oz"). Seeded with
  part, ml, oz, dash, barspoon, drop, piece. **part** and **ml** cannot be renamed or deleted: the
  ratio and the display toggle are anchored to them (FR-SET-1); their plurals are editable.

- **FR-VOC-6** Ingredient answers to multiple names ([ADR 10](adr/10-ingredient-aliases.md)): 
  aliases in entry, resolved wherever names resolve (recipe line, search, import). 
  References stored under entry's own name only. No commas in aliases.

FR-VOC-2 left for FR-REC-8 in [ADR 06](adr/06-base-spirit-on-the-line.md); its number stays
empty so no reference to it can mean two things.

### Inventory

- **FR-INV-1** Inventory lists all ingredients with stock level, searchable by any name 
  (FR-VOC-6); row reads under entry's own name.
- **FR-INV-2** Stock level toggles with single tap per ingredient.
- **FR-INV-3** Inventory shows ingredient tags in colour; can filter by them (combines with name search).

### Discovery

- **FR-DIS-1** Recipe list shows availability at glance (makeable-low distinct from makeable). Recipe 
  view marks each line running low/out.
- **FR-DIS-2** Recipes searchable by name and by the ingredients they use — any spelling 
  (FR-VOC-6), the card still reading under the recipe's own name.
- **FR-DIS-3** Recipe list filterable by tag(s), combining with the search (FR-INV-3's idiom on 
  the other list). Availability is not a filter: the availability order (FR-DIS-8) is what puts 
  the makeable first.
- **FR-DIS-4** Recipe list narrowable by base spirit ([ADR 12](adr/12-base-spirit-narrows.md)): one 
  spirit at a time, matching any alternative of any base line (ADR 11); *no base* is a choice of its 
  own, reaching the unmarked. Combines with the search and the tag filter.
- **FR-DIS-5** Random pick draws one recipe the bar can make now — low counts, missing does not — 
  from whatever the list is showing, so the search, the tag picks and the base pick all hold. It 
  opens that recipe alone and puts it on screen; a second draw moves off the one standing while 
  another can be made. Nothing makeable among them says so rather than doing nothing.
- **FR-DIS-6** Optimizer: budget **N** (1–3); evaluates ≤N out-of-stock ingredient combos; 
  reports recipes becoming can-make (ranked by count). Zero-yield hidden.
- **FR-DIS-7** Optimizer lists running-low ingredients as restock reminders.
- **FR-DIS-8** Lists (recipes, inventory, tags) readable in multiple orders: by name, by signal 
  (availability, stock, colour). Picking current order reverses it. Default: recipes by availability, 
  inventory by stock, tags by name (not persisted). Rows stable during edit.

### Settings

- **FR-SET-1** Global ratio (ml per part). Toggle switches part-based amounts parts↔ml; 
  others display as entered. One open recipe reads in other unit via toggle (FR-REC-7). 
  Ratio anchored to fixed part/ml units (FR-VOC-5).

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
- Search grammar for compound queries (several ingredients, logical operators).
- Non-base grouping.
- Almost-makeable view (missing exactly one ingredient).
- Glassware/garnish fields, photo per recipe.
- Ingredient hierarchy, quantity-level stock. (Per-line substitution is in: FR-REC-9.)
