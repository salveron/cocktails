# ADR: The device is named by its reader

**Status:** Accepted.

## Context

[ADR 22](22-a-bar-travels-behind-one-seam.md) put **one service instance per device, not per bar** on the LAN, so a guest browses a list of devices and the bars each offers. That instance needs a name: the only thing about the owner a stranger on the network ever reads, what a guest picks from (FR-BAR-8) and what their bar's source keeps.

Nothing in the app had one. The index carried `format`, `open` and `bars`, and `LanBarChannel` took a `deviceName` its caller could not supply, so `offeringsProvider` shipped empty.

## Decision

**The reader names the device; the phone's own name is what they start from.**

- **It is device state, so it lives beside `open:`**: `device:` in the index, `Shelf.deviceName` in the domain. Not a bar's: one announcement covers every bar a device offers, and a per-bar name would be a second thing to disagree with the first.
- **Left off entirely until it is set**, as every default is. An index written before this key reads as a device never named, and no migration runs.
- **The first value comes off the platform**, through the app's first `MethodChannel`: `Settings.Global.DEVICE_NAME`, the name the reader gave the phone in its own settings. No permission, no package. `Cocktails` where the setting was never written, or where there is no Android host (a desktop run, or a test).
- **Read-only while this device is announcing anything.** The announcement went up under the old name and a guest's source keeps it, so a mid-offer rename would strand every guest silently. Turning sharing off first makes the cost visible and a tap away. The lock is device-wide, as the announcement is, so the field dims on a bar whose own switch is off.
- **The granted name is not surfaced.** DNS-SD settles a clash by suffix, `Nikita's phone` → `Nikita's phone (2)` ([ADR 27](27-nearby-comes-off-bonsoir.md)), and the room says nothing. The index keeps what the reader typed. The suffix belongs to one announcement and outlives nothing, and a line explaining it would sit on screen for every reader to pay for the few whose name collided.
- **Where it is read** is [ui-design.md](../ui-design.md#sharing): a field above the switch, so a reader on their way to sharing meets the name before it is announced. That makes a bland fallback affordable and a prompt unnecessary.

## Alternatives considered

- **`device_info_plus`.** An eighth dependency for `brand`+`model`, "Google Pixel 8": not the reader's name for their phone, and identical on two of the same phone. Refused: it costs a package to arrive somewhere worse than the platform channel.
- **A name minted at first run**, two words from a list of our own. Distinct without asking, and in the product's register. Refused: a name nobody chose is a name nobody recognises in a picker, and a word list is a vocabulary to keep.
- **The first owned bar's name.** No dependency, key or field, but a lie the moment a second bar is offered from the same device, moving whenever that bar is renamed or deleted.
- **Asking at first run**, beside the first bar. Refused: a question put to every reader, including the many who never share, when they have least reason to care.
- **Overwriting the field with the granted name.** One name everywhere, but the network silently rewrites the reader's typing, and the suffix outlives the device that caused it.
- **Renaming while announced, re-announcing under the new name.** The lock's opposite. Refused: a guest's source keeps the instance name and is never re-pointed (FR-BAR-5), so a stale instance name is a guest bar that can never refresh again, and no screen would say so.

## Consequences

- **The app's first Kotlin and first `MethodChannel`**, in `MainActivity`, behind `platformNameProvider`: a seam a test overrides like any other ([ADR 18](18-data-crosses-the-edge-in-a-system-sheet.md)). No manifest entry and no permission: the setting is world-readable.
- `offeringsProvider` carries the LAN adapter at last, so an offer reaches the network.
- A rename still strands a guest that kept the old instance name. The repair is adding the bar again by the LAN (FR-BAR-5), so the lock is the whole of the protection.
- The index gains its first key about the device rather than a bar; `validateShelf` judges it under the same name rules as everything else ([ADR 08](08-names-ignore-case.md)).
