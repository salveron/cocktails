import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'empty_state.dart';

/// The three faces of the startup load — spinner, failure, model — in one
/// place, so no screen writes its own (docs/components.md#ui-shell).
class ModelView extends ConsumerWidget {
  const ModelView(this.builder, {super.key});

  final Widget Function(Model model) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(modelProvider)) {
        AsyncData(:final value) => builder(value),
        AsyncError(:final error) => EmptyState(
          icon: Icons.error_outline,
          title: 'Your data could not be opened',
          message: '$error',
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
}
