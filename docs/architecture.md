# Architecture

Technical design for [requirements.md](requirements.md); direction [vision.md](vision.md); rationale [ADRs](adr/). System-level design; module-level in [components.md](components.md).

## Technology stack

- **Flutter (Dart)** targeting Android; desktop later ([ADR 01](adr/01-technology-stack.md)).
- **Riverpod** for state management ([ADR 03](adr/03-app-structure-and-state.md)).
- Development: Linux + physical Android phone over USB.
- Minimal dependencies: `flutter_riverpod`, `yaml`, `path_provider`, `share_plus`, `file_selector`. 
  Riverpod at 2.x (3.x adds unused packages). `scrollable_positioned_list` is the first taken for 
  ergonomics rather than structure ([ADR 13](adr/13-lists-scroll-by-index.md)), and the bar it sets 
  for the next: confined to one file, with the way out written down. `font_awesome_flutter` is the 
  next, taken under that bar ([ADR 14](adr/14-the-dice-comes-off-font-awesome.md)) — by caret where 
  the other is pinned, a package that still releases being the safer for keeping up with. Sharing 
  over a network adds to this list under the same bar 
  ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)); the list is pinned to pubspec.yaml by test, 
  so a package is named here in the change that takes it and never ahead of it.

## System overview

Offline app, many bars ([ADR 20](adr/20-the-app-holds-many-bars.md)), one resident (NFR-2).

- One YAML file per bar, byte-identical to that bar's export, and an index carrying the records 
  ([ADR 02](adr/02-persistence-and-export-format.md), [ADR 21](adr/21-the-file-carries-one-bar.md)).
- Export: file copy of one bar. Import: validate, keep a copy, atomically replace one bar's 
  contents, every other bar untouched.
- Names are identity inside a bar; recipes reference by name, case-insensitive 
  ([ADR 08](adr/08-names-ignore-case.md)). A bar's own name is a label, so a bar is told apart by an 
  id the device minted and never shares.
- Writes atomic (temp→rename); rolling backups, per bar and for the index. The app is the only 
  writer of its store, and a guest bar's collection has no writer but the refresh that replaces it 
  whole ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)).

## Bars

`Shelf` is the root ([components.md](components.md#the-shelf-and-the-bar)): every bar on device, which is open, and that bar's resident collection. Nothing crosses bars (FR-BAR-1): one collection is resident; switching bars discards UI state.

**Guest bar is read-only** (FR-BAR-3/4), enforced at domain, data, and UI layers ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)). Shopping destination absent rather than empty.

**The reading unit is the reader's, the sizes are the owner's** (FR-SET-1): `Bar.display` holds the 
pick, `Collection.settings` what a part and an ounce are worth in ml. They part company on a guest bar, 
where a refresh replaces the collection whole — a pick living in that payload would be thrown away 
with it ([ADR 21](adr/21-the-file-carries-one-bar.md)).

## Storage isolation

Persistence behind interface only: `BarStore` names no file and answers an export with an opaque 
location, so the store stays swappable by adapter replacement. The per-bar shape keeps that promise 
better than the whole-database one it replaces — a bar is a row, which is what SQLite would ask for.

- A save writes one file: the bar on show, or the index. Every other bar's bytes are neither read 
  nor rewritten, which is what makes a save cost the same whatever the device holds (NFR-2). The 
  index is written when a record moves — a rename, a refresh landing, an offer, a switch — never on 
  a collection edit.
- Recovery is per bar ([ADR 02](adr/02-persistence-and-export-format.md)): a bar that fails to 
  decode opens on its newest decodable backup and says why, the bars beside it untouched. A lost 
  index is rebuilt from the bar files, which carry their names, at the price of the modes, sources 
  and refresh times — so it is backed up on the same terms.
- **Migration**: a device carrying a format-1 `cocktails.yaml` and no index has it read as an import 
  would read it ([ADR 21](adr/21-the-file-carries-one-bar.md)) and written out as the device's first 
  owned bar, under a default name the reader may change (FR-BAR-2). The old file and its backups 
  stay exactly where they are, being the net the migration runs over; a second run finds an index 
  and does nothing.

