# UI design

Screen/shell design. Modules [components.md](components.md), requirements [requirements.md](requirements.md).

## App shell

- **Destinations per the bar** in Material 3 `NavigationBar` (NFR-1): Recipes, Inventory and 
  Shopping on an owned bar, the first two on a guest one (FR-BAR-4). The stack is indexed by 
  position in the list that bar offers, never by the enum's own index 
  ([components.md](components.md#state-contracts)). Material wants three to five and gets two here — 
  accepted, the alternative being a destination that exists to say it is empty. Settings: app bar 
  gear (amounts, vocabularies, data exchange, [switching bars](#bars)).
- **`IndexedStack`** (keeps scroll/search). Forms/settings pushed via `Navigator`. 
  Recipe view inside list. `Navigator` 1.0, no nested routers. Each destination is told whether it is 
  the one on show — staying alive is free for two of the three, and not for the 
  [shopping screen](#shopping-screen).
- **Theme**: seed colour, platform-picked light/dark. `dimmedInk` (`onSurfaceVariant` at 60%) is 
  the one dim: a hint, so empty ≠ filled; a bottle a group offers that the bar lacks. One home, so 
  the two cannot drift.
- **A name reaches its own row on another destination** (FR-DIS-9, 
  [ADR 19](adr/19-a-destination-sends-the-reader-to-another.md)): one tap, on a basket's recipes and 
  bottles and on the bottles a recipe line names. **Nothing marks a name as a way out** — the ripple 
  under the finger is the whole of it, as the inventory row's own tap is (FR-INV-2). An arrow 
  per row was weighed and refused: the trailing slot already carries the tag dots and the stock dots, 
  and a widget repeated down every row is the clutter a per-line control was once reverted over. So 
  a run whose names lead somewhere reads exactly like one whose names do not — accepted, the two 
  runs on a basket now both leading somewhere, and the recipe card's inert parts being a measure and 
  a mark rather than a name.
- **The reader is put where they asked, not told why they cannot.** The serving screen clears every 
  narrowing first — its own tag and base picks, and the list's search and order — and opens the row 
  alone, which is the [random pick](#recipes-screen)'s arrival exactly, wash and all. A jump is thus 
  the one thing that clears a search, where an edit renaming an entry out of one leaves it standing: 
  an edit is the reader working *within* the query, a jump is them naming a row outside it.
- **Back undoes a jump**, one at a time down a chain of them, and leaves the app once there is none 
  left. A bottom-bar tap clears the way back — a destination the reader chose has nothing to return 
  *from*. What comes back is their place, not their narrowings: the destinations are all alive, so a 
  basket is found open where it was, but a search a jump cleared stays cleared.
- **`CollectionView`**: only reader of `collectionProvider`'s `AsyncValue`. Screens never see loading/failure.
- **`EmptyState`**: icon, title, fill hint.
- **`StartupIssues`**: displays FR-DAT-4 problems above all screens (dismissable).

## Bars

Behind the gear, **Switch bar…** — a row that travels. Not the app bar's own slot, not a drawer, not 
a fourth destination: switching is rarer than reaching a recipe and rarer than the gear itself, so it 
sits where the app already keeps what is not a destination, and the bottom bar goes on meaning what 
it has always meant.

- **The app opens on the bar it was left in**, `openId` outliving the run 
  ([ADR 20](adr/20-the-app-holds-many-bars.md)), so a reader who keeps one bar never comes here 
  twice. **An empty shelf is the one time this screen is home**: there is no bar to open, so the app 
  opens on the list, and its empty state offers the two ways to a first one — a new bar, or a file 
  (FR-BAR-2, FR-BAR-7).
- **One card a bar**, tapped to switch and popped on the way: the name, the mode, and for a guest the 
  source it came from and when it last answered. Rename, share, refresh and delete sit behind its ⋮, 
  so the screen that lists bars is the screen that manages them and no second place holds half of it.
- **The bar's name leads the title** — "Home bar's Recipes", "Anna's Ingredients". The destination 
  named alone was what the app bar carried while there was one collection; with several it answers 
  the smaller question. Nothing else marks the bar: no subtitle, no strip, the title standing on 
  every screen already.
- **A guest bar is told by the bottom bar's shape**, not by a badge (FR-BAR-4). Two destinations 
  where an owned bar has three is a difference read at a glance and read from the row the reader 
  navigates by, which is where they are looking in any case.
- **Swipe down to refresh** (FR-BAR-5), on a guest bar's lists and nowhere else — the standard 
  gesture for "ask the source again", and the reason the shell carries no refresh control and no 
  as-of. How stale a bar is reads on the card that lists it; on the bar itself, being one gesture 
  from current is worth more than being told how far from it you are.

## Searchable lists

`SearchField` pinned above (NFR-1). `matchesQuery`: case-insensitive, anywhere, no surrounding space.
Applies to inventory (FR-INV-1) and recipes (FR-DIS-2) identically. Entries answering multiple names 
(FR-VOC-6): match on any, show under entry's name — a recipe answers to its bottles' spellings too, 
so a query reaches what it is built from. Hence "answers to", not "is called", when nothing matches. 
Filter and order alike are widget state, never persisted, never on the collection's side.

**A narrowing changed is read from the top** — a search typed, a tag or a base picked, another order 
chosen. What is on show is then a different list, so it stands at its first row; the collection 
changing underneath (a rename, a stamp, an entry gone) moves nothing. The two are told apart by what 
is *picked*, not by what is on show, since only the first is the reader's own act. It re-anchors the 
scroller besides ([ADR 13](adr/13-lists-scroll-by-index.md)), which is what keeps a narrowed list off 
the offset the wider one stood at — where it would land mid-results, then jerk straight later, when 
an unrelated card is expanded.

Orders behind one icon (FR-DIS-8): chip row shows offerings + current (direction). Picking current 
reverses list. No separate Z→A/missing-first chips. Tie-break: name. Rows stable during edit; 
list out-of-order until touched after external change. Not persisted.

A list may also offer a **draw** over the rows on show — a button standing over it, answering with 
the name of a row to put on screen. Only the recipes offer one (FR-DIS-5). The list scrolls to it by 
index ([ADR 13](adr/13-lists-scroll-by-index.md)), which is why the draw is the list's rather than 
the screen's: the search never leaves the list, so no narrowing has to be named twice, and the screen 
learns nothing about where a row stands.

## Vocabulary editing

`VocabularyList`: search, sort orders, three faces, add button. Screen provides row display, 
tap handler, sort key. Inventory: stock chip + stock order. Tags: tag + palette order. 
Optional filter row narrows by custom predicate.

Same two dialogs for ingredients and tags:

- **Entry dialog**: one field (new/edit). Takes `validate…` function; shows first issue under 
  owning field (empty path = name; `aliases` = aliases). Save blocked until clear. 
  New tag opens on first unused colour.
- **Aliases** (FR-VOC-6): second plain field, always shown. Comma-separated; trimmed, blanks 
  dropped. Displayed only here ([ADR 10](adr/10-ingredient-aliases.md)).
- **Selection**: tick in swatch or ring on chip (transparent unpicked).
- **Delete dialog**: confirmation if unreferenced; refusal listing users (FR-VOC-1). 
  Same dialog for missing-ingredient offer and discard prompt.

Add via `FloatingActionButton`. Empty state prefills query (search miss → one tap). 
Successful add clears search. Recipes add pushes [recipe form](#recipe-form).

## Recipes screen

- **Card in-place expansion** (single tap, NFR-1). Independent, collapse same tap. 
  Two open side-by-side, scroll stable.
- **Compact**: name + tags (dots, inventory idiom) + ingredient names (`·`-joined, ellipsized), 
  a group reading as prose within one slot. Amounts on expand.
- **Expanded**: tags as chips, lines as `formatRecipeLine` writes, notes. Empty sections absent.
- **Edit/delete** behind ⋮ (menu pairs with availability chip). Delete confirms. 
  Rename keeps card open.
- **Filter row** under search: the base chip, then recipe tags as chips — the inventory's row 
  exactly (FR-DIS-3, `tagFilter`, which takes the base chip as its leading filter so one scroller 
  carries both and one message joins their reasons). Narrows to recipes wearing *all* picked tags; 
  combines with search. Add clears every pick. Availability filters through the order it opens in, 
  not a chip.
- **Base chip** (FR-DIS-4, [ADR 12](adr/12-base-spirit-narrows.md)): reads `Base: Any` / `Base: Gin` 
  / `Base: None` — the dimension named, so it cannot be read as a tag called "Base", and the bottle 
  in the vocabulary's own spelling. Tapping opens **Any base**, **No base**, then every base spirit 
  A→Z, the one in force ticked. `neutralSwatch`, since a bottle's name is neither tag nor signal; 
  the arrow says the tap opens a menu. Ringed like a picked tag while it narrows (**Any base** 
  alone is unringed), and ringed transparent otherwise — so it keeps a tag chip's height and 
  spacing either way, `chipRadius` rounding both alike. Absent where nothing marks a base; a pick 
  gone stale opens the list rather than emptying it, as the tag row does.
- **Random pick** (FR-DIS-5): a pair of dice (Font Awesome's `dice` — a roll reads as dice being 
  thrown, and the shipped font carries only single dice, which read as domino tiles at this size; 
  ADR 14) above the add button, the two alike in size so neither reads as the lesser reach. It 
  draws one recipe you can make from what is on show (Ready or Low), so the search, the tag picks 
  and the base pick already hold; shuts every open card, opens that one and scrolls to it. A second 
  roll moves off the one standing while another can be made, so rolling again always answers. 
  Absent where nothing is on show; rows on show but none makeable answers with a snackbar rather 
  than silence.
- **The wash** on the drawn card: its fill starts at `secondaryContainer` and settles back to where 
  every other card rests, over 700ms, easing out — the pick saying which one it is once the scroll 
  has stopped, since a list that merely stopped moving does not say what it stopped *for*. Colour 
  alone, and only the fill: a row changing height would fire the very measurement the reveal waits 
  on (ADR 13). It runs once and is let go, so a row scrolled away and back does not say it again.
- **Scale & convert** behind ⋮ (expanded cards only, FR-REC-7): factor ×1–×4, and one of the three 
  fixed units for this card alone (FR-SET-1). Every card rests at ×1 in the unit the settings name 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)), and picking that again cancels — so under an 
  ml reader it is "(part)" that marks a card as read otherwise.
- **Display-only transforms**: name row shows "(×2, ml)", measures italic. No persistence; 
  dies with card.
- **Availability chip** (FR-DIS-1): "Ready"/"Low"/"Missing" (traffic light, no count). 
  Trailing slot outside expanding body. List opens in this order (FR-DIS-8).
- **Line marks**: stock dot after line if the line is low/out (tooltip shows level); no dot = in 
  stock. Optional lines dotted too (dot + "(optional)" together).
- **Each bottle a line names reaches the Inventory** (FR-DIS-9): the name alone is the target, so a 
  substitution group offers one per alternative where a whole-line tap could only have named the 
  first. The measure, the "or" and the "(optional)" answer nothing — the one place in the app where 
  half a line responds, which is what naming a *row* rather than a line costs.
- **Substitution groups** (FR-REC-9, [ADR 11](adr/11-substitutions-on-the-line.md)): read as prose 
  — "cognac or vodka" — open and shut alike, where the file writes `/`. Bottles the bar lacks fall 
  to `dimmedInk`, but only while it holds one; a group short of everything dims nothing and takes 
  the dot, so the dot keeps meaning "this line is the problem". Dot follows the group's best 
  (`stockOfLine`). The "or" is italic on the open card — two letters between two names need it. 
  Italic thus does double duty with the scaled measure below; position tells them apart, and the 
  name row's "(×2, ml)" is what actually announces a transformed card.
## Recipe form

Create/edit: pushed page, Save in app bar. Mirrors file order (name, lines, tags, notes).

- **Line fields** (FR-REC-2/3/8/9): grammar like file ("1.5 part gin (base)", "1 part gin / vodka"). 
  `tryParseRecipeLine` on change; problem under field. Forgiving: unit omittable, plural accepted, 
  case/alias resolved, `/` spaced or not. Form saves as typed; line lands under vocabulary's 
  spelling. Fields show `/`, cards show "or" — the form is where a line is re-edited.
- **Self-growing lines**: empty line at bottom; typing adds next; erasing spare removes it. 
  Empty dropped on save. No drag/delete button.
- **Save blocked** until name passes live checks and all lines parse. `validateRecipe` checks 
  whole on save. Per-field issues under field; list-level refusals via snackbar.
- **Unknown ingredients**: if only issue, confirm to add (out, untagged). Aliases resolve first 
  (no near-duplicates offered). A group offers only the alternatives no bottle answers to.
- **Tags**: chip picker (recipe vocab). **Notes**: multiline field, opens one line tall.
- **Back**: untouched pops silently; dirty asks to discard. Whole entry → one disk save.

## Inventory screen

- **Opens on stock (fullest first)** (FR-DIS-8). One row per ingredient on filled card. 
  Rows stable during edit.
- **Stock chip** (green/amber/red with words; no hue decode). Fixed hues.
- **Row tap** cycles stock `in → low → out → in` (FR-INV-2).
- **Edit/delete** behind ⋮. Edit dialog: name, aliases, tags. Whole entry → one save. 
  New bottle starts out.
- **Tags as dots** after name (vocab order; must match legend colour).
- **Filter row** (legend): ingredient tags as chips (horizontal scroll). Picking narrows to 
  bottles with *all* picked tags (combines with name search, FR-INV-3). Add clears picks.
- **Three faces**: empty, no match, list (third names narrowing source).

## Shopping screen

- **Budget picks exactly N** (FR-DIS-6): `SegmentedButton` 1/2/3, reading the baskets of *that* many 
  bottles rather than up to that many. The best few of each size come off one search 
  ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)), so a one-bottle win is never buried 
  under the three-bottle baskets that almost always unlock more.
- **One search, not three**: the screen searches once at the largest budget and reads a size off the 
  answer, moving between sizes costing nothing. Why that is the same answer: 
  [components.md](components.md#computations).
- **"Low too" switch** (FR-DIS-7, [ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)): what 
  counts as short. Off, only what is out of stock; on, anything short of full stock, so the bottles 
  running low are bought beside the missing ones. Two words on the switch, the sentence in its tooltip 
  — the label is what a reader scans, not what teaches them.
- **The tags say what to shop for** (FR-DIS-10): the [recipes screen](#recipes-screen)'s chip row, the 
  same `tagFilter`, on its own row under the controls — a basket answering to the tags of every recipe 
  it unlocks, so a pick keeps only the baskets shopping for that category. Under the controls rather 
  than among them: the budget and the switch say how much to buy, the chips what for, and the `Wrap` 
  holding the two is already what keeps them off the edge. Always on show rather than behind an icon — 
  a narrowing that gaps the numbering has to be readable beside the gap it makes.
- **A basket is ranked among all of its size**, so a narrowed screen reads `#1, #4, #7`. The number 
  *is* the ranking, so renumbering what is on show would call the fourth-best basket the best; the gap 
  is what says a filter is doing something.
- **The tags narrow what was found, not what is looked for.** The search is not re-run per pick, it 
  being the screen's one expensive computation — so a basket the optimizer already cut for ranking 
  poorly overall never reaches the chips, and a niche tag can come up empty while a good basket for it 
  exists ([ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)). Narrowing the *recipes* the 
  search runs over would answer better, at a search per pick and a renumbering of every basket.
- **Both controls on one row** above the list, and a `Wrap` rather than a `Row`: a phone too narrow, 
  or a reader's larger text, drops the switch to a second line instead of carrying it off the edge. 
  Segments sit at 48dp — a touch target's own floor, and `visualDensity` is what reaches them, 
  `minimumSize` being dropped on the way to a segment.
- **Cards expand in place**, the [recipes screen](#recipes-screen)'s idiom: the title is 
  `Shopping Cart #N` — where the basket ranks, `#1` being the best at the size in force — the bottles 
  the subtitle, `+`-joined and clipped, trailing the count in `onSurfaceVariant`. A number is no 
  signal, so no chip; and the headline being the rank, the count beside it is read as the ranking 
  rather than as a name no two of which are the same length.
- **A basket is its bottles** (FR-DIS-6) **and the rank is only where it stands**, so an open card is 
  remembered under the bottles: the budget moved away and back finds it open where it was, and `#1` at 
  another size is another basket, shut.
- **Nothing is named twice.** Open, the subtitle goes and the bottles read in the body instead — 
  labelled `Ingredients`, each at the level it stands at — beside `Unlocks` and every recipe in full. 
  Two labelled runs of bullets, which is how a card body names things on the [import review](#data) 
  and the same `BulletRuns` widget. `Buy` was weighed as the first label and refused: the controls row 
  above already spends that word on the budget.
- **An open basket marks the picks it answered** (FR-DIS-10): each recipe under `Unlocks` wears, as 
  dots in vocabulary order, the picked tags it carries — `TagDots`, the same run a list row wears, so 
  a dot and the chip it answers to are one colour. Only the picked ones: a dot here answers the single 
  question a narrowed screen raises, so a recipe showing none rode along on the ones that do, and 
  nothing is marked at all while nothing narrows. Every tag a recipe wears was weighed and refused — 
  that is the recipe list's reading, where the dots are the row's own subject; on a basket it would 
  bury the answer among tags that had nothing to do with why the basket is here.
- **Every name on an open basket leads somewhere** (FR-DIS-9): a bottle to the Inventory, a recipe to 
  the Recipes, one tap either way. The card behind stays open and keeps its budget, so back lands on 
  the basket the reader left rather than on a screen rebuilt from nothing.
- **The stock dots are what the switch is worth reading**: restocking mixes a bottle merely running low 
  with one there is none of, and the open card is where that is told. Plain, they all read out, which 
  is the same thing a recipe card says about a line it is short of.
- **Three empty states**, told apart by why there is nothing: no recipes to be short of; nothing short 
  at all (worded by the reading in force); or nothing on show, which is the only one with somewhere to 
  go — it offers the smallest size that answers *under the tags in force*, and moves there, and offers 
  nothing where no size does. With a tag picked that last one blames the picks rather than the size, 
  joining its reasons the way `_NoMatch` does on the other lists: the size is then not what emptied 
  the screen, and saying so would be false.
- **Off screen it does not search.** The shell tells each destination whether it is the one on show; 
  this screen watches nothing while it is not. The optimizer is the one computation that must not run 
  for a reader who is not there ([components.md](components.md#state-contracts)).

## Tags screen

Behind Settings. Tab per vocab (Recipe, Ingredient, FR-VOC-4). Tag drawn as chip 
(name on full-strength colour). Opens A→Z; palette order also offered (FR-DIS-8).
- **Row tap** opens edit (name, colour together, one save). Neither tab knows its kind 
  (domain tells via `TagKind`).

## Units

Behind Settings. Form, not `VocabularyList` (no search/sort). Rows editable in place 
(name, plural). One Save for screen. Rename propagates to lines.
- **Self-growing**: empty row at bottom; typing adds next; erasing spare removes it.
- **`part`/`ml`/`oz` locked** (the ratios and the global unit anchored, ADR 09/17); plurals still 
  editable.
- **Delete blocked** while lines use it (names recipes). Unused row goes on save; 
  discard restores.
- **Validation** same as import: errors under field, Save blocked.

## Amounts

Behind Settings, below [Units](#units) — what those three fixed names are worth (FR-SET-1). The 
Units screen's shape and its `EditorScaffold`, so Save and the discard prompt read alike on both: 
one dimmed sentence, the global unit, then two rows. Nothing else.

- **The bar's unit**: `SegmentedButton` over the fixed three — the recipe card's own picker, since 
  it is the same choice made for the whole bar rather than for one card. One Save, two writes: the 
  sizes are the owner's and go to the collection, the pick is the reader's and goes to the bar's 
  record ([ADR 21](adr/21-the-file-carries-one-bar.md)), so two bars may read in different units.
- **Two rows, a sentence each** — "1 part = [30] ml", the number their only field. The global unit 
  leads, *except* ml: "1 ml = 0.0333 part" is a number no one reads or types back, so under ml each 
  row leads with the unit it sizes — which is the pair the file itself stores, making that pick a 
  plain view of storage. The three parts are columns, not a written width, so the fields stand in 
  line whatever the units are spelled like and a reader's larger text widens the sentence rather 
  than wrapping it.
- **A row owns one size**: the first what a part is worth, the second what an ounce is. So 
  redefining the part leaves the ounce where it stood ([ADR 17](adr/17-the-fixed-units-interconvert.md) 
  — a part is a preference, an ounce a constant), and the row reading across both follows instead. 
  A pick rewrites both readings and no size, so switching round the three cannot drift them.
- **Readings round to four decimals**, enough to spell a US ounce exactly. Only the reading rounds: 
  a row left alone writes nothing back, so a stored size keeps every digit it had.
- **Validation** same as import, plus what a size cannot say for itself: a ratio must be a number 
  above zero, zero having no inverse to store.

## Data

Rows on the Settings list itself, below [Amounts](#amounts) — the file leaving and the file coming 
back, one exchange read twice ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)). Not a 
screen of their own: two rows are not a room, and a menu that exists to be passed through should not 
gain a stop whose only content is the two rows behind it. What actually needs room — the 
confirmation, the FR-DAT-4 report — arrives *after* a file is picked, so it is the pick that earns a 
screen, not the row that starts it.

- **A row that acts carries no chevron**, where one that travels does — the whole of the telling, and 
  why the two kinds may share the Settings list at all. `_Entry` has the two constructors rather than 
  a flag, so a row's shape is fixed where it is written.
- **Export** (FR-DAT-1) opens the system's share sheet on a copy of everything. **Nothing is said on 
  success**: the sheet opening is the answer, and a snackbar would land under a system modal and be 
  read once stale. A failed write or a sheet that will not open speaks, and nothing else does — a 
  reader who dismisses the chooser has done nothing, which is not a failure.
- **"as one text file" is the subtitle doing a paragraph's job.** A dimmed sentence saying the 
  collection is plain text is what the screen carried that the rows do not; folded into the subtitle 
  it survives at the size the fact is worth, which is smaller than the paragraph made it look.
- **An empty collection exports anyway.** A file carrying `format: 1` and empty sections is a 
  template, not an error, and the screen has no reason to know which it is. It imports on the same 
  terms, reading as the nothing it holds.
- **Import** (FR-DAT-3) opens the system's picker and pushes what came back. One screen carries both 
  outcomes: a pick has two of them, and giving each its own shape would make one act look like two.
- **What the file holds stands in for its name**, and opens. Recipes, ingredients, tags and units, 
  recipes first — a reader tells one file from another by its recipes long before by its units. 
  Android hands over no filename worth showing 
  ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)), and the collection is what is being 
  agreed to in any case. One card a kind, its count the title, the names themselves the line under 
  it, cut off at one line; tapped, the card gives every name it counted. **Nothing is cut short**: a 
  list that stopped at fifty is exactly where the entry a reader came looking for would have been.
- **Each kind is named and ordered as the screen that manages it names and orders it** — the nouns 
  and the A→Z of `inventory_screen.dart` and `tags_screen.dart`, and the declared order 
  `units_screen.dart` leaves standing, the fixed three coming first 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)). A card is then the list it stands for, read 
  early. The two tag vocabularies share one count but keep their own runs in the body, labelled, 
  since one name may stand in both ([ADR 07](adr/07-tag-colour.md)); an empty run is left out rather 
  than heading nothing, and a kind the file holds none of offers no chevron and answers no tap.
- **Accept rides the app bar**, where every other commit in the app sits (`editor_form.dart`). What 
  the act is worth is carried by a body spelling out everything arriving, not by the size of the 
  button agreeing to it — and a button pinned under a list a reader is meant to read first argues 
  with the reading. Above the cards, the one thing the counts cannot say: everything held now goes, 
  and a copy of it is kept first (FR-DAT-3). No numbers there — the cards have them, and a second 
  set beside them reads as a discrepancy rather than a reassurance.
- **A refused file offers nothing to agree to.** The issues as the startup banner words them, 
  `line N:` and all (FR-DAT-4), under the one sentence that matters — nothing has changed. A file the 
  app cannot read holds nothing to import, so there is no button to grey out.
- **The replace leaves for the collection**, popping Settings along with the review: what was 
  imported is two screens back, and a list of recipes that were not there a moment ago says more than 
  any sentence. It says what landed as it goes, which is where an import parts from an export — a 
  share cannot know its outcome, an import knows exactly.
- **Only a failure speaks otherwise.** A picker that will not open, a file that cannot be read, a 
  replace that cannot be written; a reader who picks nothing has done nothing, and a refused file has 
  the screen to say so on. A failed replace stays on the review, leaving for a collection that never 
  reached the disk being a lie about what happened.

## Tag and stock colours

Each token: fill + ink pair (one per theme) in `palette.dart`. One traffic light (stock, 
availability). Fill: chip/dot colour. Ink: text/pick ring. `switch` exhaustive 
([ADR 07](adr/07-tag-colour.md)).

`neutralSwatch` is the exception and the reason the rest are fixed: built from scheme roles 
(`surfaceContainerHighest`/`onSurfaceVariant`), it can read as neither a tag colour nor a signal, 
and follows light/dark for free. Worn by a chip whose colour means nothing — today the base filter.
