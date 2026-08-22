import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/arriving_bar.dart';
import '../widgets/editor_form.dart';
import '../widgets/telling.dart';
import '../widgets/vocabulary_list.dart';

/// Where a file's contents end up. [own] and [replace] are one road at two
/// distances — a bar of the reader's own, founded here or standing already —
/// and which of the two is on offer follows from where the screen was reached
/// from rather than from anything the reader picks.
enum _Road { own, replace, guest }

/// One pushed page for a bar arriving: what to call it, where its contents come
/// from, and what becomes of the file (FR-BAR-2/7, FR-DAT-3). Founding and
/// importing ask the same three questions of the same file, so they are one
/// screen reached two ways — a dialog once held the name and nothing else, and
/// a second screen held the counts and nothing else (docs/ui-design.md#new-bar).
class BarFormScreen extends ConsumerStatefulWidget {
  /// FR-BAR-2/7: a bar founded here, left empty or filled from a picked file.
  const BarFormScreen.founding({super.key}) : arriving = null;

  /// FR-DAT-3, FR-BAR-7: a file already picked, bound for the open bar or for a
  /// guest bar of its own.
  const BarFormScreen.importing(ImportReview this.arriving, {super.key});

  /// The file the screen opened on; null where the reader picks their own.
  final ImportReview? arriving;

  @override
  ConsumerState<BarFormScreen> createState() => _BarFormScreenState();
}

class _BarFormScreenState extends ConsumerState<BarFormScreen> {
  final _name = TextEditingController();

  /// The last file picked and what it turned out to be, or null while none has
  /// been: an empty bar is what Save founds until one is.
  ImportReview? _picked;

  _Road _road = _Road.own;

  /// The name the road put in the field, kept so the reader's own is told from
  /// it: a suggestion gives way when the road changes, a name typed over one
  /// stands.
  String _suggested = '';

  /// What the screen opened holding, so backing out asks only where the reader
  /// has moved something themselves.
  late final ({ImportReview? picked, _Road road, String name}) _opened;

