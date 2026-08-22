# ADR: The UI groups by subject

**Status:** Accepted

## Context

`lib/ui` was a flat bag of screens and widgets in two kind-named folders, with nothing enforcing
either name and nothing stopping a widget from importing a screen —
`test/architecture_test.dart` treated every file under `lib/ui` alike. `widgets/` itself had
decayed into fifteen files with no shared identity beyond "a widget lives here": one of them,
`recipe_widgets.dart`, named after that very kind while holding four unrelated things.

## Decision

**Two siblings under `lib/ui`, never a third: `screens/`, `widgets/`.**

- **`screens/`** — full-screen routes, one per destination, pushed by `MaterialPageRoute`, every
  file named `*_screen.dart`.
- **`widgets/`** — everything else, grouped by subject, never by feature: `cards/` (a list's rows
  and a recipe's own card), `chips/` (colour read as a pill, a dot, or a picked-tag row),
  `dialogs/` (the one `AlertDialog` shape and every dialog built on it), `forms/` (the editor
  frame, its fields, and the `ValidationIssue` path reading), `lists/` (the searchable list and
  its chrome), `notices/` (empty states and failure banners). A group's own feature-specific
  file — `cards/recipe_card.dart` — sits inside its role-named group exactly as
  `screens/recipes_screen.dart` sits inside `screens/`.

`destinations.dart`, `app.dart`, `theme.dart`, `palette.dart` and `wording.dart` stay at the
root: none is a screen or a composed-from piece, and none shares a subject with five others.

### Four tests

1. Every file directly under `lib/ui/screens/` is named `*_screen.dart`.
2. Only `app.dart` and files under `screens/` import `screens/`.
3. No file sits loose under `lib/ui/widgets/` — every one is in exactly one group.
4. Every intra-`ui` import is relative, never `package:cocktails/ui/…`.

Folder-level acyclicity is not a goal: `forms/` reaches `dialogs/`, `lists/` reaches `chips/`, and
nothing stops a widget group depending on another — chasing a DAG here is how a `common/` folder
gets invented for one shared type.

## Alternatives considered

- **Keep `screens/`/`widgets/` flat, police the boundary by review alone.** Rejected: a convention
  with nothing enforcing it is what produced `recipe_widgets.dart` in the first place.
- **A third sibling for modal interruptions.** Rejected: a dialog is a widget same as any other —
  it needs a group inside `widgets/`, not a folder of its own.

## Consequences

`docs/components.md`'s module map and "Boundary rules" describe the tree these four checks
enforce. Every existing import updates to the new paths — mechanical, caught outright by
`flutter analyze`.
