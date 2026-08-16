# Requirements

Mobile app (Android), one reader per device: bars of their own to keep, others' to read (FR-BAR-1).
Direction: [vision.md](vision.md).

## Concepts

| Concept | Definition |
|---|---|
| Bar | One collection — vocabularies, stock, recipes, settings — under a name. Names are labels, not identity: two bars may carry one. Nothing crosses from one bar to the next (FR-BAR-1). |
| Bar mode | **owner**: the reader's, written and shared. **guest**: another owner's, read as of its last refresh (FR-BAR-3). |
| Ingredient | Generic name ("bourbon", "lemon juice") from user-managed vocabulary (recipes, stock). Optional ingredient tags. No brands, no hierarchy. Substitution is per line, not per ingredient (FR-REC-9). |
| Base spirit | Spirit recipe is built on — marked on the recipe line, not on the entry (an ingredient is base *in a recipe* only, never by itself). Recipe may mark multiple. |
| Stock level | Per ingredient: **in stock**, **running low**, **out** (default). |
| Tag | Coloured label from user vocabulary (interest/style/category; replaces Telegram emojis). Two vocabularies: recipe tags, ingredient tags ([ADR 07](adr/07-tag-colour.md)); optional both sides. |
| Unit | What a line measures in ("part", "dash"), from a user-managed vocabulary carrying a plural each ([ADR 09](adr/09-units-are-a-vocabulary.md)); part and ml are fixed members. |
| Recipe | Name + lines + tags + notes. |
| Availability | Per recipe, required lines only: **makeable** (all in), **makeable-low** (none out, ≥1 low), **missing** (≥1 out). A line stands at its best-stocked alternative (FR-REC-9). First two = **can-make**. |

Names unique within kind in one bar, ignoring case ([ADR 08](adr/08-names-ignore-case.md)). 
Ingredient vocabulary covers aliases too (FR-VOC-6): every spelling names one ingredient. 
Two tag vocabularies separate; one name may exist in both (different meanings).

## Functional requirements

### Bars

- **FR-BAR-1** The app holds any number of bars, each a collection of its own. Nothing crosses 
  between them: an ingredient, a tag or a unit in one is unknown to the next, and a search, a filter, a 
  draw or a jump (FR-DIS-9) reaches no further than the bar it started in. One list holds them all, 
  owned and guest alike; one bar is on show at a time and every screen reads that one.
- **FR-BAR-2** An owned bar is the reader's: created empty or from a file, renamed, written to, 
  shared (FR-BAR-6), and deleted — deletion confirmed and the bar exported beforehand, as replacing 
  its contents is (FR-DAT-3).
- **FR-BAR-3** A guest bar is another owner's, added from what they shared (FR-BAR-7/8/9) and read 
  as it stood at its last refresh. Everything in it is theirs — recipes, stock, tags, units — and 
  the reader adds nothing of their own: not a stock level, not a note, not a tag. Two things stay 
  the reader's, neither of them a change to the collection: **which unit amounts read in** 
  (FR-SET-1), a preference for reading someone else's recipes, and **what the bar is called on this 
  device**, a label on the shelf it stands on. Both are theirs to set on a guest bar exactly as on 
  one of their own, and no refresh moves either. What a part and an ounce are worth there stays the 
  owner's — the recipes were written against those. The bar is removed whenever they like, touching 
  nothing the owner holds. A device may hold guest bars and own none.
- **FR-BAR-4** A guest bar offers its recipes and its ingredients as destinations and nothing else: 
  the shopping optimizer and all that belongs to it (FR-DIS-6, FR-DIS-7, FR-DIS-10, FR-SET-2) is 
  absent there rather than empty. Everywhere in it, everything that reads works and nothing that 
  writes exists — no creating, editing or deleting, no stock toggle, no vocabulary change, and none 
  of them offered rather than refused. Availability, search, the tag and base narrowings, the random 
  pick, the orders, the jumps between the two (FR-DIS-9) and scaling all work as on an owned bar, 
  over the owner's recipes and the owner's stock. Export works too (FR-DAT-1) — a guest already 
  holds what the file would carry.
  The owner's vocabularies and sizes read on those same terms: the tags, the units and what a part 
  and an ounce are worth all open from Settings, and none of them can be touched. A reader meeting 
  an unfamiliar tag on a recipe, or a unit a line measures in, is owed the vocabulary behind it — 
  reading is what a guest bar is for, and a row opening onto the owner's answer says more than one 
  dimmed to nothing.
