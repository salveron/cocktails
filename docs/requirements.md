# Requirements

Mobile app (Android), one reader per device: bars of their own to keep, others' to read (FR-BAR-1). Direction: [vision.md](vision.md).

## Concepts

| Concept | Definition |
|---|---|
| Bar | One collection — vocabularies, stock, recipes, settings — under a name. Names are labels, not identity: no two owned bars carry one, but a guest bar may (FR-BAR-1). Nothing crosses from one bar to the next (FR-BAR-1). |
| Bar mode | **owner**: the reader's, written. **guest**: another owner's, read as of its last refresh (FR-BAR-3). Either is shared on (FR-BAR-6). |
| Ingredient | Generic name ("bourbon", "lemon juice") from user-managed vocabulary (recipes, stock). Optional ingredient tags. No brands, no hierarchy. Substitution is per line, not per ingredient (FR-REC-9). |
| Base spirit | Spirit recipe is built on — marked on the recipe line, not on the entry (an ingredient is base *in a recipe* only, never by itself). Recipe may mark multiple. |
| Stock level | Per ingredient: **in stock**, **running low**, **out** (default). |
| Tag | Coloured label from user vocabulary (interest/style/category; replaces Telegram emojis). Two vocabularies: recipe tags, ingredient tags ([ADR 07](adr/07-tag-colour.md)); optional both sides. |
| Unit | What a line measures in ("part", "dash"), from a user-managed vocabulary carrying a plural each ([ADR 09](adr/09-units-are-a-vocabulary.md)); part, ml and oz are fixed members. |
| Recipe | Name + lines + tags + notes. |
| Availability | Per recipe, required lines only: **makeable** (all in), **makeable-low** (none out, ≥1 low), **missing** (≥1 out). A line stands at its best-stocked alternative (FR-REC-9). First two = **can-make**. |

Names unique within kind in one bar, ignoring case ([ADR 08](adr/08-names-ignore-case.md)). Ingredient vocabulary covers aliases too (FR-VOC-6): every spelling names one ingredient. Two tag vocabularies separate; one name may exist in both (different meanings).

## Functional requirements

### Bars

