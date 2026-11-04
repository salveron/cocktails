import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/forms/committed_field.dart';
import '../widgets/forms/form_fields.dart';
import '../widgets/notices/failures.dart';
import '../widgets/notices/snackbar.dart';

/// The room a bar is shared from (FR-BAR-6, docs/ui-design.md#sharing): what it
/// is called, and every way it leaves — as a file, and over the LAN. Takes the
/// bar by id rather than reading the open one — Settings opens it on the bar in
/// hand, and a bar card's ⋮ opens the same room on one that is not — and any
/// bar will do, a guest's as an owner's.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen(this.barId, {super.key});

  final String barId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  /// Held rather than read where it is used: the fields commit on the way out
  /// too, and a disposing widget has no `ref` to reach the shelf with.
  late final ShelfController _shelf;

  /// Read once. The field is the reader's from there (`CommittedField`).
  late final String _deviceName;

  @override
  void initState() {
    super.initState();
    _shelf = ref.read(shelfProvider.notifier);
    _deviceName = ref.read(deviceNameProvider);
  }

  /// FR-DAT-1: the copy handed to the system's sheet. The sheet opening is the
  /// whole answer, so only a failure speaks — and a reader who dismisses the
  /// sheet has done nothing, which is not one.
  Future<void> _export() async {
    final sharer = ref.read(sharerProvider);
    await wentThrough(
      ScaffoldMessenger.of(context),
      'Could not export',
      () async => sharer(await _shelf.export(widget.barId)),
    );
  }

  /// FR-BAR-6: the offer put on the record and announced, or withdrawn and
  /// silenced. The record moves first, so a failure is reported rather than
  /// quietly un-offering the bar (ADR 22) — the switch is already saying the
  /// truth, and the snackbar says the part it cannot.
  Future<void> _share(bool offering) async {
    final messenger = ScaffoldMessenger.of(context);
    final sharing = ref.read(sharingProvider.notifier);
    await (offering
        ? _shelf.offerBar(widget.barId, Transport.lan)
        : _shelf.withdrawBar(widget.barId, Transport.lan));
    final said = sharingSaid(
      sharing.standing(widget.barId),
      offering: offering,
    );
    if (said == null) return;
    sharing.told(widget.barId);
    say(messenger, said);
  }

  @override
  Widget build(BuildContext context) {
    final bars = ref.watch(barsProvider);
    final bar = bars.where((bar) => bar.id == widget.barId).firstOrNull;
    // Deleted from under the screen: nothing left to share, and the bar the
    // app bar is the way back from.
    if (bar == null) return Scaffold(appBar: AppBar());
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(bar.name))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SectionLabel('Bar name'),
          // The bar's one name, so the card, the file and the list a guest
          // browses all follow it; a guest's is a label on this device.
          CommittedField(
            initial: bar.name,
            hintText: 'Bar name',
            validate: (name) => validateBarName(
              name,
              bars: bars,
              owned: bar.isOwned,
              except: bar.id,
            ),
            onCommit: (name) => unawaited(_shelf.renameBar(bar.id, name)),
          ),
          const FieldNote('Name the file and the bar on LAN.'),
          const SectionLabel('File'),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => unawaited(_export()),
              icon: const Icon(Icons.ios_share),
              label: const Text('Export as file'),
            ),
          ),
          // A way with no adapter in this build is absent rather than dimmed,
          // as everything a bar cannot do is.
          if (ref.watch(offeringsProvider).containsKey(Transport.lan))
            ..._lan(bar, bars),
        ],
      ),
    );
  }

  /// The device's name and the switch: the one way that is an arrangement
  /// rather than an act.
  List<Widget> _lan(Bar bar, List<Bar> bars) {
    // One announcement covers every bar this device offers, so what locks the
    // name is any of them being offered rather than this one (ADR 28).
    final offering = bar.offeredBy(Transport.lan);
    final elsewhere = bars.any(
      (other) => other.id != bar.id && other.offeredBy(Transport.lan),
    );
    final locked = _lockedBy(offering: offering, elsewhere: elsewhere);
    return [
      const SectionLabel('Device name'),
      CommittedField(
        initial: _deviceName,
        hintText: 'Device name',
        enabled: !offering && !elsewhere,
        onCommit: (name) => unawaited(_shelf.renameDevice(name)),
      ),
      // Only where it will not take a change: what a name field is for needs no
      // saying, and a line under every field is one nobody reads.
      if (locked != null) FieldNote(locked),
      _Way(
        offering: offering,
        standing: ref.watch(sharingProvider)[bar.id],
        onShare: (offering) => unawaited(_share(offering)),
      ),
      const FieldNote('Keep the app open to share over LAN.'),
    ];
  }
}

/// Why the device name will not take a change, or null while it will — naming
/// the bar that locked it where that is not the one on show.
String? _lockedBy({required bool offering, required bool elsewhere}) {
  if (elsewhere) return 'Another bar is shared. Turn sharing off to rename.';
  return offering ? 'Turn sharing off to rename.' : null;
}

/// The one way that offers and withdraws, a file being handed over rather than
/// offered (FR-BAR-7). A change still out has no switch at all: the reader has
/// moved it already, and one that slid back under them would be a lie about
/// what is happening.
class _Way extends StatelessWidget {
  const _Way({
    required this.offering,
    required this.standing,
    required this.onShare,
  });

  final bool offering;
  final SharingState? standing;
  final void Function(bool offering) onShare;

  /// Sealed, so a state added later is a compile error rather than a switch
  /// that quietly keeps drawing.
  bool get _out => switch (standing) {
    Announcing() || Silencing() => true,
    null || SharingFailed() => false,
  };

  @override
  Widget build(BuildContext context) => _out
      ? const ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_wayLabel),
          trailing: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(_wayLabel),
          value: offering,
          onChanged: onShare,
        );
}

/// The room names the bar it acts on, so the ⋮ opening it on one not in hand
/// needs no second way of saying which.
String _titleFor(String bar) => 'Share "$bar"';

const _wayLabel = 'Enable LAN';