- **FR-BAR-5** A guest bar refreshes from the source it was added from, wholesale: what arrives 
  replaces what stood and nothing is merged, save the two that are the reader's — which unit amounts 
  read in and what the bar is called here (FR-BAR-3, FR-SET-1). Neither moves; the sizes behind the 
  unit and the owner's own name for the bar arrive with everything else, and that name is read only 
  where a bar is founded from what arrived. What arrives is judged first as an imported file is 
  (FR-DAT-4) — what fails to pass leaves the bar exactly as it was. When it last refreshed is 
  readable where its bar is listed, and asking again is offered wherever the bar is read; everything 
  the app says of it, availability included, is as of the last answer. A source that cannot be 
  reached — no network, off the network, or withdrawn (FR-BAR-6) — leaves the bar readable at that 
  moment and says why it did not refresh. Nothing expires and nothing empties itself: what is too 
  old is the reader's to judge.
- **FR-BAR-6** Each owned bar is shared separately, by any of the three ways below and any 
  combination of them; a bar is shared whole or not at all, and sharing one says nothing about the 
  rest. Whichever way it travels a guest reads the same thing (FR-BAR-3). The owner sees what they 
  share and, where a way can name its guests, to whom, and may withdraw it — which ends refreshes 
  and nothing else: what a guest already holds stays theirs until they remove it. Sharing is not a 
  confidentiality control; a bar shared is a bar given.
- **FR-BAR-7** By file — the export a bar's owner sends (FR-DAT-1) is added by the guest as a guest 
  bar rather than imported into one of their own (FR-DAT-3): one file, two destinations, the 
  reader's to choose. Refreshing is being sent a newer one. Asks nothing of a network and offers no 
  withdrawal.
- **FR-BAR-8** Over the LAN — an owner offers a bar to the devices sharing their network; a guest 
  finds it there, adds it, and refreshes it while both are on that network. Asks nothing of an 
  account (NFR-3).
- **FR-BAR-9** Over the cloud — an owner offers a bar to guests they name, who add it and refresh it 
  from anywhere. The one way asking an identity, of those two sides and of no one else (NFR-3).

### Recipes

- **FR-REC-1** Create, edit, and delete recipes through structured forms.
- **FR-REC-2** Ingredient line: amount + unit + ingredient. Unit from FR-VOC-5; **part** default, 
  omittable. Amount may be range ("1.5–2"); plural for amounts ≠ 1. ≥1 non-optional line required 
  (availability judges something).
- **FR-REC-3** Line may be optional: displays but excluded from availability, and from the optimizer 
  unless the reader shops for optional ingredients too (FR-SET-2).
- **FR-REC-4** A recipe carries any number of tags, chosen from the tag vocabulary.
- **FR-REC-5** A recipe carries one free-text notes field — the home for preparation steps,
  techniques, glassware, and garnish, all unformalized.
- **FR-REC-7** Recipe view scales ×2/×3/×4 and reads one open recipe in other unit without 
  global toggle change (FR-SET-1). Display-only; range ends scale together; forgotten on close.
- **FR-REC-8** Line may mark as base spirit (clearable). Base and optional mutually exclusive.
- **FR-REC-9** Line may offer alternatives — ingredients interchangeable *in that recipe* 
  ([ADR 11](adr/11-substitutions-on-the-line.md)): one amount, one unit, one mark govern the group. 
  Any one on hand makes the line; only when all are out is it missing. Cards read them as prose, 
  dimming what the bar lacks while it holds something.

FR-REC-6 held "made it" and the history it stamped, both dropped from the product; its number stays
empty so no reference to it can mean two things.

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
  part, ml, oz, dash, barspoon, drop, piece. **part**, **ml** and **oz** cannot be renamed or
  deleted: the ratios and the global unit are anchored to them (FR-SET-1,
  [ADR 17](adr/17-the-fixed-units-interconvert.md)); their plurals are editable.

