# ADR: A bar travels behind one seam

**Status:** Accepted, except for the cloud backend, which is the human's to pick.

## Context

FR-BAR-7/8/9 give a bar three ways to travel — a file, the LAN, the cloud — and FR-BAR-5 makes them
interchangeable from above: a guest bar refreshes from whatever it was added from, and the app says
the same things about the result whichever way it came. The three are wildly different underneath: a
file needs the reader, the LAN needs discovery and a socket, the cloud needs a server and the only
identity in the product (NFR-3).

The app has never made a network call. It has three seams of exactly this shape already —
`barStoreProvider`, `sharerProvider`, `filePickerProvider` — where the platform crosses inside a
provider body and a test replaces it with a recorder (ADR 18).

FR-BAR-9's backend is a decision with cost outside the repo: money, an account, uptime, or a vendor.
FR-BAR-7 and FR-BAR-8 must not wait on it.

## Decision

**A source is a value; a channel is an interface; the transports are adapters resolved at the
composition root.** Shapes in [components.md](../components.md#the-sharing-seam).

- **`BarSource` = transport + address + what to call it**, kept with the guest bar so a refresh asks
  the same thing again. Only the adapter reads the address; nothing above `data/` builds one.
- **A fetch answers, never throws**: what arrived, what failed the import's own judgement
  (FR-DAT-4), or that the source could not be reached — offline, not found, or withdrawn, a closed
  set so the wording stays the UI's (FR-BAR-5).
- **Three interfaces, not one**: every transport fetches; only some offer and withdraw; only one
  finds. A way that cannot do a thing carries no method for it, so the file channel is honestly
  one method wide.
- **LAN = DNS-SD for finding, our own HTTP for carrying.** The owner registers one service instance
  per offered bar and serves that bar's export over a `dart:io` `HttpServer` on an unguessable path;
  the guest browses the service type and refreshes by GET. Discovery needs a package — `bonsoir` and
  `nsd` are the candidates, both registering and browsing on Android; `multicast_dns` (flutter.dev)
  is ruled out because it only browses, and the owner's side is the half we cannot do without. The
  pick, its version and its pinning are settled in the change that takes it, under the ADR 13 bar
  (one file, way out written down) and the ADR 14 pinning rule.
- **Nothing is announced unless something is shared** (NFR-5): server and service come up with the
  first offer and down with the last withdrawal. The instance name is the bar's name plus a short
  discriminator derived from its id — unique on the wire, and a guest's only way to tell two bars of
  one name apart (FR-BAR-1).
- **Withdrawal stops the offer and nothing else** (FR-BAR-6): a guest keeps what it holds, and its
  next refresh is told the source is gone.
- **The cloud transport is declared and unimplemented.** `Transport.cloud` exists so the index's
  format need not change later; the registry has no adapter for it, and the ways offered are the
  ways that answer. FR-BAR-7 and FR-BAR-8 ship without it.

## The cloud backend: for the human to decide

Ranked, with what each costs *this* project — one developer, minimal dependencies, no backend and no
accounts today, payloads of tens of KB, and an app that must stay offline-first.

1. **Supabase** — recommended. One dependency (`supabase_flutter`), real auth, and row-level
   security expresses "the guests I named" as a policy rather than as our code. Self-hostable, so
   the lock-in is soft. Costs: a sizeable transitive tail, and a free tier that pauses idle projects
   — a bar that cannot be refreshed for a week until someone pokes the dashboard.
2. **A small server of our own** — the smallest change to this codebase by a distance: the cloud
   adapter is the LAN adapter with another base URL and a bearer token per guest, zero new packages.
   Costs: hosting, a second codebase, and uptime becomes the developer's. "Guests they name" becomes
   tokens the owner mints and hands over, which is a thinner reading of FR-BAR-9 than a policy is.
3. **Firebase** — the safest ecosystem bet and the only one with no idle-pause worry; Google sign-in
   is already on the device. Costs: the heaviest by far — several plugins, a Gradle plugin, a
   generated config file, and the hardest of the four to leave.
4. **A file host the owner already has** (Drive, Dropbox, a gist): no backend of ours, no account in
   our app. Refused as an answer to FR-BAR-9 — a link cannot name its guests, which is the one thing
   that requirement asks for beyond reach-from-anywhere.

## Alternatives considered

- **Per-transport code with no seam**: three add flows, three refresh flows, three error vocabularies.
  Refused — FR-BAR-5 already says the guest sees one behaviour, so one abstraction is the honest
  shape, and the file transport alone would otherwise leak a picker into the bar list.
- **A raw socket protocol of our own over the LAN**: no HTTP, fewer bytes. Refused: HTTP is in
  `dart:io` already, is trivially testable against a loopback server, and is what makes the cloud
  adapter a near-copy of the LAN one.
- **Authentication on the LAN path**: refused as out of proportion to FR-BAR-6's own words — a bar
  shared is a bar given, and an unguessable path on a home network matches that exactly.
- **A foreground service so an offer outlives the app**: would let a guest refresh while the owner's
  phone is in a pocket. Refused for a notification and a permission the feature does not earn.

## Consequences

- `data/` gains its first outward-facing adapters, and the app its first manifest entry of its own:
  the internet permission ([architecture.md](../architecture.md#platform-facts)).
- An offer lives while the owner's app does; Android reclaims the socket behind it. Both readers
  being present is FR-BAR-8's own premise, so this is a limit rather than a gap.
- A file-sourced bar refreshes by asking the reader for a file, which is the only interactive fetch —
  legal because no fetch in this app is ever unattended (NFR-4/5 leave no room for polling).
- The state layer gains work in flight: refreshes that outlive a gesture, and offers that outlive a
  screen ([components.md](../components.md#work-in-flight)).
