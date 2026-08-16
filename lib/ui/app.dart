/// Material 3 app frame: what the app opens on, the bottom-bar destinations the
/// open bar offers, settings gear.
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
import 'widgets/banners.dart';

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
/// list of them where there is none (ADR 20). Nothing below here is built
/// before the shelf answers, so every screen reads a collection rather than the
/// wait for one (docs/ui-design.md#app-shell).
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
          title: 'The saved data could not be opened',
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

/// The screen behind [destination], told whether it is the one on show: the
/// optimizer is the one computation that must not run unwatched
/// (ui-design.md#shopping-screen), nor be built at all on a guest (FR-BAR-4).
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
  /// Named, never an index: the position is the offered list's (FR-BAR-4).
  Destination _current = Destination.recipes;

  /// What jumps have left, latest last — destinations, never their states
  /// (ADR 19). One stands here at most once and never the one on show, so a
  /// chain of jumps unwinds one at a time and a loop of them cannot grow it.
  final _trail = <Destination>[];

  @override
  Widget build(BuildContext context) {
    // Non-null: `_Home` stands above this and draws the list where none is open.
    final open = ref.watch(openBarProvider)!;
    final offered = destinationsOf(open.mode);
    // Watched only to switch: which row was asked for is the serving screen's,
    // and this hears nothing of it.
    ref.listen(revealProvider, (_, request) {
      if (request == null) return;
      // A request naming a row is a jump and leaves a way back; one naming only
      // a destination is a landing, and a reader who has just crossed into a
      // bar has nothing here to return from (docs/ui-design.md#bars).
      if (request.name == null) {
        _land(request.destination);
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
          // smaller question (docs/ui-design.md#bars). Nothing else marks the
          // bar, and the pushed screens above keep their own plain titles.
          title: Text("${open.name}'s ${_current.label}"),
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
            const RefreshFailure(),
            Expanded(
              child: IndexedStack(
                index: offered.indexOf(_current),
                children: [
                  for (final destination in offered)
                    _screenOf(destination, showing: destination == _current),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: offered.indexOf(_current),
          onDestinationSelected: (index) => _land(offered[index]),
          destinations: [
            for (final destination in offered)
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
  void _land(Destination destination) => setState(() {
    _trail.clear();
    _current = destination;
  });
}
