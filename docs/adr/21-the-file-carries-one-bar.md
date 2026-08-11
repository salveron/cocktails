# ADR: The file carries one bar, the device keeps the rest

**Status:** Accepted

## Context

FR-DAT-1 now exports one bar of many, and FR-BAR-7 makes that same file a way a bar travels: one
file, two destinations — imported into an owned bar or added as a guest one. So the file has to say
enough for a stranger to hold the bar, and no more than a bar's owner would want to give.

FR-REC-6 is retired, so `made:` leaves the format. Dropping an optional key would not force a bump
on its own — a file without it was always legal — but a bump is coming for the reasons below, and
what it should carry all at once is the question.

FR-BAR-3/5 draw a line through `settings:`. On a guest bar the reading unit is the reader's and
outlives every refresh, while `part_ml` and `oz_ml` are the owner's and arrive with the payload that
replaces everything. One key of that block belongs to a different person from the other two, and a
refresh throws the block away.

## Decision

**Format 2. The file carries the collection and the bar's name; mode, source, refresh time and id
stay on the device. The reading unit leaves the collection and lives on the bar.**

- **`name:` at the top of the file.** A guest needs something to call the bar, Android hands over no
  filename worth showing (ADR 18), and the owner is the one who named it — a refresh takes the new
  name with everything else.
- **Mode, source, refresh time and id are never in the file.** Mode is the relationship between this
  device and the bar, not a property of the bar, and the same file makes either kind (FR-BAR-7).
  Source and refresh time are this device's record of how and when it got the bar. An id in the file
  would make an exported copy claim to be the original.
- **`Bar.display` holds the reading unit; `Settings` holds only the two ml sizes.** The pick
  physically cannot ride in the payload, so no refresh can lose it and no code has to remember not
  to take it. It still travels in the file, inside `settings:` where a reader expects it, as a
  starting value for whoever establishes a bar from it.
- **Establishing takes the file's `display`; refreshing keeps the bar's.** One difference, at two
  call sites, spelled by the type: a decode answers a `BarPayload` and the caller says what becomes
  of each of its three parts.
- **Format 1 is read on import and written back as 2**, its `made:` ignored rather than reported.
  The device's own format-1 store is migrated by that same route, so there is one reader of the old
  format rather than two.
- **The index carries the same `format:`** — one number for the whole on-disk layout.

## Alternatives considered

- **Metadata in the file, ignored on the wrong path**: fewer moving parts, one document per bar and
  no index. Refused: a `mode: owner` key would be a lie in every guest's copy, and the reader of a
  hand-editable file would be invited to change a thing the app must ignore.
- **A sidecar per bar instead of an index**: no single file to lose, and adding a bar is one write.
  Refused for the bar list — an index is one read where sidecars are one read per bar — and because
  the order of the list and which bar is open need a home of their own anyway. The index is backed
  up like a bar, and rebuildable from the bar files at the price of the modes and sources.
- **Reject format 1 outright (FR-DAT-4's "unsupported version")**: simplest gate, no dead branch.
  Refused because [architecture.md](../architecture.md#data-format) already promised bumps would
  migrate on import, and honouring it costs one branch and buys the reader every file they exported
  before today.
- **Keep `display` in `Settings` and carry it across a refresh by hand**: no signature moves at all.
  Refused as the weaker enforcement — the rule would live in a line of code rather than in the shape
  of the data, and a second refresh path would forget it.
- **Move `display:` to the file's top level, beside `name:`**: would mirror the split exactly.
  Refused because the grouping it suggests is false — `name` is the owner's and `display` the
  reader's, so top-level would mean two different things at once — and because a reader looking for
  how amounts read looks under `settings:`.

## Consequences

- `Settings` is two fields, and `displayMeasure` takes the pick as a parameter beside them.
- The bar's name and reading unit stand in two files at once, the bar's own and the index. The index
  is the authority; the file's copies are read only where a bar is established or the index rebuilt.
- The shareable copy is named from the bar, so a guest holding three of them can tell them apart
  ([architecture.md](../architecture.md#platform-facts)).
- A refresh from a file cannot tell one file from another: the file carries no id, and the reader's
  pick is the judgement (FR-BAR-7).
