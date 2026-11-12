# ADR: Nearby comes off Bonsoir

**Status:** Accepted.

## Context

[ADR 22](22-a-bar-travels-behind-one-seam.md) settled the shape of the LAN transport (DNS-SD for finding, our own HTTP for carrying) and left the discovery package to the change that takes it, under the [ADR 13](13-lists-scroll-by-index.md) bar (confined to one file, way out written down) and the [ADR 14](14-the-dice-comes-off-font-awesome.md) pinning rule (caret where a package still releases, pinned where it is quiet).

Two candidates register *and* browse on Android, the pairing the owner's half cannot do without; `multicast_dns` browses only, which ADR 22 ruled out. Both are MIT, from verified publishers, score 160/160, and are federated plugins with five sub-packages. Both wrap the same Android API, `NsdManager`, so nothing below differs.

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

**Cadence is the axis that decides it.** Everything else is a wash. ADR 13 priced dormancy in a package quiet for three years, and ADR 14 watched that price come due on Ionicons, which stopped compiling. `nsd` is not dormant, but a 13-month gap is the same risk in a smaller size, and it is the half that would need pinning and re-reading on every release.

**Linux is the quiet tiebreak.** It buys nothing a reader sees, the app targeting Android, but [architecture.md](../architecture.md#technology-stack) says desktop later and the development machine is Linux. A round trip can run without a phone in hand.

## Decision

**`bonsoir`, by caret, confined to `lan_discovery.dart`.**

- **By caret, not pinned**: it still releases, and ADR 14 settled that keeping up is the cheaper reading of a live package's risk. The opposite reading applies to `nsd`, so the picks would differ in pinning.
- **One file, and the way out is a `nsd` shim behind the same three functions.** The confined surface is *announce this name on this port*, *stop announcing*, and *browse for a bounded while, answering name and addresses*, none of which names a Bonsoir type above itself. Both packages answer that shape, so the way out is a rewrite of one file against an API of the same size, not a redesign.
- **We resolve, and we resolve late.** Bonsoir's explicit resolve is what ADR 22's *resolve afresh on every ask* and *a browse is never left running* both want; `nsd`'s default would resolve every device on the network, asked about or not.
- **Addresses, not hostnames.** A resolved service already carries `hostAddresses`. Android cannot resolve a `.local` name from a socket, so `dart:io` cannot connect to one. The address is what the fetch uses, and neither it nor the port is ever stored ([ADR 22](22-a-bar-travels-behind-one-seam.md)).
- **We declare the two permissions ourselves**, though `bonsoir_android` merges them in: an inherited permission is invisible where this project writes its platform facts down, and ADR 22 already says the internet permission is the first that is ours.

## What a reader would notice

**Between the two packages, nothing much.** Both drive `NsdManager`, so devices found, time taken and withdrawals look the same. Two thin differences: Bonsoir tells *"that name was taken"* from *"you got the name you asked for"* without comparing strings, and `nsd` fills the picker marginally sooner by resolving devices the reader never asked about. Neither reaches this milestone; both land with the picker.

Two things found while comparing *do* reach the reader, and belong to the feature:

- **A permission prompt is coming, and FR-BAR-8 has never had to answer for one.** `targetSdk` is Flutter's own default, taken as it moves ([architecture.md](../architecture.md#platform-facts)): 36 today. `NEARBY_WIFI_DEVICES` is already required above 33. Android 16 makes local-network access restrictable opt-in; **Android 17 makes it mandatory behind `ACCESS_LOCAL_NETWORK`, a runtime permission with a system dialog**. The day Flutter's default reaches 37, the reader meets that dialog the first time they offer or look for a bar, and a refusal has to read as something. The largest consequence here, and a UI question.
- **The instance name is the OS's to grant, not the reader's to choose.** Both packages document the conflict rename, `Bar` → `Bar (2)` → `Bar (3)`. A guest's source goes stale when the owner renames their device or loses a conflict on a later launch; re-sourcing (FR-BAR-5) is the repair, the second reason that clause was worth widening. [ADR 28](28-the-device-is-named-by-its-reader.md) settled what is *kept*: the name the reader typed, the granted one belonging to an announcement that outlives nothing.

## Alternatives considered

- **`nsd` 5.0.1, pinned exactly.** The closer call than the table suggests: a smaller API, a documented permission set, and an `integration_test` doing register-discover-unregister, a ready-made model for proving the round trip. Refused on cadence, on Linux, and on `autoResolve` pulling against ADR 22's rule that a browse is never left running longer than a reader is looking.
- **Prove both on the device, then pick.** The roadmap does say this pairing must be proven before anything rests on it. Refused as the *default* order, not on merit: the confined surface is three functions wide, so proving the second costs a second wrapper against an API we would not otherwise write. Reversed if the round trip fails — the way out is already the shim above.
- **`multicast_dns`.** Ruled out in ADR 22 and unchanged here.
- **No package: DNS-SD over raw sockets.** Multicast, record parsing, conflict handling and a platform's own daemon to coexist with. Far past the ADR 13 bar for a dependency, and this app has never spoken a wire protocol.

## Consequences

- A seventh dependency, taken under the fifth's bar. `bonsoir` names five sub-packages, the largest transitive tail this app has taken; the dependency-list test pins direct names only, so [architecture.md](../architecture.md#technology-stack) gains one.
- **The app's first permissions of its own**: `INTERNET` and `CHANGE_WIFI_MULTICAST_STATE`, declared rather than inherited, plus `NEARBY_WIFI_DEVICES` at the target the app already builds against. What a register and a browse ask for is confirmed on the device, not assumed.
- `lan_discovery.dart` is the only file that names a Bonsoir type; everything above it sees a name, a port and a list of addresses.
- Desktop later costs nothing extra on this path.
- **A runtime local-network prompt is a dated, forecastable change**, not a surprise: it arrives with `targetSdk` 37 and wants a wording FR-BAR-8 does not have yet.
