import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two ingredients under one recipe — enough for every "not empty" screen.
final fixtureModel = Model(
  ingredients: [
    Ingredient('gin', stock: StockLevel.in_),
    Ingredient('campari'),
  ],
  recipeTags: const [Tag('classic', color: TagColor.rose)],
  recipes: [
    Recipe(
      'Negroni',
      tags: const ['classic'],
      lines: const [
        RecipeLine(Amount(1), Unit.part, 'gin'),
        RecipeLine(Amount(1), Unit.part, 'campari'),
      ],
    ),
  ],
);

/// A store whose file did not decode, recovered onto [fixtureModel].
MemoryModelStore corruptStore() => MemoryModelStore()
  ..outcome = Corrupt([
    SourcedIssue(
      ValidationIssue(
        const ['recipes', 0],
        ValidationIssueKind.unknownIngredient,
        'Unknown ingredient: "rye"',
      ),
      4,
    ),
  ], recoveredFromBackup: fixtureModel);

/// [widget] under the provider override the composition root makes, so a
/// widget test reaches the real state layer over an in-memory store.
Widget scoped(Widget widget, {ModelStore? store}) => ProviderScope(
  overrides: [
    modelStoreProvider.overrideWithValue(store ?? MemoryModelStore()),
  ],
  child: widget,
);

/// The whole app, pumped past its startup load.
Future<void> pumpApp(WidgetTester tester, {ModelStore? store}) async {
  await tester.pumpWidget(scoped(const CocktailsApp(), store: store));
  await tester.pumpAndSettle();
}

/// One screen on its own, pumped past its startup load.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  ModelStore? store,
}) async {
  await tester.pumpWidget(
    scoped(
      MaterialApp(home: Scaffold(body: screen)),
      store: store,
    ),
  );
  await tester.pumpAndSettle();
}
