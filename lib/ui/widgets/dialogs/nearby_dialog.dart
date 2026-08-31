/// What is offered nearby, put to the reader (FR-BAR-8,
/// docs/ui-design.md#new-bar): one browse, its answers grouped under the device
/// offering them, and a pick that is agreed to before anything is fetched.
library;

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme.dart';
import '../cards/entry_card.dart';
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
  late Future<List<Found>> _browsing;
  Found? _picked;

  @override
  void initState() {
    super.initState();
    _browsing = _browse();
  }

  /// A browse runs while the reader is looking and no longer (ADR 22), so it
  /// starts with the dialog and again only where they ask for it.
  Future<List<Found>> _browse() async {
    return ref.read(nearbyProvider)();
  }

  void _lookAgain() => setState(() {
    _picked = null;
    _browsing = _browse();
  });

  @override
  Widget build(BuildContext context) => DialogFrame(
    title: 'Bars nearby',
    crossAxisAlignment: CrossAxisAlignment.stretch,
    content: [
      FutureBuilder<List<Found>>(
        future: _browsing,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(connectionState: ConnectionState.done, :final data?) =>
            data.isEmpty
                ? _NothingNearby(onLookAgain: _lookAgain)
                : _Offered(
                    found: data,
                    picked: _picked,
                    onPick: (found) => setState(() => _picked = found),
                  ),
          _ => const _Looking(),
        },
      ),
    ],
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: _picked == null
            ? null
            : () => Navigator.of(context).pop(_picked),
        child: const Text('Choose'),
      ),
    ],
  );
}

/// Every bar found, under the device offering it — which is what tells two of
/// one name apart, names being labels rather than identity (FR-BAR-1).
class _Offered extends StatelessWidget {
  const _Offered({
    required this.found,
    required this.picked,
    required this.onPick,
  });

  final List<Found> found;
  final Found? picked;
  final void Function(Found found) onPick;

  @override
  Widget build(BuildContext context) {
    final byDevice = <String, List<Found>>{};
    for (final bar in found) {
      byDevice.putIfAbsent(bar.source.from, () => []).add(bar);
    }
    final devices = byDevice.keys.toList()..sort(compareNames);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final device in devices) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Text(device, style: Theme.of(context).textTheme.labelLarge),
          ),
          for (final bar in byDevice[device]!)
            EntryCard(
              title: Text(bar.name),
              margin: const EdgeInsets.symmetric(vertical: 4),
              selected: bar.source == picked?.source,
              onTap: () => onPick(bar),
            ),
        ],
      ],
    );
  }
}

class _Looking extends StatelessWidget {
  const _Looking();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Both sides have to be there at once for a bar to be found at all, which is
/// the one thing a reader can act on.
class _NothingNearby extends StatelessWidget {
  const _NothingNearby({required this.onLookAgain});

  final VoidCallback onLookAgain;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const MutedText(
        'Nothing is being shared on this network. Both devices have to be on '
        'it, with the other reader sharing the bar and their app open.',
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onLookAgain,
          child: const Text('Look again'),
        ),
      ),
    ],
  );
}
