/// Failure wording, kept in one home so a failure reads the same wherever met.
/// Two banners: a torn file and an unreachable source are different news.
/// The shape of any spoken message, failure or success, is `snackbar.dart`'s.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../cards/bullet_runs.dart';

/// What a load could not read (FR-DAT-4); dismissing hides only these issues.
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
    return _Banner(
      'Could not read parts of the saved data:\n${issues.join('\n')}',
      onDismiss: () => setState(() => _dismissed = issues),
    );
  }
}

/// A failed refresh (FR-BAR-5). Dismissing it stops a snackbar repeating it.
class RefreshFailure extends ConsumerWidget {
  const RefreshFailure({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openBarProvider);
    if (open == null) return const SizedBox.shrink();
    final said = refreshSaid(ref.watch(refreshesProvider)[open.id], open.name);
    if (said == null) return const SizedBox.shrink();
    return _Banner(
      said,
      onDismiss: () => ref.read(refreshesProvider.notifier).told(open.id),
    );
  }
}

/// A refused file (FR-DAT-4). [standing] is what stays true despite it;
/// there is nothing here to agree to.
class RefusedFile extends StatelessWidget {
  const RefusedFile(this.issues, {required this.standing, super.key});

  final List<String> issues;
  final String standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Could not read the file',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MutedText(standing),
        const SizedBox(height: 16),
        BulletRuns([bulletRun(issues)]),
      ],
    );
  }
}

/// What a refresh of [bar] came to, or null when there is nothing to say:
/// none asked, one still out, or one landed (the lists already show that).
String? refreshSaid(RefreshState? standing, String bar) => switch (standing) {
  null || Reaching() => null,
  RefreshRefused(:final issues) =>
    'Could not read the data ("$bar" was not changed):\n${issues.join('\n')}',
  // One line: the bar is as it was, and the reader is already looking at it.
  RefreshUnreachable(:final why) => 'Could not refresh: ${_because(why)}',
};

/// What a sharing change came to, or null when there is nothing to say.
/// The record moves first (ADR 22), so only the announcement can fail.
String? sharingSaid(SharingState? standing, {required bool offering}) =>
    switch (standing) {
      null || Announcing() || Silencing() => null,
      SharingFailed() =>
        offering
            ? 'Could not announce the bar to the network.'
            : 'Withdrawn, but could not tell the network.',
    };

/// Why a nearby bar did not arrive (FR-BAR-8), in the same three reasons.
String nearbySaid(UnreachableReason why, String bar) =>
    'Could not add "$bar": ${_because(why)}';

/// The three ways a source goes unreached, worded only here (ADR 22).
String _because(UnreachableReason why) => switch (why) {
  UnreachableReason.offline => 'device offline.',
  UnreachableReason.notFound => 'source not found.',
  UnreachableReason.withdrawn => 'owner stopped sharing.',
};

class _Banner extends StatelessWidget {
  const _Banner(this.said, {required this.onDismiss});

  final String said;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    leading: const Icon(Icons.warning_amber_outlined),
    content: Text(said),
    actions: [TextButton(onPressed: onDismiss, child: const Text('Dismiss'))],
  );
}
