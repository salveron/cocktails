import 'package:flutter/material.dart';

void main() {
  runApp(const CocktailsApp());
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
