import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What a load could not read (FR-DAT-4), above every destination until the
/// reader dismisses it. Dismissal is of the issues on show rather than of the
/// banner: crossing to a bar whose file is torn has something new to say, and
/// a dismissal made before the crossing was not about it.
class LoadIssues extends ConsumerStatefulWidget {
  const LoadIssues({super.key});

  @override
  ConsumerState<LoadIssues> createState() => _LoadIssuesState();
}

class _LoadIssuesState extends ConsumerState<LoadIssues> {
  List<String>? _dismissed;

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(loadIssuesProvider);
    if (issues.isEmpty || listEquals(_dismissed, issues)) {
      return const SizedBox.shrink();
    }
    return MaterialBanner(
      leading: const Icon(Icons.warning_amber_outlined),
      content: Text('Some saved data could not be read:\n${issues.join('\n')}'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = issues),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
