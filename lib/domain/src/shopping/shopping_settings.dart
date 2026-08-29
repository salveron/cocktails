/// How the optimizer is asked and what its screen opens on (FR-SET-2) — the
/// reader's, so ADR 24 rides it on the bar's record rather than in the file.
library;

/// What a budget can be (FR-DIS-6) — one search at the largest answers them
/// all — and how many baskets of one size are worth offering (ADR 15).
const budgets = [1, 2, 3];
const basketCounts = [10, 25, 50];

/// The defaults are the answer the app gave before any of it could be set.
final class ShoppingSettings {
  /// Whether a tag pick aims the search or sifts its answer (FR-DIS-10).
  final bool aiming;

  /// Where the screen's own two controls start (FR-DIS-6, FR-DIS-7), moving
  /// freely from both and writing neither back.
  final int budget;
  final bool restocking;

  /// The best few of each size (ADR 15), and whether an optional line is short
  /// at all (FR-REC-3).
  final int keptPerSize;
  final bool buyingOptional;

  /// Wire tokens, declared here rather than left as bare literals in data/
  /// (collection.dart's rule for every other value): a rename of the field
  /// above must not move the format.
  static const aimToken = 'aim';
  static const budgetToken = 'budget';
  static const lowToken = 'low';
  static const mostToken = 'most';
  static const optionalToken = 'optional';

  const ShoppingSettings({
    this.aiming = false,
    this.budget = 1,
    this.restocking = false,
    this.keptPerSize = 25,
    this.buyingOptional = false,
  });

  ShoppingSettings copyWith({
    bool? aiming,
    int? budget,
    bool? restocking,
    int? keptPerSize,
    bool? buyingOptional,
  }) => ShoppingSettings(
    aiming: aiming ?? this.aiming,
    budget: budget ?? this.budget,
    restocking: restocking ?? this.restocking,
    keptPerSize: keptPerSize ?? this.keptPerSize,
    buyingOptional: buyingOptional ?? this.buyingOptional,
  );

  @override
  bool operator ==(Object other) =>
      other is ShoppingSettings &&
      other.aiming == aiming &&
      other.budget == budget &&
      other.restocking == restocking &&
      other.keptPerSize == keptPerSize &&
      other.buyingOptional == buyingOptional;

  @override
  int get hashCode =>
      Object.hash(aiming, budget, restocking, keptPerSize, buyingOptional);

  @override
  String toString() =>
      'ShoppingSettings(${aiming ? 'aiming' : 'sifting'}, $budget of '
      '$keptPerSize)';
}
