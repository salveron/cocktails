# ADR: A bar travels behind one seam

**Status:** Accepted. The cloud backend is open until cloud sharing is scheduled (a [future direction](../vision.md#future-directions)).

## Context

FR-BAR-7/8: a bar travels by file or LAN. FR-BAR-5 makes them interchangeable from above: a guest refreshes from whatever it was added from, and the app says the same things either way. Underneath they differ: a file needs the reader; the LAN needs discovery and a socket. A cloud way, a future direction, would add a server and the only identity in the product (NFR-3).

Three seams of this shape exist (`barStoreProvider`, `sharerProvider`, `filePickerProvider`): the platform crosses inside a provider body, and a test swaps in a recorder (ADR 18).

## Decision

**A source is a value; a channel is an interface; the transports are adapters resolved at the composition root.** Shapes in [components.md](../components.md#the-sharing-seam).

- **`BarSource` = transport + address + what to call it**, kept with the guest bar so a refresh can ask again. Only the adapter reads the address; nothing above `data/` builds one. A guest refreshes only the way it was added (FR-BAR-5), so the source is one value, kept as it arrived. Re-pointing is refused: a bar sent as a file and later found nearby is re-added by the second road; the seam fetches, nothing else.
- **A fetch answers, never throws**: what arrived; what failed the import's own judgement (FR-DAT-4); or unreachable (offline, not found, withdrawn: a closed set so the wording stays the UI's, FR-BAR-5). A fourth answer, *no answer*, fits the file fetch: a picker the reader may dismiss, neither a refusal nor a silent source. `UnreachableReason` lives in the domain, not beside the channel: `ui/` puts it into words and reads no further down.
- **Three interfaces, not one**: every transport fetches; some offer and withdraw; one finds. A way that cannot do a thing has no method for it, so the file channel is one method wide.
- **LAN = DNS-SD for finding, our own HTTP for carrying.** Discovery costs a package; transfer none. Package, version and pinning: [ADR 27](27-nearby-comes-off-bonsoir.md), taken under the ADR 13 bar, so one file names it and its exit is written down.
- **One server and one service instance per device, not per bar.** The `dart:io` `HttpServer` answers what the device offers (each bar's id, name, and unguessable path to its bytes) and the bytes. Announcing the device lets a withdrawal be told from an owner gone quiet: the instance answers while its list stops naming the bar. No bar name on the wire for mDNS browsers, no TXT record: the list is a document with its own format. That number tracks the LAN protocol, not the on-disk schema (the two answer different things), so a storage bump cannot turn a guest away from an unchanged list; the check runs at discovery, before the bar's own version gate.
- **A guest keeps the instance name and the bar's id, never an address.** The port is ephemeral and the lease is not ours, so each fetch resolves the instance afresh, reads the list, and takes the path it names. Paths are never stored, so the owner may rotate them freely. Two bars of one name are told apart by id (FR-BAR-1).
- **Where the ask stopped is which reason it answers** (FR-BAR-5): no network of our own is `offline`; an instance that will not resolve is `notFound` (owner's device off, app shut, or another network); an instance whose list no longer names the bar is `withdrawn`.
- **The server is handed a function, not the store.** An offered bar is rarely the one on show, and only one collection is resident (ADR 20), so the adapter takes "the bytes of this bar id"; the state layer composes that over a load and the canonical emitter. This is the `filePickerProvider` seam, so a test needs neither socket nor file.
- **Nothing is announced unless shared** (NFR-5): up with the first offer, down with the last withdrawal. **Neither outlives the run**: the server dies with the process, so a surviving record would point a switch at a silent network. The record resets to not-shared on load; sharing again is one tap, better than a bar quietly back on the network at every start.
- **A browse is never left running**, nor waited out past its answer: it yields each device as it resolves, so a fetch stops at its instance and a list draws what it has. It closes at its window or when the reader stops looking; a multicast lock held around the clock would cost battery.
- **Any bar may be offered**, a guest's as an owned one's (FR-BAR-6): an offer is a record edit, which a guest takes as it takes a rename; the list names what this device holds. A second guest reads the first's copy as of its last refresh. Served are the record's own name and unit over the bar file's collection, so a rename or unit pick moves the index, never the bar file.
- **Withdrawal stops the offer and nothing else** (FR-BAR-6): a guest keeps what it holds; its next refresh is told the source is gone.
- **The cloud transport is declared and unimplemented.** `Transport.cloud` exists so the index format need not change later; no adapter is registered, so offered ways are the ways that answer.

## The cloud backend: open until it is scheduled

Cost sits outside the repo: money, an account, uptime, a vendor. Ranked by what each costs *this* project: one developer, minimal dependencies, no backend or accounts today, payloads of tens of KB, offline-first.

1. **Supabase**: recommended. One dependency (`supabase_flutter`); real auth; row-level security expresses "the guests I named" as policy, not code. Self-hostable, so lock-in is soft. Costs: a sizeable transitive tail; a free tier pauses idle projects, so a bar cannot refresh for a week until someone pokes the dashboard.
2. **A small server of our own**: smallest change by a distance; the cloud adapter is the LAN adapter with another base URL and a bearer token per guest, zero new packages. Costs: hosting, a second codebase, uptime becomes the developer's. "Guests they name" becomes owner-minted tokens: a thinner reading than a policy.
3. **Firebase**: safest ecosystem bet, the only one with no idle-pause worry; Google sign-in already on the device. Costs: heaviest by far (several plugins, a Gradle plugin, a generated config file); hardest of the four to leave.
4. **A file host the owner already has** (Drive, Dropbox, a gist): no backend or account of ours. Refused: a link cannot name its guests, the one thing cloud sharing asks beyond reach-from-anywhere.

## Alternatives considered

- **Per-transport code, no seam**: an add flow, a refresh flow and an error vocabulary apiece. Refused: FR-BAR-5 wants one guest behaviour, and the file alone would leak a picker into the bar list.
- **A raw socket protocol over the LAN**: no HTTP, fewer bytes. Refused: HTTP is in `dart:io`, testable on loopback, and makes the cloud adapter a near-copy of the LAN one.
- **Authentication on the LAN path**: refused as out of proportion to FR-BAR-6: a bar shared is a bar given, and an unguessable path matches that.
- **One DNS-SD instance per offered bar** (name plus an id discriminator). Refused: a withdrawn instance vanishes, indistinguishable from an owner whose phone is off, though FR-BAR-5 needs the difference; it also announces every shared bar's name to anything browsing the network.
- **A foreground service so an offer outlives the app**: lets a guest refresh while the owner's phone is in a pocket. Refused: a notification and a permission the feature does not earn.

## Consequences

- `data/` gains its first outward-facing adapters; the app its first manifest entry, the internet permission ([architecture.md](../architecture.md#platform-facts)).
- An offer lives while the owner's app does; Android reclaims the socket behind it. Both readers present is FR-BAR-8's premise: a limit, not a gap.
- A file-sourced bar refreshes by asking the reader for a file, the only interactive fetch; legal because no fetch here is unattended (NFR-4/5 leave no room for polling).
- The state layer gains work in flight: refreshes outliving a gesture, offers outliving a screen ([components.md](../components.md#work-in-flight)).
