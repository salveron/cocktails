import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/arriving_bar.dart';
import '../widgets/editor_form.dart';

/// One pushed page for founding a bar (FR-BAR-2/7): what to call it, where its
/// contents come from, and — where a file carried them — whose bar it is. A
/// dialog held the name and nothing else; the roads a file opens need what it
/// holds put in front of the reader first, which is what earns a page
/// (docs/ui-design.md#bars). The founding opens the bar, so this leaves for it.
class BarFormScreen extends ConsumerStatefulWidget {
  const BarFormScreen({super.key});

  @override
  ConsumerState<BarFormScreen> createState() => _BarFormScreenState();
}

class _BarFormScreenState extends ConsumerState<BarFormScreen> {
  final _name = TextEditingController();

  /// The last file picked and what it turned out to be, or null while none has
  /// been: an empty bar is what Save founds until one is.
  ImportReview? _picked;

  BarMode _mode = BarMode.owner;

  /// What the reader called a bar of their own, held while a guest's owner
  /// names the field instead — so undoing that choice gives their name back.
  String _ownName = '';

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _dirty => !_name.isBlank || _picked != null;

  /// Nothing to save while the bar has no name, and nothing at all while a file
  /// the app could not read is standing — founding an empty bar in its place
  /// would be a lie about what became of it.
  bool get _canSave {
    final picked = _picked;
    if (picked == null) return !_name.isBlank;
    if (picked.bar == null) return false;
    // A guest bar's name is its owner's, so that field is never the reader's
    // to leave blank.
    return _mode == BarMode.guest || !_name.isBlank;
  }

  /// Puts a file's contents behind the bar, and its name in the field where the
  /// reader has not named one themselves. A file that will not read leaves the
  /// bar the reader's own — there is nothing to be a guest of.
  Future<void> _pick() async {
    final picked = await pickBar(context, ref);
    if (picked == null || !mounted) return;
    final arriving = picked.bar;
    if (arriving == null) {
      _mode = BarMode.owner;
    } else if (_name.isBlank) {
      _name.text = arriving.name;
    }
    setState(() => _picked = picked);
  }

  void _dropFile() => setState(() {
    _picked = null;
    _mode = BarMode.owner;
  });

  /// A guest bar's name is its owner's and every refresh brings it back
  /// (FR-BAR-5), so the field goes quiet and reads theirs while that road is
  /// chosen. The text moves outside `setState`, the controller's own listener
  /// being what asks for the frame.
  void _chose(BarMode mode, BarPayload arriving) {
    if (mode == _mode) return;
    if (mode == BarMode.guest) {
      _ownName = _name.text;
      _name.text = arriving.name;
    } else {
      _name.text = _ownName;
    }
    setState(() => _mode = mode);
  }

  /// The three roads out (FR-BAR-2/7), and the reader's typed name on the two
  /// that leave the bar theirs.
  Future<void> _save() async {
    final shelf = ref.read(shelfProvider.notifier);
    final arriving = _picked?.bar;
    if (_mode == BarMode.guest && arriving != null) {
      await shelf.addGuestBar(fileSource, arriving);
    } else {
      await shelf.addOwnedBar(_name.typed, from: arriving);
    }
    // Past the bar list this was reached through: a new bar is opened by the
    // making of it, so the reader lands in it rather than back on the gear.
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final arriving = picked?.bar;
    final guest = _mode == BarMode.guest;
    return EditorScaffold(
      title: 'New bar',
      dirty: _dirty,
      discardTitle: 'Discard this bar?',
      onSave: _canSave ? () => unawaited(_save()) : null,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          enabled: !guest,
          decoration: const InputDecoration(hintText: 'Bar name'),
        ),
        if (guest) const FieldNote("A guest bar keeps its owner's name."),
        const SectionLabel('Contents'),
        _Source(
          picked: picked != null,
          onPick: () => unawaited(_pick()),
          onDrop: _dropFile,
        ),
        if (picked == null)
          const FieldNote(
            'Empty unless a file fills it — an export another owner sent, or '
            'one this device made itself.',
          ),
        if (picked != null && arriving == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: RefusedFile(
              picked.issues,
              standing:
                  'Nothing has been added. Pick another file, or leave '
                  'the bar empty.',
            ),
          ),
        if (arriving != null) ...[
          const SectionLabel('Whose bar'),
          SegmentedButton<BarMode>(
            segments: const [
              ButtonSegment(value: BarMode.owner, label: Text('Owned')),
              ButtonSegment(value: BarMode.guest, label: Text('Guest')),
            ],
            selected: {_mode},
            onSelectionChanged: (chosen) => _chose(chosen.first, arriving),
          ),
          FieldNote(
            guest
                ? "The owner's, read to here and read-only. Refreshes from a "
                      'newer file they send.'
                : 'A copy, this device\'s own to edit. Nothing links it back '
                      'to the file.',
          ),
          const SectionLabel('What the file holds'),
          BarHoldings(arriving.collection),
        ],
      ],
    );
  }
}

/// Where the bar's contents come from — the one file transport today, and where
/// finding one nearby will stand (FR-BAR-8). The clear beside it is the way
/// back to an empty bar, and the way out of a file that would not read.
class _Source extends StatelessWidget {
  const _Source({
    required this.picked,
    required this.onPick,
    required this.onDrop,
  });

  final bool picked;
  final VoidCallback onPick;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: FilledButton.tonalIcon(
          onPressed: onPick,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(picked ? 'From another file' : 'From import'),
        ),
      ),
      if (picked) ...[
        const SizedBox(width: 8),
        IconButton(
          onPressed: onDrop,
          icon: const Icon(Icons.close),
          tooltip: 'Leave it empty',
        ),
      ],
    ],
  );
}
