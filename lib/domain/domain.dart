/// The domain layer's public surface — see docs/components.md.
library;

export 'src/collection/amount.dart';
export 'src/collection/amount_scaling.dart';
export 'src/collection/collection.dart';
export 'src/collection/collection_edits.dart';
export 'src/collection/collection_validation.dart';
export 'src/collection/ingredient.dart';
export 'src/collection/ingredient_stock.dart' hide isShortLine;
export 'src/collection/recipe.dart';
export 'src/collection/recipe_availability.dart' hide canMake;
export 'src/collection/recipe_discovery.dart' hide basesOf;
export 'src/collection/recipe_line.dart'
    hide reservedSuffixes, alternativeSeparator, formatAmount, amountText;
export 'src/collection/tag.dart';
export 'src/collection/unit.dart';
export 'src/collection/unit_sizes.dart';
export 'src/issues.dart' hide checkName, addProblems, Problem;
export 'src/names.dart' show nameKey, nameKeys, compareNames, NameComparison;
export 'src/shelf/bar.dart' hide summaryOf;
export 'src/shelf/shelf.dart';
export 'src/shelf/shelf_edits.dart';
export 'src/shelf/shelf_validation.dart';
export 'src/shelf/sharing.dart';
export 'src/shopping/optimizer.dart';
export 'src/shopping/shopping_settings.dart';
export 'src/tokens.dart' hide enumFromToken;
