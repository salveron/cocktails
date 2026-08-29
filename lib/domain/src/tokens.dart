/// A value that declares its own wire token, read by every enum across the
/// three folders below.
library;

abstract interface class Tokened {
  String get token;
}

/// Linear lookup shared by every [Tokened] enum; not exported (ADR-04).
T? enumFromToken<T extends Tokened>(List<T> values, String text) {
  for (final value in values) {
    if (value.token == text) return value;
  }
  return null;
}
