/// Material 3 app frame: three bottom-bar destinations, settings gear.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'destinations.dart';
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

/// The screen behind [destination], told whether it is the one on show: all
/// three stay alive below, and the optimizer is the one computation that must
/// not run for a screen nobody is looking at (ui-design.md#shopping-screen).
Widget _screenOf(Destination destination, {required bool showing}) =>
    switch (destination) {
      Destination.recipes => const RecipesScreen(),
      Destination.inventory => const InventoryScreen(),
      Destination.shopping => ShoppingScreen(showing: showing),
    };

/// IndexedStack keeps destinations alive for scroll/search state preservation (NFR-1).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Destination _current = Destination.recipes;

  /// What jumps have left, latest last — destinations, never their states
  /// (ADR 19). One stands here at most once and never the one on show, so a
  /// chain of jumps unwinds one at a time and a loop of them cannot grow it.
  final _trail = <Destination>[];

  @override
  Widget build(BuildContext context) {
    // Watched only to switch: which row was asked for is the serving screen's,
    // and this hears nothing of it.
    ref.listen(revealProvider, (_, request) {
      if (request != null) _jumpTo(request.destination);
    });
    return PopScope(
      // Back undoes a jump while there is one to undo, and leaves otherwise.
      // Settings is a route above this one, so its own back is untouched.
      canPop: _trail.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _current = _trail.removeLast());
      },
      child: Scaffold(
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
                  for (final destination in Destination.values)
                    _screenOf(destination, showing: destination == _current),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _current.index,
          onDestinationSelected: _choose,
          destinations: [
            for (final destination in Destination.values)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      ),
    );
  }

  /// Switches to [destination], remembering what it left so back can undo it.
  void _jumpTo(Destination destination) {
    if (destination == _current) return;
    setState(() {
      _trail
        ..remove(_current)
        ..remove(destination)
        ..add(_current);
      _current = destination;
    });
  }

  /// A destination the reader chose has nothing to return *from*, so the trail
  /// goes with the tap: back never undoes a move they made themselves.
  void _choose(int index) => setState(() {
    _trail.clear();
    _current = Destination.values[index];
  });
}
