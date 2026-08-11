/// How names fold, match and order — the one home for the rule every
/// vocabulary keeps (ADR-08). Public in src/, not exported (ADR-04).
library;

/// One name any case (ADR-08).
String nameKey(String name) => name.toLowerCase();

Set<String> nameKeys(Iterable<String> names) => {
  for (final name in names) nameKey(name),
};

extension NameComparison on String {
  bool sameName(String other) => nameKey(this) == nameKey(other);
}

/// A→Z, the order every list falls back to and ties break on.
int compareNames(String a, String b) => nameKey(a).compareTo(nameKey(b));

/// Whether [name] already stands in [seen]; adds it either way.
bool repeatsName(Set<String> seen, String name) => !seen.add(nameKey(name));

/// Indexes of duplicate names; repeated values at higher index.
List<int> duplicateNameIndexes(List<String> names) {
  final seen = <String>{};
  return [
    for (var i = 0; i < names.length; i++)
      if (repeatsName(seen, names[i])) i,
  ];
}

/// Element-wise equality check.
bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
