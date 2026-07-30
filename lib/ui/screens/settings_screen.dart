import 'package:flutter/material.dart';

import 'tags_screen.dart';

/// Settings pushed from app bar gear (ratio, display, export, tags).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.label_outline),
          title: const Text('Tags'),
          subtitle: const Text(
            'Recipe and ingredient labels, and their colours',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const TagsScreen())),
        ),
      ],
    ),
  );
}
