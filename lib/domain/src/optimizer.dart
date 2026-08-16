/// What to buy next (FR-DIS-6, FR-DIS-7): the purchases leaving the most
/// recipes makeable — or, restocking, fully stocked — within a budget.
library;

import 'availability.dart';
import 'names.dart';
import 'collection.dart';

/// What a budget can be (FR-DIS-6) — one search at the largest answers them
/// all.
const budgets = [1, 2, 3];

final class Purchase {
  final List<String> ingredients;
  final List<String> unlocks;

  Purchase(List<String> ingredients, List<String> unlocks)
    : ingredients = List.unmodifiable(ingredients),
      unlocks = List.unmodifiable(unlocks);

  @override
  bool operator ==(Object other) =>
      other is Purchase &&
      listEquals(other.ingredients, ingredients) &&
      listEquals(other.unlocks, unlocks);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(ingredients), Object.hashAll(unlocks));

  @override
  String toString() =>
      'Purchase(${ingredients.join(' + ')} → ${unlocks.join(', ')})';
}

/// The purchases of at most [budget] ingredients worth making, most recipes
/// first, then fewest ingredients, then A→Z — the best [most] of each basket
/// size, so a cheap win is never buried under the baskets one ingredient
/// bigger.
///
/// The ingredients worth weighing are only those some recipe is actually short
/// of, so the pool is the gaps' own ingredients and the search is every basket
/// drawn from it. That search is quick; what is not is dressing every basket it
/// finds as an answer, and at a few hundred recipes it finds tens of thousands.
/// So a basket is weighed by its count alone and only the ones kept are ever
/// named.
///
/// [restocking] is what counts as short (ADR 16): a line standing at out, or
/// one short of full stock — which puts the ingredients running low in the pool
/// and makes the goal ready rather than merely makeable.
List<Purchase> purchasesWithin(
  Collection collection,
  int budget, {
  int most = 25,
  bool restocking = false,
}) {
  if (budget < 1) return const [];
  final gaps = <({Set<String> ingredients, String recipe})>[];
  final pool = <String>{};
  for (final recipe in collection.recipes) {
    for (final gap in _gapsOf(
      collection,
      recipe,
      budget,
      restocking: restocking,
    )) {
      gaps.add((ingredients: gap, recipe: recipe.name));
      pool.addAll(gap);
    }
  }
  if (gaps.isEmpty) return const [];

  final ingredients = pool.toList()..sort(compareNames);
  final ids = {for (var i = 0; i < ingredients.length; i++) ingredients[i]: i};
  final radix = ingredients.length + 1;
  final closes = <int, Set<String>>{};
  for (final gap in gaps) {
    final part = [for (final ingredient in gap.ingredients) ids[ingredient]!]
      ..sort();
    (closes[_packed(part, radix)] ??= <String>{}).add(gap.recipe);
  }

  final shelves = List.generate(budget + 1, (_) => <_Kept>[]);
  final yields = <int, int>{};
  final unlocks = <String>{};
  for (final basket in _baskets(ingredients.length, budget)) {
    _unlockedBy(unlocks, basket, closes, radix);
    final yield = unlocks.length;
    yields[_keyOfPart(basket, (1 << basket.length) - 1, radix)] = yield;
    if (yield == 0 || !_earnsIts(basket, yield, yields, radix)) continue;
    _shelve(shelves[basket.length], basket, yield, most);
  }

  final purchases = <Purchase>[];
  for (final shelf in shelves) {
    for (final kept in shelf) {
      _unlockedBy(unlocks, kept.basket, closes, radix);
      purchases.add(
        Purchase([
          for (final id in kept.basket) ingredients[id],
        ], [...unlocks]..sort(compareNames)),
      );
    }
  }
  return purchases..sort(_bestFirst);
}

typedef _Kept = ({List<int> basket, int yield});

/// [kept] onto a shelf holding the best [most] of its size, richest first. A
/// basket ties with one already there only by unlocking the same number, and
/// the earlier one reads first alphabetically, so a tie keeps what it has.
void _shelve(List<_Kept> shelf, List<int> basket, int yield, int most) {
  if (shelf.length >= most && yield <= shelf.last.yield) return;
  var at = shelf.length;
  while (at > 0 && shelf[at - 1].yield < yield) {
    at--;
  }
  shelf.insert(at, (basket: List.of(basket), yield: yield));
  if (shelf.length > most) shelf.removeLast();
}

