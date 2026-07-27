import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';
import '../widgets/model_view.dart';

/// Placeholder until the list and the stock toggle land (M10).
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) => ModelView(
    (model) => model.ingredients.isEmpty
        ? const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No ingredients yet',
            message:
                'Every ingredient your recipes use is listed here, with what '
                'you have in stock.',
          )
        : Center(child: Text('Ingredients: ${model.ingredients.length}')),
  );
}
