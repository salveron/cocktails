import 'dart:async';

import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/arriving_bar.dart';
import '../widgets/telling.dart';
import 'amounts_screen.dart';
import 'bar_form_screen.dart';
import 'bars_screen.dart';
import 'shopping_settings_screen.dart';
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
    // What may be written to the open bar, and null on a guest one. The
    // vocabularies open either way and read there (FR-BAR-4); what dims is the
    // row whose screen would have nothing at all to say.
    final writable = ref.watch(barWriterProvider) != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _Entry.opens(
            icon: Icons.label_outline,
            title: 'Tags',
            subtitle: 'Labels and their colours',
            page: TagsScreen(),
          ),
          const _Entry.opens(
            icon: Icons.straighten_outlined,
            title: 'Units',
            subtitle: 'What lines are measured in',
            page: UnitsScreen(),
          ),
          // The pick is the reader's on any bar and the sizes are the owner's,
          // so this offers both and lets a guest move only the pick (FR-BAR-3).
          const _Entry.opens(
            icon: Icons.swap_horiz,
            title: 'Amounts',
            subtitle: 'How amounts read and convert',
            page: AmountsScreen(),
          ),
          // The one row that dims, the optimizer being absent on a guest bar
          // and these its settings alone (FR-BAR-4, FR-SET-2).
          _Entry.opens(
            icon: Icons.shopping_cart_outlined,
            title: 'Shopping',
            subtitle: 'What the optimizer is asked',
            page: const ShoppingSettingsScreen(),
            enabled: writable,
          ),
          // A guest already holds what the file would carry (FR-DAT-1).
          _Entry.acts(
            icon: Icons.ios_share,
            title: 'Export',
            subtitle: 'Share all as one text file',
            act: () => unawaited(_export(context, ref)),
          ),
          // The one file row, read by mode: an owned bar takes a file in, a
          // guest asks its source for a newer one (FR-BAR-5/7). The same
          // exchange from either side, so neither dims to make room.
          if (writable)
            _Entry.acts(
              icon: Icons.file_open_outlined,
              title: 'Import',
              subtitle: 'Replace all, or add as a guest',
              act: () => unawaited(_import(context, ref)),
            )
          else
            _Entry.acts(
              icon: Icons.refresh,
              title: 'Refresh',
              subtitle: 'Ask its source for a newer copy',
              act: () => unawaited(_refresh(context, ref)),
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

/// Writes the copy and hands it to the system's sheet (FR-DAT-1). The sheet
/// opening is the whole answer, so only a failure speaks — and a reader who
/// dismisses the sheet has done nothing, which is not one.
Future<void> _export(BuildContext context, WidgetRef ref) async {
  final sharer = ref.read(sharerProvider);
  final shelf = ref.read(shelfProvider.notifier);
  await wentThrough(
    ScaffoldMessenger.of(context),
    'Could not export',
    () async => sharer(await shelf.export()),
  );
}

/// FR-BAR-5: a guest bar's source asked again from the gear — the pull's own
/// question, put where a reader who came looking for it will look. What it came
/// to is said here and marked told, the banner that would carry it standing
/// behind this screen unread.
Future<void> _refresh(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final shelf = ref.read(shelfProvider.notifier);
  final refreshes = ref.read(refreshesProvider.notifier);
  final bar = ref.read(openBarProvider);
  if (bar == null) return;
  await shelf.refresh(bar.id);
  // Gone where the reader left while the source was being asked; the banner
  // carries what it came to instead, which is what it is there for.
  if (!context.mounted) return;
  final landed = ref.read(openBarProvider)?.refreshed != bar.refreshed;
  // Nothing to say where the reader dismissed the picker: the source was never
  // asked, so neither an answer nor a failure is one.
  final said =
      refreshSaid(refreshes.standing(bar.id), bar.name) ??
      (landed ? 'Refreshed.' : null);
  if (said == null) return;
  refreshes.told(bar.id);
  say(messenger, said);
}

/// Takes a file off the system's picker and puts what is in it in front of the
/// reader (FR-DAT-3/4). Nothing is touched here: the form is where a road is
/// agreed to, and it is the same form a bar is founded on — one file, the same
/// three questions, whichever end it was picked from (FR-BAR-7).
Future<void> _import(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  final picked = await pickBar(context, ref);
  if (picked == null) return;
  await navigator.push(
    MaterialPageRoute<void>(builder: (_) => BarFormScreen.importing(picked)),
  );
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

  /// A row that acts is drawn only where the act is on offer, so none of them
  /// dims: what a guest bar cannot do it is not asked to refuse.
  const _Entry.acts({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.act,
  }) : page = null,
       enabled = true;

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
