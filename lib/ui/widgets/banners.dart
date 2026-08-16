/// What the app could not read, said above every destination: the last load's
/// issues (FR-DAT-4) and the open bar's last refresh where it did not land
/// (FR-BAR-5). Two banners rather than one — a torn file on disk and a source
/// that would not answer are different news, and a reader dismissing either has
/// not heard the other.
library;

import 'package:cocktails/domain/domain.dart';
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
    return _Banner(
      'Some saved data could not be read:\n${issues.join('\n')}',
      onDismiss: () => setState(() => _dismissed = issues),
    );
  }
}

/// What the open bar's last refresh came to, where it did not land (FR-BAR-5).
/// Silent while one is out — the swipe's own spinner is saying that — and
/// silent again the moment another is asked for, since `refreshesProvider`
/// clears what the last came to. Dismissal is of that answer rather than of the
/// banner, as the load's is.
class RefreshFailure extends ConsumerStatefulWidget {
  const RefreshFailure({super.key});

  @override
  ConsumerState<RefreshFailure> createState() => _RefreshFailureState();
}

class _RefreshFailureState extends ConsumerState<RefreshFailure> {
  RefreshState? _dismissed;

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(openBarProvider);
    if (open == null) return const SizedBox.shrink();
    final standing = ref.watch(refreshesProvider)[open.id];
    final said = identical(standing, _dismissed)
        ? null
        : switch (standing) {
            null || Reaching() => null,
            RefreshRefused(:final issues) =>
              'What arrived could not be read, so "${open.name}" stands as it '
                  'was:\n${issues.join('\n')}',
            RefreshUnreachable(:final why) =>
              '"${open.name}" could not be refreshed: ${_because(why)} It '
                  'stands as it was.',
          };
    if (said == null) return const SizedBox.shrink();
    return _Banner(
      said,
      onDismiss: () => setState(() => _dismissed = standing),
    );
  }
}

/// The three ways a source goes unreached, in the app's own words — the reason
/// is closed so that this is the only place they are put into any (ADR 22).
String _because(UnreachableReason why) => switch (why) {
  UnreachableReason.offline => 'this device is offline.',
  UnreachableReason.notFound => 'its source could not be found.',
  UnreachableReason.withdrawn => 'its owner has stopped sharing it.',
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