## Sharing

Three ways a bar travels (FR-BAR-7/8/9) behind one seam 
([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). A **source** is a transport plus what that 
transport needs to ask again, kept with the guest bar so it refreshes from the thing it was added 
from. A fetch answers a value, never an exception: what arrived, what stopped it being read (the 
import's own judgement, FR-DAT-4), or that the source could not be reached — offline, not found, or 
withdrawn — which leaves the bar readable as it stood and says which (FR-BAR-5). It may also answer 
nothing at all, where the reader was asked and stood down.

- **File** (FR-BAR-7): the source is the reader, and holds no address to keep. A refresh opens the 
  document picker, so a file-sourced bar cannot be told from any other file picked for it — what 
  arrives replaces what stood, and the pick is the judgement; a picker dismissed leaves the bar 
  exactly as it was, having failed at nothing. Nothing to withdraw, nothing announced. **One picked 
  file has three destinations**, and which one it takes is settled on the one form that reads it: 
  the open bar's contents replaced (FR-DAT-3), a new bar of the reader's own founded from it 
  (FR-BAR-2), or a guest bar founded beside it (FR-BAR-7). Only the last keeps the source; none of 
  the three takes the file's name for the bar's, that being the reader's to leave or change 
  ([ADR 21](adr/21-the-file-carries-one-bar.md)).
- **LAN** (FR-BAR-8): an owner registers one DNS-SD service per offered bar and serves that bar over 
  a `dart:io` HTTP server on an unguessable path; a guest browses the service type, adds what it 
  finds and refreshes by GET. Discovery costs a package, the transfer none (ADR 22). Server and 
  service come up with the first offer and down with the last withdrawal, so a device sharing 
  nothing announces nothing (NFR-5). The instance name carries the bar's name and a short 
  discriminator off its id, so two bars of one name are two services and a guest is given something 
  besides the name to tell them by.
- **Cloud** (FR-BAR-9): the one way asking an identity (NFR-3) and the one needing a server. The 
  transport is declared and no adapter registered, the ways on offer being the ways that answer — so 
  the choice waits without holding the other two up.

Withdrawal (FR-BAR-6) stops an offer and nothing else: what a guest holds stays theirs, and their 
next refresh is told the source is gone. Sharing is not confidentiality — the LAN path is 
unguessable rather than authenticated, and a bar shared is a bar given.

## Data format

A bar's file — identical to that bar's export ([ADR 02](adr/02-persistence-and-export-format.md), 
[ADR 21](adr/21-the-file-carries-one-bar.md)). Example carrying every construct:

```yaml
format: 2
name: Home bar         # the bar's, a label rather than an identity (FR-BAR-1)

settings:
  part_ml: 30          # how many ml one part is (FR-SET-1)
  oz_ml: 29.5735       # and one ounce; ml is the anchor, so it needs none (ADR 17)
  display: part        # part | ml | oz — what the three read in; the reader's (ADR 21)

units:                                 # yours to manage (ADR 09)
  - {name: part, plural: parts}
  - {name: ml}                         # plural omitted = reads like the name
  - {name: oz}                         # fixed, like the two above (ADR 17)
  - {name: dash, plural: dashes}

ingredients:
  - {name: bourbon, stock: in, aliases: [bourbon whiskey]}  # also answers to (ADR 10)
  - {name: lemon juice, stock: low, tags: [citrus]}
  - {name: lime juice, tags: [citrus]}
  - {name: rich demerara syrup, tags: [syrup, homemade]}   # stock omitted = out
  - {name: egg white, stock: in}                           # untagged

ingredient_tags:                       # what a bottle can be labelled
  - {name: citrus, color: sand}
  - {name: homemade, color: slate}
  - {name: syrup, color: indigo}

recipe_tags:                           # a separate vocabulary (ADR 07)
  - {name: sour, color: rose}
  - {name: classic, color: teal}

recipes:
  - name: Whiskey Sour
    tags: [sour, classic]
    lines:
      - 1.5-2 parts bourbon (base)
      - 0.75 parts lemon juice / lime juice   # either one makes it (ADR 11)
      - 0.5 parts rich demerara syrup
      - 0.5 parts egg white (optional)
    notes: dry shake, then shake with ice
```

Rules:

- `format`: schema version, 2, and the version of the whole on-disk layout — the index below carries 
  the same number, one bump moving both. Unsupported versions rejected (FR-DAT-4). **Format 1 is 
  read on import and written back as 2**, its `made:` key ignored rather than reported, the one 
  exception to unknown keys below; nothing else reads it, the device's own format-1 file being 
  migrated through that same route.
- `name`: the bar's own, under the same value rules as every other name and under no uniqueness rule 
  at all (FR-BAR-1). Required; a format-1 file has none and is named by the reader adding it. Read 
  where a bar is founded from the file and nowhere else — like `display`, it is what the reader 
  starts from rather than what the bar is called ([ADR 21](adr/21-the-file-carries-one-bar.md)).
- `units`: measurement vocabulary ([ADR 09](adr/09-units-are-a-vocabulary.md)). `plural` 
  omitted where same as name. Absent = shipped seven (`part ml oz dash barspoon drop piece`). 
  Present = whole vocabulary. All spellings unique under fold; `part`/`ml`/`oz` required.
- `settings`: `part_ml` and `oz_ml` are the owner's, `display` the reader's — it and `name` are what 
  a guest bar's refresh does not take (FR-BAR-5, [ADR 21](adr/21-the-file-carries-one-bar.md)).
- Ingredient entries: `name` required; `stock` = `in`|`low`|`out` (default); `tags` and 
  `aliases` (optional). Names and aliases: one namespace, unique under fold, no commas. 
  References resolve by any spelling, stored under entry's name.
- Tag entries: `name` and `color` required (palette: [ADR 07](adr/07-tag-colour.md)). 
  Two vocabularies separate; one name may exist in both.
- A `tags` list — on a recipe or on an ingredient — holds names only, resolved against that
  side's vocabulary. The colour lives with the tag, once.
- Line: `<amount> [unit] <ingredient>` with optional mark ` (base)` or ` (optional)`, 
  never both ([ADR 06](adr/06-base-spirit-on-the-line.md)). Amount: decimal or range `a-b`. 
  Unit: optional, resolves against vocabulary (name or plural), omitted = `part` (FR-REC-2). 
  Writer emits singular for 1, plural otherwise. Accepts input plurals. Unknown units reported.
- Alternatives on a line: `/`-separated, spaces optional on input, written back as ` / ` 
  ([ADR 11](adr/11-substitutions-on-the-line.md), FR-REC-9). Split is lexical — after the unit, 
  after the mark — so one amount, unit and mark govern the group and no reading depends on the 
  vocabulary. `/` barred from every ingredient spelling; a name repeated on one line reported.
- References must resolve to matching vocabulary; names unique within kind ([ADR 08](adr/08-names-ignore-case.md)). 
  Spelling preserved. Value rules (FR-DAT-4): names non-empty, single-line, no surrounding 
  whitespace; amounts positive, range ends ordered; no duplicate tags. Unknown keys are structural 
  errors, and validation failures report the YAML line and the offending value.
- App writes canonical form (fixed order, indentation, no comments) from a custom emitter spec'd 
  here and pinned by round-trip tests. FR-DAT-5 covers content only: hand-written 
  `1.50 2 dash 1 gin` normalises to `1.5 2 dashes 1 part gin`, byte-identical from the app's own 
  output onward.
- Tokens declared as enum fields (stock, display, mark, colour, mode, transport), not Dart 
  identifiers (ADR 09).

The index is device state rather than an export: it travels nowhere and is the one file no reader is 
meant to open, written by the same canonical emitter and judged by the same rules.

```yaml
format: 2
open: 5f2c9a           # the bar on show; the key stays, valueless, where none is

bars:
  - {id: 5f2c9a, name: Home bar, mode: owner, display: part, offers: [{via: lan}], updated: "2026-08-14T09:12:00.000Z", holds: {recipe: 12, ingredient: 30, tag: 8, unit: 7}}
  - {id: b3e1d7, name: Home bar, mode: guest, display: ml, refreshed: "2026-08-09T18:22:04.000Z", holds: {recipe: 40, ingredient: 55, tag: 3, unit: 7}, source: {via: lan, at: _cocktails._tcp/x, from: Home bar (b3e)}}
```

One record, one line: the halves a mode rules out are left off as every default is, and a timestamp
is quoted because its colons would otherwise end the scalar in flow context.

`id` is opaque, minted here, unique within the index and never written to a bar's own file. `mode` 
is `owner`|`guest`; `via` is `file`|`lan`|`cloud`, `at` the transport's own business, `from` what to 
call the source where one is read. `offers` is an owner's, one entry per way a bar is shared, 
carrying the guests it names where the way can (FR-BAR-6); `source` and `refreshed` are a guest's,
`updated` an owner's. `holds` is what the bar list reads it by, one count per `Holding` under a token
of its own — optional, like `updated`: a record written before summaries existed carries neither, and
the startup load counts that bar once and writes the index back (ADR 20). A `holds` missing a kind is
dropped whole rather than read as a bar that holds none of it.

## Domain computations

- **Availability** (required lines only): all `in` = makeable; none `out` but some `low` = makeable-low; 
  any `out` = missing. A line stands at its best-stocked alternative (`stockOfLine`, FR-REC-9). 
  Derived provider, never stored. Lost bottles read as `out`.
- **Base spirit** (FR-DIS-4, [ADR 12](adr/12-base-spirit-narrows.md)): a predicate, not a placement. 
  Every alternative of every base line counts, so a group matches under each bottle it names; the 
  spirits offered are read off the recipes, deduped by name key and read A→Z.
- **Random pick** (FR-DIS-5): drawn from the rows on show, so every narrowing already holds; 
  `canMake` is the one reading of what counts (low does, unjudged does not), shared with the 
  optimizer below. The draw moves off the recipe already standing while another can be made, so a 
  second roll always answers differently.
- **Optimizer** (FR-DIS-6, [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)): a missing 
  recipe's gap is not one set of bottles but a choice between several — any one alternative of a 
  group closes its line (ADR 11) — so the ways of making it are the cross product over the lines it 
  is short of, cut at N. The bottles worth weighing are exactly those gaps', and every basket of ≤ N 
  drawn from them is scored by the recipes some part of it closes. A basket must beat each of its 
  own smaller selves, or it *is* one of them carrying a passenger; a sub-basket's recipes being 
  always a subset, comparing counts settles it. Ranked by recipes unlocked, then fewest bottles, 
  then A→Z. Zero-yield never arises — it cannot beat its own parts. What counts as short is the 
  one thing the reader sets ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)): out of 
  stock, or anything short of full stock, which is what puts the bottles running low in the pool. 
  Keeping the best few *of each size* is also what makes one search answer every budget, since the 
  bottles a wider one adds close nothing on their own ([components.md](components.md#computations)).
- **Line parsing**: shared parser/formatter, both routes (form, codec); takes unit vocabulary 
  (decides unit vs. name). Codec reads `units` first.
- **Display transforms** (FR-REC-7, FR-SET-1): factor multiplies amounts (range ends together); 
  a line in one fixed unit converts into the one the bar's `display` names, through the two ml sizes 
  ([ADR 17](adr/17-the-fixed-units-interconvert.md)). ×1 in the bar's own unit = the card at 
  rest. Rounded to 2 decimals.
- **A refresh lands whole** (FR-BAR-5): what arrives is judged as an imported file is (FR-DAT-4), and 
  only then replaces the guest bar's collection and refresh time together. Nothing is merged and 
  nothing compared; the bar's `display` survives by never having been in the payload and its `name` 
  by being out of `refreshedAt`'s reach, and what fails to pass leaves the bar exactly as it was.

## Platform facts

- App-private directory: `shelf.yaml` and `bars/<id>.yaml`, each with three rolling backups beside 
  it (`shelf.backup-1/2/3.yaml`, `bars/<id>.backup-1/2/3.yaml`). The copies that leave or stand 
  behind sit at the top: the shareable one under a basename folded from the bar's name 
  (`home-bar.yaml`, `bar.yaml` where nothing survives the fold), so a guest holding three of them can 
  tell one from another, and `cocktails-before-import.yaml` / `cocktails-before-delete.yaml`, the 
  nets FR-DAT-3 and FR-BAR-2 ask for. Writes via `.tmp` + rename.
- The copy leaves through the Android share sheet, over the `FileProvider` `share_plus` ships 
  ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)); the plugin re-copies it into 
  `cacheDir/share_plus/`, so the receiving app sees the basename above. The share provider's 
  manifest entry is the plugin's own; the internet permission the LAN transport needs is the first 
  that is ours (ADR 22).
