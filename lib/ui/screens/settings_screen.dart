import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/vocabulary_list.dart';
import 'amounts_screen.dart';
import 'tags_screen.dart';
import 'units_screen.dart';

/// Settings pushed from app bar gear: the vocabularies that travel, then the
/// one exchange read twice — the file leaving and the file coming back, which
/// is why both live here rather than drifting apart (ADR 18,
/// docs/ui-design.md#data).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        const _Entry.opens(
          icon: Icons.label_outline,
          title: 'Tags',
          subtitle: 'Recipe and ingredient labels, and their colours',
          page: TagsScreen(),
        ),
        const _Entry.opens(
          icon: Icons.straighten_outlined,
          title: 'Units',
          subtitle: 'What a recipe line is measured in, and its plural',
          page: UnitsScreen(),
        ),
        const _Entry.opens(
          icon: Icons.swap_horiz,
          title: 'Amounts',
          subtitle: 'The unit amounts read in, and what each is worth',
          page: AmountsScreen(),
        ),
        _Entry.acts(
          icon: Icons.ios_share,
          title: 'Export',
          subtitle: 'Share everything as one text file',
          act: () => unawaited(_export(context, ref)),
        ),
        _Entry.acts(
          icon: Icons.file_open_outlined,
          title: 'Import',
          subtitle: 'Replace everything from one text file',
          act: () => unawaited(_import(context, ref)),
        ),
      ],
    ),
  );
}

/// Runs [action] and answers whether it got through, [refusal] leading the
/// snackbar where it did not. Every failure speaks, not only the `Exception`s:
/// nothing awaits some of these, so what is not caught here reaches a reader as
/// nothing happening at all, which is the one outcome worse than a refusal.
Future<bool> _wentThrough(
  ScaffoldMessengerState messenger,
  String refusal,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('$refusal: $error')));
    return false;
  }
}

/// Writes the copy and hands it to the system's sheet (FR-DAT-1). The sheet
/// opening is the whole answer, so only a failure speaks — and a reader who
/// dismisses the sheet has done nothing, which is not one.
Future<void> _export(BuildContext context, WidgetRef ref) async {
  final sharer = ref.read(sharerProvider);
  final notifier = ref.read(collectionProvider.notifier);
  await _wentThrough(
    ScaffoldMessenger.of(context),
    'Could not export',
    () async => sharer(await notifier.export()),
  );
}

/// Takes a file off the system's picker and puts what is in it in front of the
/// reader (FR-DAT-3/4). Nothing is touched here: the review is where a replace
/// is agreed to, and `review` cannot fail — the codec answers a file it cannot
/// read with issues rather than an exception.
Future<void> _import(BuildContext context, WidgetRef ref) async {
  final picker = ref.read(filePickerProvider);
  final notifier = ref.read(collectionProvider.notifier);
  final navigator = Navigator.of(context);
  await _wentThrough(
    ScaffoldMessenger.of(context),
    'Could not read that file',
    () async {
      final text = await picker();
      // A reader who picked nothing has done nothing, which is not a failure.
      if (text == null) return;
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => _ImportReview(notifier.review(text)),
        ),
      );
    },
  );
}

/// What a picked file turned out to be, and the one place a replace is agreed to
/// (FR-DAT-3/4). Pushed rather than shown over the list, the room a
/// confirmation and a report need arriving after the pick rather than before it.
/// Accept rides the app bar, where every other commit in the app sits
/// (`editor_form.dart`); the weight of the act is carried by a body that spells
/// out everything arriving, not by the size of the button agreeing to it.
class _ImportReview extends ConsumerWidget {
  const _ImportReview(this.review);

  final ImportReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The collection alone: what else the file carries is the two destinations'
    // to take, and both are M36's (FR-BAR-7).
    final incoming = review.bar?.collection;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
        actions: [
          // A file the app cannot read holds nothing to accept.
          if (incoming != null)
            TextButton(
              onPressed: () => unawaited(_accept(context, ref, incoming)),
              child: const Text('Accept'),
            ),
        ],
      ),
      body: incoming == null ? _Refused(review.issues) : _Holdings(incoming),
    );
  }

  /// Replaces everything and leaves for the collection itself: what was imported
  /// is two screens back, and the reader's own list is the answer no sentence
  /// improves on. Unlike a share, an import knows what it did, so it says so
  /// too — the messenger is the app's, so the word outlives both pops.
  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    Collection incoming,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final replaced = await _wentThrough(
      messenger,
      'Could not import',
      () => ref.read(collectionProvider.notifier).replaceAll(incoming),
    );
    if (!replaced) return;
    navigator.popUntil((route) => route.isFirst);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${counted(incoming.recipes.length, 'recipe')} imported.',
        ),
      ),
    );
  }
}

