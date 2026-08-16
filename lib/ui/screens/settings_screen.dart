import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/arriving_bar.dart';
import '../widgets/vocabulary_list.dart';
import 'amounts_screen.dart';
import 'bars_screen.dart';
import 'tags_screen.dart';
import 'units_screen.dart';

/// Settings pushed from app bar gear: the vocabularies that travel, then the
/// one exchange read twice — the file leaving and the file coming back, which
/// is why both live here rather than drifting apart (ADR 18,
/// docs/ui-design.md#data).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // What may be written to the open bar, and null on a guest one. The rows
    // that would change the owner's collection stay where they are and go
    // quiet: dimmed, leading nowhere (FR-BAR-4).
    final writable = ref.watch(barWriterProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _Entry.opens(
            icon: Icons.label_outline,
            title: 'Tags',
            subtitle: 'Labels and their colours',
            page: const TagsScreen(),
            enabled: writable,
          ),
          _Entry.opens(
            icon: Icons.straighten_outlined,
            title: 'Units',
            subtitle: 'What lines are measured in',
            page: const UnitsScreen(),
            enabled: writable,
          ),
          // The pick is the reader's on any bar, so this one never dims; what
          // it offers there is the pick alone (FR-BAR-3).
          const _Entry.opens(
            icon: Icons.swap_horiz,
            title: 'Amounts',
            subtitle: 'How amounts read and convert',
            page: AmountsScreen(),
          ),
          // A guest already holds what the file would carry (FR-DAT-1).
          _Entry.acts(
            icon: Icons.ios_share,
            title: 'Export',
            subtitle: 'Share all as one text file',
            act: () => unawaited(_export(context, ref)),
          ),
          _Entry.acts(
            icon: Icons.file_open_outlined,
            title: 'Import',
            subtitle: 'Replace all from a text file',
            act: () => unawaited(_import(context, ref)),
            enabled: writable,
          ),
          // Last, being the way out of this bar rather than anything in it.
          const _Entry.opens(
            icon: Icons.liquor_outlined,
            title: 'Change bar',
            subtitle: 'Every bar this device holds',
            page: BarsScreen(),
          ),
        ],
      ),
    );
  }
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
  final shelf = ref.read(shelfProvider.notifier);
  await _wentThrough(
    ScaffoldMessenger.of(context),
    'Could not export',
    () async => sharer(await shelf.export()),
  );
}

/// Takes a file off the system's picker and puts what is in it in front of the
/// reader (FR-DAT-3/4). Nothing is touched here: the review is where a road is
/// agreed to.
Future<void> _import(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  final picked = await pickBar(context, ref);
  if (picked == null) return;
  await navigator.push(
    MaterialPageRoute<void>(builder: (_) => _ImportReview(picked)),
  );
}

/// Runs [road] and leaves for the collection itself: what arrived is two
/// screens back, and the reader's own list is the answer no sentence improves
/// on. Unlike a share, this knows what it did, so it says so too — the
/// messenger is the app's, so the word outlives both pops. A road that could
/// not be taken stays on the review, leaving for a collection that never
/// reached the disk being a lie about what happened.
Future<void> _took(
  BuildContext context,
  String refusal,
  String Function() said,
  Future<void> Function() road,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  if (!await _wentThrough(messenger, refusal, road)) return;
  navigator.popUntil((route) => route.isFirst);
  messenger.showSnackBar(SnackBar(content: Text(said())));
}

/// What a picked file turned out to be, and where its two roads are agreed to
/// (FR-DAT-3/4, FR-BAR-7). Pushed rather than shown over the list, the room a
/// confirmation and a report need arriving after the pick rather than before
/// it. Both roads ride the app bar, where every other commit in the app sits
/// (`editor_form.dart`); the weight of either is carried by a body that spells
/// out everything arriving, not by the size of the button agreeing to it.
///
/// Reached from an owned bar alone — Import dims on a guest, whose collection
/// is not this device's to replace (FR-BAR-4) — so Replace is offered without
/// asking whose bar is on show.
class _ImportReview extends ConsumerWidget {
  const _ImportReview(this.review);

  final ImportReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The whole bar is taken; the body reads its collection, what else the file
    // carries being the two roads it can take, and theirs (FR-BAR-7).
    final incoming = review.bar;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import'),
        actions: [
          // A file the app cannot read holds nothing to take either road with.
          if (incoming != null) ...[
            TextButton(
              onPressed: () => unawaited(_addGuest(context, ref, incoming)),
              child: const Text('Add as guest'),
            ),
            TextButton(
              onPressed: () => unawaited(_replace(context, ref, incoming)),
              child: const Text('Replace'),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: incoming == null
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: RefusedFile(
                    review.issues,
                    standing:
                        'Nothing has changed. The collection stands as it was.',
                  ),
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _Roads(incoming.name),
                ),
                BarHoldings(incoming.collection),
              ],
      ),
    );
  }

  /// FR-DAT-3: the open bar keeps its name and its place and takes these
  /// contents, a copy of what stood kept first.
  Future<void> _replace(
    BuildContext context,
    WidgetRef ref,
    BarPayload incoming,
  ) => _took(
    context,
    'Could not import',
    () => '${counted(incoming.collection.recipes.length, 'recipe')} imported.',
    () => ref.read(shelfProvider.notifier).replaceOpen(incoming),
  );

  /// FR-BAR-7's other road: a bar of its own, the owner's to name and refresh,
  /// and nothing on the shelf is touched to make room for it.
  Future<void> _addGuest(
    BuildContext context,
    WidgetRef ref,
    BarPayload incoming,
  ) => _took(
    context,
    'Could not add that bar',
    () => '"${incoming.name}" added as a guest bar.',
    () => ref.read(shelfProvider.notifier).addGuestBar(fileSource, incoming),
  );
}

/// The one thing the counts cannot say: what each road does with them. No
/// numbers here — the cards have them, and a second set beside them reads as a
/// discrepancy rather than a reassurance. Both bars are named, the two roads
/// differing in exactly which one ends up holding this.
class _Roads extends ConsumerWidget {
  const _Roads(this.arriving);

  final String arriving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Non-null: the gear this was reached through is the open bar's own.
    final open = ref.watch(openBarProvider)!.name;
    return DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replace puts this in place of everything "$open" holds now. '
            'A copy is kept first.',
          ),
          const SizedBox(height: 8),
          Text(
            'Add as guest leaves "$open" alone and founds "$arriving" beside '
            'it, read-only.',
          ),
        ],
      ),
    );
  }
}

/// One row of the menu: what it is, and what a tap does with it. A row that
/// travels wears the chevron saying so; a row that acts where it stands
/// carries none, which is the whole of the telling. A row [enabled] is false on
/// dims whole — icon, title, caption and chevron together — and answers no tap:
/// the reader sees what the app does with a bar of their own without being
/// walked into a screen that would refuse them (FR-BAR-4).
class _Entry extends StatelessWidget {
  const _Entry.opens({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
    this.enabled = true,
  }) : act = null;

  const _Entry.acts({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.act,
    this.enabled = true,
  }) : page = null;

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;
  final VoidCallback? act;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled,
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