- A file comes back through `ACTION_OPEN_DOCUMENT` on `file_selector`, so no layer here holds a 
  `content://` URI. The Android plugin answers with an `XFile.fromData` — the bytes, not a path to 
  them — and `XFile.readAsString` **drops the encoding asked of it** on that branch, decoding byte 
  per character; `Orange Curaçao` came back `Orange CuraÃ§ao`. The pick seam decodes UTF-8 itself and 
  refuses malformed input rather than substituting, a U+FFFD being the same loss made quieter. The 
  nets are written and never read: nothing in the app opens one, and app-private storage puts them 
  past the reader as well. What they buy is that the bytes are still there — for a later version to 
  offer, or for `adb` to pull — not a way back today.
- Android Auto Backup carries the whole app-private data directory, declared in `backup_rules.xml` 
  (API 24–30) and `data_extraction_rules.xml` (31+, cloud backup and device transfer alike). The 
  `root` domain rather than `file`: `path_provider`'s documents directory is `app_flutter/`, a 
  sibling of `files/` and not a child, so a `file` rule would carry nothing at all. Tens of bars of 
  hundreds of recipes run to single-digit MB, ×4 for the rolling backups beside them — inside the 
  25 MB quota, which is what makes carrying the rotation affordable rather than worth excluding 
  (neither rules format has a wildcard to exclude it with).
