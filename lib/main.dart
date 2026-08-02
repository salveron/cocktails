import 'package:cocktails/data/data.dart';
import 'package:cocktails/state/state.dart';
import 'package:cocktails/ui/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Composition root: sole place knowing store location.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  runApp(
    ProviderScope(
      overrides: [
        modelStoreProvider.overrideWithValue(FileModelStore(directory)),
      ],
      child: const CocktailsApp(),
    ),
  );
}
