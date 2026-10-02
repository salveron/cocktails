import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/forms/editor_form.dart';
import '../widgets/forms/form_fields.dart';
import '../widgets/notices/failures.dart';
import '../widgets/notices/snackbar.dart';

/// The room a bar is shared from (FR-BAR-6, docs/ui-design.md#sharing): what
/// this device is called, and the ways this bar travels on its own. Takes the
/// bar by id rather than reading the open one — Settings opens it on the bar in
/// hand, and a bar card's ⋮ opens the same room on one that is not.
class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen(this.barId, {super.key});

  final String barId;

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();

  /// Held rather than read where it is used: the field commits on the way out
  /// too, and a disposing widget has no `ref` to reach the shelf with.
  late final ShelfController _shelf;

  /// The last name this screen put on the record, and what it was seeded with
  /// until then — so a field the reader only looked at renames nothing, and the
  /// phone's own answer is not frozen into the index by a visit.
  late String _committed;

  @override
  void initState() {
    super.initState();
    _shelf = ref.read(shelfProvider.notifier);
    // Read once. The field is the reader's from here, and a rebuild must not
    // put back what they are in the middle of typing.
    _committed = ref.read(deviceNameProvider);
    _name.text = _committed;
    _focus.addListener(_leftTheField);
  }

  @override
  void dispose() {
    // A reader who typed and went straight back keeps what they typed.
    _commit();
    _focus.dispose();
    _name.dispose();
    super.dispose();
  }

  /// Leaving the field is the commit: a Settings control acts where it stands
  /// rather than waiting for a Save. A name the reader has not moved reaches
  /// the index as nothing at all.
  void _commit() {
    if (_name.isBlank || _name.typed == _committed) return;
    _committed = _name.typed;
    unawaited(_shelf.renameDevice(_committed));
  }

  /// A blank field is no name at all, so it gives back the one that stood
  /// rather than leaving the device nameless.
  void _leftTheField() {
    if (_focus.hasFocus) return;
    if (_name.isBlank) {
      _name.text = _committed;
      return;
    }
    _commit();
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
    // One announcement covers every bar this device offers, so what locks the
    // name is any of them being offered rather than this one (ADR 28).
    final offering = bar.offeredBy(Transport.lan);
    final elsewhere = bars.any(
      (other) => other.id != bar.id && other.offeredBy(Transport.lan),
    );
    final standing = ref.watch(sharingProvider)[bar.id];
    final locked = _lockedBy(offering: offering, elsewhere: elsewhere);
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(bar.name))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const SectionLabel('Device name'),
          TextField(
            controller: _name,
            focusNode: _focus,
            enabled: !offering && !elsewhere,
            decoration: const InputDecoration(hintText: 'Device name'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _focus.unfocus(),
          ),
          // Only where it will not take a change: what a name field is for
          // needs no saying, and a line under every field is one nobody reads.
          if (locked != null) FieldNote(locked),
          _Way(
            offering: offering,
            standing: standing,
            onShare: (offering) => unawaited(_share(offering)),
          ),
          const FieldNote('LAN sharing works only until the app is closed.'),
        ],
      ),
    );
  }
}

/// Why the name will not take a change, or null while it will — naming the bar
/// that locked it where that is not the one on show.
String? _lockedBy({required bool offering, required bool elsewhere}) {
  if (elsewhere) return 'Another bar is shared. Turn sharing off to rename.';
  return offering ? 'Turn sharing off to rename.' : null;
}

/// The one way that answers, a file being handed over rather than offered
/// (FR-BAR-7). A change still out has no switch at all: the reader has moved it
/// already, and one that slid back under them would be a lie about what is
/// happening.
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
