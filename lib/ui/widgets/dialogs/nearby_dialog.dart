/// What is offered nearby, put to the reader (FR-BAR-8,
/// docs/ui-design.md#new-bar): one browse, its answers grouped under the device
/// offering them, and a pick that is agreed to before anything is fetched.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../../wording.dart';
import '../cards/entry_card.dart';
import '../notices/empty_state.dart';
import 'dialog_frame.dart';

/// The bar the reader picked, or null where they closed on nothing. Nothing is
/// fetched here: what a bar holds is read on the form it is agreed to, the way
/// a picked file is.
Future<Found?> promptForNearby(BuildContext context) =>
    showDialog<Found>(context: context, builder: (_) => const _NearbyDialog());

class _NearbyDialog extends ConsumerStatefulWidget {
  const _NearbyDialog();

  @override
  ConsumerState<_NearbyDialog> createState() => _NearbyDialogState();
}

class _NearbyDialogState extends ConsumerState<_NearbyDialog> {
  late Stream<List<Found>> _browsing;
  Found? _picked;

  @override
  void initState() {
    super.initState();
    _browsing = ref.read(nearbyProvider)();
  }

  /// A browse runs while the reader is looking and no longer (ADR 22), so it
  /// starts with the dialog and again only where they ask for it.
  void _tryAgain() => setState(() {
    _picked = null;
    _browsing = ref.read(nearbyProvider)();
  });

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Found>>(
    stream: _browsing,
    builder: (context, snapshot) {
      // Drawn again as each device answers rather than once at the end, and
      // still looking until the browse closes: a reader may take the first
      // thing they recognise without waiting out the window.
      final found = snapshot.data ?? const <Found>[];
      final looking = snapshot.connectionState != ConnectionState.done;
      return DialogFrame(
        title: 'Bars nearby',
        crossAxisAlignment: CrossAxisAlignment.stretch,
        content: [
          if (found.isEmpty)
            looking ? const Looking() : const _NothingNearby()
          else
            _Offered(
              found: found,
              picked: _picked,
              looking: looking,
              onPick: (bar) => setState(() => _picked = bar),
            ),
        ],
        // Where there is nothing to take, the ask to look again stands in
        // Select's place rather than beside a button that could never be
        // pressed.
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (found.isNotEmpty)
            TextButton(
              onPressed: _picked == null
                  ? null
                  : () => Navigator.of(context).pop(_picked),
              child: const Text('Select'),
            )
          else if (!looking)
            TextButton(onPressed: _tryAgain, child: const Text('Try again')),
        ],
      );
    },
  );
}

/// Every bar found, each carrying the device offering it — which is what tells
/// two of one name apart, names being labels rather than identity (FR-BAR-1).
/// Ordered by device and then by bar, so one device's bars still stand
/// together without a heading over them.
class _Offered extends StatelessWidget {
  const _Offered({
    required this.found,
    required this.picked,
    required this.looking,
    required this.onPick,
  });

  final List<Found> found;
  final Found? picked;

  /// Whether more may still arrive, which is what the mark under the list says.
  final bool looking;

  final void Function(Found found) onPick;

  @override
  Widget build(BuildContext context) {
    final ordered = [...found]
      ..sort((a, b) {
        final byDevice = compareNames(a.source.from, b.source.from);
        return byDevice != 0 ? byDevice : compareNames(a.name, b.name);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bar in ordered)
          EntryCard(
            title: _Offering(bar),
            margin: const EdgeInsets.symmetric(vertical: 4),
            selected: bar.source == picked?.source,
            onTap: () => onPick(bar),
          ),
        if (looking) const Looking(),
      ],
    );
  }
}

/// The bar's name, and after it the device offering it — dimmed, the way a
/// card's own subtitle is: it tells one card from another rather than naming
/// what a tap will take.
class _Offering extends StatelessWidget {
  const _Offering(this.bar);

  final Found bar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: bar.name),
          TextSpan(
            text: '$beside${bar.source.from}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      style: theme.textTheme.bodyLarge,
    );
  }
}

/// Both sides have to be there at once for a bar to be found at all, which is
/// the one thing a reader can act on.
class _NothingNearby extends StatelessWidget {
  const _NothingNearby();

  @override
  Widget build(BuildContext context) => const MutedText(
    'Nothing is shared on this network. Both devices have to be on it, '
    "with the owner's app open.",
  );
}
