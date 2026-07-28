import 'package:flutter/material.dart';

/// What every name search means, in one place: case-insensitive, anywhere in
/// the name (docs/ui-design.md#searchable-lists).
bool matchesQuery(String text, String query) =>
    text.toLowerCase().contains(query.trim().toLowerCase());

/// The field pinned above a searchable list. The caller owns [controller] and
/// rebuilds on its changes, so the list and the clear button stay in step.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        isDense: true,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: controller.clear,
              ),
      ),
    ),
  );
}