  @override
  void initState() {
    super.initState();
    _picked = widget.arriving;
    _road = widget.arriving == null ? _Road.own : _Road.replace;
    // No build yet to watch it through, so this one read stands alone.
    _suggest(ref.read(openBarProvider)?.name ?? '');
    _opened = (picked: _picked, road: _road, name: _name.text);
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _importing => widget.arriving != null;

  bool get _dirty =>
      _picked != _opened.picked ||
      _road != _opened.road ||
      _name.text != _opened.name;

  /// Nothing to save while the bar has no name, and nothing at all while a file
  /// the app could not read is standing: founding an empty bar in its place, or
  /// emptying a collection in its name, would each be a lie about the file.
  bool get _canSave {
    final picked = _picked;
    return !_name.isBlank && (picked == null || picked.bar != null);
  }

  /// The name the road offers, in the field where the reader has not written
  /// their own. Replacing puts back the bar being replaced, which the import is
  /// not renaming; the two roads that found a bar start from the file's own
  /// name (ADR 21), and from nothing where there is no file to take one from.
  /// The text moves outside `setState`, the controller's own listener being
  /// what asks for the frame. [open] is `build`'s own watch of it, threaded
  /// through rather than read again here.
  void _suggest(String open) {
    final offered = switch (_road) {
      _Road.replace => open,
      _Road.own || _Road.guest => _picked?.bar?.name ?? '',
    };
    if (_name.text == _suggested) _name.text = offered;
    _suggested = offered;
  }

  Future<void> _pick(String open) async {
    final picked = await pickBar(context, ref);
    if (picked == null || !mounted) return;
    // A file that will not read leaves the roads where the screen opened them:
    // there is nothing to be a guest of, and nothing to put in place of a
    // collection.
    if (picked.bar == null) _road = _opened.road;
    setState(() => _picked = picked);
    _suggest(open);
  }

  void _dropFile(String open) {
    setState(() {
      _picked = null;
      _road = _Road.own;
    });
    _suggest(open);
  }

  void _chose(_Road road, String open) {
    if (road == _road) return;
    setState(() => _road = road);
    _suggest(open);
  }

  /// [arriving] is non-null on the two roads that need it: each is offered only
  /// while a readable file is in hand, and dropping one puts the road back.
  Future<void> _take(_Road road, String name, BarPayload? arriving) {
    final shelf = ref.read(shelfProvider.notifier);
    return switch (road) {
      _Road.own => shelf.addOwnedBar(name, from: arriving),
      _Road.guest => shelf.addGuestBar(name, fileSource, arriving!),
      _Road.replace => shelf.replaceOpen(name, arriving!),
    };
  }

  /// A road that would not go through stays on the screen and says why: leaving
  /// for a collection that never reached the disk is a lie about what happened.
  Future<void> _save(BarPayload? arriving) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final road = _road;
    final refusal = switch (road) {
      _Road.own => 'Could not make that bar',
      _Road.guest => 'Could not add that bar',
      _Road.replace => 'Could not import',
    };
    final went = await wentThrough(
      messenger,
      refusal,
      () => _take(road, _name.typed, arriving),
    );
    if (!went) return;
    // Past the list or the gear this was reached through: a bar founded here is
    // opened by the making of it, and a bar replaced is read where it stands.
    navigator.popUntil((route) => route.isFirst);
    // Only the road that puts the reader back where they started says what it
    // did — the other two answer with a bar that was not there before.
    if (road == _Road.replace && arriving != null) {
      final recipes = arriving.collection.recipes.length;
      say(messenger, '${counted(recipes, 'recipe')} imported.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final arriving = picked?.bar;
    // Named wherever Replace is offered: that road is reached through the open
    // bar's own gear.
    final open = ref.watch(openBarProvider)?.name ?? '';
    return EditorScaffold(
      title: _importing ? 'Import' : 'New bar',
      dirty: _dirty,
      discardTitle: _importing ? 'Discard this import?' : 'Discard this bar?',
      onSave: _canSave ? () => unawaited(_save(arriving)) : null,
      children: [
        TextField(
          controller: _name,
          // The pick is done on the way in when importing, so the screen is
          // there to be read rather than typed into.
          autofocus: !_importing,
          decoration: const InputDecoration(hintText: 'Bar name'),
        ),
        // No heading: the button says what it does, and the note under it says
        // what standing without one means.
        const SizedBox(height: 16),
        _Source(
          picked: picked != null,
          onPick: () => unawaited(_pick(open)),
          // An import has nothing to leave empty: the file is what it is for.
          onDrop: _importing ? null : () => _dropFile(open),
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
              standing: _importing
                  ? 'Nothing has changed. "$open" stands as it was.'
                  : 'Nothing has been added. Pick another file, or leave the '
                        'bar empty.',
            ),
          ),
        if (arriving != null) ...[
          const SectionLabel('Mode'),
          Segments(
            values: [_importing ? _Road.replace : _Road.own, _Road.guest],
            selected: _road,
            labelOf: (road) => switch (road) {
              _Road.own => 'Owned',
              _Road.replace => 'Replace',
              _Road.guest => 'Guest',
            },
            showSelectedIcon: true,
            onPick: (road) => _chose(road, open),
          ),
          // One line each: the choice is read at a glance or not at all.
          FieldNote(switch (_road) {
            _Road.own => 'A copy to edit here. Nothing refreshes it.',
            _Road.replace =>
              'Replace everything this bar holds now. A copy is kept.',
            _Road.guest =>
              "The owner's copy, read-only. Refreshed from their file.",
          }),
          const SectionLabel('Contents'),
          BarHoldings(arriving.collection),
        ],
      ],
    );
  }
}

/// Where the bar's contents come from — the one file transport today, and where
/// finding one nearby will stand (FR-BAR-8). The clear beside it is the way back
/// to an empty bar, and the way out of a file that would not read; it is absent
/// where there is no such way back.
class _Source extends StatelessWidget {
  const _Source({
    required this.picked,
    required this.onPick,
    required this.onDrop,
  });

  final bool picked;
  final VoidCallback onPick;
  final VoidCallback? onDrop;

  @override
  Widget build(BuildContext context) {
    final onDrop = this.onDrop;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onPick,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(picked ? 'Choose another file' : 'From import'),
          ),
        ),
        if (picked && onDrop != null) ...[
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
}
