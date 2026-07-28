/// The app frame: the Material 3 shell every screen lives in — three
/// destinations in the bottom bar, settings behind the app bar's gear
/// (docs/ui-design.md#app-shell).
library;

import 'package:flutter/material.dart';

import 'screens/inventory_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shopping_screen.dart';
import 'theme.dart';
import 'widgets/startup_issues.dart';

class CocktailsApp extends StatelessWidget {
  const CocktailsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cocktails',
    theme: cocktailsTheme(Brightness.light),
    darkTheme: cocktailsTheme(Brightness.dark),
    home: const AppShell(),
  );
}

enum _Destination {
  recipes(
    'Recipes',
    Icons.local_bar_outlined,
    Icons.local_bar,
    RecipesScreen(),
  ),
  inventory(
    'Inventory',
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    InventoryScreen(),
  ),
  shopping(
    'Shopping',
    Icons.shopping_cart_outlined,
    Icons.shopping_cart,
    ShoppingScreen(),
  );

  const _Destination(this.label, this.icon, this.selectedIcon, this.screen);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;
}

/// Every destination stays alive in an [IndexedStack], so switching away and
/// back keeps a screen's scroll position and search text (NFR-1).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _Destination _current = _Destination.recipes;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_current.label),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    ),
    body: Column(
      children: [
        const StartupIssues(),
        Expanded(
          child: IndexedStack(
            index: _current.index,
            children: [
              for (final destination in _Destination.values) destination.screen,
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _current.index,
      onDestinationSelected: (index) =>
          setState(() => _current = _Destination.values[index]),
      destinations: [
        for (final destination in _Destination.values)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    ),
  );
}
