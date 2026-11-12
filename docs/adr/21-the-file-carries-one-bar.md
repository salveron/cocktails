# ADR: The file carries one bar, the device keeps the rest

**Status:** Accepted

## Context

FR-DAT-1 now exports one bar of many; FR-BAR-7 makes that file a way a bar travels: one file, two destinations (an owned bar imported, or a guest one added). So the file says enough for a stranger to hold the bar, and no more than its owner would give.

FR-REC-6 is retired, so `made:` leaves the format. Dropping an optional key alone forces no bump (a file without it was always legal), but a bump is coming: the question is what it should carry all at once.

FR-BAR-3/5 draw a line through `settings:`. On a guest bar the reading unit is the reader's and outlives every refresh; `part_ml` and `oz_ml` are the owner's and arrive with the payload that replaces everything. One key of that block belongs to a different person from the other two, and a refresh throws the block away.

## Decision

**Format 2. The file carries the collection and the bar's name; mode, source, refresh time and id stay on the device. The reading unit leaves the collection and lives on the bar.**

- **`name:` is a starting value, not a synced field.** A guest needs a name to call the bar; Android offers no filename worth showing (ADR 18). The owner named it, but the file's name is only what whoever founds a bar from it *starts* with (FR-BAR-2/3), read nowhere else. A refresh never moves it: a reader's rename must not be silently overwritten by someone else's next refresh.
- **Mode, source, refresh time, id, `updated:` and `holds:` are never in the file.** Mode is the device's relationship to the bar, so the same file makes either kind (FR-BAR-7). Source and refresh time record how this device got the bar; an id in the file would make a copy claim to be the original. `updated:` (when contents last changed here) and `holds:` (the per-kind count, [ADR 20](20-the-app-holds-many-bars.md)) are this device's history: a bar is counted where it lands, not by trusting a travelled number.
- **Both are optional keys on the index's records; format 2 did not move.** An index written before they existed decodes as a bar not yet summarised, which the reader repairs rather than refuses. A `holds:` missing a kind is dropped whole, not zero-patched: a partial count looks like a bar holding nothing.
- **`Bar.display` holds the reading unit; `UnitSizes` holds only the two ml sizes** (renamed from `Settings`, since it never stores a reading unit). The pick cannot ride in the payload, so no refresh can lose it and no code must remember not to take it. It still travels in the file, inside `settings:` where readers look, as a starting value for whoever establishes a bar.
- **`shopping:` joins the guest-refused half of the record beside `source`, `refreshed` and `updated`.** `Bar.shopping` is `ShoppingSettings?`, null on a guest and refused wherever one is found anyway ([ADR 24](24-the-tags-may-aim-the-optimizer.md)): the same "refused on the wrong mode" rule this ADR applies to the other three.
- **Establishing takes the file's `name:` and `display`; refreshing keeps the bar's.** The difference sits at two call sites, spelled by type: a decode answers a `BarContent`, and the caller says what becomes of each of its three parts. `Bar.refreshedAt` reaches neither (it takes only the collection and stamp), so no refresh can lose a reader's pick. Founding passes a name in: `addOwnedBar`, `addGuestBar` and `replaceOpen` take it beside the payload.
- **Format 1 is read on import and written back as 2**, its `made:` ignored, not reported. The device's own format-1 store migrates by the same route: one reader of the old format, not two.
- **The index carries the same `format:`**: one number for the whole on-disk layout.

## Alternatives considered

- **Metadata in the file, ignored on the wrong path**: fewer moving parts, one document per bar, no index. Refused: a `mode: owner` key would lie in every guest's copy, and a hand-editable file would invite changing what the app must ignore.
- **A sidecar per bar, not an index**: no single file to lose; adding a bar is one write. Refused for the bar list: an index is one read where sidecars are one per bar, and list order and the open bar need a home anyway. The index is backed up like a bar and rebuildable from bar files, at the price of modes and sources.
- **Reject format 1 outright (FR-DAT-4's "unsupported version")**: simplest gate, no dead branch. Refused: [architecture.md](../architecture.md#data-format) already promised bumps would migrate on import; honouring it costs one branch and buys the reader every file exported before today.
- **Keep `display` in `Settings`, carried across a refresh by hand**: no signature moves. Refused as weaker enforcement: the rule would live in a line of code, not the shape of the data, and a second refresh path would forget it.
- **Move `display:` to the top level, beside `name:`**: mirrors the split exactly. Refused: the grouping is false (`name` is the owner's, `display` the reader's; top level would mean two things at once), and a reader looking for how amounts read looks under `settings:`.

## Consequences

- `UnitSizes` is two fields; `scaledAmountText` takes the pick as a parameter beside them.
- The bar's name and reading unit stand in two files: the bar's own and the index. The index is the authority; the file's copies are read only where a bar is established or the index rebuilt. On a guest bar they disagree from the first rename onward, correctly: the file says what its owner calls the bar, the index what this reader calls it.
- The shareable copy is named from the bar, so a guest holding three can tell them apart ([architecture.md](../architecture.md#platform-facts)).
- A refresh from a file cannot tell one file from another: no id in the file; the reader's pick is the judgement (FR-BAR-7).