- **FR-BAR-1** The app holds any number of bars, each a collection of its own. Nothing crosses: an ingredient, tag or unit in one is unknown to the next, and a search, filter, draw or jump (FR-DIS-9) stays in the bar it started in. Owned and guest bars share one list; one bar is on show at a time, and every screen reads it. An owned bar's name is unique on the device, in any case, and refused where made. A guest bar's name labels someone else's collection and collides with nothing.
- **FR-BAR-2** An owned bar is the reader's: created empty or from a file, renamed, written to, shared (FR-BAR-6), deleted. Deletion is confirmed and the bar exported first, as replacing its contents is (FR-DAT-3).
- **FR-BAR-3** A guest bar is another owner's, added from what they shared (FR-BAR-7/8) and read as it stood at its last refresh. Everything in it is theirs; the reader adds nothing: no stock level, note or tag. Two things stay the reader's, neither a collection change: **which unit amounts read in** (FR-SET-1), a preference for reading someone else's recipes; and **what the bar is called on this device**. Both are set as on an owned bar; no refresh moves either. What a part and an ounce are worth stays the owner's. Removable at any time, touching nothing the owner holds. A device may hold guest bars and own none.
- **FR-BAR-4** A guest bar offers its recipes and ingredients as destinations only. The optimizer and all that belongs to it (FR-DIS-6, FR-DIS-7, FR-DIS-10, FR-SET-2) is absent, not empty. Reads work; writes are not offered at all: no creating, editing or deleting, no stock toggle, no vocabulary change. Availability, search, narrowings, random pick, orders, jumps (FR-DIS-9) and scaling work as on an owned bar, over the owner's recipes and stock. Export and sharing work too (FR-DAT-1, FR-BAR-6). The owner's tags, units and sizes open from Settings, read-only. A reader meeting an unfamiliar tag or unit on a recipe is owed its vocabulary: a row opening onto the owner's answer says more than one dimmed to nothing.
- **FR-BAR-5** A guest bar refreshes only from its source: a file-sent bar by being sent a newer file, a bar found nearby by asking that device again. A reader wanting the other way adds the bar again by it. Refresh is wholesale: what arrives replaces what stood, nothing merged, save the reader's two, which unit amounts read in and the bar's name here (FR-BAR-3, FR-SET-1); neither moves. The sizes and the owner's name arrive with the rest; the name is read only where a bar is founded from what arrived. Arrivals are validated as an import is (FR-DAT-4); a failure leaves the bar exactly as it was. The last refresh shows where the bar is listed; asking again is offered wherever the bar is read. Everything the app says of it, availability included, is as of the last answer. An unreachable source (no network, off the network, or withdrawn, FR-BAR-6) leaves the bar readable and says why it did not refresh. Nothing expires or empties itself; what is too old is the reader's to judge.
- **FR-BAR-6** Each bar is shared separately, by either or both ways below: a guest bar as an owned one, a guest already holding what each way would carry (FR-BAR-4). A bar is shared whole or not at all; sharing one says nothing about the rest. Whichever way it travels, a guest reads the same thing (FR-BAR-3), as of the last time the sharer's own copy arrived. The sharer sees what they share and, where a way can name its guests, to whom; they may withdraw it, which ends refreshes and nothing else. A guest keeps what they hold until they remove it. Sharing is not a confidentiality control; a bar shared is a bar given.
- **FR-BAR-7** By file: the owner's export (FR-DAT-1) is added as a guest bar, not imported into an owned one (FR-DAT-3). One file, two destinations, the reader's to choose. Needs no network; offers no withdrawal.
- **FR-BAR-8** Over the LAN: a reader offers a bar, owned or a guest's, to devices on their network; a guest finds it there, adds it, and refreshes it while both are on that network. Needs no account (NFR-3).

### Recipes

- **FR-REC-1** Create, edit and delete recipes through structured forms.
- **FR-REC-2** Ingredient line: amount + unit + ingredient. Unit from FR-VOC-5; **part** default, omittable. Amount may be range ("1.5–2"); plural for amounts ≠ 1. ≥1 non-optional line required.
- **FR-REC-3** Line may be optional: shown, but excluded from availability and from the optimizer unless the reader shops for optional ingredients too (FR-SET-2).
- **FR-REC-4** A recipe carries any number of tags from the tag vocabulary.
- **FR-REC-5** A recipe carries one free-text notes field: the home for preparation steps, techniques, glassware and garnish, all unformalized.
- **FR-REC-7** Recipe view scales ×2/×3/×4 and reads one open recipe in another unit without changing the global toggle (FR-SET-1). Display only; range ends scale together; forgotten on close.
- **FR-REC-8** Line may mark as base spirit (clearable). Base and optional are mutually exclusive.
- **FR-REC-9** Line may offer alternatives: ingredients interchangeable *in that recipe* ([ADR 11](adr/11-substitutions-on-the-line.md)). One amount, unit and mark govern the group. Any one on hand makes the line; it is missing only when all are out. Cards read them as prose, dimming what the bar lacks while it holds something.

FR-REC-6 held "made it" and the history it stamped, both dropped from the product; its number stays empty so no reference to it can mean two things.

### Vocabularies

