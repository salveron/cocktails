# ADR: Data crosses the edge in a system sheet, both ways

**Status:** Accepted

## Context

[FR-DAT-1](../requirements.md) sends the collection out: one action exports everything to a text
file, "shareable via platform file sharing". [FR-DAT-3/4](../requirements.md) bring one back: one
action imports a file, replacing the database, after confirmation and validation. They are M24 and
M25 — but they are one seam read twice, and settling only the outgoing half would leave the two free
to drift into different metaphors, different packages and different types.

The data layer already answers the inner half of both. `ModelStore.exportSnapshot` writes
`cocktails-export.yaml` beside the store and returns its location, opaque by design so the UI never
learns it is a path; import is `YamlCodec.decode` then `save`, deliberately not a store method so the
confirmation and the pre-import export can slot between
([components.md](../components.md#data-contracts)). What is missing at both ends is the platform.

**Android will not take a path on the way out.** Since API 24 a `file://` URI in an outgoing intent
throws `FileUriExposedException`, so a shared file travels as a `content://` URI from a declared
`FileProvider`, with read permission granted to whichever app the reader picks: a `<provider>`, an
`xml/file_paths` resource, `FileProvider.getUriForFile`, `ACTION_SEND` carrying `EXTRA_STREAM` and
`FLAG_GRANT_READ_URI_PERMISSION`, and `Intent.createChooser` around it.

**Android will not give a path on the way in.** The Storage Access Framework answers
`ACTION_OPEN_DOCUMENT` with a `content://` URI belonging to some other app's DocumentsProvider —
possibly Drive, possibly a network share, possibly nothing on this device. It has to be read through
a `ContentResolver` stream, and it is not valid past the process that asked for it.

The app has no Kotlin of its own — `MainActivity.kt` is the generated three-liner — and its manifest
is the generated one. Whatever is chosen writes this repo's first platform code or takes its first
plugin, in both directions.

[ADR 13](13-lists-scroll-by-index.md) set the bar for a dependency beyond the stack ADR 01 fixed:
*confined to one file, with the way out written down*. [ADR 14](14-the-dice-comes-off-font-awesome.md)
took the sixth under that rule and added the pinning question — pinned exactly where a package is
dormant, by caret where it still releases — after its own first choice, a single-maintainer package
dormant two years, turned out not to compile at all.

## Decision

**Both directions hand off to a sheet the system draws, and the file crosses the edge as an `XFile`
either way.**

The app never draws a file UI, never browses storage, and never names a location a reader could read.
Out, it says "here is a file, take it somewhere"; in, "give me a file, wherever it lives". That is the
one metaphor the two milestones share, and the packages follow from it rather than the other way
round.

- **Out (M24): the share sheet, on `share_plus 13.3.0`** — `fluttercommunity.dev` (verified),
  BSD-3-Clause. Wraps `ACTION_SEND`, and ships **its own** `<provider>`: `ShareFileProvider` at
  `${applicationId}.flutter.share_provider`, over an `xml/flutter_share_file_paths` declaring
  `<cache-path name="cache" path="share_plus/"/>`. Manifest merging pulls both into the build, so the
  Android side of this repo stays empty: no manifest edit, no resource, no Kotlin.
- **In (M25): the document picker, on `file_selector 1.1.0`** — `flutter.dev` (verified),
  BSD-3-Clause. Wraps `ACTION_OPEN_DOCUMENT`, and its Android implementation copies the picked
  document into the app's cache and hands back a real path, so no layer of this app ever holds a
  `content://` URI or reads through a `ContentResolver`.
- **The currency is `XFile`.** `share_plus` takes one, `file_selector` returns one, and both take it
  from the same `cross_file` package. One type crosses the edge in both directions rather than a type
  per direction — the concrete half of "the same feel", and the half a reviewer can check.
- **`exportSnapshot` takes the model.** It copies the store *file* today, which is wrong the moment a
  reader can reach it: a session started from `Corrupt` with a recovered backup would export the
  corrupt text rather than the collection on screen. It becomes `exportSnapshot(Model)` — the store
  encodes what it is given and writes the copy, still returning an opaque location, still
  byte-identical to the store file in every ordinary case since the emitter is canonical. This is
  also what FR-DAT-3's pre-import export will want in M25: the state *before* the replace, which is
  the model in hand and not yet anything on disk.
- **No type filter on the way in.** SAF filters by MIME, and YAML has none Android's table knows —
  `application/yaml` was only registered in 2024 (RFC 9512), and the `mime` package share_plus looks
  types up in carries no `.yaml` or `.yml` mapping at all, verified against the resolved 2.0.0 rather
  than assumed. A filter would grey out the very file the reader came for. Accepting anything and
  letting the decode judge is already the app's contract: FR-DAT-4 says the import validates and
  reports what and where, so a wrong file is answered by the same machinery a damaged right one is.
- **The MIME type is stated on the way out**, for the same missing-mapping reason: left to the
  lookup, the copy goes out as an unknown type and fewer apps offer to receive it.
- **Two seams of one shape, in `state/`.** The platform seams already live there —
  `modelStoreProvider` for the file system, `clockProvider` for the clock. `sharerProvider` lands
  beside them in M24 and `filePickerProvider` in M25: a function each, overridden by a widget test
  with a recorder, so each package is named in one file and each screen calls a function. M24 does
  not declare M25's half in advance; it declares the shape M25's half will copy.
- **Both by caret**, under ADR 14's rule rather than ADR 13's. `share_plus` released 2026-07-23, two
  weeks before this milestone. `file_selector` last released eight months ago, which for a finished
  plugin surface published by `flutter.dev` is stability rather than dormancy — the Flutter team
  keeps its own packages compiling against current Flutter, which is exactly what ADR 14's dead
  package lacked.
- **The way out is the seam, both ways.** Dropping either package rewrites the body of one provider.
  Nothing above it — not the controller, not the screen, not a test — knows what a share or a pick is
  made of.

## Alternatives considered

- **`file_picker` alone, for both directions.** Chosen at one point in this decision and reversed, so
  the reason is recorded rather than rediscovered. It answers the symmetry question most literally —
  `saveFile` opens `ACTION_CREATE_DOCUMENT`, `pickFiles` opens `ACTION_OPEN_DOCUMENT`, so out and in
  are *the same sheet mirrored*, "Save a copy…" and "Open…" — for **nine resolved packages against
  25** and one direct dependency instead of two. It was reversed on
  [file_picker#1885](https://github.com/miguelpruivo/flutter_file_picker/issues/1885): saving over an
  existing file on Android writes the new bytes but does not truncate, so a smaller export over a
  larger one yields the new document followed by the tail of the old — a silently damaged export,
  discovered at import rather than at export, which is the wrong end. **Closed as not planned.** A
  dated filename and a read-back would have contained it, but containing a data-corrupting defect on
  the one path whose entire job is to produce a faithful copy is a poor trade for eight packages that
  never reach the APK. It is also the single-maintainer risk ADR 14 priced, showing up on the first
  milestone rather than the third. Secondarily: `saveFile` makes `bytes` optional in its signature
  while Android throws without it
  ([file_picker#1588](https://github.com/miguelpruivo/flutter_file_picker/issues/1588)), and
  FR-DAT-1 would have needed amending, SAF handing the file to a *place* rather than to an app.
- **`share_plus` out, `file_picker` in.** 17 packages rather than 25, and the truncation defect above
  is on the *write* path only — `pickFiles` is untouched by it, so this pairing is not unsafe. It is
  passed over on the two things that separate the pickers once safety is equal: `file_picker` answers
  with its own `PlatformFile`, so the two directions would trade in different types and the seams
  would stop being the same shape; and having just moved off that package over a defect its
  maintainer declined, taking it back for the other half would be an odd reading of the same
  evidence. The eight packages saved are all platform implementations that resolve into the lockfile
  and never into the APK.
- **`MethodChannel`s of our own, both ways.** Roughly: a `<provider>` and an `xml/file_paths` in the
  manifest, ~40 lines of Kotlin for the send, and another ~50 for the pick — `ACTION_OPEN_DOCUMENT`
  comes back on `onActivityResult`, so the channel needs a result relay, and the `content://` URI
  then has to be streamed through a `ContentResolver` into a cache file before Dart can read it. No
  dependency, no dead desktop code, and no exposure to anyone else's defects. Passed over on
  **verifiability**: none of that Kotlin can be exercised by `flutter test`, CI runs no instrumented
  test and builds no APK any test runs against, and the parts that actually break — provider
  authority, paths resource, grant flag, result relay — would be covered by nothing at all. The
  packages' equivalents are covered by their own suites and by millions of downloads a month. What is
  bought is the removal of an untested surface from this repo.
- **`file_selector` for the outgoing half too.** Would have made one package answer both directions
  with the `XFile` currency intact. Not available: its own support table marks "choose a save
  location" ❌ on Android, and
  [flutter#168318](https://github.com/flutter/flutter/issues/168318) asking for it is still open.
- **An intent filter, so Cocktails appears in *other* apps' share sheets.** The true mirror of the
  outgoing metaphor: share out of Cocktails, share back into it. Genuinely attractive, and out of
  scope rather than wrong — FR-DAT-3 asks for an action *inside* the app, this adds a second entry
  point that starts outside it, and it drags in cold-start intent handling and a confirmation flow
  reached before the model has loaded. Worth revisiting after M25 as an addition, never as the
  replacement.
- **Share the text, not the file.** `ACTION_SEND` with `EXTRA_TEXT` needs no provider at all. A
  message body is not a file, so nothing round-trips into FR-DAT-3, and Android's binder transaction
  limit puts a ceiling on a collection the format is meant to scale past.
- **Export now, decide import later.** What this ADR was first drafted as, and the reason it was
  rewritten: FR-DAT-3's pre-import export is the same call as FR-DAT-1's export, the two sit
  on one Settings menu, and a reader meets them a minute apart. Deciding them a milestone apart is
  how they end up feeling like two different apps.

## Consequences

- **A seventh and eighth dependency, and 25 resolved packages** — `share_plus`,
  `share_plus_platform_interface`, `file_selector`, its platform interface and its six platform
  implementations, plus `cross_file`, `file`, `mime`, `uuid`, `web`, `fixnum`, `http`, `http_parser`,
  `ffi_leak_tracker`, `flutter_web_plugins`, `win32` and four `url_launcher` implementations. Almost
  all of it is for platforms this app does not build: it resolves into `pubspec.lock` and not into
  the APK, Gradle taking only the Android implementation of each plugin. Noise in the lockfile, not
  weight in the build — but these are the first dependencies whose tails are larger than themselves,
  and the count is the accepted price of passing over the nine-package alternative above.
- **Nothing this app writes is ever overwritten in place.** The staging copy goes to the app's own
  directory through `FileModelStore`'s existing temp-and-rename, which truncates by construction, and
  the reader's own copy is made by whichever app receives it. The defect that reversed the
  alternative above has no analogue on this path — worth stating, since it is what the extra packages
  were bought for.
- **The shared file is a copy of a copy, and the picked one likewise.** Outward, `exportSnapshot`
  writes `cocktails-export.yaml` into the app-private directory and the plugin copies *that* into
  `cacheDir/share_plus/`, clearing the folder at the start of each share; the name the receiving app
  sees is the file's own basename, which makes the store's naming a user-visible fact rather than an
  internal one. Inward, the picked document is copied into the app cache before Dart sees it, so the
  import reads a stable local file and a document that vanishes mid-import cannot happen.
- **`XFile.name` is not the document's name on Android.** The picker drops the SAF display name and
  the last path segment stands in for it
  ([flutter#131328](https://github.com/flutter/flutter/issues/131328)). M25 must not put that string
  in front of a reader as "the file you picked".
- **`state/` gains Flutter plugin imports.** No boundary moves — `architecture_test.dart` constrains
  the app's own layers, and external packages are already free (`data/` imports `yaml`, `ui/` imports
  Font Awesome). But the state layer stops being pure Dart plus Riverpod, which is worth noticing
  before a third platform seam lands there.
- **The share result is not read, and neither is success announced.** Android reports the chosen app
  through a `PendingIntent` the plugin registers, and reports nothing at all for a chooser the reader
  dismisses, so treating "shared" as an outcome would lie in the common case. Nor does the app
  confirm its own half: the sheet opening *is* the answer, and a snackbar saying the copy was written
  would fire underneath a system modal and be read, if at all, once it was stale. Only a failure
  speaks.
- **M25 arrives with its mechanism already chosen** and designs what actually needs designing: the
  confirmation, the pre-import export, and how FR-DAT-4's issues are put in front of a reader.
