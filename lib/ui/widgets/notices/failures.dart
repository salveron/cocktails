/// What the app could not do, put to the reader: the two banners standing above
/// every destination — the last load's issues (FR-DAT-4) and the open bar's last
/// refresh where it did not land (FR-BAR-5) — and the refusal a picked file
/// gets. Two banners rather than one, a torn file on disk and a source that
/// would not answer being different news; one home for the words, so a
/// failure is worded once however the reader meets it. `snackbar.dart` carries
/// the shape a spoken message takes, failure or success alike.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../cards/bullet_runs.dart';

/// What a load could not read (FR-DAT-4), above every destination until the
/// reader dismisses it. Dismissal is of the issues on show rather than of the
/// banner: crossing to a bar whose file is torn has something new to say.
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
/// Silent while one is out — the swipe's own spinner says that — and again the
/// moment another is asked for. Dismissing tells the map the reader has heard
/// it, so this and a screen that said it in a snackbar cannot say it twice.
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

/// Why the file was not read, and where (FR-DAT-4), under the one sentence that
/// matters — [standing], what is true despite it, which differs by what the
/// file was about to be used for. There is nothing here to agree to.
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
                'This file cannot be read',
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

/// What a refresh of [bar] came to, in the app's own words, and null where
/// there is nothing to report — no ask, one still out, or one that landed, which
/// the reader's own lists answer better than a sentence. The one wording, met as
/// a banner where they pulled and as a snackbar where they tapped.
String? refreshSaid(RefreshState? standing, String bar) => switch (standing) {
  null || Reaching() => null,
  RefreshRefused(:final issues) =>
    'What arrived could not be read, so "$bar" stands as it '
        'was:\n${issues.join('\n')}',
  // One line: a source that did not answer is met by a reader who asked for
  // one thing and got nothing, and the bar standing as it was is what they are
  // already looking at.
  RefreshUnreachable(:final why) => 'Could not refresh: ${_because(why)}',
};

/// What a change to a bar's sharing came to, and null where there is nothing
/// to report — nothing out, one still out, or one that went through, which the
/// switch answers better than a sentence. The record moves first and the
/// network second (ADR 22), so what failed is the announcement and never the
/// offer: the switch is telling the truth either way.
String? sharingSaid(SharingState? standing, {required bool offering}) =>
    switch (standing) {
      null || Announcing() || Silencing() => null,
      SharingFailed() =>
        offering
            ? 'Shared, but this device could not announce it.'
            : 'Withdrawn, but the network could not be told.',
    };

/// Why a bar found nearby did not arrive (FR-BAR-8) — the add's reading of the
/// same three, where [refreshSaid] carries the refresh's.
String nearbySaid(UnreachableReason why, String bar) =>
    '"$bar" could not be added: ${_because(why)}';

/// The three ways a source goes unreached, worded nowhere else (ADR 22).
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
