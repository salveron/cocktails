# Architecture

Technical design for [requirements.md](requirements.md); direction [vision.md](vision.md); rationale [ADRs](adr/). System-level design; module-level in [components.md](components.md).

## Technology stack

- **Flutter (Dart)** targeting Android; desktop later ([ADR 01](adr/01-technology-stack.md)).
- **Riverpod** for state management ([ADR 03](adr/03-app-structure-and-state.md)).
- Development: Linux + physical Android phone over USB.
- Minimal dependencies: `flutter_riverpod`, `yaml`, `path_provider`, `share_plus`, `file_selector`. Riverpod at 2.x (3.x adds unused packages). `scrollable_positioned_list`, pinned exactly, was taken for ergonomics and set the bar for the rest: confined to one file, way out written down ([ADR 13](adr/13-lists-scroll-by-index.md)). `font_awesome_flutter` ([ADR 14](adr/14-the-dice-comes-off-font-awesome.md)) and `bonsoir` took that bar too, both by caret: a package that still releases is safer to keep up with. `bonsoir` is the first network package, for DNS-SD on the LAN transport ([ADR 27](adr/27-nearby-comes-off-bonsoir.md), [ADR 22](adr/22-a-bar-travels-behind-one-seam.md)), and the largest transitive tail yet: five sub-packages and a D-Bus stack under the Linux one. The test pins this list to pubspec.yaml: a package is named here in the change that takes it, never ahead.

## System overview

Offline app, many bars ([ADR 20](adr/20-the-app-holds-many-bars.md)), one resident (NFR-2).

- One YAML file per bar, byte-identical to its export, plus an index carrying the records ([ADR 02](adr/02-persistence-and-export-format.md), [ADR 21](adr/21-the-file-carries-one-bar.md)).
- Export: file copy of one bar. Import: validate, keep a copy, atomically replace that bar; others untouched.
- Names are identity inside a bar; recipes reference by name, case-insensitive ([ADR 08](adr/08-names-ignore-case.md)). A bar's name is a label; a device-minted id it never shares tells bars apart.
- Writes atomic (`.tmp` + rename), with rolling backups per bar and for the index. The app is the only writer; a guest bar has no writer but the refresh that replaces it whole ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)).

## Bars

The shelf's shape and its "nothing crosses" guarantee (FR-BAR-1) are [components.md](components.md#the-shelf-and-the-bar)'s; the reader's reading unit against owner-kept sizes is [ADR 21](adr/21-the-file-carries-one-bar.md)'s (FR-SET-1).

**Guest bar is read-only** (FR-BAR-3/4), enforced at domain, data and UI layers ([ADR 23](adr/23-nothing-writes-a-guest-bar.md)). Shopping destination absent, not empty.

## Storage isolation

Persistence sits behind an interface: `BarStore` names no file and answers an export with an opaque location, so an adapter can replace the store. A row per bar, as SQLite would ask, keeps that better than a whole database.

- A save writes one file: the bar on show, or the index. Other bars are neither read nor rewritten, so a save costs the same whatever the device holds (NFR-2). The index is written when a record moves (rename, refresh landing, offer, switch), never on a collection edit.
- Recovery is per bar ([ADR 02](adr/02-persistence-and-export-format.md)): a bar that fails to decode opens on its newest decodable backup and says why; neighbours untouched. A lost index is rebuilt from the bar files, which carry names, at the cost of modes, sources and refresh times, so it is backed up on the same terms.
- **Migration**: a format-1 `cocktails.yaml` with no index is read as an import would read it ([ADR 21](adr/21-the-file-carries-one-bar.md)) and written as the device's first owned bar, under a default name the reader may change (FR-BAR-2). The old file and backups stay in place as the net; a second run finds an index and does nothing.

## Sharing

Two ways a bar travels (FR-BAR-7/8), behind one seam ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). A **source** is a transport plus what it needs to ask again, kept with the guest bar, which refreshes from the way it was added and no other (FR-BAR-5). A fetch answers a value, never an exception: what arrived; what failed the import's judgement (FR-DAT-4); the source unreachable (`offline`, `notFound`, `withdrawn`), leaving the bar readable and saying which (FR-BAR-5); or nothing, where the reader stood down.

