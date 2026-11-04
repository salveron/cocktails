import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/notices/failures.dart';
import '../widgets/notices/snackbar.dart';
import 'amounts_screen.dart';
import 'bar_form_screen.dart';
import 'bars_screen.dart';
import 'share_screen.dart';
import 'shopping_settings_screen.dart';
import 'tags_screen.dart';
import 'units_screen.dart';

/// Settings pushed from app bar gear: the vocabularies that travel, then the
/// two ways data crosses the edge — every way a bar leaves, behind one row, and
/// the way one comes back in, which is why both live here rather than drifting
/// apart (ADR 18, docs/ui-design.md#data).
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
      body: ListView(children: [_Entries(writable: writable)]),
    );
  }
}

/// Every row the gear opens onto, in the order a reader meets them.
class _Entries extends ConsumerWidget {
  const _Entries({required this.writable});

  final bool writable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openBarProvider);
    // Reaching a source outlasts the tap, so the row it was asked from says so
    // where its icon stands (FR-BAR-5).
    final reaching = ref.watch(refreshesProvider)[open?.id] is Reaching;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
          subtitle: 'Define the units lines are measured in',
          page: UnitsScreen(),
        ),
        // The pick is the reader's on any bar and the sizes are the owner's, so
        // this offers both and lets a guest move only the pick (FR-BAR-3).
        const _Entry.opens(
          icon: Icons.swap_horiz,
          title: 'Amounts',
          subtitle: 'Set how amounts read and convert',
          page: AmountsScreen(),
        ),
        // The one row that dims, the optimizer being absent on a guest bar and
        // these its settings alone (FR-BAR-4, FR-SET-2).
        _Entry.opens(
          icon: Icons.shopping_cart_outlined,
          title: 'Shopping',
          subtitle: 'Set what the optimizer looks for',
          page: const ShoppingSettingsScreen(),
          enabled: writable,
        ),
        // Every way this bar leaves, a guest's as an owner's: a guest already
        // holds what a file or the LAN would carry (FR-DAT-1, FR-BAR-6).
        if (open != null)
          _Entry.opens(
            icon: Icons.ios_share,
            title: 'Share',
            subtitle: 'Export as a file or share over LAN',
            page: ShareScreen(open.id),
          ),
        // The one file row, read by mode: an owned bar takes a file in, a guest
        // asks its source for a newer one (FR-BAR-5/7). The same exchange from
        // either side, so neither dims to make room.
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
            subtitle: _refreshCaption(open?.source),
            working: reaching,
            act: () => unawaited(_refresh(context, ref)),
          ),
        // Last, being the way out of this bar rather than anything in it.
        const _Entry.opens(
          icon: Icons.liquor_outlined,
          title: 'Change bar',
          subtitle: 'Switch, create or manage bars',
          page: BarsScreen(),
        ),
      ],
    );
  }
}

/// What a refresh asks, by the way the bar came: a guest refreshes from that
/// one source and no other (FR-BAR-5), so the row says which it is.
String _refreshCaption(BarSource? source) => switch (source?.via) {
  Transport.file => 'Pick a newer file',
  Transport.lan => 'Ask the sharing device again',
  Transport.cloud || null => 'Ask the source for a newer copy',
};

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
  }) : act = null,
       working = false;

  /// A row that acts is drawn only where the act is on offer, so none of them
  /// dims: what a guest bar cannot do it is not asked to refuse.
  const _Entry.acts({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.act,
    this.working = false,
  }) : page = null,
       enabled = true;

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? page;
  final VoidCallback? act;
  final bool enabled;

  /// Whether what this row asked for is still out: the icon says so where the
  /// icon is, and the row answers no second tap until it lands.
  final bool working;

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: enabled && !working,
    leading: working
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon),
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
