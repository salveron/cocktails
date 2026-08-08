import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/ui/widgets/model_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart';

/// A store whose load blows up — the only way to reach the failure face.
final class _FailingStore implements ModelStore {
  @override
  Future<LoadOutcome> load() async => throw StateError('disk on fire');

  @override
  Future<void> save(Model model) async {}

  @override
  Future<String> exportSnapshot(
    Model model, {
    ExportPurpose purpose = ExportPurpose.share,
  }) async => '';
}

void main() {
  final view = ModelView((model) => const Text('loaded'));

  group('model view', () {
    testWidgets('shows a spinner until the startup load resolves', (
      tester,
    ) async {
      await tester.pumpWidget(scoped(MaterialApp(home: view)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('loaded'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('loaded'), findsOneWidget);
    });

    testWidgets('shows the failure when the store cannot be read', (
      tester,
    ) async {
      await pumpScreen(tester, view, store: _FailingStore());
      expect(find.text('Your data could not be opened'), findsOneWidget);
      expect(find.textContaining('disk on fire'), findsOneWidget);
      expect(find.text('loaded'), findsNothing);
    });
  });
}
