import 'dart:async';

import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'amounts_screen.dart';
import 'tags_screen.dart';
import 'units_screen.dart';

/// Settings pushed from app bar gear: the vocabularies that travel, then the
/// file leaving where it stands — M25's import lands beside it (ADR 18,
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
      ],
    ),
  );
}

/// Writes the copy and hands it to the system's sheet (FR-DAT-1). The sheet
/// opening is the whole answer, so only a failure speaks — and a reader who
/// dismisses the sheet has done nothing, which is not one. Every failure
/// speaks, not only the `Exception`s: nothing awaits this, so what is not
/// caught here reaches a reader as silence.
Future<void> _export(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(sharerProvider)(
      await ref.read(modelProvider.notifier).export(),
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text('Could not export: $error')));
  }
}

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
