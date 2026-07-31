/// The read-only providers over the model (docs/components.md).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'model_controller.dart';

/// Availability by recipe name, recomputed whole on every model change — the
/// pass is under a millisecond at NFR-2 scale. Empty until the load lands.
final availabilityProvider = Provider<Map<String, Availability>>((ref) {
  final model = ref.watch(modelProvider).valueOrNull;
  return {
    if (model != null)
      for (final recipe in model.recipes)
        recipe.name: availabilityOf(model, recipe),
  };
});
