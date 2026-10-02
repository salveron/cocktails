import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../wording.dart';
import '../widgets/cards/bar_holdings.dart';
import '../widgets/dialogs/nearby_dialog.dart';
import '../widgets/forms/editor_form.dart';
import '../widgets/forms/form_fields.dart';
import '../widgets/notices/empty_state.dart';
import '../widgets/notices/failures.dart';
import '../widgets/notices/snackbar.dart';

/// Where a file's contents end up. [own] and [replace] are one road at two
/// distances — a bar of the reader's own, founded here or standing already —
/// and which of the two is on offer follows from where the screen was reached
/// from rather than from anything the reader picks.
enum _Road { own, replace, guest }

/// A file off the system's picker, decoded and judged before anything is done
/// with it (FR-DAT-3/4). Null where nothing came back to judge: picking nothing
/// is nothing done, and a picker that would not open says so where it stands
/// rather than leaving the screen silent.
Future<ImportReview?> pickBar(BuildContext context, WidgetRef ref) async {
  final picker = ref.read(filePickerProvider);
  final shelf = ref.read(shelfProvider.notifier);
  ImportReview? review;
  final went = await wentThrough(
    ScaffoldMessenger.of(context),
    'Could not read that file',
    () async {
      final text = await picker();
      if (text != null) review = shelf.review(text);
    },
  );
  return went ? review : null;
}

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

  /// The last bar picked and what it turned out to be, or null while none has
  /// been: an empty bar is what Save founds until one is.
  ImportReview? _picked;

  /// Where what is in hand came from, which is what a guest bar keeps and asks
  /// again (FR-BAR-5). A file names no sender, so it is the road's own default
  /// until a bar arrives off the network.
  BarSource _source = fileSource;

  _Road _road = _Road.own;

  /// A bar found nearby is being fetched: the roads are closed and the spot its
  /// contents will fill says so, a browse and two asks over the wire being long
  /// enough for a reader to wonder.
  bool _fetching = false;

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
    _source = fileSource;
    setState(() {
      _picked = picked;
      _road = _arrivedRoad(picked);
    });
    _suggest(open);
  }

  void _dropFile(String open) {
    setState(() {
      _picked = null;
      _source = fileSource;
      _road = _Road.own;
    });
    _suggest(open);
  }

  /// FR-BAR-8: a bar found nearby, picked and then fetched — the pick is agreed
  /// to in the dialog and what it holds is read here, which is the one road a
  /// file already takes. A source that could not be reached leaves the form
  /// exactly as it stood and says why: nothing arrived to show.
  Future<void> _findNearby(String open) async {
    final found = await promptForNearby(context);
    if (found == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _fetching = true);
    final arrived = await ref.read(shelfProvider.notifier).reach(found.source);
    if (!mounted) return;
    setState(() => _fetching = false);
    final why = arrived.why;
    if (why != null) return say(messenger, nearbySaid(why, found.name));
    final review = arrived.review;
    if (review == null) return;
    _source = found.source;
    setState(() {
      _picked = review;
      _road = _arrivedRoad(review);
    });
    _suggest(open);
  }

  /// What a bar arriving lands on: **Guest**, which is what a bar someone else
  /// shared usually is, and the road that keeps the source it came by
  /// (FR-BAR-5). A file that will not read offers no road at all, so the screen
  /// keeps the one it opened on — there is nothing to be a guest of, and
  /// nothing to put in place of a collection.
  _Road _arrivedRoad(ImportReview arrived) =>
      arrived.bar == null ? _opened.road : _Road.guest;

  void _chose(_Road road, String open) {
    if (road == _road) return;
    setState(() => _road = road);
    _suggest(open);
  }

  /// [arriving] is non-null on the two roads that need it: each is offered only
  /// while a readable file is in hand, and dropping one puts the road back.
  Future<void> _take(_Road road, String name, BarContent? arriving) {
    final shelf = ref.read(shelfProvider.notifier);
    return switch (road) {
      _Road.own => shelf.addOwnedBar(name, from: arriving),
      _Road.guest => shelf.addGuestBar(name, _source, arriving!),
      _Road.replace => shelf.replaceOpen(name, arriving!),
    };
  }

  /// A road that would not go through stays on the screen and says why: leaving
  /// for a collection that never reached the disk is a lie about what happened.
  Future<void> _save(BarContent? arriving) async {
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
      // An import has nothing to put back: the file is what it is for.
      onReset: _importing || picked == null || _fetching
          ? null
          : () => _dropFile(open),
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
          taken: picked == null
              ? null
              : (_source.via == Transport.lan ? _Way.lan : _Way.file),
          // Closed while a bar is on its way: which roads exist is the entry's
          // to say, whether either may be taken now is the fetch's.
          open: !_fetching,
          // Importing is a file already in hand, so the road that would replace
          // it with something off the network is not one this entry offers.
          onFind: _importing ? null : () => unawaited(_findNearby(open)),
          onPick: () => unawaited(_pick(open)),
        ),
        if (_fetching) const Looking(),
        if (picked == null && !_fetching)
          const FieldNote(
            'Empty unless something fills it — an export another owner sent, '
            'or a bar shared nearby.',
          ),
        if (picked != null && arriving == null && !_fetching)
          _RefusedFileNote(picked: picked, importing: _importing, open: open),
        if (arriving != null && !_fetching)
          _ArrivedContent(
            arriving: arriving,
            importing: _importing,
            road: _road,
            onPickRoad: (road) => _chose(road, open),
          ),
      ],
    );
  }
}