- **File** (FR-BAR-7): the source is the reader; it holds no address. A refresh opens the picker, so a file-sourced bar cannot be told from any other file picked for it: the pick is the judgement, and what arrives replaces what stood. A dismissed picker leaves the bar as it was, having failed at nothing. Nothing to withdraw or announce. **One picked file has three destinations**, settled by the form that reads it: the open bar's contents replaced (FR-DAT-3), a new owned bar founded from it (FR-BAR-2), or a guest bar founded beside it (FR-BAR-7), the only one keeping the source. None takes the file's name for the bar's ([ADR 21](adr/21-the-file-carries-one-bar.md)).
- **LAN** (FR-BAR-8): an owner's or guest's device announces itself once on DNS-SD and serves over a `dart:io` HTTP server: its offered list, and each bar's bytes at an unguessable path. Discovery costs a package; transfer none. **One server and one service instance per device**, whatever it shares: up with the first offer, down with the last withdrawal, so a device sharing nothing announces nothing (NFR-5). A guest keeps the instance name and the bar's id, never an address, and resolves afresh on every ask. Where the ask stopped gives the reason: **no non-loopback interface** is `offline`; an instance absent from a browse is `notFound`; a list not naming the bar, or a path answering nothing, is `withdrawn` ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)). The source string is the bar id and instance name, id leading, since only it has an alphabet the split can trust. Offers last only as long as the app: the record goes back to not-shared at the next load.

Withdrawal (FR-BAR-6) stops an offer and nothing else: a guest keeps what it holds, and its next refresh is told the source is gone. Sharing is not confidentiality: the LAN path is unguessable, not authenticated, and a bar shared is a bar given ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)).

## Data format

A bar's file, identical to its export ([ADR 02](adr/02-persistence-and-export-format.md), [ADR 21](adr/21-the-file-carries-one-bar.md)). Example carrying every construct:

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

ingredient_tags:                       # what an ingredient can be labelled
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

- `format`: schema and layout version, 2, shared with the index; one bump moves both. Unsupported versions rejected (FR-DAT-4). **Format 1 is read on import and written back as 2**, its `made:` key ignored rather than reported: the one exception to unknown keys. Nothing else reads it; the device's own format-1 file migrates by that route.
- `name`: the bar's own, under the value rules of any name and no uniqueness (FR-BAR-1). Required; a format-1 file has none, so its adder names it. A starting value only: read when founding a bar, never on refresh ([ADR 21](adr/21-the-file-carries-one-bar.md)).
- `units`: measurement vocabulary ([ADR 09](adr/09-units-are-a-vocabulary.md)). `plural` omitted where it equals the name. Absent = shipped seven (`part ml oz dash barspoon drop piece`); present = whole vocabulary. Spellings unique under fold; `part`/`ml`/`oz` required.
- `settings`: `part_ml` and `oz_ml` are the owner's, `display` the reader's. `display` and `name` are what a guest bar's refresh does not take (FR-BAR-5, [ADR 21](adr/21-the-file-carries-one-bar.md)).
- Ingredients: `name` required; `stock` = `in`|`low`|`out` (default); `tags` and `aliases` optional. Names and aliases share one namespace: unique under fold, no commas. References resolve by any spelling and are stored under the entry's name.
- Tags: `name` and `color` required (palette: [ADR 07](adr/07-tag-colour.md)). The two vocabularies are separate; a name may exist in both.
- A recipe's or ingredient's `tags` list holds names only, resolved in that side's vocabulary; the colour lives with the tag, once.
- Line: `<amount> [unit] <ingredient>`, with an optional mark ` (base)` or ` (optional)`, never both ([ADR 06](adr/06-base-spirit-on-the-line.md)). Amount: decimal or range `a-b`. Unit: optional, by name or plural; omitted = `part` (FR-REC-2). The writer emits singular for 1, plural otherwise; input plurals are accepted; unknown units are reported.
- Alternatives: `/`-separated, spaces optional on input, written back as ` / ` ([ADR 11](adr/11-substitutions-on-the-line.md), FR-REC-9). The split is lexical (after unit, after mark): one amount, unit and mark govern the group, and no reading depends on the vocabulary. `/` is barred from every ingredient spelling; a name repeated on one line is reported.
- References resolve to matching vocabulary; names are unique within kind ([ADR 08](adr/08-names-ignore-case.md)); spelling is preserved. Value rules (FR-DAT-4): names non-empty, single-line, no surrounding whitespace; amounts positive, range ends ordered; no duplicate tags. Unknown keys are structural errors; failures report the YAML line and offending value.
- The app writes canonical form (fixed order, indentation, no comments) via the emitter specified here, pinned by round-trip tests. FR-DAT-5 covers content only: hand-written `1.50 2 dash 1 gin` normalises to `1.5 2 dashes 1 part gin`, byte-identical from the app's own output onward.
- Enum fields, not Dart identifiers: stock, display, mark, colour, mode, transport (ADR 09).