- **FR-VOC-6** Ingredient answers to multiple names ([ADR 10](adr/10-ingredient-aliases.md)): 
  aliases in entry, resolved wherever names resolve (recipe line, search, import). 
  References stored under entry's own name only. No commas in aliases.

FR-VOC-2 left for FR-REC-8 in [ADR 06](adr/06-base-spirit-on-the-line.md); its number stays
empty so no reference to it can mean two things.

### Ingredients

- **FR-ING-1** Ingredients screen lists all ingredients with stock level, searchable by any name 
  (FR-VOC-6); row reads under entry's own name.
- **FR-ING-2** Stock level toggles with single tap per ingredient.
- **FR-ING-3** Ingredients screen shows ingredient tags in colour; can filter by them (combines with 
  name search).

### Discovery

- **FR-DIS-1** Recipe list shows availability at glance (makeable-low distinct from makeable). Recipe 
  view marks each line running low/out.
- **FR-DIS-2** Recipes searchable by name and by the ingredients they use — any spelling 
  (FR-VOC-6), the card still reading under the recipe's own name.
- **FR-DIS-3** Recipe list filterable by tag(s), combining with the search (FR-ING-3's idiom on 
  the other list). Availability is not a filter: the availability order (FR-DIS-8) is what puts 
  the makeable first.
- **FR-DIS-4** Recipe list narrowable by base spirit ([ADR 12](adr/12-base-spirit-narrows.md)): one 
  spirit at a time, matching any alternative of any base line (ADR 11); *no base* is a choice of its 
  own, reaching the unmarked. Combines with the search and the tag filter.
- **FR-DIS-5** Random pick draws one recipe the bar can make now — low counts, missing does not — 
  from whatever the list is showing, so the search, the tag picks and the base pick all hold. It 
  opens that recipe alone and puts it on screen; a second draw moves off the one standing while 
  another can be made. Nothing makeable among them says so rather than doing nothing.
- **FR-DIS-6** Optimizer: budget **N** (1–3); evaluates ≤N ingredient combos drawn from what 
  recipes are short of; reports recipes becoming can-make, ranked by count, then by fewest ingredients. 
  Zero-yield hidden, and so is a combo unlocking no more than a smaller one inside it — every 
  ingredient offered earns its place. A substitution group counts as satisfied by any one purchase 
  (FR-REC-9). The best few of each size are offered rather than every combo 
  ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)); how few is the reader's to raise 
  (FR-SET-2).
- **FR-DIS-7** What counts as short is the reader's to say, through one switch 
  ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)): off, only what is out of stock — 
  the bar can make what it is merely low on; on, anything short of full stock, so ingredients running 
  low are bought alongside missing ones and the goal becomes ready rather than merely makeable. 
  Being shoppable is how a low ingredient is reminded of; the optimizer keeps no separate restock 
  list. Which way the switch starts is the reader's to set (FR-SET-2).
- **FR-DIS-8** Lists (recipes, ingredients, tags) readable in multiple orders: by name, by signal 
  (availability, stock, colour). Picking current order reverses it. Default: recipes by availability, 
  ingredients by stock, tags by name (not persisted). Rows stable during edit.
- **FR-DIS-9** A name on one destination reaches its own row on another 
  ([ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)): a basket's recipes open on the 
  Recipes, a basket's ingredients and a recipe line's ingredients on the Ingredients screen. One tap, nothing marking 
  the name as a way out. The row arrives open and alone where its list expands, revealed the way a 
  random pick is (FR-DIS-5), and every narrowing in the way — search, tags, base, order — is cleared 
  first: a reader who named a row asked to see it, not to be told why they cannot. A line naming an 
  ingredient by any of its spellings reaches it under the vocabulary's own (FR-VOC-6), and each 
  alternative of a substitution group is its own target (FR-REC-9). Back undoes a jump and a chain of 
  them one at a time; a destination the reader chose themselves clears the way back.
