# Requirements — pilot

Pilot scope: a single-user mobile app on the owner's Android phone; no accounts, no
sharing. Why and where it's heading: [vision.md](vision.md).

## Concepts

| Concept | Definition |
|---|---|
| Ingredient | Generic name ("bourbon", "lemon juice") from one flat, user-managed vocabulary shared by recipes and inventory. No brands, hierarchy, or substitutions. |
| Base spirit | An ingredient flagged as a grouping anchor — the strong spirits (whiskey, gin, rum, tequila, vodka, absinthe, …). The flag is set by the user, not derived. |
| Stock level | Per ingredient: **in stock**, **running low**, or **out** (default for new ingredients). |
| Tag | Label from a separate, user-managed vocabulary — the single mechanism for interest, style, and category (successor of the Telegram emojis). |
| Recipe | Name + ingredient lines + tags + free-text notes + made-history (last-made date and times-made count). |
| Availability | Computed per recipe over its required (non-optional) ingredient lines: **makeable** (all in stock), **makeable-low** (none out, at least one running low), **missing** (at least one out). The first two together: **can-make**. |

Recipe, ingredient, and tag names are each unique within their kind.

## Functional requirements

### Recipes

- **FR-REC-1** Create, edit, and delete recipes through structured forms.
- **FR-REC-2** An ingredient line is amount + unit + ingredient. Units: **part** (default),
  ml, oz, dash, barspoon, drop, piece. An amount may be a range ("1.5–2").
- **FR-REC-3** An ingredient line may be marked optional: it displays with the recipe but
  is excluded from the availability computation (and thus from the shopping optimizer).
- **FR-REC-4** A recipe carries any number of tags, chosen from the tag vocabulary.
- **FR-REC-5** A recipe carries one free-text notes field — in the pilot the home for
  preparation steps, techniques, glassware, and garnish, all unformalized.
- **FR-REC-6** A "made it" action stamps the current date and increments a times-made
  counter; the recipe shows both.
- **FR-REC-7** The recipe view can scale ingredient amounts ×2/×3/×4 (display only; range
  ends scale together).

### Vocabularies

- **FR-VOC-1** Ingredients and tags can be added, renamed (propagates everywhere), and
  deleted; deletion is blocked while any recipe references the entry.
- **FR-VOC-2** An ingredient can be flagged as a base spirit; the flag can be cleared.

### Inventory

- **FR-INV-1** The inventory screen lists all ingredients with their stock level,
  searchable by name.
- **FR-INV-2** Stock level changes with a single-tap toggle per ingredient.

### Discovery

- **FR-DIS-1** The recipe list shows each recipe's availability state at a glance;
  makeable-low is visually distinct from makeable. The recipe view marks each ingredient
  line that is running low or out.
- **FR-DIS-2** Recipes are searchable by name.
- **FR-DIS-3** The list can be filtered by tag(s), by ingredient(s) — any ingredient,
  not only base spirits — and by availability state; filters combine.
- **FR-DIS-4** Recipes can be browsed grouped by base spirit. A recipe appears under every
  base spirit it contains; recipes with none form a single ungrouped section at the end of
  the view.
- **FR-DIS-5** A random-pick action suggests one can-make recipe, respecting active
  filters.
- **FR-DIS-6** The shopping optimizer takes a purchase budget **N** (selectable 1–3) and
  evaluates combinations of up to N out-of-stock ingredients, reporting for each
  combination the recipes that would become can-make, ranked by that count.
  Combinations that unlock nothing are not shown.
- **FR-DIS-7** The shopping optimizer separately lists running-low ingredients as restock
  reminders.

### Settings

- **FR-SET-1** A global ratio defines how many ml one part is. A display toggle switches
  part-based amounts between parts and ml; other units always display as entered.

### Data exchange

- **FR-DAT-1** A single action exports all data (vocabularies, base-spirit flags, stock
  levels, recipes with made-history, settings) to one text file that can be moved
  off-device through the platform's normal file sharing.
- **FR-DAT-2** The export file is human-readable and self-describing — its structure is
  understandable and editable without the app, by a person or an AI assistant — and it
  carries a format version.
- **FR-DAT-3** A single action imports such a file, **replacing the entire database** with
  its contents. Import requires explicit confirmation and automatically exports the
  current state beforehand, so the previous state is recoverable.
- **FR-DAT-4** Import validates the file before applying it. On any structural or
  referential error — unknown ingredient reference, duplicate name, malformed amount,
  unsupported format version — nothing is changed and the app reports what is wrong and
  where.
- **FR-DAT-5** Export and import round-trip losslessly: exporting, importing that
  unmodified file, and exporting again yields identical content.

## Non-functional requirements

- **NFR-1** Phone-only UI; the frequent actions (look up a recipe, toggle stock, "made
  it") take no more than a few taps.
- **NFR-2** Instant feel with a collection of several hundred recipes — no perceptible
  lag in lists, search, filters, or the shopping optimizer at N = 3.
- **NFR-3** Single user, no account or login.
- **NFR-4** Fully offline-capable: every feature works with no network connectivity.

## Out of pilot scope

Recorded for later; ordering undecided (see
[vision.md](vision.md#direction-beyond-the-pilot)):

- Guest access / publishing of the available list.
- PC/desktop app.
- In-app parsing of the Telegram format: any migration goes through the FR-DAT-3 import
  file, produced outside the app.
- Formalized preparation: ordered steps and a technique vocabulary, with filtering by
  technique.
- Grouping by non-base-spirit ingredients.
- Almost-makeable view (recipes missing exactly one ingredient).
- Dedicated glassware and garnish fields; a photo per recipe.
- Ingredient substitutions or hierarchy; quantity-level stock tracking.
