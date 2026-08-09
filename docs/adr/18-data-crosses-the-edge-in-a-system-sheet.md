# ADR: Data crosses the edge in a system sheet, both ways

**Status:** Accepted

## Context

FR-DAT-1/3/4: export all to shareable file (M24), import file replacing DB after validation (M25). One seam, two milestones; settling one half risks drift. Data layer: `ModelStore.exportSnapshot` writes `cocktails-export.yaml` (opaque location); import is `YamlCodec.decode` + `save` (not store method, allows confirmation and pre-import export interleaved). Platform handling missing both ends.

Android constraints: (a) API 24+: `file://` URI throws `FileUriExposedException`; must use `content://` from `FileProvider` (b) Storage Access Framework: `ACTION_OPEN_DOCUMENT` returns `content://` URI of unknown app's provider; read via `ContentResolver` stream, invalid past process. App has no Kotlin (generated three-liner); first plugin/platform code goes both directions.

ADR 13 set dependency bar: *confined to one file, way out written down*. ADR 14 added pinning rule.

## Decision

**Both directions use system sheet; file crosses edge as `XFile` both ways. One metaphor: app says "take it" (out), "give me it" (in).**

- **Out (M24)**: `share_plus 13.3.0` (`fluttercommunity.dev`, BSD-3-Clause). Wraps `ACTION_SEND`, ships own `ShareFileProvider` at `${applicationId}.flutter.share_provider`. Manifest merge auto-includes; no Kotlin, manifest edit, or resource in repo.
- **In (M25)**: `file_selector 1.1.0` (`flutter.dev`, BSD-3-Clause). Wraps `ACTION_OPEN_DOCUMENT`, copies picked document to cache, returns real path; no `content://` URI or `ContentResolver` in app.
- **Currency: `XFile`**. Both directions; one type, one feel, reviewable.
- **`exportSnapshot(Model)`**: store encodes what given, writes copy, returns opaque location. Same call for FR-DAT-3 pre-import export (state before replace).
- **No type filter in**: SAF filters MIME; `application/yaml` only registered 2024, `mime` package has no mapping. Filter would grey out reader's file. App's contract (FR-DAT-4): decode judges validity.
- **MIME stated out**: left to lookup, copy goes unknown type, fewer apps receive it.
- **Platform seams in `state/`**: `sharerProvider` (M24), `filePickerProvider` (M25); functions named once per file, overridden by widget test recorder.
- **Both by caret** (ADR 14 rule): `share_plus` released 2026-07-23; `file_selector` eight months ago (stability for `flutter.dev` package).
- **Way out is seam both ways**: drop either, rewrite provider body only; nothing above knows share/pick internals.

## Alternatives considered

- **`file_picker` both ways**: symmetry (same sheet out/in); 9 packages vs 25, 1 dependency vs 2. Reversed: [#1885](https://github.com/miguelpruivo/flutter_file_picker/issues/1885) — save truncates file (new bytes + old tail); corrupted export discovered at import not export. Closed not-planned. Single-maintainer risk (ADR 14); secondary: `saveFile` `bytes` optional ([#1588](https://github.com/miguelpruivo/flutter_file_picker/issues/1588)), FR-DAT-1 needs amend.
- **`share_plus` out, `file_picker` in**: 17 packages; truncation only on write. Passed: different types (`PlatformFile` vs `XFile`), seams lose same shape; moving back after defect rejection is poor reading.
- **`MethodChannel` both ways**: ~40 lines Kotlin send, ~50 pick, result relay, `ContentResolver` stream. No dependency, no dead desktop, no exposure. Passed: **verifiability** — Kotlin untestable, no instrumented/APK test, unseen failure points (provider, resource, flag, relay). Packages covered by own suites + millions downloads.
- **`file_selector` both ways**: `XFile` intact. Not available: save location ❌ Android ([flutter#168318](https://github.com/flutter/flutter/issues/168318) open).
- **Intent filter**: true mirror (receive Cocktails in others' sheets). Out of scope — FR-DAT-3 is inside-app action; cold-start intent + pre-load confirmation. Revisit M25+.
- **Text not file**: `ACTION_SEND` + `EXTRA_TEXT` no provider. No round-trip to FR-DAT-3; binder transaction limit caps collection scale.
- **Decide import later**: ADR was first drafted this way; rejected: FR-DAT-3 and FR-DAT-1 exports are same call, one Settings menu, minute apart. Milestone gap feels like different apps.

## Consequences

- **7th/8th dependency, 25 resolved packages**: `share_plus`, `file_selector` + platform interfaces + implementations, `cross_file`, `file`, `mime`, `uuid`, `web`, `fixnum`, `http`, `http_parser`, `ffi_leak_tracker`, `flutter_web_plugins`, `win32`, `url_launcher`. Most for unbuilt platforms (lock file not APK); first with tails larger than themselves. Price of passing 9-package alternative.
- **No in-place overwrites**: staging via `FileModelStore` temp-and-rename (truncates); reader's copy by receiving app. No truncation analogue here (what extra packages bought).
- **Copy of copy both ways**: `exportSnapshot` → `cocktails-export.yaml` → plugin copies to `cacheDir/share_plus/` (clears folder at start of share); basename visible to receiver. Picked document copied to cache before Dart sees it; stable local file; no vanish mid-import.
- **`XFile.name` not document name on Android**: picker drops SAF display name ([flutter#131328](https://github.com/flutter/flutter/issues/131328)); last path segment used. M25 must not show string as "file you picked".
- **`state/` gains plugin imports**: no boundary moves; `architecture_test.dart` constrains app layers. State stops being pure Dart + Riverpod (before 3rd platform seam).
- **Share result not read; success not announced**: Android reports via `PendingIntent` or nothing for dismiss. Treating "shared" as outcome lies in common case. App doesn't confirm; sheet opening is answer. Snackbar fires under modal, stale. Only failure speaks.
- **M25 mechanism pre-chosen**: designs confirmation, pre-import export, FR-DAT-4 issue presentation.
