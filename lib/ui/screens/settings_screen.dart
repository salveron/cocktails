import 'package:flutter/material.dart';

import 'amounts_screen.dart';
import 'tags_screen.dart';
import 'units_screen.dart';

/// Settings pushed from app bar gear (amounts, export, tags, units).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: const [
        _Entry(
          icon: Icons.label_outline,
          title: 'Tags',
          subtitle: 'Recipe and ingredient labels, and their colours',
          page: TagsScreen(),
        ),
        _Entry(
          icon: Icons.straighten_outlined,
          title: 'Units',
          subtitle: 'What a recipe line is measured in, and its plural',
          page: UnitsScreen(),
        ),
        _Entry(
          icon: Icons.swap_horiz,
          title: 'Amounts',
          subtitle: 'The unit amounts read in, and what each is worth',
          page: AmountsScreen(),
        ),
      ],
    ),
  );
}

/// One row of the menu: what it is, and the screen it opens.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page)),
  );
}
