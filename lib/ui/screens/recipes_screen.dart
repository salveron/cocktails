import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';

/// Placeholder until the list lands (M13).
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) => ModelView(
    (model) => model.recipes.isEmpty
        ? const EmptyState(
            icon: Icons.local_bar_outlined,
            title: 'No recipes yet',
            message:
                'Recipes you add appear here, marked with what you can make '
                'from the bottles you have.',
          )
        : Center(child: Text('Recipes: ${model.recipes.length}')),
  );
}