The index is device state: it travels nowhere, and no reader is meant to open it; the same emitter and rules apply.

```yaml
format: 2
device: Nikita's phone # what this device announces itself as; left off until named
open: 5f2c9a           # the bar on show; the key stays, valueless, where none is

bars:
  - {id: 5f2c9a, name: Home bar, mode: owner, display: part, shopping: {aim: true, budget: 2, low: false, most: 25, optional: false}, offers: [{via: lan}], updated: "2026-08-14T09:12:00.000Z", holds: {recipe: 12, ingredient: 30, tag: 8, unit: 7}}
  - {id: b3e1d7, name: Home bar, mode: guest, display: ml, refreshed: "2026-08-09T18:22:04.000Z", holds: {recipe: 40, ingredient: 55, tag: 3, unit: 7}, source: {via: lan, at: _cocktails._tcp/x, from: Home bar (b3e)}}
```

One record, one line. Halves a mode rules out are left off, as defaults are; timestamps are quoted, as colons would end the scalar in flow context.

`device`: the name the LAN announces under ([ADR 28](adr/28-the-device-is-named-by-its-reader.md)); the reader's, judged by the name rules, left off until given (the phone's own name stands in). `id`: opaque, minted here, unique in the index, never in a bar's own file. `mode`: `owner`|`guest`. `via`: `file`|`lan`|`cloud`. `at`: the transport's business. `from`: what to call the source where one is read. `offers`: either mode's; one entry per way a bar is shared, naming guests where the way can (FR-BAR-6). `source` and `refreshed`: guest's; `updated`: owner's. `holds`: what the bar list reads, one count per `Holding` under its own token. Optional like `updated`: a record written before summaries carries neither, and the startup load counts that bar once and writes the index back (ADR 20). A `holds` missing a kind is dropped whole, not read as a bar holding none of it.

`shopping`: what the optimizer is asked (FR-SET-2, [ADR 24](adr/24-the-tags-may-aim-the-optimizer.md)). The reader's, hence here, not in the bar's file. Left off while nothing in it has moved; written whole once anything has. Absent means defaults, so an old record reads as the answer the app gave then; no migration runs. `budget` and `most` must be values their screen offers; `validateShelf` refuses others.

The offered list is the one document written to the wire, not disk, and the only one a stranger reads (FR-BAR-8, [ADR 22](adr/22-a-bar-travels-behind-one-seam.md)):

```yaml
lan_format: 1

bars:
  - {id: 5f2c9a, name: Home bar, path: 3f9c1e5a7b2d4e8f0a6c9b1d3e5f7a2c}
```

`lan_format` moves with the LAN protocol, not the schema: a storage bump must not turn away a guest whose list never changed. The check runs at discovery, before the bar's own version gate. Three fields and no more: a projection of a bar, never a record. Nothing a device keeps to itself goes on the wire, not the open bar, nor a guest bar's own source. `path` is drawn per run from secure randomness, never stored, and may be rotated freely; it is the whole of a shared bar's protection.

## Domain computations

