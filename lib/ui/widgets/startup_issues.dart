import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the startup load could not read (FR-DAT-4), above every destination
/// until the user dismisses it.
class StartupIssues extends ConsumerStatefulWidget {
  const StartupIssues({super.key});

  @override
  ConsumerState<StartupIssues> createState() => _StartupIssuesState();
}

class _StartupIssuesState extends ConsumerState<StartupIssues> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(startupIssuesProvider);
    if (_dismissed || issues.isEmpty) return const SizedBox.shrink();
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_outlined),
      content: Text(
        'Some of your saved data could not be read:\n${issues.join('\n')}',
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = true),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
