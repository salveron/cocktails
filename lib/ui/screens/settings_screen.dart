import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Pushed from the app bar's gear; placeholder until the settings (M23) and
/// data exchange (M24/M25) land.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: const EmptyState(
      icon: Icons.settings_outlined,
      title: 'Nothing to set yet',
      message:
          'The part-to-ml ratio, the part/ml display toggle, and importing '
          'and exporting your data will live here.',
    ),
  );
}