- **FR-VOC-1** Add, rename (propagates) and delete ingredients and tags; deletion blocked while referenced. Ingredient entry includes aliases (FR-VOC-6), settled in the same edit.
- **FR-VOC-3** Every tag carries a colour from a fixed palette: chosen on create, changeable, shown everywhere. The palette holds no green/amber/red ([ADR 07](adr/07-tag-colour.md)).
- **FR-VOC-4** Ingredients take tags from their own vocabulary, separate from recipe tags; neither kind is offered on the other. Both are managed on one screen, a tab each.
- **FR-VOC-5** Measurement units are a vocabulary of their own ([ADR 09](adr/09-units-are-a-vocabulary.md)), managed from Settings: add; rename (propagates to every line); delete (blocked while a line uses it); a plural per unit, left empty where it reads like the name ("ml", "oz"). Seeded with part, ml, oz, dash, barspoon, drop, piece. **part**, **ml** and **oz** cannot be renamed or deleted (FR-SET-1, [ADR 17](adr/17-the-fixed-units-interconvert.md)); their plurals stay editable.

- **FR-VOC-6** An ingredient answers to multiple names ([ADR 10](adr/10-ingredient-aliases.md)): aliases are entered with it, resolved wherever names resolve (recipe line, search, import). References are stored under the entry's own name only. No commas in aliases.

FR-VOC-2 left for FR-REC-8 in [ADR 06](adr/06-base-spirit-on-the-line.md); its number stays empty so no reference to it can mean two things.

### Ingredients

- **FR-ING-1** Ingredients screen lists all ingredients with stock level, searchable by any name (FR-VOC-6); each row reads under the entry's own name.
- **FR-ING-2** Stock level toggles with a single tap per ingredient.
- **FR-ING-3** Ingredients screen shows ingredient tags in colour and can filter by them (combines with name search).

### Discovery

- **FR-DIS-1** Recipe list shows availability at a glance (makeable-low distinct from makeable). Recipe view marks each line running low or out.
- **FR-DIS-2** Recipes searchable by name and by the ingredients they use, in any spelling (FR-VOC-6); the card still reads under the recipe's own name.
- **FR-DIS-3** Recipe list filterable by tags, combining with search (FR-ING-3's idiom on the other list). Availability is not a filter: the availability order (FR-DIS-8) puts the makeable first.
- **FR-DIS-4** Recipe list narrowable by base spirit ([ADR 12](adr/12-base-spirit-narrows.md)): one spirit at a time, matching any alternative of any base line (ADR 11). *No base* is a choice of its own, reaching the unmarked. Combines with search and the tag filter.
- **FR-DIS-5** Random pick draws one recipe the bar can make now (low counts, missing does not) from whatever the list shows, so search, tag and base picks hold. It opens that recipe alone, on screen; a second draw moves off the one standing while another can be made. If none is makeable, it says so rather than doing nothing.
- **FR-DIS-6** Optimizer: budget **N** (1–3). Evaluates ≤N ingredient combos drawn from what recipes are short of; reports recipes becoming can-make, ranked by count, then by fewest ingredients. Hidden: zero-yield combos, and any combo unlocking no more than a smaller one inside it. A substitution group counts as satisfied by any one purchase (FR-REC-9). Only the best few of each size are offered ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)); how few is the reader's to raise (FR-SET-2).
- **FR-DIS-7** What counts as short is the reader's to say, through one switch ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)). Off: only out-of-stock counts, so the bar can make what it is merely low on. On: anything short of full stock counts, so low ingredients are bought with missing ones and the goal is ready, not merely makeable. The optimizer keeps no separate restock list. The switch's starting position is the reader's to set (FR-SET-2).
- **FR-DIS-8** Lists (recipes, ingredients, tags) sort by name or by signal (availability, stock, colour). Picking the current order reverses it. Defaults: recipes by availability, ingredients by stock, tags by name (not persisted). Rows stay stable during edit.
- **FR-DIS-9** A name on one destination reaches its own row on another ([ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)): a basket's recipes open on Recipes; a basket's or a recipe line's ingredients open on Ingredients. One tap, with nothing marking the name as a way out. The row arrives open and alone where its list expands, revealed as a random pick is (FR-DIS-5), with every narrowing (search, tags, base, order) cleared first: a reader who named a row asked to see it, not to be told why they cannot. A line naming an ingredient by any spelling reaches it under the vocabulary's own name (FR-VOC-6); each alternative of a substitution group is its own target (FR-REC-9). Back undoes a jump, and a chain of them one at a time; a destination the reader chose clears the way back.
- **FR-DIS-10** Shopping baskets answer to recipe tag (FR-DIS-3's idiom on the optimizer's answers, combining with the budget and the reading of short), one of two ways the reader picks (FR-SET-2, [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)). **Sifting**: a basket is kept where each picked tag is worn by some recipe it unlocks, not necessarily the same one. Only the answer narrows, not the search: a basket keeps its rank among all of its size, so the numbering on show gaps. **Aiming**: the picks say what the search is *for*; a basket ranks by how many of the recipes it unlocks wear any pick. Picking one asks for the baskets unlocking most of that category, drops any unlocking none, and keeps the numbering unbroken. Either way a basket names every recipe it unlocks and marks each with the picks that recipe answers; one answering none is marked with nothing.

