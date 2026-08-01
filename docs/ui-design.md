# UI design

Screen and shell design for `ui/`. Module boundaries, interfaces in [components.md](components.md); 
requirements in [requirements.md](requirements.md).

## App shell

`main.dart` builds the `ProviderScope` and hands off to `CocktailsApp`, which owns the
`MaterialApp` — title, both themes, and `AppShell` as its home.

- **Three destinations** (Recipes, Inventory, Shopping) in Material 3 `NavigationBar`, one tap 
  apart (NFR-1). Settings: app bar gear (ratio, toggle, vocabularies, data exchange); set once, not browsed.
- **Destinations in `IndexedStack`** (keeps scroll/search on switch). Below-destination content 
  (forms, settings) pushed `Navigator` over shell. Recipe view inside list ([Recipes](#recipes-screen)). 
  Routing: `Navigator` 1.0 (no deep links/nested routers; `go_router` unneeded).
- **Theme**: one seed colour generates light/dark schemes; platform picks. One component theme only: 
  the hint style, dimmed to 60% so an empty field never reads as a filled one — every hint in the app, 
  one home.
- **`ModelView`**: only reader of `modelProvider`'s `AsyncValue` (spinner on load, failure, or model). 
  Screens never see loading/failure states.
- **`EmptyState`**: one shape (icon, title, what would fill it).
- **`StartupIssues`**: displays startup-load problems (FR-DAT-4) above all destinations; dismissable.

## Searchable lists

`SearchField` is pinned above the list, always visible: no tap stands between the screen and
a search (NFR-1). `matchesQuery` beside it is the one rule every name search applies —
case-insensitive, anywhere in the name, surrounding space ignored — so inventory (FR-INV-1)
and the recipe list (FR-DIS-2) cannot drift apart. The query is the field's own
`TextEditingController`, owned by the screen; the combinable filters of FR-DIS-3 are a
separate concern and get their own provider.

## Vocabulary editing

The inventory, the two tag tabs and the recipe list are one widget, `VocabularyList`: the
pinned search, the A→Z sort, the three faces, the add button, and the query the "nothing
matches" face hands to it. A screen supplies only what a row shows and what its tap does — the stock chip and one tap
per bottle on the inventory, the tag itself and its edit dialog on a tag tab. Three lists that
behave alike because they are the same list. A screen with something else to narrow by hands
over a filter as one piece — the row drawn under the search, the test an entry must pass, and
what it is narrowing by — so the list can name it in the face it shows when nothing is left.

Ingredients and tags use same two dialogs (screens can't drift):

- **Entry dialog**: one field (new or edit). Takes vocab `validate…` function; shows first issue 
  under field; Save unreachable until none (app refuses what codec refuses, reserved suffixes 
  included). Untouched empty field not marked. Under field: whatever entry carries (palette for tag, 
  ingredient-tag vocab for ingredient) — one-place settle, no sub-dialogs. New tag opens on first 
  unused colour (distinct without asking).
- **Chosen marked in mark's ink**: tick in swatch (plain circle, room) or ring outside chip (full of 
  name). Filter row wears same ring. Ring transparent when unpicked (picking changes colour, nothing 
  else; no re-flow).
- **Every section full field width** (swatches/chips start at field, not floating).
- **Delete dialog**: two faces over `usersOfTag`/`recipesUsingIngredient` (confirmation if nothing 
  references; refusal naming what does, FR-VOC-1). Reason shows where delete attempted (never disabled 
  without explanation). Both faces, the recipe form's missing-ingredient offer and its discard prompt 
  are one dialog: a question, what it has to list, two buttons — a refusal being the one with nothing 
  to agree to.

Add is `FloatingActionButton` the list brings (no per-screen button on shell `Scaffold`). Empty 
face has add prefilled with query (search miss → one tap to create). Successful add clears search 
(else new entry lands outside query, looks unchanged). Recipes' add pushes [recipe form](#recipe-form) 
instead of dialog.

## Recipes screen

- **View inside list**: recipe card expands in place (single tap, nothing pushed/returned, NFR-1). 
  Cards expand independently, collapse on same tap. Two open side-by-side; no unbidden collapse; 
  scroll stable.
- **Compact card: two lines** (name with tag dot per tag using inventory idiom: fill colour, vocab 
  order, name in tooltip; plus ingredient names recipe order, dot-separated, ellipsized; what-goes-in 
  glance, amounts one tap deeper). Optional ingredients unlabelled.
- **Full card**: tags as chips, ingredient lines exactly as `formatRecipeLine` writes ("1.5 part gin 
  (base)"; card reads like file, marks carry own words) until asked to read them otherwise (scaling 
  below). Then notes, then the made row. Empty sections absent — the made row never is, since it 
  carries the button.
- **Vocab actions from inventory**: add via list button, edit/delete behind per-row ⋮ (tap spent on 
  expansion; menu pairs with availability chip). Add/edit push [recipe form](#recipe-form); delete 
  confirms (nothing references recipe). Card open on rename stays open under new name (expansion = entry, 
  not name). M18: filter row under search (tag legend).
- **Scale & convert behind the ⋮, on an open card only** (FR-REC-7): one dialog settles the factor 
  (×1–×4) and the unit part-based lines read in (FR-SET-1 for this card alone, opening on the global 
  default), Cancel/Apply like every other dialog — ×1 in parts is the way back, so it needs no reset 
  of its own. A closed card is not offered it: there are no amounts on show to transform.
- **The card carries no control, only the news**: the name row gains "(×2, ml)" beside the name, dot 
  idiom, and each line's measure turns italic — the one part of a line that is then not what the 
  recipe says. Reading is not editing: nothing reaches the model, the file, or the global toggle, and 
  the reading dies with the card like the Undo beside it (both let go in one place).
- **Availability chip left of the ⋮** (FR-DIS-1): "Ready", "Low", "Missing" in the inventory's own 
  traffic light — one idiom on both list screens, colour never decoded alone. No count on "Missing": 
  fixed widths keep the column calm and every name cut at the same place; the count is one tap away, 
  where the lines are marked anyway. Trailing slot sits outside the body that opens, so the verdict 
  stays put while the card is open.
- **Line marks as dots, only where there is something to say** (FR-DIS-1): a [stock dot](#tag-and-stock-colours) 
  after a line whose bottle is low or out, level in its tooltip; an in-stock line carries none, so no 
  dot *is* "in stock". Words would not fit beside a line that already ends in "(base)". Optional lines 
  are dotted too — the dot reports the bottle, and the line's own "(optional)" says it does not count, 
  right beside it, so a red dot on a "Ready" card explains itself.
- **Made row closes the full card**: history text left (absent until the first stamp), Undo, "Made it" 
  right (FR-REC-6). Text ellipsizes, buttons don't (clipped date beats wrapped row). Undo appears on 
  stamp, restores the exact history it replaced (date included, one stamp deep), and dies with the 
  card — its lifetime is the card's, not a timer's. Long press on the button resets to never-made 
  behind the shared confirm dialog: the count only climbs, so a mis-tap has Undo and an old count has 
  reset. Both are one write. Undo state sits in the screen keyed by name, beside expansion and for the 
  same reason (the list disposes what scrolls).

## Recipe form

Create and edit: one pushed page (shell rule for forms), titled for action, Save in app bar. 
Top to bottom mirrors card and file (name, lines, tags, notes, FR-REC-1..5).

- **One field per line, grammar as entry**: "1.5 part gin (base)" (FR-REC-2/3/8). Shared parser is 
  only reader (form can't drift from codec). `tryParseRecipeLine` on every change; problem under field 
  (entry dialog idiom; untouched empty not mistake). Hint shows shape. Typing is forgiving where the 
  file is: the unit may be left out ("1 gin") or plural ("2 dashes"), and a bottle typed in any case 
  is the bottle it names ([ADR 08](adr/08-names-ignore-case.md)) — the line saved carries the 
  vocabulary's own spelling and the full unit, so the card reads canonically whatever was typed.
- **Lines self-grow**: bottom field always empty; typing spawns next, and erasing that line takes the 
  spare back — one field stands empty, never two, and never the one the cursor is in (a field emptied 
  mid-list stays until save, since removing it under the cursor is worse). Empty fields dropped on 
  save. No per-line ✕, add button, drag: order is typed order (reorder = cut-paste).
- **Save unreachable** until name passes live rules (dialogs' duplicate/whitespace) and all non-empty 
  lines parse. Live name check reads only issues at the empty path, so what the half-typed rest is 
  still missing waits for Save. On save, `validateRecipe` checks whole; value rule syntax can't see 
  lands under field via `lines[i]` path (components.md seam). Refusal no field can carry → snackbar 
  (Save unchanged indistinguishable from broken; fields only place for message) — the recipe with 
  nothing required (FR-REC-2) refuses there, its path naming the lines list, not one line.
- **Unknown ingredients: offer not wall**: if only issue, confirmation lists and adds them (out, 
  untagged) before save (never dead-ends to inventory). Declining marks fields. Typos caught where 
  list read, before confirming.
- **Tags/notes ask nothing**: picker is dialogs' chip row over recipe vocab (FR-REC-4), absent if 
  empty. Notes: one multiline field opening one line tall and growing with what is typed (FR-REC-5) — 
  most recipes carry a sentence, and an empty box three lines deep pushes the rest off screen.
- **Back asks once**: untouched form pops silently; dirty asks to discard (fully typed recipe lost to 
  back-swipe = worst). Rename saves as remove-then-add (nothing refs recipe by name). Whole entry 
  (new bottles) → model as one edit (one save to disk, components.md#state-contracts).

## Inventory screen

- **Flat A→Z**: one row per ingredient on filled card (tinted, rounded; mass separation not ruled). 
  Nothing re-sorts on tap (row stable mid-restock).
- **Stock chip traffic light** (green in, amber low, red out; words too; no hue decode). Fixed 
  hues not scheme roles (amber seed: `primaryContainer` brown, `tertiaryContainer` green; collided).
- **Row tap advances stock one step** (`in → low → out → in`; real transition = one tap, FR-INV-2; 
  each saves via controller).
- **Edit/delete behind per-row ⋮** (row tap taken by stock; vocab actions own target). Edit: name 
  and tags at once in add dialog (bottle born tagged). Whole entry (rename) → model one edit (one 
  save, components.md#state-contracts). New bottle starts out (one tap corrects).
- **Tag as dot after name** (borderless, chip fill, vocab order; two matching tags match dots). Dot 
  read against legend (must be legend's colour). Names would crowd and repeat; name ellipsizes, dots 
  don't (half-drawn run misreports count).
- **Filter row is that legend**: every ingredient tag as chip, pinned under search, absent if empty. 
  Horizontal scroll not wrap (pinned over list = one line depth). Picking narrows to bottles with 
  *every* picked tag; name search combines (FR-INV-3). Tag rename/delete from Settings drops from 
  picks, not filter-on-unseen. Successful add clears picks like search (new bottle can't land outside 
  filter, look unchanged).
- **Three faces**: empty, nothing matched, list. Third names what narrowed (query, tags, both).

## Tags screen

Behind Settings, not bottom bar (vocab arranged once, used from referencing screens).

- **Tab per vocab** (Recipe, Ingredient) in screen app bar. Peers (nothing to say each other, 
  FR-VOC-4); tabs keep both one tap away (vs. stacking one scroll where boundary explained).
- **Tag drawn as own chip** (name on colour at full strength). Colour judging = seeing it; this screen 
  is where chosen.
- **Row tap opens edit dialog** (no other action for tag row, unlike inventory row's stock tap). ⋮ 
  carries Edit beside Delete (menu never only way in). Name and colour settle together and reach the 
  model as one edit — the rename that carries the tag into everything wearing it included — so one 
  save reaches the disk (components.md#state-contracts).
- **Neither tab knows which one it is.** The domain tells the vocabularies apart (`TagKind`); the 
  screen supplies only the words each is introduced with. A third vocabulary is a new kind and one 
  more arm of the wording switch, not a second screen.

## Tag and stock colours

Each token maps to a pair (fill + ink staying legible); one pair per theme. `palette.dart` is single 
home. One traffic light serves both signals — a bottle's stock and the verdict on the recipe holding 
it up read in the same three hues, since they are the same news at two scales. Fill is the colour a token *is* (chip fill, dot, eye-matched across screen). Ink is for things 
holding against fill or page (chip lettering, picked ring, swatch tick). `switch` over `TagColor` 
exhaustive (new member [ADR 07](adr/07-tag-colour.md) doesn't compile until swatch added).
