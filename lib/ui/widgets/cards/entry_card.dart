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
    this.menu,
    this.body,
    this.onTap,
    this.selected,
    this.margin = _listMargin,
    super.key,
  });

  /// What the text stands from the card's edge, and so what everything else on
  /// the tile's row does: the trailing from the other edge, and a chip from
  /// the ⋮'s glyph box beside it.
  static const _inset = 16.0;

  /// What a ⋮ gives up of an inset on each side: its button reaches that far
  /// past its glyph box to make a fingertip, over the inset around it.
  static const _menuInset = _inset - RowMenu.roomAroundDots;

  /// What a list insets its rows by, and what a form standing them among its
  /// own fields overrides — a form pads its whole page already, so a row
  /// keeping this would sit narrower than every field above it.
  static const _listMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  final Widget title;
  final Widget? subtitle;
  final Widget? body;

  final Widget? trailing;

  /// Stands last in the trailing slot, an inset after [trailing], its glyph box
  /// an inset from the edge.
  final RowMenu? menu;
  final VoidCallback? onTap;

  /// If true/false, wear the ring a picked tag chip wears; if null, no ring —
  /// the card is not one of a choice (docs/ui-design.md#tag-and-stock-colours).
  final bool? selected;

  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final body = this.body;
    final trailing = this.trailing;
    final menu = this.menu;
    final menuDrawn = menu != null && menu.drawn;
    final tile = ListTile(
      title: title,
      subtitle: subtitle,
      trailing: menuDrawn
          ? Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _menuInset,
              children: [?trailing, menu],
            )
          : trailing,
      contentPadding: EdgeInsetsDirectional.only(
        start: _inset,
        end: menuDrawn ? _menuInset : _inset,
      ),
      onTap: onTap,
    );
    final selected = this.selected;
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: margin,
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      // Transparent where it is a choice not made, so picking one moves
      // nothing on the screen but the colour.
      shape: selected == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: selected ? scheme.primary : Colors.transparent,
              ),
            ),
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

/// An [EntryCard] that opens in place: [subtitle] shown only while collapsed,
/// [body] only while [open]. Built regardless of [open] — a body no reader
/// can see costs nothing unlaid-out.
class ExpandingCard extends StatelessWidget {
  const ExpandingCard({
    required this.open,
    required this.title,
    this.subtitle,
    this.trailing,
    this.menu,
    this.body,
    this.onToggle,
    this.margin = EntryCard._listMargin,
    super.key,
  });

  final bool open;
  final Widget title;
  final String? subtitle;
  final Widget? trailing;
  final RowMenu? menu;
  final Widget? body;
  final VoidCallback? onToggle;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return EntryCard(
      margin: margin,
      title: title,
      subtitle: subtitle == null || open
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      menu: menu,
      body: open ? body : null,
      onTap: onToggle,
    );
  }
}

class RowMenu extends StatelessWidget {
  const RowMenu(this.actions, {super.key});

  final Map<String, VoidCallback> actions;

  /// What the button keeps around its 24-wide glyph box to make a fingertip's
  /// 48: the room the dots have to tap, in the insets either side of the box.
  static const roomAroundDots = (kMinInteractiveDimension - 24) / 2;

  /// Nothing at all where nothing is offered, so a guest bar's rows lose the ⋮
  /// rather than gaining one that opens onto an empty menu (FR-BAR-4). Here
  /// rather than in each caller: a row builds the actions its bar allows and
  /// says nothing about whether any survived.
  bool get drawn => actions.isNotEmpty;

  @override
  Widget build(BuildContext context) => !drawn
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