class _RefusedFileNote extends StatelessWidget {
  const _RefusedFileNote({
    required this.picked,
    required this.importing,
    required this.open,
  });

  final ImportReview picked;
  final bool importing;
  final String open;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: RefusedFile(
      picked.issues,
      standing: importing
          ? 'Nothing has changed. "$open" stands as it was.'
          : 'Nothing has been added. Pick another file, or leave the bar '
                'empty.',
    ),
  );
}

class _ArrivedContent extends StatelessWidget {
  const _ArrivedContent({
    required this.arriving,
    required this.importing,
    required this.road,
    required this.onPickRoad,
  });

  final BarContent arriving;
  final bool importing;
  final _Road road;
  final void Function(_Road road) onPickRoad;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionLabel('Mode'),
      SizedBox(
        width: double.infinity,
        child: Segments(
          values: [importing ? _Road.replace : _Road.own, _Road.guest],
          selected: road,
          labelOf: (road) => switch (road) {
            _Road.own => 'Owned',
            _Road.replace => 'Replace',
            _Road.guest => 'Guest',
          },
          showSelectedIcon: true,
          onPick: onPickRoad,
        ),
      ),
      // One line each: the choice is read at a glance or not at all.
      FieldNote(switch (road) {
        _Road.own => 'A copy to edit here. Nothing refreshes it.',
        _Road.replace =>
          'Replace everything this bar holds now. A copy is kept.',
        _Road.guest =>
          "The owner's copy, read-only. Refreshed from its source.",
      }),
      const SectionLabel('Contents'),
      BarHoldings(arriving.collection),
    ],
  );
}

/// The two roads a bar's contents arrive by — a file the reader hands over
/// (FR-BAR-7) and one shared on the network (FR-BAR-8). One segmented shape,
/// the width of the fields and of the Mode choice below it, with neither half
/// ever staying lit: each leaves the screen and comes back with contents rather
/// than settling into a state. The labels say which road *and* what a second
/// tap would do, so a road already taken reads as one that may be taken again.
/// Where the file road stands alone — the import entry, which opens on a file
/// already picked — it is a button rather than a segment of one.
class _Source extends StatelessWidget {
  const _Source({
    required this.taken,
    required this.open,
    required this.onFind,
    required this.onPick,
  });

  /// The road what is in hand arrived by, and null while nothing is: it is the
  /// segment that stays lit, and the only label that changes.
  final _Way? taken;

  /// Whether either road may be taken now; which of them exist is [onFind]'s.
  final bool open;

  final VoidCallback? onFind;
  final VoidCallback onPick;

  /// A road not taken reads as it did before any was: the reader is not being
  /// told they may pick "another" of something they never picked. Alone, the
  /// file button has the width for the whole phrase; sharing a row, each half
  /// has about half a phone and would ellipsize.
  String _labelOf(_Way way) => switch ((way, way == taken, onFind == null)) {
    (_Way.file, false, _) => 'From import',
    (_Way.file, true, true) => 'Select another file',
    (_Way.file, true, false) => 'Another file',
    (_Way.lan, false, _) => 'From LAN',
    (_Way.lan, true, _) => 'Another bar',
  };

  @override
  Widget build(BuildContext context) {
    final onFind = this.onFind;
    if (onFind == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: open ? onPick : null,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(_labelOf(_Way.file)),
        ),
      );
    }
    return SegmentedActions<_Way>(
      values: _Way.values,
      taken: taken,
      labelOf: _labelOf,
      iconOf: (way) =>
          way == _Way.file ? Icons.file_open_outlined : Icons.wifi_tethering,
      onAct: open ? (way) => way == _Way.file ? onPick() : onFind() : null,
    );
  }
}

/// The two roads, named so the segments have something to be.
enum _Way { file, lan }
