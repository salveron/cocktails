# Vision

A personal cocktail recipe database as a mobile & PC app — the structured successor to a
hand-curated Telegram channel.

## Problem

Telegram channel cannot answer: what can I make, what's missing, which purchase unlocks new drinks.
No searchability, marks stale. And its readers have nowhere to follow: a structured collection is
one person's where a channel was everyone's.

## Product idea

One app: recipe collection + home-bar inventory.

- **Structured recipes** — ingredients with measurements, tags, free-text notes.
- **Live availability** — inventory determines automatically which recipes are makeable.
- **Discovery** — search, filter by ingredient/tag/base spirit; shopping optimizer finds 
  which 2–3 bottles unlock the most new drinks.
- **Portable data** — export/import one human-readable text file; bulk work outside the app.
- **Bars of one's own, and others' to read** — the device holds several: each owned bar the
  reader's to keep and to share, each guest bar someone else's, read as it last arrived.

## Future directions

Compatible but out of scope (see [requirements.md](requirements.md#out-of-scope)):

- PC/desktop app.
- Formalized preparation, dedicated glassware/garnish fields, photos.
- Likes and dislikes on the recipe card — one vote each way per recipe, and a guest voting from
  their own app on the recipes of the owner whose bar they read.

## Constraints

Single developer, AI-assisted. One reader per device, mobile-only. Simplicity wins. 
Telegram migration via external import file only.

## Success

Every requirement in [requirements.md](requirements.md) works reliably on the phone. 
Adoption is not a success criterion.
