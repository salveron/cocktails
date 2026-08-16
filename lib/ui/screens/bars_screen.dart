import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../destinations.dart';
import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';
import 'bar_form_screen.dart';

/// A stamp as a reader tells the time: the largest whole unit it has been, and
/// "just now" under a minute. Coarse on purpose — how current a bar is answers
/// whether to refresh it, which no count of seconds makes clearer.
String _agoInWords(DateTime now, DateTime at) {
  const scale = [
    (31536000, 'year'),
    (2592000, 'month'),
    (604800, 'week'),
    (86400, 'day'),
    (3600, 'hour'),
    (60, 'minute'),
  ];
  final seconds = now.difference(at).inSeconds;
  for (final (span, noun) in scale) {
    if (seconds >= span) return '${counted(seconds ~/ span, noun)} ago';
  }
  return 'just now';
}

/// Every bar the device holds, and everything done to one — the screen that
/// lists bars is the screen that manages them, so no second place holds half of
/// it (FR-BAR-1/2, docs/ui-design.md#bars). Reached behind the gear, and home
/// whenever no bar is open ([ADR 20](../../../docs/adr/20-the-app-holds-many-bars.md)).
class BarsScreen extends ConsumerStatefulWidget {
  const BarsScreen({super.key});

  @override
  ConsumerState<BarsScreen> createState() => _BarsScreenState();
}

class _BarsScreenState extends ConsumerState<BarsScreen> {
  /// Which cards stand open. Nothing is fetched to open one: what a bar holds
  /// is counted on its record (ADR 20), so this is the whole of a card's state.
  final _opened = <String>{};

  @override
  Widget build(BuildContext context) {
    // Home is this screen wherever no bar is open, so a copy pushed from the
    // gear steps aside rather than standing on top of one just like it.
    ref.listen(openBarProvider, (_, open) {
      if (open == null) _leave();
    });
    final bars = ref.watch(barsProvider);
    final openId = ref.watch(openBarProvider)?.id;
    // One reading for the whole list, so no two cards date themselves apart.
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(title: const Text('Bars')),
      body: bars.isEmpty
          ? const EmptyState(
              icon: Icons.liquor_outlined,
              title: 'No bars',
              message:
                  'A bar holds one collection — its recipes, its bottles, and '
                  'the tags and units they are written in.',
            )
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [
                for (final bar in bars)
                  _card(bar, now, isOpen: bar.id == openId),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_add()),
        tooltip: 'New bar',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// The name and how current the bar is while closed, what it holds once
  /// opened. Whose bar it is rides beside the ⋮ as a chip, the mode being what
  /// decides everything the bar offers (FR-BAR-3).
  Widget _card(Bar bar, DateTime now, {required bool isOpen}) {
    final standing = _standing(bar, now, isOpen: isOpen);
    return VocabularyRow(
      title: Text(bar.name),
      subtitle: standing == null ? null : Text(standing),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BarModeChip(bar.mode),
          RowMenu({
            // Offered on a guest bar too: what a bar is called here is the
            // reader's, as the unit it reads in is (FR-BAR-3, ADR 21).
            'Rename': () => unawaited(_rename(bar)),
            'Delete': () => unawaited(_delete(bar)),
          }),
        ],
      ),
      body: _opened.contains(bar.id) ? _body(bar) : null,
      onTap: () => setState(() {
        if (!_opened.remove(bar.id)) _opened.add(bar.id);
      }),
    );
  }

  /// Which bar is loaded, and how long ago it last became what it holds — an
  /// owner's own edit, a guest's last answer from its source (FR-BAR-5). Null
  /// where there is neither to say: a bar summarised before this device kept
  /// stamps has no date to give, and says nothing rather than guessing one.
  String? _standing(Bar bar, DateTime now, {required bool isOpen}) {
    final at = bar.isOwned ? bar.updated : bar.refreshed;
    final parts = [
      if (isOpen) 'Loaded',
      if (at != null)
        '${bar.isOwned ? 'Updated' : 'Synced'} ${_agoInWords(now, at)}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _body(Bar bar) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _counts(bar),
      const SizedBox(height: 8),
      // Right, where the card's one commit belongs and where every dialog in
      // the app puts its own; filled tonal, being the thing the card opens for.
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.tonal(
          onPressed: () => unawaited(_open(bar)),
          child: const Text('Open bar'),
        ),
      ),
    ],
  );

  /// How much the bar holds, kind by kind, read off the record the list is
  /// already holding — no file, no wait, no spinner over four numbers (ADR 20).
  /// A bar whose file could not be read carries no summary and says so.
  Widget _counts(Bar bar) {
    final holds = bar.holds;
    if (holds == null) {
      return Text(
        'This bar could not be read.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return BulletRuns([
      bulletRun([
        for (final holding in holds.entries)
          counted(holding.value, holding.key.noun),
      ]),
    ]);
  }

  /// A crossing takes the reader to the bar itself rather than back to the gear
  /// they reached this screen through (FR-BAR-1). The bar already loaded is
  /// crossed into just the same — there is nothing to read again, so the reader
  /// is simply put where the crossing would have left them.
  Future<void> _open(Bar bar) async {
    if (bar.id == ref.read(openBarProvider)?.id) {
      ref.read(revealProvider.notifier).land(Destination.recipes);
    } else {
      await ref.read(shelfProvider.notifier).openBar(bar.id);
    }
    _leave();
  }

  /// FR-BAR-2/7: the name, and where the bar's contents come from. A pushed
  /// form rather than a dialog, the file roads needing what a file holds put in
  /// front of the reader first — and it leaves for the new bar itself, a bar
  /// being opened by the making of it.
  Future<void> _add() => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const BarFormScreen.founding()),
  );

  Future<void> _rename(Bar bar) async {
    final name = await promptForName(
      context,
      title: 'Rename bar',
      hintText: 'What to name it',
      initial: bar.name,
    );
    if (name == null) return;
    await ref.read(shelfProvider.notifier).renameBar(bar.id, name);
  }

  /// FR-BAR-2: confirmed, and the copy said out loud — the same promise an
  /// import makes before replacing a collection.
  Future<void> _delete(Bar bar) async {
    final agreed = await confirmDialog(
      context,
      title: 'Delete "${bar.name}"?',
      message: 'Everything in it goes with it. A copy is kept first.',
      cancel: 'Cancel',
      confirm: 'Delete',
    );
    if (!agreed) return;
    await ref.read(shelfProvider.notifier).removeBar(bar.id);
  }

  /// Back to the bar on show, however deep the gear left this screen — where
  /// there is nothing to pop this screen is already home and stays.
  void _leave() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
