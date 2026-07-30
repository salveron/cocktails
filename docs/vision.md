# Vision

A personal cocktail recipe database as a mobile & PC app — the structured successor to a
hand-curated Telegram channel.

## Problem

Telegram channel: terse recipe lines with emojis. Cannot answer: *what can I make right now*, 
*what am I missing*, *which purchase unlocks the most new drinks*. Marks stale, emojis 
conflate meanings, nothing searchable.

## Product idea

One app: recipe collection + home-bar inventory.

- **Structured recipes** — ingredients with measurements, tags, free-text notes.
- **Live availability** — inventory determines automatically which recipes are makeable.
- **Discovery** — search, filter by ingredient/tag/base spirit; shopping optimizer finds 
  which 2–3 bottles unlock the most new drinks.
- **Portable data** — export/import one human-readable text file; bulk work outside the app.

## Future directions

Compatible but out of scope (see [requirements.md](requirements.md#out-of-pilot-scope)):

- Guest access publishing.
- PC/desktop app.
- Formalized preparation, dedicated glassware/garnish fields, photos, substitutions.

## Constraints

Single developer with AI assistance. Single-user, mobile-only. Simplicity wins ties. 
Telegram migration through import file prepared outside the app; no in-app Telegram format parsing.

## Success

Every requirement in [requirements.md](requirements.md) works reliably on the phone. 
Adoption is not a pilot criterion.