/// Why the file was not read, and where (FR-DAT-4). There is nothing to agree
/// to: a file the app cannot read holds nothing to import.
class _Refused extends StatelessWidget {
  const _Refused(this.issues);

  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This file cannot be imported',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Nothing has changed. Your collection is exactly as it was.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        BulletRuns([bulletRun(issues)]),
      ],
    );
  }
}

/// Everything the file carries, kind by kind, each card opening to the names
/// behind its count — every one of them, however many: a reader agreeing to
/// replace a collection is owed sight of the one replacing it, and a list cut
/// short is exactly where the entry they were looking for would have been.
class _Holdings extends StatefulWidget {
  const _Holdings(this.incoming);

  final Collection incoming;

  @override
  State<_Holdings> createState() => _HoldingsState();
}

class _HoldingsState extends State<_Holdings> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 16),
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          'Replaces everything you have now. A copy of it is kept first.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      for (final holding in _holdingsOf(widget.incoming)) _card(holding),
    ],
  );

  /// Count as the title, the names themselves as the line under it, the whole
  /// list when opened. A kind the file holds none of opens onto nothing, so it
  /// offers no chevron and does not answer a tap.
  Widget _card(_Holding holding) {
    final open = _open.contains(holding.noun);
    final empty = holding.count == 0;
    return VocabularyRow(
      title: Text(counted(holding.count, holding.noun)),
      subtitle: open || empty
          ? null
          : Text(holding.line, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: empty
          ? null
          : Icon(open ? Icons.expand_less : Icons.expand_more),
      body: open ? BulletRuns(holding.runs) : null,
      onTap: empty ? null : () => setState(() => _open.toggle(holding.noun)),
    );
  }
}

/// One kind the file carries: what the app calls it, and the names behind it.
final class _Holding {
  const _Holding(this.noun, this.runs);

  final String noun;

  /// One run but for the tags, whose single count covers two vocabularies a
  /// body has to keep apart (ADR 07).
  final List<BulletRun> runs;

  int get count => runs.fold(0, (total, run) => total + run.bullets.length);

  /// Runs end to end, as the line under the title reads them — and only as far
  /// as the ellipsis can outrun, the body being where the rest is owed. Joining
  /// two thousand names lays out a paragraph to show one line of it.
  String get line => runs
      .expand((run) => run.bullets)
      .take(_lineNames)
      .map((bullet) => bullet.name)
      .join(', ');
}

/// More names than a phone's width fits, so the ellipsis lands on the line
/// rather than on the count of what was left out of it.
const _lineNames = 24;

/// What the file amounts to, recipes first: a reader tells one collection from
/// another by what it makes long before by the vocabulary serving it. Each kind
/// is named and ordered as the screen managing it names and orders it, so a card
/// here reads as the list it stands for (`inventory_screen.dart`,
/// `tags_screen.dart`, `units_screen.dart`).
List<_Holding> _holdingsOf(Collection collection) => [
  _Holding('recipe', [_run(collection.recipes.map((recipe) => recipe.name))]),
  _Holding('ingredient', [
    _run(collection.ingredients.map((ingredient) => ingredient.name)),
  ]),
  _Holding('tag', [
    _run(collection.recipeTags.map((tag) => tag.name), label: 'Recipe'),
    _run(collection.ingredientTags.map((tag) => tag.name), label: 'Ingredient'),
  ]),
  _Holding('unit', [
    _run(collection.units.map((unit) => unit.name), sorted: false),
  ]),
];

/// A→Z on the app's one ordering (ADR 08), so a reader scanning a long card
/// finds a name where every other list in the app would put it — but for the
/// units, whose vocabulary order carries the fixed three first and which
/// `units_screen.dart` leaves standing (ADR 17).
BulletRun _run(Iterable<String> names, {String? label, bool sorted = true}) =>
    bulletRun(sorted ? ([...names]..sort(byName)) : names, label: label);

/// One row of the menu: what it is, and what a tap does with it. A row that
/// travels wears the chevron saying so; a row that acts where it stands
/// carries none, which is the whole of the telling.
class _Entry extends StatelessWidget {
  const _Entry.opens({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  }) : act = null;

  const _Entry.acts({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.act,
  }) : page = null;

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;
  final VoidCallback? act;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: page == null ? null : const Icon(Icons.chevron_right),
    onTap:
        act ??
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => page!)),
  );
}