- **FR-DIS-10** Shopping baskets answer to recipe tag — FR-DIS-3's idiom on the optimizer's answers, 
  combining with the budget and the reading of short — one of two ways, the reader's to pick 
  (FR-SET-2, [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)). **Sifting**: a basket is kept where 
  each picked tag is worn by some recipe it unlocks, not necessarily the same one, so picking one 
  shops for a category. What is narrowed is the answer, not the search behind it: a basket keeps the 
  rank it holds among all of its size, and the numbering on show gaps. **Aiming**: the picks say what 
  the search is *for*, and a basket ranks by how many of the recipes it unlocks wear any of them — so 
  picking one asks for the baskets unlocking the most of that category, one unlocking none of it is 
  gone, and the numbering runs unbroken. Either way a basket names every recipe it unlocks and marks 
  each with the picks that recipe answers, so which of them reached the basket is read rather than 
  inferred; one answering none is marked with nothing.

### Settings

- **FR-SET-1** One global unit, picked from the fixed three, and a ratio per convertible one 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)): a line measured in part, ml or oz reads in 
  the one picked; anything else displays as entered. What a part and an ounce are worth is the 
  reader's to set, and every bar carries both its own (FR-BAR-1). On a guest bar the two part 
  company: the unit is picked there as on an owned one and outlasts every refresh, where the sizes 
  are the owner's and arrive with the rest of the bar (FR-BAR-3, FR-BAR-5). Display only — nothing 
  converted is written. One open recipe reads otherwise without moving the global (FR-REC-7).
- **FR-SET-2** What the optimizer is asked, and what its screen opens on, are the reader's to set — 
  per bar and never in the file (FR-BAR-1, [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)): 
  which of FR-DIS-10's two readings a tag pick carries, how many baskets of each size are offered 
  (FR-DIS-6), and whether an optional line is worth shopping for (FR-REC-3). The budget and the 
  reading of short (FR-DIS-6, FR-DIS-7) are set here too, as the values the screen starts at — the 
  screen's own controls move freely from them and nothing is written back. Absent on a guest bar, 
  which has no optimizer to ask (FR-BAR-4).

### Data exchange

- **FR-DAT-1** Single action exports one bar (vocabularies, stock, recipes, line marks, settings) 
  to one text file; shareable via platform file sharing. A guest bar exports as an owned one does 
  (FR-BAR-4).
- **FR-DAT-2** Export file is human-readable, self-describing (editable without app, by person or AI); 
  carries format version.
- **FR-DAT-3** Single action imports a file into an owned bar — establishing a new one, or 
  **replacing one that exists**, which requires explicit confirmation and auto-exports that bar's 
  current state beforehand (previous state recoverable). Every other bar is untouched. The same file 
  may instead be added as a guest bar (FR-BAR-7).
- **FR-DAT-4** Import validates before applying. On structural/referential error (unknown ingredient, 
  duplicate name, malformed amount, unsupported version): nothing changed; app reports what and where.
- **FR-DAT-5** Export/import round-trip losslessly (export, import unmodified, export again = identical).

## Non-functional requirements

- **NFR-1** Phone-only; frequent actions (look up recipe, toggle stock, reach another bar) ≤ few taps.
- **NFR-2** Hundreds of recipes per bar and tens of bars: instant (no perceptible lag in lists, 
  search, filters, optimizer at N=3, or in reaching another bar). A refresh never holds up the bar 
  on show.
- **NFR-3** One reader per device, and no account for being one: keeping bars, exchanging files and 
  sharing over the LAN ask for none. Sharing over the cloud is the single exception (FR-BAR-9).
- **NFR-4** Offline but for refreshes: every bar the device holds stays readable with no network — 
  owned ones whole, guest ones as of their last refresh (FR-BAR-5). Only reaching a source needs one.
- **NFR-5** Nothing of a bar leaves the device unless its owner shared that bar; a device sharing 
  nothing announces nothing.

## Out of scope

See [vision.md](vision.md#future-directions):

- PC/desktop app.
- Judging one bar by another — a guest reads the owner's stock, never their own (FR-BAR-4).
- The optimizer on a guest bar — shopping answers for the bar its reader stocks (FR-BAR-4).
- Moving recipes or ingredients between bars (nothing crosses, FR-BAR-1).
- In-app Telegram parsing (migration via FR-DAT-3 outside app).
- Formalized prep (ordered steps, technique vocab, filtering).
- Search grammar for compound queries (several ingredients, logical operators).
- Non-base grouping.
- Almost-makeable view (missing exactly one ingredient).
- Glassware/garnish fields, photo per recipe.
- Ingredient hierarchy, quantity-level stock. (Per-line substitution is in: FR-REC-9.)
