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
- **The startup load is met once, here.** While it runs the app is a **bare spinner** — no app bar, 
  no bottom bar: chrome naming a bar the app has not read yet would say more than it knows. Where it 
  fails outright the whole screen says so. Only past both does anything else get built, which is 
  what lets every screen below read a collection rather than the wait for one 
  ([components.md](components.md#state-contracts)). A per-screen wrapper doing this seven times was 
  what stood here before, and it cost every screen a level of indentation to say what one gate says.
- **`EmptyState`**: icon, title, fill hint.
- **`LoadIssues`**: displays FR-DAT-4 problems above all screens, from startup or from a crossing 
  alike. Dismissable — of the issues on show, so the next bar's trouble is not swallowed by a tap 
  made before it.

## Bars

Behind the gear, **Change bar** — a row that travels, and the **last** one on the Settings list. Not 
the app bar's own slot, not a drawer, not a fourth destination: switching is rarer than reaching a 
recipe and rarer than the gear itself, so it sits where the app already keeps what is not a 
destination, and the bottom bar goes on meaning what it has always meant. Last because it is the way 
*out* of this bar rather than anything in it — everything above it acts on the bar in hand, and a row 
that changes which bar that is belongs after them, not before. It carries no ellipsis: the chevron 
already says a screen follows, and "…" on top of it says the same thing twice.

- **The app opens on the bar it was left in**, `openId` outliving the run 
  ([ADR 20](adr/20-the-app-holds-many-bars.md)), so a reader who keeps one bar never comes here 
  twice. **No bar open means this screen is home**: there is no destination to draw, so the app opens 
  on the list, and its empty state says what a bar is. That is a first run before the founding, and 
  the reader who deleted the bar they were standing in — one rule rather than a case for each. 
  Deleting the open bar is why: it leaves the reader on the list they are already on, where the app 
  choosing the next bar for them would be an arbitrary one.
- **One card a bar, expanded in place** — the recipe card's own gesture 
  ([recipes screen](#recipes-screen)). Closed it is the name, whether the bar is loaded, and how 
  current it is; opened it is what the bar holds, kind by kind, and the way in. The screen that lists 
  bars is the screen that manages them, and no second place holds half of it. **A card opens onto 
  counts, never contents**: the list reads the index alone (ADR 20), and since the counts are on the 
  record the card opens instantly and no second collection is ever resident.
- **Rename and Delete sit behind the row's ⋮**, the control the inventory and both tag lists already 
  use for exactly this. Buttons on the card was the first shape, on the grounds that the card already 
  opened to hold them; the ⋮ wins now that it is reachable **without** opening the card, which is 
  what a reader wants for the two operations that do not care what the bar holds. **Open bar** stays 
  a **filled tonal** button on the **right** of the body: it is the one thing the card is opened 
  *for*, so it carries the weight the card's one commit deserves and stands where every dialog in 
  the app puts its own. Right rather than left because the eye leaves a card at its trailing edge, 
  and filled rather than flat because a card that opens to offer one action should not make that 
  action the quietest thing on it. **Rename is offered on a guest bar too**: what a bar is called 
  on this device is the reader's, exactly as the unit it reads in is (FR-BAR-3), and no refresh 
  takes their name back ([ADR 21](adr/21-the-file-carries-one-bar.md)). The owner's name for it is 
  where the field starts and nothing more.
- **The subtitle says standing, never ownership**: "Loaded" on the bar the app has read, then 
  "Updated 3 hours ago" for an owner's own edit or "Synced 2 days ago" for a guest's last answer from 
  its source (FR-BAR-5). Coarse on purpose — the question it settles is whether to refresh, which no 
  count of seconds makes clearer. A bar the device has never dated says nothing rather than guessing: 
  an index written before stamps existed has no date to give, and "just now" would be a lie about it.
- **Whose bar it is is a chip beside the ⋮** — "Owned" or "Guest" — read the way the inventory row's 
  stock chip is, and on the same traffic light: **green** for owned, **amber** for guest (see 
  [colours](#tag-and-stock-colours)). Scheme roles came first, on the grounds that a mode is no 
  reading on that light; the hues win because the light is not really about stock but about what 
  the app will let a reader do here, and a guest bar is precisely the amber case — everything that 
  writes is missing from it (FR-BAR-4). The words carry the meaning either way, as on every chip.
- **Open bar is offered on every bar, the loaded one included.** It used to be absent there, as the 
  way the list said which bar was on show — but the subtitle says that now, in words, and an absent 
  control that means "you are here" reads as one that is broken. On the bar already loaded there is 
  nothing to read again, so it simply puts the reader where the crossing would have left them: the 
  recipes, and no way back to the list, a bar the reader chose being nothing to return from.
- **A tap opens the card; it never switches.** ui-design's first draft had the card itself do the 
  crossing, which put a bar's every narrowing one stray tap from being thrown away. The crossing is 
  now its own button, and the reader lands in the bar rather than back on the gear.
- **The bar's name leads the title** — "Home bar's Recipes", "Anna's Ingredients". The destination 
  named alone was what the app bar carried while there was one collection; with several it answers 
  the smaller question. The bar's own destinations carry it and nothing else does: Settings, the 
  vocabularies and the forms keep their own plain titles, being one push above a title that has just 
  said which bar this is. Nothing else marks the bar: no subtitle, no strip.
- **A guest bar is told by the bottom bar's shape**, not by a badge (FR-BAR-4). Two destinations 
  where an owned bar has three is a difference read at a glance and read from the row the reader 
  navigates by, which is where they are looking in any case. The shell indexes the stack by position 
  in the offered list rather than by the enum, so the two cannot drift apart on a bar that offers 
  fewer.
- **Everything that writes is absent on a guest, never refused** (FR-BAR-4). One fact does it — 
  `barWriterProvider` answering null ([components.md](components.md#state-contracts)) — and every 
  control is built from it: no add button on either list, no ⋮ on an inventory row, no Edit or Delete 
  on a recipe card, and a row tap that no longer rotates the stock. **Scale & convert survives**, 
  being a way of reading the owner's line rather than a change to it, as do search, the narrowings, 
  the orders, the random pick and the jumps. A ⋮ with nothing left in it draws nothing rather than 
  opening onto an empty menu — the rule lives in `RowMenu` itself, so a row builds the actions its 
  bar allows and never asks whether any survived.
- **The Settings rows that would write dim rather than vanish** — Tags and Units, greyed whole and 
  leading nowhere. Absent was the alternative and reads worse here than on the bottom bar: 
  a destination that is missing is a shape, where a *menu row* that is missing is indistinguishable 
  from one the reader has forgotten the name of. Dimmed, the list goes on saying what the app does 
  with a bar of one's own. Amounts stays live (the pick is the reader's on any bar), Export stays 
  live (a guest already holds what the file would carry, FR-DAT-1), and Change bar stays live, being 
  the way out. **Import is not dimmed but replaced**: the file row reads the other way round on a 
  guest bar, where it is **Refresh** — "ask its source for a newer copy" (FR-BAR-5) — the same 
  exchange from the other side rather than a row with nothing behind it. Dimming was what stood 
  here, and it was the one row where the greyed version said something false: this bar does have 
  business with a file, just not the one an owned bar has.
- **Swipe down to refresh** (FR-BAR-5), on a guest bar's lists and nowhere else — the standard 
  gesture for "ask the source again", and the reason the shell carries no refresh control and no 
  as-of. How stale a bar is reads on the card that lists it; on the bar itself, being one gesture 
  from current is worth more than being told how far from it you are. **A bar holding nothing 
  answers the pull too**: an empty list has no rows to pull on, and that is exactly where the 
  gesture is the only way to ask at all, so the empty state is given something to overscroll.
- **A refresh that did not land says so above the destinations**, beside the load banner and 
  worded like it: what arrived and would not read gets the `line N:` issues (FR-DAT-4), a source 
  that could not be reached gets one of the three reasons in the app's own words. Two banners 
  rather than one — a torn file on disk and a source that would not answer are different news, and 
  a reader dismissing either has not heard the other. **Nothing is said while a refresh is out**: 
  the pull's own spinner is saying it, and asking again clears what the last ask came to.

### New bar

**A pushed form, not a dialog** — the name field first, then where the bar's contents come from, 
then what becomes of it. A dialog carried the name and nothing else, which was right while an owned 
bar was the only thing this button could make; a picked file has to be *read* before it is agreed 
to (the counts, the refusals) and has destinations to choose between (FR-BAR-7), and neither fits 
over a list. Save rides the app bar, where every other commit in the app sits, and back asks 
before dropping what was typed — the recipe form's own frame (`editor_form.dart`).

**It is the same screen [Import](#data) pushes.** One file, the same three questions — what to call 
it, what it holds, where it goes — so founding and importing are one form reached two ways rather 
than two screens drifting apart. What differs is the entry: founding starts with no file and the 
roads **Owned | Guest**, importing starts with the file already picked and the roads 
**Replace | Guest**, Replace being the same road as Owned at the other end of a bar's life. The 
name field autofocuses only where the reader has typing to do — on the import entry the screen is 
there to be read, and a keyboard over it argues with that.

- **From import is a button, not a row**: the form is not a menu, and the pick is the one thing on 
  it that leaves the screen. It is where **Find nearby** will stand when the LAN transport lands 
  (FR-BAR-8), which is the other reason the section is "Contents" rather than "From a file".
- **A file picked in is shown before it is agreed to** — the cards, the counts and the refusals of 
  [Import](#data), which is not a resemblance but the same screen. A file that will not read shows 
  its issues and offers no road: founding an empty bar in its place would be a lie about what became 
  of it.
- **The road is a segmented choice, and it appears only once a file is in hand**: there is nothing 
  to be a guest *of* until one is. It sits with the other controls, above the counts rather than 
  after them — the form reads name, contents, road, and then ends on what the file holds, which is 
  the one thing on the screen that is read rather than answered. **Owned** is a copy, this device's 
  own to edit, with nothing linking it back — FR-BAR-2's "created from a file". **Replace** is that 
  same road onto a bar that already exists (FR-DAT-3). **Guest** is the owner's, read-only, 
  refreshed by a newer file they send (FR-BAR-3/5/7). Under it, one line saying what the chosen 
  road will do, and to which bar by name.
- **The name is the reader's on every road**, the guest one included: what a bar is called on this 
  device is theirs to choose exactly as the unit it reads in is (FR-BAR-3), and no refresh takes it 
  back. The field went quiet and read the owner's while a refresh still renamed the bar; with that 
  gone there is nothing left to dim, and the road a file takes no longer decides who names what.
- **A name the road suggests gives way; a name the reader typed stands.** The file's own name 
  (ADR 21) is a better default than an empty field, and the bar being replaced is a better one than 
  the file's — an import is not a rename. So the suggestion follows the toggle, and the moment the 
  reader writes over it, it is theirs and the toggle stops touching it. Clearing the file takes back 
  the name that came in with it: a bar of nothing is the reader's own to name.
- **Choose another file** sits where From import was, once one is in hand — the way out of a file 
  that would not read, and the way to a better one. The clear beside it is offered only where there 
  is something to be cleared *to*: founding falls back to an empty bar, where an import has no such 
  thing to fall back on and is left by the back arrow instead.

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
- **A guest bar is offered the pick alone** (FR-BAR-3). The unit amounts read in is a preference for 
  reading someone else's collection; what a part and an ounce are worth is the owner's, the recipes 
  having been written against those. So the rows go and the `SegmentedButton` stays, and Save writes 
  the record without touching the file.
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
- **Every caption is one line.** Six rows whose subtitles wrapped read as twelve, and the wrap fell 
  where the phone's width happened to land rather than where the sense broke. Cut to fit, the list 
  scans as a list. Dropping them altogether was weighed and refused: **Units** and **Amounts** are 
  the pair no title tells apart — one is the vocabulary a line is written in, the other what a part 
  and an ounce are worth — and a caption is the only thing standing between them.
- **An empty collection exports anyway.** A file carrying `format: 1` and empty sections is a 
  template, not an error, and the screen has no reason to know which it is. It imports on the same 
  terms, reading as the nothing it holds.
- **Import** (FR-DAT-3) opens the system's picker and pushes what came back onto the 
  [New bar](#new-bar) form, the file already in hand. One screen carries both outcomes: a pick has 
  two of them, and giving each its own shape would make one act look like two. It is the *same* 
  screen a bar is founded on — a file arriving asks the same three questions wherever the reader 
  picked it, and two screens asking them apart is how the two answers drift.
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
- **The roads are a segmented choice, and Save is the commit** — the form's own shape 
  (`editor_form.dart`), where two app-bar buttons stood before. **Replace** puts the file in place 
  of everything the open bar holds, a copy kept first (FR-DAT-3); **Guest** leaves that bar alone 
  and founds one of its own beside it (FR-BAR-7). Two commits in the app bar made the screen an 
  either/or with no state, which read as a dialog wearing a page; a road *chosen* and then agreed 
  to is one question at a time, and it is the shape the reader already met founding a bar. Under 
  the choice, the one thing the counts cannot say: what the road on show will do, and to which bar 
  by name. No numbers there — the cards have them, and a second set beside them reads as a 
  discrepancy rather than a reassurance.
- **Import is reached from an owned bar alone**, the row reading **Refresh** on a guest whose 
  collection is not this device's to replace (FR-BAR-4, FR-BAR-5). So Replace is offered without 
  asking whose bar is on show, and a device holding only guest bars reaches the guest road through 
  [New bar](#new-bar) instead — which is where it belongs in any case, an arriving bar being a new 
  bar rather than an edit to one.
- **A refused file offers nothing to agree to.** The issues as the startup banner words them, 
  `line N:` and all (FR-DAT-4), under the one sentence that matters — nothing has changed. A file the 
  app cannot read holds nothing to import, so there is no button to grey out.
- **Either road leaves for the collection**, popping Settings along with the form: what arrived is 
  two screens back, and a list of recipes that were not there a moment ago says more than any 
  sentence. **Only Replace says what landed** — it is the road that puts the reader back where they 
  started, where nothing about the screen has changed but its contents. The two that found a bar 
  land the reader *in* a bar that was not there a moment ago, which no sentence improves on. That 
  an import can speak at all is where it parts from an export: a share cannot know its outcome.
- **Only a failure speaks otherwise.** A picker that will not open, a file that cannot be read, a 
  road that cannot be written; a reader who picks nothing has done nothing, and a refused file has 
  the screen to say so on. A road that did not go through stays on the form, leaving for a 
  collection that never reached the disk being a lie about what happened.
- **Refresh, in the same row's place on a guest bar** (FR-BAR-5), asks the source again — the pull's 
  own question put where a reader who went looking for it will look, and the only way to ask on a 
  bar whose lists are too short to pull. It **says what it came to right there**: the banner that 
  carries a failed refresh stands behind this screen unread, so the answer arrives as a snackbar 
  and is marked told, and the banner does not repeat it on the way back. A refresh that landed says 
  so too — the reader is looking at a menu, not at the lists that would otherwise be the answer.

## Tag and stock colours

Each token: fill + ink pair (one per theme) in `palette.dart`. One traffic light — stock, 
availability, and whose bar it is (FR-BAR-3): green where the app is fully open to the reader, 
amber where it is not, red where nothing can be made. Fill: chip/dot colour. Ink: text/pick ring. 
`switch` exhaustive ([ADR 07](adr/07-tag-colour.md)).

`neutralSwatch` is the exception and the reason the rest are fixed: built from scheme roles 
(`surfaceContainerHighest`/`onSurfaceVariant`), it can read as neither a tag colour nor a signal, 
and follows light/dark for free. Worn by a chip whose colour means nothing — today the base filter.
