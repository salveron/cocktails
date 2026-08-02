# UI design

Screen and shell design for `ui/`. Module boundaries, interfaces in [components.md](components.md); 
requirements in [requirements.md](requirements.md).

## App shell

- **Three destinations** (Recipes, Inventory, Shopping) in Material 3 `NavigationBar` (NFR-1). 
  Settings: app bar gear (ratio, toggle, vocabularies, data exchange).
- **`IndexedStack`** (keeps scroll/search). Forms/settings pushed via `Navigator`. 
  Recipe view inside list. `Navigator` 1.0, no nested routers.
- **Theme**: seed colour, platform-picked light/dark. `dimmedInk` (`onSurfaceVariant` at 60%) is 
  the one dim: a hint, so empty ≠ filled; a bottle a group offers that the bar lacks. One home, so 
  the two cannot drift.
- **`ModelView`**: only reader of `modelProvider`'s `AsyncValue`. Screens never see loading/failure.
- **`EmptyState`**: icon, title, fill hint.
- **`StartupIssues`**: displays FR-DAT-4 problems above all screens (dismissable).

## Searchable lists

`SearchField` pinned above (NFR-1). `matchesQuery`: case-insensitive, anywhere, no surrounding space.
Applies to inventory (FR-INV-1) and recipes (FR-DIS-2) identically. Entries answering multiple names 
(FR-VOC-6): match on any, show under entry's name — a recipe answers to its bottles' spellings too, 
so a query reaches what it is built from. Hence "answers to", not "is called", when nothing matches. 
Filter and order alike are widget state, never persisted, never on the model's side.

Orders behind one icon (FR-DIS-8): chip row shows offerings + current (direction). Picking current 
reverses list. No separate Z→A/missing-first chips. Tie-break: name. Rows stable during edit; 
list out-of-order until touched after external change. Not persisted.

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
- **Expanded**: tags as chips, lines as `formatRecipeLine` writes, notes, made row. 
  Empty sections absent (except made row carries button).
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
- **Scale & unit** behind ⋮ (expanded cards only, FR-REC-7): factor ×1–×4, unit for part-based 
  (FR-SET-1 this card only). ×1 in parts cancels.
- **Display-only transforms**: name row shows "(×2, ml)", measures italic. No persistence; 
  dies with card.
- **Availability chip** (FR-DIS-1): "Ready"/"Low"/"Missing" (traffic light, no count). 
  Trailing slot outside expanding body. List opens in this order (FR-DIS-8).
- **Line marks**: stock dot after line if the line is low/out (tooltip shows level); no dot = in 
  stock. Optional lines dotted too (dot + "(optional)" together).
- **Substitution groups** (FR-REC-9, [ADR 11](adr/11-substitutions-on-the-line.md)): read as prose 
  — "cognac or vodka" — open and shut alike, where the file writes `/`. Bottles the bar lacks fall 
  to `dimmedInk`, but only while it holds one; a group short of everything dims nothing and takes 
  the dot, so the dot keeps meaning "this line is the problem". Dot follows the group's best 
  (`stockOfLine`). The "or" is italic on the open card — two letters between two names need it. 
  Italic thus does double duty with the scaled measure below; position tells them apart, and the 
  name row's "(×2, ml)" is what actually announces a transformed card.
- **Made row**: history text (absent until first stamp), Undo, "Made it" (FR-REC-6). 
  Undo one-deep. Long-press resets to never-made.

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

## Tags screen

Behind Settings. Tab per vocab (Recipe, Ingredient, FR-VOC-4). Tag drawn as chip 
(name on full-strength colour). Opens A→Z; palette order also offered (FR-DIS-8).
- **Row tap** opens edit (name, colour together, one save). Neither tab knows its kind 
  (domain tells via `TagKind`).

## Units

Behind Settings. Form, not `VocabularyList` (no search/sort). Rows editable in place 
(name, plural). One Save for screen. Rename propagates to lines.
- **Self-growing**: empty row at bottom; typing adds next; erasing spare removes it.
- **`part`/`ml` locked** (ratio, display toggle anchored, ADR 09); plurals still editable.
- **Delete blocked** while lines use it (names recipes). Unused row goes on save; 
  discard restores.
- **Validation** same as import: errors under field, Save blocked.

## Tag and stock colours

Each token: fill + ink pair (one per theme) in `palette.dart`. One traffic light (stock, 
availability). Fill: chip/dot colour. Ink: text/pick ring. `switch` exhaustive 
([ADR 07](adr/07-tag-colour.md)).

`neutralSwatch` is the exception and the reason the rest are fixed: built from scheme roles 
(`surfaceContainerHighest`/`onSurfaceVariant`), it can read as neither a tag colour nor a signal, 
and follows light/dark for free. Worn by a chip whose colour means nothing — today the base filter.
