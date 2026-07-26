import 'package:cocktails/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app builds and shows its name', (tester) async {
    await tester.pumpWidget(const CocktailsApp());
    expect(find.text('Cocktails'), findsOneWidget);
  });
}