### Settings

- **FR-SET-1** One global unit, picked from the fixed three, and a ratio per convertible one ([ADR 17](adr/17-the-fixed-units-interconvert.md)): a line measured in part, ml or oz reads in the one picked; anything else displays as entered. What a part and an ounce are worth is set per bar, by the reader (FR-BAR-1). On a guest bar the unit is the reader's and outlasts refreshes; the sizes are the owner's and arrive with the bar (FR-BAR-3, FR-BAR-5). Display only; nothing converted is written. One open recipe can read otherwise without moving the global (FR-REC-7).
- **FR-SET-2** The reader sets what the optimizer is asked and what its screen opens on, per bar and never in the file (FR-BAR-1, [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)): which of FR-DIS-10's two readings a tag pick carries, how many baskets of each size are offered (FR-DIS-6), and whether an optional line is worth shopping for (FR-REC-3). The budget and the reading of short (FR-DIS-6, FR-DIS-7) are set here too, as the screen's starting values; its own controls move freely and nothing is written back. Absent on a guest bar (FR-BAR-4).

### Data exchange

- **FR-DAT-1** One action exports one bar (vocabularies, stock, recipes, line marks, settings) to one text file, shareable via platform file sharing. A guest bar exports as an owned one does (FR-BAR-4).
- **FR-DAT-2** Export file is human-readable and self-describing, editable without the app, by person or AI; carries a format version.
- **FR-DAT-3** One action imports a file, or a bar found on the LAN (FR-BAR-8), into an owned bar: a new one, or **replacing one that exists**, which needs explicit confirmation and auto-exports that bar's current state first (previous state recoverable). Every other bar is untouched. The same file or bar may instead be added as a guest bar (FR-BAR-7, FR-BAR-8).
- **FR-DAT-4** Import validates before applying. On a structural or referential error (unknown ingredient, duplicate name, malformed amount, unsupported version), nothing changes and the app reports what and where.
- **FR-DAT-5** Round-trip is lossless: export, import unmodified, export again; the two exports are identical.

## Non-functional requirements

- **NFR-1** Phone-only; frequent actions (look up recipe, toggle stock, reach another bar) ≤ few taps.
- **NFR-2** Hundreds of recipes per bar and tens of bars: instant, no perceptible lag in lists, search, filters, the optimizer at N=3, or reaching another bar. A refresh never holds up the bar on show.
- **NFR-3** One reader per device, and no account for being one: keeping bars, exchanging files and sharing over the LAN ask for none.
- **NFR-4** Offline but for refreshes: every bar the device holds stays readable with no network, owned ones whole and guest ones as of their last refresh (FR-BAR-5). Only reaching a source needs one.
- **NFR-5** Nothing of a bar leaves the device unless its reader shared that bar; a device sharing nothing announces nothing.

## Out of scope

See [vision.md](vision.md#future-directions):

- PC/desktop app.
- Sharing over the cloud.
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
