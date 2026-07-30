# UI design

Screen- and shell-level design for `ui/`: what every screen shares, and the design of each
screen itself. Module boundaries and the interfaces `ui/` consumes are in
[components.md](components.md); requirements are in [requirements.md](requirements.md).

## App shell

`main.dart` builds the `ProviderScope` and hands off to `CocktailsApp`, which owns the
`MaterialApp` — title, both themes, and `AppShell` as its home.

- **Three destinations** — Recipes, Inventory, Shopping — in a Material 3 `NavigationBar`,
  each one tap from any other (NFR-1). Settings is not a destination but sits behind the app
  bar's gear: the ratio, the display toggle, the tag vocabularies and data exchange are set
  once, not browsed.
- **Destinations live in an `IndexedStack`**, so switching away and back keeps a screen's
  scroll position and search text. Everything below a destination — forms, settings — is a
  `Navigator` push over the shell; the recipe view alone is not below the list but inside
  it ([Recipes screen](#recipes-screen)). Routing is `Navigator` 1.0: the pilot has
  no deep links, no URL bar and no nested routers, so `go_router` would buy nothing.
- **Theme** — one seed colour in `theme.dart` generates the light and dark schemes and the
  platform setting picks between them. No per-component theming.
- **`ModelView`** is the only reader of `modelProvider`'s `AsyncValue`: a spinner while the
  startup load runs, a failure state if it throws, the model otherwise. Screens take the
  loaded `Model` and never see the other two states.
- **`EmptyState`** is the one shape of "nothing here yet" — icon, title, and a line naming
  what would fill it.
- **`StartupIssues`** shows what the startup load could not read (FR-DAT-4) above every
  destination, until dismissed.

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

Ingredients and tags are edited through the same two dialogs, so the screens cannot drift
apart:

- **The entry dialog** — one field, for a new entry or an edit. It takes the vocabulary's
  `validate…` function rather than holding any rule of its own, shows the first issue under the
  field, and keeps Save out of reach until there is none: the app refuses exactly what the codec
  refuses, reserved mark suffixes included. An untouched empty field is not a mistake yet, so it
  is left unmarked. Under the field sits whatever else the entry carries — the palette for a tag
  (FR-VOC-3), the ingredient-tag vocabulary for an ingredient (FR-INV-3) — so an entry is settled
  in one place and no part of it needs a dialog of its own. A vocabulary carrying neither gets
  the field alone. A new tag opens on the first colour its vocabulary has not spent yet: distinct
  colours without being asked for.
- **Chosen is marked in the mark's own ink** — a tick inside a swatch, which is a plain circle
  with room to spare, and a ring just outside a chip, which is already full of its name. The
  filter row over the inventory wears the same ring. That ring is drawn transparent rather than
  left off while a chip is unpicked, so picking one changes its colour and nothing else: a chip
  that grew under the finger would re-flow the row it sits in.
- **Every section runs the field's full width**, so the swatches and the chips begin where the
  field begins instead of floating in the middle of the dialog.
- **The delete dialog** has two faces over the model's `…Using…` queries: a plain confirmation
  when nothing references the entry, and a refusal naming what does (FR-VOC-1) — recipes for an
  ingredient or a recipe tag, ingredients for an ingredient tag. The reason shows where the
  delete was attempted — never a disabled control with no explanation.

Adding is a `FloatingActionButton` the list brings with it: the destinations share the shell's
`Scaffold`, which has no per-screen button slot, so `VocabularyList` carries a `Scaffold` of its
own. The "nothing matches" face carries that same add prefilled with the query, so a search that
found nothing is one tap from creating it. A successful add clears the search — otherwise the
new entry could land outside the query and the screen would look as if nothing had happened.
The recipes' add fills the same slot but pushes the [recipe form](#recipe-form) instead of a
dialog: a recipe is more than one dialog holds.

## Recipes screen

- **The view lives inside the list** — every recipe is a card that expands in place, so
  looking one up is a single tap with nothing pushed and nothing to come back from (NFR-1).
  Cards expand independently and collapse on the same tap: two recipes can be open side by
  side, and no card ever collapses unbidden, so the scroll never jumps.
- **The compact card is two lines.** The name, with a tag dot per recipe tag after it — the
  inventory's idiom: fill colour, vocabulary order, name in the tooltip — and under it the
  ingredient names in the recipe's own order, dot-separated and ellipsized on one line:
  what goes in it at a glance, the amounts one tap deeper. Optional ingredients are listed
  undistinguished.
- **The full card replaces both summaries with the real thing** — the tags as their chips,
  and the ingredient lines exactly as `formatRecipeLine` writes them ("1.5 part gin (base)"),
  so the card reads like the file and each mark carries its own words. Then the notes as
  typed, then the made-history line — "Made 4 times · last 12 Jul 2026". A section with
  nothing to say is absent: no notes, no history, no empty heading.
- **The vocabulary actions are the inventory's** — add through the list's own button, edit
  and delete behind a per-row ⋮ on compact and expanded cards alike: the row's tap is spent
  on expansion, and the menu will pair with M16's availability chip in the trailing slot as
  it pairs with the stock chip on the inventory. Add and edit push the
  [recipe form](#recipe-form); delete only confirms, since nothing references a recipe. A card
  open when its recipe is renamed stays open under the new name: the expansion belongs to the
  entry, not to the name it used to have.
  M15 puts the "made it" action on the full card, M17's scaling sits by the lines, and
  M18's filter row slots under the search, becoming the legend the dots are read against.

## Recipe form

Create and edit are one pushed page — the shell's rule for forms — titled for what it is
doing, Save an app-bar action. Top to bottom it mirrors the card and the file: the name, the
ingredient lines, the tag picker, the notes (FR-REC-1..5).

- **One field per line, the grammar as the entry** — a line is typed exactly as the file
  writes it, marks included: "1.5 part gin (base)" (FR-REC-2/3/8). The shared parser is the
  only reader, so the form cannot drift from the codec; `tryParseRecipeLine` runs on every
  change and the problem sits under its own field, the entry dialog's idiom — an untouched
  empty field is no mistake. The hint shows the shape.
- **The lines grow by themselves** — the bottom field is always empty and typing in it
  spawns the next; a field emptied out is dropped on save. No per-line ✕, no add button, no
  drag handles: order is the typed order, and reordering is cut-and-paste.
- **Save stays out of reach** until the name passes the live rule the dialogs apply — its
  duplicate and whitespace checks — and every non-empty line parses. On save `validateRecipe`
  judges the whole entry; a value rule syntax cannot see — a zero amount, range ends out of
  order — lands under its field through the `lines[i]` path, the seam components.md names.
  A refusal no field can carry is said in a snackbar instead: a Save that changes nothing and
  explains nothing is indistinguishable from a broken one, and the fields are the only place
  the form has to put a message.
- **Unknown ingredients are an offer, not a wall** — when they are all that is wrong, one
  confirmation lists them and adds them (out of stock, untagged) before the recipe saves, so
  entering a recipe never dead-ends into the inventory screen. Declining marks the fields
  instead. Typos are caught where the list is read, before confirming.
- **Tags and notes ask nothing** — the picker is the dialogs' chip row over the recipe
  vocabulary (FR-REC-4), absent while that vocabulary is empty; the notes are one multiline
  field (FR-REC-5).
- **Backing out of edits asks once** — an untouched form pops silently; a dirty one asks to
  discard, because a fully typed recipe lost to a stray back-swipe is the worst thing this
  page could do. A rename saves as remove-then-add — nothing references a recipe by name, so
  nothing propagates — and the whole entry, the bottles it introduced included, goes to the
  model as a single edit so one save reaches the disk (components.md#state-contracts).

## Inventory screen

- **Flat A→Z**, one row per ingredient on its own filled card — a tinted ground and rounded
  corners, separating rows by mass rather than by a rule between them. Nothing re-sorts under a
  tap, so a row never moves away mid-restock.
- **The stock chip is a traffic light** — green in stock, amber low, red out — and spells the
  level out in words as well, so the row never asks the reader to decode a hue. Those hues are
  fixed rather than scheme roles: with the amber seed, `primaryContainer` comes out brown and
  `tertiaryContainer` green, which marked in-stock and low with each other's signal.
- **A tap on the row advances the stock one step** — `StockLevel.next`, in → low → out → in.
  That is the life of a bottle, so every real transition costs one tap (FR-INV-2), and each
  one saves through the model controller.
- **Edit and delete sit behind a per-row ⋮ menu**, since the row's tap already belongs to
  stock: the vocabulary actions get a target of their own instead of a hidden gesture. Edit is
  the name and the tags at once, in the dialog the add button opens too — so a bottle can be
  born tagged — and the whole entry, the rename included, goes to the model as a single edit so
  one save reaches the disk (components.md#state-contracts). A new bottle starts out of stock,
  which one tap on its row corrects.
- **Each tag is a dot after the name** — borderless, in the fill its chip wears below, in
  vocabulary order so two bottles wearing the same tags wear the same dots. A dot is read by
  matching it to the legend, so it has to be the legend's colour and not a second version of it.
  Names there would crowd every row and repeat down the whole list; when width runs out the name
  ellipsizes and the dots do not, since a half-drawn run misreports how many there are.
- **The filter row is that legend** — every ingredient tag as a chip in its colour, pinned under
  the search and absent until the vocabulary has something in it. It scrolls sideways rather than
  wrapping: pinned over a list it has to stay one line deep however long the vocabulary grows.
  Picking narrows to the bottles carrying *every* picked tag, and the name search narrows on top
  of that (FR-INV-3). A tag renamed or deleted from Settings drops out of the picks instead of
  filtering on unseen, and a successful add clears the picks as it clears the search — the new
  bottle must not land outside a filter and leave the screen looking as if nothing had happened.
- **Three faces:** the empty inventory, nothing matched, the list. The third face names whatever
  narrowed it — the query, the picked tags, or both.

## Tags screen

Behind Settings rather than in the bottom bar: a vocabulary is arranged once and then used from
the screens that reference it.

- **A tab per vocabulary** — Recipe, Ingredient — in the screen's own app bar. They are peers
  with nothing to say to each other (FR-VOC-4), so tabs keep both one tap away instead of
  stacking them into one scroll where the boundary has to be explained.
- **A tag is drawn as its own chip**, its name lettered on its colour at full strength. Judging
  a colour means seeing it, and this is the screen where it is chosen.
- **The row's tap opens the edit dialog** — a tag row has no other action to spend it on, unlike
  an inventory row, whose tap belongs to stock. The ⋮ carries that same Edit beside Delete, so
  the menu is never the only way in.

## Tag and stock colours

Each token maps to a pair — a fill and the ink that stays legible on it — one pair per theme;
`palette.dart` is the single home for both maps. The fill is the colour a token *is*: a chip
fills with it, a dot is nothing but it, and the two are matched by eye across a screen. The ink
is for whatever has to hold against that fill or against the page — the chip's lettering, a
picked chip's ring, the tick inside a chosen swatch. The `switch` over `TagColor` is exhaustive,
so a new palette member ([ADR 07](adr/07-tag-colour.md)) does not compile until it has been
given a pair.