- Application ID: `dev.salveron.cocktails`.
- Minimum Android: Flutter's own default, taken as it moves (minSdk 24 today).
- UI: English only.

## Build & distribution

- APK built locally, sideloaded; no Play Store yet. The universal APK carries three ABIs and runs 
  about 53 MB; `--split-per-abi` roughly thirds it where one device is the target.
- **Release keystore outside the repo**, named by `android/key.properties` (`storeFile` — relative 
  to `android/` or absolute — `storePassword`, `keyAlias`, `keyPassword`). Both the properties file 
  and `*.jks`/`*.keystore` are gitignored. Made once and kept, because it is the app's identity: 
  Android tells two builds apart by signature, and Play Store would bind to this same certificate, 
  so replacing it is not an option a later release has.
  ```
  keytool -genkey -v -keystore <path>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cocktails
  ```
- **A release build with no `key.properties` is refused**, not quietly signed with the debug key. A 
  debug-signed APK cannot update one signed anywhere else, and the only way past that is an 
  uninstall — which takes every bar on the device with it.
- CI builds the release APK against a throwaway key of its own. That is what puts R8 on every push 
  rather than on the one machine that packages the real thing; debug builds never run it.

## Testing

- **Unit tests** (pure Dart, no device): availability, discovery, optimizer, validation, 
  YAML round-trip (FR-DAT-5), shelf invariants and the guest-bar refusal (ADR 23).
- **Integration tests**: atomic write, backup rotation, corrupt-file recovery, a save of one bar 
  leaving every other bar's bytes untouched, the format-1 migration, and the LAN adapter against its 
  own loopback server.
- **Widget tests**: recipe form, stock toggle, import confirmation, list search and filtering, a 
  guest bar offering no way to write and no shopping destination.
- CI: format check, `flutter analyze`, test suite, local APK build on every push.
