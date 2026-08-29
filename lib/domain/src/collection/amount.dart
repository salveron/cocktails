/// A single value or a range (FR-REC-2).
library;

final class Amount {
  final double min;
  final double max;

  const Amount(double value) : this.range(value, value);

  const Amount.range(this.min, this.max);

  bool get isRange => min != max;

  @override
  bool operator ==(Object other) =>
      other is Amount && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => isRange ? 'Amount($min-$max)' : 'Amount($min)';
}
