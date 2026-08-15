/// Material 3 app frame: what the app opens on, three bottom-bar destinations,
/// settings gear.
library;

import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'destinations.dart';
import 'screens/bars_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shopping_screen.dart';
import 'theme.dart';
import 'widgets/empty_state.dart';
import 'widgets/load_issues.dart';

class CocktailsApp extends StatelessWidget {
  const CocktailsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cocktails',
    theme: cocktailsTheme(Brightness.light),
    darkTheme: cocktailsTheme(Brightness.dark),
    home: const _Home(),
  );
}

/// What the app opens on, and the one place the startup load is met: a spinner
/// while it runs, what it failed with where it did, then the bar on show or the
/// list of them where there is none
/// ([ADR 20](../../docs/adr/20-the-app-holds-many-bars.md)). Nothing below here
/// is built before the shelf has answered, which is what lets every screen read
/// a collection rather than the wait for one (docs/ui-design.md#app-shell).
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // What the load is doing, never the shelf itself: a stock tap would
    // otherwise rebuild the shell a keyed subtree exists to hold still.
    final failure = ref.watch(shelfProvider.select((shelf) => shelf.error));
    if (failure != null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.error_outline,
          title: 'Your data could not be opened',
          message: '$failure',
        ),
      );
    }
    if (!ref.watch(shelfProvider.select((shelf) => shelf.hasValue))) {
      // Bare, rather than shell chrome around it: an app bar naming a bar it
      // has not read yet would be saying more than it knows.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // A shelf holding no open bar is met by the bar list, there being no
    // destination to draw.
    final open = ref.watch(openBarProvider);
    if (open == null) return const BarsScreen();
    // Keyed by the bar on show, so a crossing rebuilds everything under it and
    // takes every search, pick, open card and jump trail with it (FR-BAR-1).
    return AppShell(key: ValueKey(open.id));
  }
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
      if (request == null) return;
      // A request naming a row is a jump and leaves a way back; one naming only
      // a destination is a landing, and a reader who has just crossed into a
      // bar has nothing here to return from (docs/ui-design.md#bars).
      if (request.name == null) {
        _choose(request.destination.index);
      } else {
        _jumpTo(request.destination);
      }
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
          // The bar's name leads the title, the destination answering the
          // smaller question once the app holds more than one collection
          // (docs/ui-design.md#bars). Nothing else marks the bar, and the
          // pushed screens above this one keep their own plain titles.
          title: Text(switch (ref.watch(openBarProvider)) {
            final bar? => "${bar.name}'s ${_current.label}",
            null => _current.label,
          }),
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
            const LoadIssues(),
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
