import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/model_view.dart';
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
  final notifier = ref.read(modelProvider.notifier);
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
  final notifier = ref.read(modelProvider.notifier);
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
class _ImportReview extends StatelessWidget {
  const _ImportReview(this.review);

  final ImportReview review;

  @override
  Widget build(BuildContext context) {
    final incoming = review.model;
    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: incoming == null
          ? _Refused(review.issues)
          : ModelView(
              (current) => _Replacing(incoming: incoming, current: current),
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
        for (final issue in issues)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $issue'),
          ),
      ],
    );
  }
}

/// What the file holds, what it stands to replace, and the button that does it.
/// The counts are what a reader recognises the file by: Android hands over no
/// name worth showing (ADR 18), and it is the collection being agreed to anyway.
class _Replacing extends ConsumerWidget {
  const _Replacing({required this.incoming, required this.current});

  final Model incoming;
  final Model current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('This file holds', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final holding in _holdings(incoming))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(holding),
          ),
        const SizedBox(height: 16),
        Text(
          'Replaces the ${counted(current.recipes.length, 'recipe')} and '
          '${counted(current.ingredients.length, 'bottle')} you have now. '
          'A copy of them is kept first.',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => unawaited(_replace(context, ref)),
          child: const Text('Replace everything'),
        ),
      ],
    );
  }

  /// Replaces everything and leaves for the collection itself: what was
  /// imported is two screens back, and the reader's own list is the answer no
  /// sentence improves on. Unlike a share, an import knows what it did, so it
  /// says so too — the messenger is the app's, so the word outlives both pops.
  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final replaced = await _wentThrough(
      messenger,
      'Could not import',
      () => ref.read(modelProvider.notifier).replaceAll(incoming),
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

/// What a collection amounts to, recipes first: a reader tells one file from
/// another by what it holds long before by how many units it declares.
List<String> _holdings(Model model) => [
  counted(model.recipes.length, 'recipe'),
  counted(model.ingredients.length, 'bottle'),
  counted(model.recipeTags.length + model.ingredientTags.length, 'tag'),
  counted(model.units.length, 'unit'),
];

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
