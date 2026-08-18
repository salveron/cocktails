/// Generic list edits shared by collection_edits.dart and shelf_edits.dart.
library;

/// [item] replacing the first entry any of [matches] finds, in order — a
/// rename tries its old identity before its own; an id upsert needs one.
List<T> upserted<T>(List<T> items, T item, List<bool Function(T)> matches) {
  for (final match in matches) {
    final index = items.indexWhere(match);
    if (index >= 0) return [...items]..[index] = item;
  }
  return [...items, item];
}

List<T> without<T>(List<T> items, bool Function(T) matches) => [
  for (final item in items)
    if (!matches(item)) item,
];
