import 'package:cocktails/domain/model.dart';
import 'package:cocktails/domain/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValidationIssue', () {
    test('location renders keys and indexes', () {
      expect(
        ValidationIssue(['recipes', 0, 'lines', 2], 'oops').location,
        'recipes[0].lines[2]',
      );
      expect(
        ValidationIssue(['settings', 'part_ml'], 'oops').location,
        'settings.part_ml',
      );
    });

    test('toString carries location and message', () {
      expect(ValidationIssue(['tags', 1], 'oops').toString(), 'tags[1]: oops');
    });
  });

  group('validateModel', () {
    test('empty parts are valid', () {
      expect(validateModel(), isEmpty);
    });

    test('the architecture example is valid', () {
      final issues = validateModel(
        ingredients: [
          const Ingredient('bourbon', isBase: true, stock: StockLevel.in_),
          const Ingredient('lemon juice', stock: StockLevel.low),
          const Ingredient('rich demerara syrup'),
          const Ingredient('egg white', stock: StockLevel.in_),
        ],
        tags: [const Tag('sour'), const Tag('classic')],
        recipes: [
          Recipe(
            'Whiskey Sour',
            tags: ['sour', 'classic'],
            lines: const [
              RecipeLine(Amount.range(1.5, 2), Unit.part, 'bourbon'),
              RecipeLine(Amount(0.75), Unit.part, 'lemon juice'),
              RecipeLine(Amount(0.5), Unit.part, 'rich demerara syrup'),
              RecipeLine(Amount(0.5), Unit.part, 'egg white', isOptional: true),
            ],
            notes: 'dry shake, then shake with ice',
            made: MadeHistory(DateTime(2026, 7, 18), 12),
          ),
        ],
      );
      expect(issues, isEmpty);
    });

    test('flags a non-positive part_ml', () {
      final issues = validateModel(settings: const Settings(partMl: 0));
      expect(issues, hasLength(1));
      expect(issues.single.path, ['settings', 'part_ml']);
      expect(issues.single.message, contains('positive'));
    });

    test('flags malformed names in every vocabulary', () {
      final issues = validateModel(
        ingredients: [const Ingredient('')],
        tags: [const Tag(' sour')],
        recipes: [Recipe('Old\nFashioned')],
      );
      expect(issues, hasLength(3));
      expect(issues[0].path, ['ingredients', 0]);
      expect(issues[0].message, contains('Empty'));
      expect(issues[1].path, ['tags', 0]);
      expect(issues[1].message, contains('whitespace'));
      expect(issues[2].path, ['recipes', 0]);
      expect(issues[2].message, contains('Line break'));
    });

    test('flags an ingredient name ending with the reserved suffix', () {
      final issues = validateModel(
        ingredients: [const Ingredient('silly (optional)')],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['ingredients', 0]);
      expect(issues.single.message, contains('reserved'));
    });

    test('the reserved suffix rule is ingredient-only', () {
      final issues = validateModel(
        tags: [const Tag('odd (optional)')],
        recipes: [Recipe('Strange (optional)')],
      );
      expect(issues, isEmpty);
    });

    test('flags duplicate names at the repeated position', () {
      final issues = validateModel(
        ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        tags: [const Tag('sour'), const Tag('sour')],
        recipes: [Recipe('Negroni'), Recipe('Negroni')],
      );
      expect(issues, hasLength(3));
      expect(issues[0].path, ['ingredients', 1]);
      expect(issues[0].message, 'Duplicate ingredient name: "gin"');
      expect(issues[1].path, ['tags', 1]);
      expect(issues[2].path, ['recipes', 1]);
    });

    test('flags unknown ingredient and tag references', () {
      final issues = validateModel(
        recipes: [
          Recipe(
            'Negroni',
            tags: ['classic'],
            lines: const [RecipeLine(Amount(1), Unit.part, 'gin')],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['recipes', 0, 'tags', 0]);
      expect(issues[0].message, contains('"classic"'));
      expect(issues[1].path, ['recipes', 0, 'lines', 0]);
      expect(issues[1].message, contains('"gin"'));
    });

    test('flags a tag repeated on one recipe', () {
      final issues = validateModel(
        tags: [const Tag('sour')],
        recipes: [
          Recipe('Daiquiri', tags: ['sour', 'sour']),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'tags', 1]);
      expect(issues.single.message, contains('"sour"'));
    });

    test('flags non-positive and out-of-order amounts', () {
      final issues = validateModel(
        ingredients: [const Ingredient('gin')],
        recipes: [
          Recipe(
            'Martini',
            lines: const [
              RecipeLine(Amount(0), Unit.part, 'gin'),
              RecipeLine(Amount.range(2, 1.5), Unit.part, 'gin'),
            ],
          ),
        ],
      );
      expect(issues, hasLength(2));
      expect(issues[0].path, ['recipes', 0, 'lines', 0]);
      expect(issues[0].message, contains('positive'));
      expect(issues[1].path, ['recipes', 0, 'lines', 1]);
      expect(issues[1].message, contains('2-1.5'));
    });

    test('flags a times-made count below 1', () {
      final issues = validateModel(
        recipes: [
          Recipe('Negroni', made: MadeHistory(DateTime(2026, 7, 18), 0)),
        ],
      );
      expect(issues, hasLength(1));
      expect(issues.single.path, ['recipes', 0, 'made', 'times']);
    });

    test('collects every issue in one pass', () {
      final issues = validateModel(
        settings: const Settings(partMl: -1),
        ingredients: [const Ingredient('gin'), const Ingredient('gin')],
        recipes: [
          Recipe(
            'Negroni',
            lines: const [RecipeLine(Amount(1), Unit.part, 'vermouth')],
          ),
        ],
      );
      expect(issues, hasLength(3));
    });
  });
}
