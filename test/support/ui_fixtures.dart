/// The Bar/Collection fixtures the UI suites share: a reader's own bar in
/// owner and guest shape, the collections that draw something on every
/// screen, a bar's file as the codec would hand it back, and the store built
/// over them — what changes when a screen needs a new shape of data
/// (docs/components.md#testing).
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';

import 'domain_test_support.dart';
import 'memory_bar_store.dart';

/// The one bar every widget test runs over: owned, so nothing is hidden for
/// being a guest's, and reading in parts.
Bar testBar({
  String name = 'Home bar',
  FixedUnit display = FixedUnit.part,
  ShoppingSettings shopping = const ShoppingSettings(),
}) => Bar(
  id: 'test01',
  name: name,
  mode: BarMode.owner,
  display: display,
  shopping: shopping,
);

/// Another owner's, read as it stood at its last refresh (FR-BAR-3) — the
/// counterpart to [testBar], so one screen can be judged in both modes. The
/// source is what makes it a guest at all: a bar with none is refused.
///
/// Named apart from `domain/shelf_test.dart`'s own `guestBar`: that one builds
/// a bare model `Bar` with a summary set directly, for the merge rules a
/// `Collection` never enters; this one is read by widget tests, which reach
/// its counts by summarising a real [Collection] over it.
Bar testGuestBar({
  String name = "Ada's bar",
  FixedUnit display = FixedUnit.part,
}) => Bar(
  id: 'guest1',
  name: name,
  mode: BarMode.guest,
  display: display,
  source: const BarSource(via: Transport.file, at: 'ada.yaml', from: 'Ada'),
  refreshed: testNow.subtract(const Duration(days: 2)),
);

/// What the clock answers under test, so anything a screen dates reads the
/// same on every run.
final testNow = DateTime.utc(2026, 8, 14, 12);

/// Two ingredients under one recipe — the least a screen needs to be drawn
/// with something on it, and what every "not empty" case is read over.
final smallCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
  ],
  recipeTags: const [Tag('classic', color: TagColor.rose)],
  recipes: [negroniRecipe],
);

/// Three recipes off their reading order, covering every card section and
/// every form field: tags, marks, a range and notes — and each section's
/// absence too. Shared by the recipe list and the recipe form, so neither can
/// be exercised against a shape the other never sees.
final recipeCollection = Collection(
  ingredients: [
    Ingredient('bourbon'),
    Ingredient('campari'),
    Ingredient('egg white'),
    Ingredient('gin'),
    Ingredient('lemon juice'),
    Ingredient('lime juice'),
    Ingredient('sugar syrup'),
    Ingredient('sweet vermouth'),
    Ingredient('white rum'),
  ],
  recipeTags: const [
    Tag('classic', color: TagColor.rose),
    Tag('sour', color: TagColor.sand),
  ],
  recipes: [
    Recipe(
      'Whiskey Sour',
      tags: const ['sour', 'classic'],
      lines: const [
        RecipeLine(Amount(2), 'part', ['bourbon'], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['lemon juice']),
        RecipeLine(Amount(0.75), 'part', ['sugar syrup']),
        RecipeLine(Amount(1), 'piece', ['egg white'], mark: LineMark.optional),
      ],
    ),
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin'], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['campari']),
        RecipeLine(Amount(1), 'part', ['sweet vermouth']),
      ],
      notes: 'Stir over ice.',
    ),
    Recipe(
      'Daiquiri',
      lines: const [
        RecipeLine(Amount.range(1.5, 2), 'part', [
          'white rum',
        ], mark: LineMark.base),
        RecipeLine(Amount(1), 'part', ['lime juice']),
      ],
    ),
  ],
);

/// The three verdicts at once (FR-DIS-1), and an optional line the verdict
/// passes over though the card still marks it. Its A→Z runs against its
/// availability, so the two orders can never be read for each other.
const stocked = ['Campari Shot', 'Gin Shot', 'Negroni'];

/// A collection long enough that a row can be drawn from beyond the fold: two
/// worth making at either end of the alphabet, nothing but missing ones between
/// (ADR 13). Read by name, so availability cannot bring the far one forward.
final longCollection = Collection(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('vodka'),
  ],
  recipes: [
    Recipe(
      'Aviation',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
      ],
    ),
    for (var filler = 1; filler <= 38; filler++)
      Recipe(
        'Filler ${filler.toString().padLeft(2, '0')}',
        lines: const [
          RecipeLine(Amount(1), 'part', ['vodka']),
        ],
      ),
    Recipe(
      'Zombie',
      lines: const [
        RecipeLine(Amount(1), 'part', ['gin']),
      ],
    ),
  ],
);

/// An ingredient answering to a second name, so a search can reach a recipe by
/// a spelling no line of it holds (FR-VOC-6).
final aliasedCollection = recipeCollection.withIngredient(
  Ingredient('gin', aliases: const ['juniper']),
  replacing: 'gin',
);

/// [collection] as a bar's file — the shape a picked document actually has
/// from format 2 on: the owner's name and the unit it reads in ride with the
/// contents (ADR 21).
String fileOf(
  Collection collection, {
  String name = "Ada's bar",
  FixedUnit display = FixedUnit.part,
}) => const YamlCodec().encode((
  name: name,
  display: display,
  collection: collection,
));

/// A file the codec reads and the rules refuse: nothing declares "rye". The
/// one damaged file every screen that meets one is judged against.
const damagedFile = '''
format: 1
recipes:
  - name: Sazerac
    lines: ["2 parts rye"]
''';

/// A store whose bar file did not decode, recovered onto [smallCollection].
MemoryBarStore corruptStore() {
  final bar = testBar();
  return MemoryBarStore((bars: [bar], openId: bar.id))
    ..barOutcomes[bar.id] = Rejected(
      [
        SourcedIssue(
          ValidationIssue(
            const [],
            ValidationIssueKind.unknownIngredient,
            'Unknown ingredient: "rye"',
          ),
          4,
        ),
      ],
      recovered: (
        name: bar.name,
        display: bar.display,
        collection: smallCollection,
      ),
    );
}

const names = ['Daiquiri', 'Negroni', 'Whiskey Sour'];