/// The recipes [basket] makes, into [unlocks]: those closed by any of its
/// parts. Filled rather than returned — this runs once per basket searched.
void _unlockedBy(
  Set<String> unlocks,
  List<int> basket,
  Map<int, Set<String>> closes,
  int radix,
) {
  unlocks.clear();
  for (var mask = 1; mask <= (1 << basket.length) - 1; mask++) {
    final closed = closes[_keyOfPart(basket, mask, radix)];
    if (closed != null) unlocks.addAll(closed);
  }
}

/// Whether every ingredient in [basket] pays its way: dropping any one of them
/// has to cost a recipe. A basket unlocking no more than one of its own smaller
/// selves is that smaller one with a passenger — and since a sub-basket's
/// recipes are always a subset, matching counts mean matching answers, so the
/// count settles it. Baskets grow by size, so the smaller are already weighed.
bool _earnsIts(List<int> basket, int yield, Map<int, int> yields, int radix) {
  if (basket.length < 2) return true;
  final whole = (1 << basket.length) - 1;
  for (var i = 0; i < basket.length; i++) {
    final without = yields[_keyOfPart(basket, whole ^ (1 << i), radix)] ?? 0;
    if (without >= yield) return false;
  }
  return true;
}

/// The alternative purchases that would make [recipe] — one per way of closing
/// every line [restocking] counts as short, any single alternative closing a
/// group (ADR-11). Empty where it needs nothing, or more than [budget] allows.
List<Set<String>> _gapsOf(
  Collection collection,
  Recipe recipe,
  int budget, {
  required bool restocking,
}) {
  var gaps = [<String>{}];
  var short = false;
  for (final line in recipe.lines) {
    if (line.isOptional) continue;
    final stock = stockOfLine(collection, line);
    if (restocking ? stock == StockLevel.in_ : stock != StockLevel.out) {
      continue;
    }
    short = true;
    final ways = {
      for (final name in line.ingredients) collection.spellingOf(name),
    };
    final grown = <String, Set<String>>{};
    for (final gap in gaps) {
      for (final way in ways) {
        final wider = {...gap, way};
        if (wider.length <= budget) grown[_keyOf(wider)] = wider;
      }
    }
    if (grown.isEmpty) return const [];
    gaps = grown.values.toList();
  }
  return short ? gaps : const [];
}

/// Every basket of 1..[budget] ingredients out of a pool of [size], ids
/// ascending — which, the pool being sorted, is also the order a basket reads
/// in. One list is walked in place rather than built per basket: at NFR-2 scale
/// these run to tens of thousands, and the caller only reads the one it is
/// given.
Iterable<List<int>> _baskets(int size, int budget) sync* {
  for (var take = 1; take <= budget && take <= size; take++) {
    final basket = List<int>.generate(take, (i) => i);
    while (true) {
      yield basket;
      var last = take - 1;
      while (last >= 0 && basket[last] == size - take + last) {
        last--;
      }
      if (last < 0) break;
      basket[last]++;
      for (var next = last + 1; next < take; next++) {
        basket[next] = basket[next - 1] + 1;
      }
    }
  }
}

/// Ascending pool ids as one number, digits in base [radix] running from 1 so
/// no basket is another's leading zero. Baskets are judged tens of thousands
/// at a time, and an int key costs neither a list nor a hash of one.
int _packed(Iterable<int> ids, int radix) =>
    ids.fold(0, (key, id) => key * radix + id + 1);

/// The same, over the ingredients [mask] takes out of [basket] — built in
/// place, this being the innermost step of the whole search.
int _keyOfPart(List<int> basket, int mask, int radix) {
  var key = 0;
  for (var i = 0; i < basket.length; i++) {
    if ((mask & (1 << i)) != 0) key = key * radix + basket[i] + 1;
  }
  return key;
}

/// One name per set of ingredients, folded and ordered, so two spellings of the
/// same gap are one key (ADR-08). Joined on the one character validation bars
/// from a name (ADR-11) — on a space, {'lemon', 'juice'} and {'lemon juice'}
/// would key alike.
String _keyOf(Iterable<String> ingredients) =>
    (ingredients.map(nameKey).toList()..sort()).join(alternativeSeparator);

/// Most recipes first, then the smaller basket, then A→Z. Both baskets already
/// read A→Z, so the tie-break walks them side by side — a key built per
/// comparison would be built a million times over a collection's worth.
int _bestFirst(Purchase a, Purchase b) {
  final byYield = b.unlocks.length.compareTo(a.unlocks.length);
  if (byYield != 0) return byYield;
  final bySize = a.ingredients.length.compareTo(b.ingredients.length);
  if (bySize != 0) return bySize;
  for (var i = 0; i < a.ingredients.length; i++) {
    final byName = compareNames(a.ingredients[i], b.ingredients[i]);
    if (byName != 0) return byName;
  }
  return 0;
}