- **Availability** (required lines only): all `in` = makeable; no `out`, some `low` = makeable-low; any `out` = missing. A line stands at its best-stocked alternative (`stockOfLine`, FR-REC-9). Derived, never stored; lost ingredients read as `out`.
- **Base spirit** (FR-DIS-4, [ADR 12](adr/12-base-spirit-narrows.md)): a predicate, not a placement. Every alternative of every base line counts, so a group matches under each ingredient it names. Spirits offered come off the recipes, deduped by name key, A→Z.
- **Random pick** (FR-DIS-5): drawn from the rows on show, so every narrowing holds. `canMake` is the one reading of what counts (low does, unjudged does not), shared with the optimizer. While another recipe can be made, the draw moves off the standing one, so a second roll always differs.
- **Optimizer** (FR-DIS-6, [ADR 15](adr/15-the-optimizer-answers-with-the-best-few.md)): a missing recipe's gap is a choice of ingredient sets, since any one alternative of a group closes its line ([ADR 11](adr/11-substitutions-on-the-line.md)). Its ways of making are the cross product over its short lines, cut at N. Only gap ingredients are weighed; every basket of ≤ N from them is scored by the recipes some part of it closes. A basket must beat each of its smaller selves, or it carries a passenger. Zero yield never arises: it cannot beat its parts. Ranked by recipes unlocked, then fewest ingredients, then A→Z. The reader sets "short" ([ADR 16](adr/16-the-optimizer-buys-what-is-running-low.md)): out of stock, or short of full stock, which puts low ingredients in the pool. Keeping the best few *of each size* lets one search answer every budget, as the ingredients a wider one adds close nothing on their own ([components.md#computations](components.md#computations)).
- **Line parsing**: one parser/formatter for both routes (form, codec), taking the unit vocabulary, which decides unit vs. name. The codec reads `units` first.
- **Display transforms** (FR-REC-7, FR-SET-1): factor multiplies amounts, range ends together. A fixed-unit line converts into the `display` unit through the two ml sizes ([ADR 17](adr/17-the-fixed-units-interconvert.md)). ×1 in the bar's own unit is the card at rest. Rounded to 2 decimals.
- **A refresh lands whole** (FR-BAR-5): what arrives is judged as an imported file is (FR-DAT-4), then replaces the guest collection and refresh time together. Nothing is merged or compared; `display` survives by never being in the payload, and `name` by being out of `refreshedAt`'s reach. What fails leaves the bar as it was.

## Platform facts

