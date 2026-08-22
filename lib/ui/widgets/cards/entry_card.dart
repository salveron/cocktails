/// The card a list's row stands on, and the two things built from it: a row
/// that opens in place, and its overflow menu (docs/ui-design.md#vocabulary-editing).
library;

import 'package:flutter/material.dart';

/// Single entry card with optional body; ripple clipped to card corners.
class EntryCard extends StatelessWidget {
  const EntryCard({
    required this.title,
    this.subtitle,
    this.trailing,
    this.body,
    this.onTap,
    this.margin = _listMargin,
    super.key,
  });

  /// What a list insets its rows by, and what a form standing them among its
  /// own fields overrides — a form pads its whole page already, so a row
  /// keeping this would sit narrower than every field above it.
  static const _listMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  final Widget title;
  final Widget? subtitle;
  final Widget? body;

  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final tile = ListTile(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
    );
    return Card.filled(
      margin: margin,
      color: Theme.of(context).colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: body == null
          ? tile
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tile,
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: body,
                ),
              ],
            ),
    );
  }
}

/// An [EntryCard] that opens in place: [subtitle] shown only while
/// collapsed unless [hideSubtitleWhenOpen] says otherwise (bars_screen keeps
/// its standing line either way), [body] only while [open]. Built regardless
/// of [open] — a body no reader can see costs nothing unlaid-out.
class ExpandingRow extends StatelessWidget {
  const ExpandingRow({
    required this.open,
    required this.title,
    this.subtitle,
    this.hideSubtitleWhenOpen = true,
    this.trailing,
    this.body,
    this.onToggle,
    this.margin = EntryCard._listMargin,
    super.key,
  });

  final bool open;
  final Widget title;
  final String? subtitle;
  final bool hideSubtitleWhenOpen;
  final Widget? trailing;
  final Widget? body;
  final VoidCallback? onToggle;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return EntryCard(
      margin: margin,
      title: title,
      subtitle: subtitle == null || (open && hideSubtitleWhenOpen)
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      body: open ? body : null,
      onTap: onToggle,
    );
  }
}

class RowMenu extends StatelessWidget {
  const RowMenu(this.actions, {super.key});

  final Map<String, VoidCallback> actions;

  /// Nothing at all where nothing is offered, so a guest bar's rows lose the ⋮
  /// rather than gaining one that opens onto an empty menu (FR-BAR-4). Here
  /// rather than in each caller: a row builds the actions its bar allows and
  /// says nothing about whether any survived.
  @override
  Widget build(BuildContext context) => actions.isEmpty
      ? const SizedBox.shrink()
      : PopupMenuButton<VoidCallback>(
          tooltip: 'More',
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            for (final action in actions.entries)
              PopupMenuItem(value: action.value, child: Text(action.key)),
          ],
        );
}
