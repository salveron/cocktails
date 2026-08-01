import 'package:flutter/material.dart';

/// Case-insensitive substring match.
bool matchesQuery(String text, String query) =>
    text.toLowerCase().contains(query.trim().toLowerCase());

/// Search field with clear button (caller owns controller/rebuild). [trailing]
/// rides beside the field, for what acts on the list rather than on the text.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    child: Row(
      children: [
        Expanded(
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
        ),
        ?trailing,
      ],
    ),
  );
}