- App-private directory: `shelf.yaml` and `bars/<id>.yaml`, each with three rolling backups (`shelf.backup-1/2/3.yaml`, `bars/<id>.backup-1/2/3.yaml`). Copies that leave or stand behind sit at the top: the shareable one under a basename folded from the bar's name (`home-bar.yaml`; `bar.yaml` where nothing survives the fold), so a guest holding three can tell them apart; and `cocktails-before-import.yaml` / `cocktails-before-delete.yaml`, the nets FR-DAT-3 and FR-BAR-2 ask for.
- The copy leaves by the Android share sheet, over `share_plus`'s `FileProvider` ([ADR 18](adr/18-data-crosses-the-edge-in-a-system-sheet.md)); the plugin re-copies it to `cacheDir/share_plus/`, so the receiver sees the basename above. That manifest entry is the plugin's; the LAN permissions below are the first that are ours ([ADR 22](adr/22-a-bar-travels-behind-one-seam.md)).
- A file returns through `ACTION_OPEN_DOCUMENT` on `file_selector`; no layer holds a `content://` URI. The plugin answers with `XFile.fromData` (bytes, not a path), and `XFile.readAsString` **drops the encoding asked of it** there, decoding byte per character: `Orange Curaçao` came back `Orange CuraÃ§ao`. The pick seam decodes UTF-8 itself and refuses malformed input; a U+FFFD is the same loss made quieter. The nets are written and never read, and app-private storage puts them past the reader too; they keep the bytes for a later version or for `adb` to pull, not a way back today.
- DNS-SD announces and browses through the plugin's platform APIs ([ADR 27](adr/27-nearby-comes-off-bonsoir.md)). The app declares `INTERNET` and `CHANGE_WIFI_MULTICAST_STATE` itself. **A service is reached at an address, never at a name**: Android resolves no `.local` hostname from a socket. Verified on the round trip: the address may be **IPv6-only** (the development machine has one global IPv6 address and no IPv4), so a URL built from it must bracket the host; and a service is announced with its port but *found* without one, the port arriving only with the resolve, so nothing is reached off a found service alone. On the phone, a register and a browse ask for **nothing beyond those two**: `NEARBY_WIFI_DEVICES` gates the Wi-Fi APIs, not the NSD path, so discovery runs without it.
- **The LAN's announced name is read from the phone's settings** through the app's first `MethodChannel`, the only Kotlin it writes: `Settings.Global.DEVICE_NAME`, world-readable, no permission, no manifest entry. It is the value the reader starts from and overwrites, never announced on its own ([ADR 28](adr/28-the-device-is-named-by-its-reader.md)). A never-named phone, or any non-Android host, answers nothing and the app falls back to a constant.
- **A runtime local-network prompt is coming, dated not sudden.** `targetSdk` is Flutter's default as it moves: 36 today, and the NSD path asks for no permission at that target (above). Android 16 makes local-network access restrictable opt-in; Android 17 makes it mandatory behind `ACCESS_LOCAL_NETWORK`, a runtime permission with a system dialog. Once the default reaches 37, the reader meets it on the first offer or look-up, and a refusal needs wording FR-BAR-8 lacks ([ADR 27](adr/27-nearby-comes-off-bonsoir.md)).
- Android Auto Backup carries the whole app-private data directory, declared in `backup_rules.xml` (API 24–30) and `data_extraction_rules.xml` (31+, cloud backup and device transfer alike). Use the `root` domain, not `file`: `path_provider`'s documents directory is `app_flutter/`, a sibling of `files/` rather than a child, so a `file` rule would carry nothing. Tens of bars of hundreds of recipes run to single-digit MB, ×4 with rolling backups, inside the 25 MB quota: carrying the rotation is affordable, not worth excluding, and neither rules format has a wildcard to exclude it with.
- Application ID: `dev.salveron.cocktails`, with `.debug` added on debug builds, so a device run installs beside the release app rather than updating it (the signatures differ). The share provider's authority derives from the id and follows the suffix. A debug build has its own storage: a device run never reads the reader's bars.
- Minimum Android: Flutter's own default, taken as it moves (minSdk 24, targetSdk 36 today).
- UI: English only.

## Build & distribution

- APK built locally and sideloaded; no Play Store yet. The universal APK carries three ABIs, about 53 MB; `--split-per-abi` roughly thirds it where one device is the target.
- **Release keystore outside the repo**, named by `android/key.properties` (`storeFile`, relative to `android/` or absolute; `storePassword`; `keyAlias`; `keyPassword`). The properties file and `*.jks`/`*.keystore` are gitignored. Made once and kept as the app's identity: Android tells builds apart by signature, and a Play Store listing would bind to this certificate, so no later release can replace it.
  ```
  keytool -genkey -v -keystore <path>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cocktails
  ```
- **A release build with no `key.properties` is refused**, not quietly signed with the debug key. A debug-signed APK cannot update one signed elsewhere; the only way past that is an uninstall, which takes every bar on the device with it.
- **The build's JDK is pinned to 21** in `android/gradle/gradle-daemon-jvm.properties` and CI's `setup-java`, not whichever `java` leads `PATH` (a distro upgrade once made that a JRE-only 25 with no compiler). Gradle finds an installed JDK 21 itself; with none, it refuses by name rather than falling back. The other inputs are already fixed: `pubspec.lock`, the Gradle wrapper, AGP and Kotlin in `settings.gradle.kts`, and Flutter in CI.
- CI builds the release APK against a throwaway key, putting R8 on every push, not only on the one machine that packages the real thing; debug builds never run it.

## Testing

Strategy and organization: [components.md](components.md#testing). CI: format check, `flutter analyze`, test suite, local APK build on every push.
