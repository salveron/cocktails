import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/empty_state.dart';
import '../widgets/vocabulary_dialogs.dart';
import '../widgets/vocabulary_list.dart';

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
  /// The cards standing open, each holding what its one read answered with. A
  /// card opening is what sends the app to disk — the list itself knows only
  /// the index (ADR 20) — and the future is kept so a rebuild does not ask a
  /// second time. Closing a card forgets it, so opening it again reads afresh.
  final _opened = <String, Future<Map<Holding, int>?>>{};

  @override
  Widget build(BuildContext context) {
    // Home is this screen wherever no bar is open, so a copy pushed from the
    // gear steps aside rather than standing on top of one just like it.
    ref.listen(openBarProvider, (_, open) {
      if (open == null) _leave();
    });
    final bars = ref.watch(barsProvider);
    final openId = ref.watch(openBarProvider)?.id;
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
                for (final bar in bars) _card(bar, isOpen: bar.id == openId),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_add()),
        tooltip: 'New bar',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// The name while closed, what the bar holds and what may be done to it once
  /// opened. The bar on show offers no way in, which is how the list says which
  /// one that is.
  Widget _card(Bar bar, {required bool isOpen}) {
    final holdings = _opened[bar.id];
    return VocabularyRow(
      title: Text(bar.name),
      trailing: Icon(holdings == null ? Icons.expand_more : Icons.expand_less),
      body: holdings == null ? null : _body(bar, holdings, isOpen: isOpen),
      onTap: () => setState(() {
        if (_opened.remove(bar.id) != null) return;
        _opened[bar.id] = ref
            .read(shelfProvider.notifier)
            .holdingsOfBar(bar.id);
      }),
    );
  }

  Widget _body(
    Bar bar,
    Future<Map<Holding, int>?> holdings, {
    required bool isOpen,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FutureBuilder(future: holdings, builder: _counts),
      OverflowBar(
        spacing: 8,
        children: [
          if (!isOpen)
            TextButton(
              onPressed: () => unawaited(_open(bar)),
              child: const Text('Open bar'),
            ),
          TextButton(
            onPressed: () => unawaited(_rename(bar)),
            child: const Text('Rename'),
          ),
          TextButton(
            onPressed: () => unawaited(_delete(bar)),
            child: const Text('Delete'),
          ),
        ],
      ),
    ],
  );

  /// How much the bar holds, kind by kind. Nothing stands here while the read
  /// is in flight: a card that has just opened is a moment old, and a spinner
  /// on four numbers reads as longer than the wait it stands for.
  Widget _counts(
    BuildContext context,
    AsyncSnapshot<Map<Holding, int>?> snapshot,
  ) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SizedBox.shrink();
    }
    final holdings = snapshot.data;
    if (holdings == null) {
      return Text(
        'This bar could not be read.',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return BulletRuns([
      bulletRun([
        for (final holding in holdings.entries)
          counted(holding.value, holding.key.noun),
      ]),
    ]);
  }

  /// A crossing takes the reader to the bar itself rather than back to the gear
  /// they reached this screen through (FR-BAR-1).
  Future<void> _open(Bar bar) async {
    await ref.read(shelfProvider.notifier).openBar(bar.id);
    _leave();
  }

  /// FR-BAR-2. A new bar is opened by the making of it, so this leaves for it
  /// the way a crossing does.
  Future<void> _add() async {
    final name = await promptForName(
      context,
      title: 'New bar',
      hintText: "What you'll call it",
    );
    if (name == null) return;
    await ref.read(shelfProvider.notifier).addOwnedBar(name);
    _leave();
  }

  Future<void> _rename(Bar bar) async {
    final name = await promptForName(
      context,
      title: 'Rename bar',
      hintText: "What you'll call it",
      initial: bar.name,
    );
    if (name == null) return;
    await ref.read(shelfProvider.notifier).renameBar(bar.id, name);
  }

  /// FR-BAR-2: confirmed, and the copy said out loud — the same promise the
  /// import review makes before replacing a collection.
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
