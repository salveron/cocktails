/// What the shell offers, and how one screen sends a reader to a named row on
/// another (docs/adr/19-a-destination-sends-the-reader-to-another.md).
library;

import 'package:cocktails/domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Public where this was `app.dart`'s own: a screen names the one it sends to.
enum Destination {
  recipes('Recipes', Icons.local_bar_outlined, Icons.local_bar),
  ingredients('Ingredients', Icons.inventory_2_outlined, Icons.inventory_2),
  shopping('Shopping', Icons.shopping_cart_outlined, Icons.shopping_cart);

  const Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom-bar order, indexed by position and never by the enum (FR-BAR-4).
List<Destination> destinationsOf(BarMode mode) => switch (mode) {
  BarMode.owner => Destination.values,
  BarMode.guest => const [Destination.recipes, Destination.ingredients],
};

/// A destination and a row to reveal there — never an index, a widget or an
/// entity, and the name the entry's own, whatever spelling the sender held. A
/// null [name] is a crossing rather than a jump: land, name no row (ADR 19).
typedef Reveal = ({Destination destination, String? name});

/// The one request pending, or none: one-shot, cleared by the screen serving it.
class Reveals extends Notifier<Reveal?> {
  @override
  Reveal? build() => null;

  void ask(Destination destination, String name) =>
      state = (destination: destination, name: name);

  void land(Destination destination) =>
      state = (destination: destination, name: null);

  void served() => state = null;
}

final revealProvider = NotifierProvider<Reveals, Reveal?>(Reveals.new);

/// The row [serving] has been asked for, taken as it is read, or null where
/// [request] names another screen. The one home for what a screen serving a
/// request owes: ignore what is not its own, and clear what is.
String? takeReveal(WidgetRef ref, Reveal? request, Destination serving) {
  if (request == null || request.destination != serving) return null;
  ref.read(revealProvider.notifier).served();
  return request.name;
}
