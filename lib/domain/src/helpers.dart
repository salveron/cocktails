/// Logic shared between domain files. Public within the layer, not exported
/// from the barrel — the "public in src/, not exported" tier of
/// docs/adr/04-module-boundaries.md.
library;

/// One name however it is capitalised (docs/adr/08-names-ignore-case.md).
String nameKey(String name) => name.toLowerCase();

Set<String> nameKeys(Iterable<String> names) => {
  for (final name in names) nameKey(name),
};

extension NameComparison on String {
  bool sameName(String other) => nameKey(this) == nameKey(other);
}

/// Whether [name] already stands in [seen], which gains it either way.
bool repeatsName(Set<String> seen, String name) => !seen.add(nameKey(name));

/// Indexes in [names] whose value already appeared at a lower index.
List<int> duplicateNameIndexes(List<String> names) {
  final seen = <String>{};
  return [
    for (var i = 0; i < names.length; i++)
      if (repeatsName(seen, names[i])) i,
  ];
}

/// Element-wise equality; lists of different lengths are never equal.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
