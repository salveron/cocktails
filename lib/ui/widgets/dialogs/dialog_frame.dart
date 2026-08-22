/// The one `AlertDialog` shape every dialog in the app opens in.
library;

import 'package:flutter/material.dart';

/// The `AlertDialog` shell every dialog in the app opens in: scrollable, one
/// title, a column of [content], a row of [actions].
class DialogFrame extends StatelessWidget {
  const DialogFrame({
    required this.title,
    required this.content,
    required this.actions,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final String title;
  final List<Widget> content;
  final List<Widget> actions;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: content,
    ),
    actions: actions,
  );
}
