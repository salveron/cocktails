# ADR: Nearby comes off Bonsoir

**Status:** Accepted.

## Context

[ADR 22](22-a-bar-travels-behind-one-seam.md) settled the shape of the LAN transport — DNS-SD for
finding, our own HTTP for carrying — and deliberately left the discovery package to the change that
takes it, under the [ADR 13](13-lists-scroll-by-index.md) bar (confined to one file, way out written
down) and the [ADR 14](14-the-dice-comes-off-font-awesome.md) pinning rule (caret where a package
still releases, pinned where it is quiet). This is that change.

Two candidates register *and* browse on Android, which is the pairing the owner's half cannot do
without; `multicast_dns` browses only and ADR 22 ruled it out on exactly that. Both are MIT, both
come from a verified publisher, both score 160/160, and both are federated plugins with five
sub-packages. Both wrap the same Android API — `NsdManager` — so nothing below either of them
differs.

## The two, side by side

| | `bonsoir` 7.1.5 | `nsd` 5.0.1 |
|---|---|---|
| Last release | 2026-08-11, six across 2026 | 2026-04-04, after a 13-month gap (Nov 2024 → Dec 2025) |
| Pinning it would take (ADR 14) | caret | pinned exactly |
| Likes / 30-day downloads | 160 / 57.7k | 77 / 64.9k |
| Platforms | Android, iOS, macOS, Windows, **Linux** | Android, iOS, macOS, Windows |
| API shape | objects — `BonsoirBroadcast`, `BonsoirDiscovery`, sealed events | free functions — `register`, `startDiscovery`, `stopDiscovery` |
| Resolving | explicit, per service, when we ask | `autoResolve` on by default; explicit `resolve` also offered |
| Addresses | `hostAddresses` on resolve | `addresses` only under `ipLookupType: any` |
| Name conflict | a `NameAlreadyExists` event of its own | the granted name comes back on the `Registration` |
| Android permissions | declared in its own plugin manifest, merged in | declared by us |

**Cadence is the axis that decides it.** Everything else is close enough to call a wash, and ADR 13
priced dormancy in a package that had gone quiet for three years — ADR 14 then watched that price
come due on Ionicons, which stopped compiling. `nsd` is not dormant, but a 13-month gap in its
history is the same risk in a smaller size, and it is the half of this pair that would have to be
pinned and re-read on every release.

**Linux is the quiet tiebreak.** It buys nothing a reader sees — the app targets Android — but
[architecture.md](../architecture.md#technology-stack) says desktop later, and the development
machine is Linux. A package that runs there is one a round trip can be exercised on without a phone
in hand.

## Decision

**`bonsoir`, by caret, confined to `lan_discovery.dart`.**

- **By caret, not pinned**: it still releases, and ADR 14 already settled that keeping up is the
  cheaper reading of a live package's risk. The opposite reading applies to `nsd`, which is why the
  two picks would not have carried the same pinning.
- **One file, and the way out is a `nsd` shim behind the same three functions.** The confined surface
  is *announce this name on this port*, *stop announcing*, and *browse for a bounded while, answering
  name and addresses* — none of which names a Bonsoir type above itself. Both packages answer that
  shape, so the way out is a rewrite of one file against an API of the same size, not a redesign.
- **We resolve, and we resolve late.** Bonsoir's explicit resolve is what ADR 22's *resolve afresh on
  every ask* and *a browse is never left running* both want; `nsd`'s default would resolve every
  device on the network whether or not the reader asked about one.
- **Addresses, not hostnames.** A resolved service carries `hostAddresses` already in hand. Android
  cannot resolve a `.local` name from a socket, so a hostname is not something `dart:io` can connect
  to — the address is what the fetch uses, and neither it nor the port is ever stored
  ([ADR 22](22-a-bar-travels-behind-one-seam.md)).
- **We declare the two permissions ourselves** even though `bonsoir_android` merges them in. An
  inherited permission is invisible where this project writes its platform facts down, and ADR 22
  already says the internet permission is the first that is ours.

## What a reader would notice

**Between the two packages: essentially nothing.** Both drive `NsdManager`, so the devices found, the
time taken to find them, and what a withdrawal looks like are the same either way. The two thin
differences are that Bonsoir can tell *"that name was taken"* from *"you got the name you asked for"*
without comparing strings, and that `nsd` would fill the picker marginally sooner by resolving
devices the reader never asked about. Neither reaches this milestone; both land with the picker.

Two things found while comparing *do* reach the reader, and belong to the feature rather than to
either package:

- **A permission prompt is coming, and FR-BAR-8 has never had to answer for one.** `targetSdk` is
  Flutter's own default, taken as it moves ([architecture.md](../architecture.md#platform-facts)) —
  36 today. `NEARBY_WIFI_DEVICES` is already required above 33. Android 16 makes local-network access
  restrictable opt-in; **Android 17 makes it mandatory behind `ACCESS_LOCAL_NETWORK`, a runtime
  permission with a system dialog**. The day Flutter's default reaches 37, the reader meets that
  dialog the first time they offer or look for a bar — and a refusal has to read as something. That
  is a UI question, and it is the largest consequence in this comparison.
- **The instance name is the OS's to grant, not the reader's to choose.** Both packages document the
  conflict rename — `Bar` → `Bar (2)` → `Bar (3)`. So what is stored is the name that came *back*,
  never the one asked for; and a guest's source still goes stale when the owner renames their device
  or loses a conflict on a later launch. Re-sourcing (FR-BAR-5) is the repair, which is the second
  reason that clause was worth widening.

## Alternatives considered

- **`nsd` 5.0.1, pinned exactly.** The closer call than the table suggests: a smaller API, an
  explicitly documented permission set rather than an inherited one, and it ships an
  `integration_test` doing register-discover-unregister that is a ready-made model for proving the
  round trip. Refused on cadence, on Linux, and on `autoResolve` pulling against ADR 22's rule that a
  browse is never left running longer than a reader is looking.
- **Prove both on the device, then pick.** Honest, and the roadmap does say this pairing must be
  proven before anything rests on it. Refused as the *default* order rather than on merit: the
  confined surface is three functions wide, so proving the second costs a second wrapper against an
  API we would not otherwise write. Reversed if the round trip fails — the way out is already the
  shim above.
- **`multicast_dns`.** Ruled out in ADR 22 and unchanged here: it browses only, and the owner's half
  is the one we cannot do without.
- **No package — DNS-SD over raw sockets.** Multicast, record parsing, conflict handling and a
  platform's own daemon to coexist with. Far past the ADR 13 bar for a dependency, and this app has
  never spoken a wire protocol.

## Consequences

- A seventh dependency, taken under the fifth's bar. `bonsoir` names five sub-packages, the largest
  transitive tail this app has taken; the dependency-list test pins direct names only, so
  [architecture.md](../architecture.md#technology-stack) gains one.
- **The app's first permissions of its own**: `INTERNET` and `CHANGE_WIFI_MULTICAST_STATE`, declared
  rather than inherited, plus `NEARBY_WIFI_DEVICES` at the target the app already builds against.
  What a register and a browse actually ask for is confirmed on the device, not assumed here.
- `lan_discovery.dart` is the only file that names a Bonsoir type; everything above it sees a name, a
  port and a list of addresses.
- Desktop later costs nothing extra on this path, and a round trip can be exercised on the Linux
  development machine as well as on the phone.
- **A runtime local-network prompt is a dated, forecastable change**, not a surprise: it arrives with
  `targetSdk` 37 and wants a wording FR-BAR-8 does not have yet.
