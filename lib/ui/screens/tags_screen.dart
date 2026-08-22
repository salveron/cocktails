import 'dart:async';

import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/state/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/color_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/entry_list.dart';
import '../widgets/vocabulary_dialogs.dart';

/// Both tag vocabularies, a tab each — add, rename with propagation, colour,
/// and reference-blocked delete (FR-VOC-1/3/4). Designed in
/// docs/ui-design.md#tags-screen.
///
/// On a guest bar the search and the orders stand and everything that writes
/// goes — the add, the row menu, the tap that opened an edit (FR-BAR-4).
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(collectionProvider);
    return DefaultTabController(
      length: TagKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tags'),
          bottom: TabBar(
            tabs: [
              for (final kind in TagKind.values) Tab(text: kind.words.tab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final kind in TagKind.values) _TagTab(kind, collection),
          ],
        ),
      ),
    );
  }
}

/// What one vocabulary is called on this screen. The domain tells the two
/// apart; only the wording is the screen's, and one exhaustive switch holds
/// all of it, so a third vocabulary cannot be drawn without being named.
typedef _Words = ({
  String tab,
  String noun,
  String plural,
  String hint,
  String blockedByNoun,
  String blurb,
});

extension on TagKind {
  _Words get words => switch (this) {
    TagKind.recipe => (
      tab: 'Recipe',
      noun: 'recipe tag',
      plural: 'recipe tags',
      hint: 'Recipe tag name',
      blockedByNoun: 'recipes',
      blurb:
          'A tag groups recipes that belong together — sour, classic, tiki '
          '— and wears a colour of its own.',
    ),
    TagKind.ingredient => (
      tab: 'Ingredient',
      noun: 'ingredient tag',
      plural: 'ingredient tags',
      hint: 'Ingredient tag name',
      blockedByNoun: 'ingredients',
      blurb:
          'A tag groups ingredients that belong together — citrus, syrup, '
          'homemade — and wears a colour of its own.',
    ),
  };
}

class _TagTab extends ConsumerWidget {
  const _TagTab(this.kind, this.collection);

  final TagKind kind;
  final Collection collection;

  _Words get words => kind.words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final writer = ref.watch(barWriterProvider);
    return EntryCardList<Tag>(
      entries: collection.tagsOf(kind),
      nameOf: (tag) => tag.name,
      rowOf: (tag) => EntryCard(
        // Left-align chip (prevents stretching).
        title: Align(alignment: Alignment.centerLeft, child: TagChip(tag)),
        // An empty menu draws nothing at all, so a guest's rows lose the ⋮
        // rather than gaining one that opens onto nothing.
        trailing: RowMenu(
          writer == null
              ? const {}
              : {
                  'Edit': () => unawaited(_editTag(context, writer, tag)),
                  'Delete': () => unawaited(_delete(context, writer, tag)),
                },
        ),
        onTap: writer == null
            ? null
            : () => unawaited(_editTag(context, writer, tag)),
      ),
      onAdd: writer == null ? null : (query) => _add(context, writer, query),
      noun: words.noun,
      plural: words.plural,
      orders: {...alphabetical, 'Colour': (tag) => tag.color.index},
      empty: EmptyState(
        icon: Icons.label_outline,
        title: 'No ${words.plural} yet',
        // The blurb describes what one is for, which reads as an invitation —
        // and a guest has none to take up.
        message: writer == null
            ? 'This bar carries no ${words.plural}.'
            : words.blurb,
      ),
    );
  }

  /// Returns true after adding (clears search).
  Future<bool> _add(
    BuildContext context,
    BarWriter writer,
    String query,
  ) async {
    final color = _unspentColor(collection.tagsOf(kind));
    final tag = await promptForTag(
      context,
      title: 'New ${words.noun}',
      hintText: words.hint,
      validate: _nameRule(color),
      color: color,
      initial: query,
    );
    if (tag == null || !context.mounted) return false;
    await writer.upsertTag(kind, tag);
    return true;
  }

  /// Name and colour come back together, so the whole entry goes to the
  /// collection as one edit — one save, one backup rotation — the rename it
  /// into the entries wearing it included (FR-DAT-4).
  Future<void> _editTag(BuildContext context, BarWriter writer, Tag tag) async {
    final edited = await promptForTag(
      context,
      title: 'Edit "${tag.name}"',
      hintText: words.hint,
      validate: _nameRule(tag.color, except: tag.name),
      color: tag.color,
      initial: tag.name,
    );
    if (edited == null || !context.mounted) return;
    await writer.upsertTag(kind, edited, replacing: tag.name);
  }

  Future<void> _delete(BuildContext context, BarWriter writer, Tag tag) async {
    final confirmed = await confirmDelete(
      context,
      what: tag.name,
      blockedBy: collection.usersOfTag(kind, tag.name),
      blockedByNoun: words.blockedByNoun,
    );
    if (!confirmed || !context.mounted) return;
    await writer.removeTag(kind, tag.name);
  }

  /// Name rules (excluding [except] to prevent collision on rename). A tag
  /// answers to its name alone, so the entry's other halves go unread.
  List<ValidationIssue> Function(VocabularyEntry) _nameRule(
    TagColor color, {
    String? except,
  }) =>
      (entry) => validateTag(
        Tag(entry.name, color: color),
        otherTagNames: otherNames(collection.tagNames(kind), except),
      );
}

/// First unused color from palette; wraps once exhausted.
TagColor _unspentColor(List<Tag> tags) {
  final spent = {for (final tag in tags) tag.color};
  return TagColor.values.firstWhere(
    (color) => !spent.contains(color),
    orElse: () => TagColor.values.first,
  );
}
