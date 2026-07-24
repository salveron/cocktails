# Vision

A personal cocktail recipe database as a mobile & PC app — the structured successor to a
hand-curated Telegram channel.

## Problem

The collection currently lives in a Telegram channel: terse recipe lines with emojis
encoding availability and interest. The format stores knowledge but cannot answer the
questions that matter at the bar: *what can I make right now*, *what am I missing*,
*which purchase unlocks the most new drinks*. Marks go stale, one emoji conflates several
meanings, and nothing is searchable or filterable.

## Product idea

One app owns both the recipe collection and the home-bar inventory:

- **Structured recipes** — ingredients with measurements, tags, and free-text notes for
  everything that resists formalization (preparation, glassware, garnish).
- **Live availability** — the inventory of ingredients on hand determines, automatically,
  which recipes can be made.
- **Discovery** — search, filter by ingredient and tag, group by base spirit; a shopping
  optimizer answers "which two or three bottles unlock the most new drinks".
- **Owned, portable data** — the entire database exports to and imports from one readable
  text file, so bulk work can happen outside the app (with an AI assistant, in an editor)
  rather than through hundreds of taps.

## Direction beyond the pilot

Ideas kept compatible with, but outside, the pilot (see
[requirements.md](requirements.md#out-of-pilot-scope)):

- **Guest access** — others see which cocktails are on offer at a party, either always or
  when explicitly published.
- **PC/desktop app** for comfortable bulk editing.
- Richer recipe data: formalized preparation steps and techniques, dedicated glassware and
  garnish fields, photos, ingredient substitutions.

## Constraints

Single developer with AI assistance. Simplicity wins ties: the pilot is a single-user,
mobile-only app, and features are added only after the core is implemented and tested.

The existing Telegram collection is migrated in through the import file, prepared outside
the app with AI help; the app itself never learns the Telegram format.

## Success

The pilot succeeds when it is feature-complete: every requirement in
[requirements.md](requirements.md) works reliably on the phone. Adoption (retiring the
Telegram workflow) is intentionally not a pilot criterion.
