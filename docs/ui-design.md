# UI design

Screen- and shell-level design for `ui/`: what every screen shares, and the design of each
screen itself. Module boundaries and the interfaces `ui/` consumes are in
[components.md](components.md); requirements are in [requirements.md](requirements.md).

## App shell

`main.dart` builds the `ProviderScope` and hands off to `CocktailsApp`, which owns the
`MaterialApp` — title, both themes, and `AppShell` as its home.

- **Three destinations** — Recipes, Inventory, Shopping — in a Material 3 `NavigationBar`,
  each one tap from any other (NFR-1). Settings is not a destination but sits behind the app
  bar's gear: the ratio, the display toggle and data exchange are set once, not browsed.
- **Destinations live in an `IndexedStack`**, so switching away and back keeps a screen's
  scroll position and search text. Everything below a destination — recipe view, forms,
  settings — is a `Navigator` push over the shell. Routing is `Navigator` 1.0: the pilot has
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

Ingredients and tags are edited through the same two dialogs, so the two screens cannot drift
apart:

- **The name dialog** — one field, for a new entry or a rename. It takes the vocabulary's
  `validate…` function rather than holding any rule of its own, shows the first issue under the
  field, and keeps Save out of reach until there is none: the app refuses exactly what the codec
  refuses, reserved mark suffixes included. An untouched empty field is not a mistake yet, so it
  is left unmarked.
- **The delete dialog** has two faces over `recipesUsing…`: a plain confirmation when nothing
  references the entry, and a refusal naming the recipes that do (FR-VOC-1). The reason shows
  where the delete was attempted — never a disabled control with no explanation.

Adding is a `FloatingActionButton` the screen owns: the destinations share the shell's
`Scaffold`, which has no per-screen button slot, so each screen brings its own `Scaffold` for
it. The "nothing matches" face carries that same add prefilled with the query, so a search that
found nothing is one tap from creating it. A successful add clears the search — otherwise the
new entry could land outside the query and the screen would look as if nothing had happened.

## Inventory screen

- **Flat A→Z**, one row per ingredient: the name and a chip that spells the stock level out
  instead of leaving it to colour. Nothing re-sorts under a tap, so a row never moves away
  mid-restock.
- **A tap on the row advances the stock one step** — `StockLevel.next`, in → low → out → in.
  That is the life of a bottle, so every real transition costs one tap (FR-INV-2), and each
  one saves through the model controller.
- **Rename and delete sit behind a per-row ⋮ menu**, since the row's tap already belongs to
  stock: the vocabulary actions get a target of their own instead of a hidden gesture. A new
  bottle starts out of stock, which one tap on its row corrects.
- **Three faces:** the empty inventory, the query nothing matched, the list.
