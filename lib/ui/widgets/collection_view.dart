import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// The three faces of the startup load — spinner, failure, collection — in
/// one place, so no screen writes its own (docs/ui-design.md#app-shell).
class CollectionView extends ConsumerWidget {
  const CollectionView(this.builder, {super.key});

  final Widget Function(Collection collection) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(collectionProvider)) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: 'Your data could not be opened',
          message: '$error',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
}
