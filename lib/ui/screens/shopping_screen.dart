import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

/// Placeholder until the optimizer lands (M22).
class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
    icon: Icons.shopping_cart_outlined,
    title: 'Nothing to shop for',
    message:
        'Mark what you are out of, and the bottles that unlock the most '
        'recipes appear here.',
  );
}
