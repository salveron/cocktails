/// How a pick set changes — one control's own toggle.
library;

extension ToggleMembership<T> on Set<T> {
  void toggle(T value) {
    if (!remove(value)) add(value);
  }
}
