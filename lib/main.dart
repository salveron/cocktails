import 'package:cocktails/data/data.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The composition root: the only place that knows where the store lives
/// (docs/architecture.md#platform-facts).
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

class CocktailsApp extends StatelessWidget {
  const CocktailsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cocktails',
      home: Scaffold(body: Center(child: Text('Cocktails'))),
    );
  }
}
