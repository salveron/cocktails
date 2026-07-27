/// Logic shared between domain files. Public within the layer, not exported
/// from the barrel — the "public in src/, not exported" tier of
/// docs/adr/04-module-boundaries.md.
library;

/// Indexes in [names] whose value already appeared at a lower index.
List<int> duplicateNameIndexes(List<String> names) {
  final seen = <String>{};
  final duplicates = <int>[];
  for (var i = 0; i < names.length; i++) {
    if (!seen.add(names[i])) {
      duplicates.add(i);
    }
  }
  return duplicates;
}

/// Element-wise equality; lists of different lengths are never equal.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
