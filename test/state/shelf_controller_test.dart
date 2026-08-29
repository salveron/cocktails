import 'dart:convert';
import 'dart:typed_data';

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';
import 'package:cocktails/domain/src/shelf/bar.dart' show summaryOf;
import 'package:cocktails/state/state.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/state_test_support.dart';
import '../support/test_support.dart';

void main() {
  setUpShelf();

  group('startup load', () {
    test('an empty store starts the app on an empty collection', () async {
      final store = MemoryBarStore();
      final container = await started(store);
      expect(collectionOf(container), Collection());
      expect(container.read(loadIssuesProvider), isEmpty);
      // A device holding nothing is given one owned bar to write into.
      expect(store.savedShelf?.bars, hasLength(1));
      expect(store.savedShelf?.bars.single.mode, BarMode.owner);
      expect(store.savedShelf?.openId, store.savedShelf?.bars.single.id);
    });

    test('a stored collection is loaded as it stands', () async {
      final container = await started();
      expect(collectionOf(container), stored);
      expect(container.read(loadIssuesProvider), isEmpty);
    });

    test('a corrupt store starts on the recovered backup', () async {
      store.barOutcomes[bar.id] = Rejected([
        issueAt(4),
      ], recovered: payloadOf(stored));
      final container = await started();
      expect(collectionOf(container), stored);
      expect(container.read(loadIssuesProvider), [
        'line 4: Unknown ingredient: "rye"',
      ]);
    });

    test('a corrupt store with nothing to recover starts empty', () async {
      store.barOutcomes[bar.id] = Rejected([issueAt(4)]);
      final container = await started();
      expect(collectionOf(container), Collection());
      expect(container.read(loadIssuesProvider), hasLength(1));
    });

    test('an issue without a line still reports what is wrong', () async {
      store.barOutcomes[bar.id] = Rejected([issueAt(null)]);
      final container = await started();
      expect(container.read(loadIssuesProvider), ['Unknown ingredient: "rye"']);
    });

    test('the issues are published when the load resolves', () async {
      store.barOutcomes[bar.id] = Rejected([issueAt(4)]);
      final container = containerFor(store);
      expect(container.read(loadIssuesProvider), isEmpty);
      await container.read(shelfProvider.future);
      expect(container.read(loadIssuesProvider), hasLength(1));
    });
  });

  // ADR 23 holds on the controller's own routes too, which take no writer:
  // an edit, an import and a record change each answer for a guest bar.
  group('a guest bar on the controller\'s own routes', () {
    /// A guest bar, which nothing but a refresh may write (FR-BAR-3).
    final visiting = Bar(
      id: 'f7a2b8',
      name: "Ada's bar",
      mode: BarMode.guest,
      source: const BarSource(
        via: Transport.file,
        at: 'ada.yaml',
        from: "Ada's bar",
      ),
    );

    // Each file rotates three backups, so writing one that did not move costs
    // a reader an older copy of it for nothing.
    test('a collection edit leaves the index alone', () async {
      final container = await started();
      await writerOf(container).setStock('campari', StockLevel.in_);
      expect(store.savedBars[bar.id]?.$2, collectionOf(container));
      expect(store.savedShelf, isNull, reason: 'no record moved');
    });

    test('a record edit leaves the collection\'s file alone', () async {
      final container = await started();
      await controllerOf(container).setDisplay(FixedUnit.oz);
      expect(store.savedShelf?.bars.single.display, FixedUnit.oz);
      expect(store.saved, isNull, reason: 'the collection did not move');
    });

    test('an import moves both, so both are written', () async {
      final container = await started();
      await controllerOf(container).replaceOpen('Ada\'s bar', (
        name: 'unread',
        display: FixedUnit.ml,
        collection: Collection(ingredients: [Ingredient('rye')]),
      ));
      expect(store.saved?.ingredientNamed('rye'), isNotNull);
      // The name is the reader's, so the file's own is never read here.
      expect(store.savedShelf?.bars.single.name, 'Ada\'s bar');
      expect(container.read(openBarProvider)?.display, FixedUnit.ml);
    });

    // The domain's own refusal, the third of ADR 23's enforcements and the one
    // no route around the writer can escape.
    test('the raw route refuses a guest bar rather than writing it', () async {
      final seeded = MemoryBarStore.of(visiting, stored);
      final container = await started(seeded);
      await expectLater(
        controllerOf(container).editCollection(
          (collection) => collection.withStock('gin', StockLevel.out),
        ),
        throwsArgumentError,
      );
      expect(seeded.savedBars, isEmpty, reason: 'nothing was written');
    });

    test('an import leaves a guest bar exactly as it stood', () async {
      final seeded = MemoryBarStore.of(visiting, stored);
      final container = await started(seeded);
      await controllerOf(container).replaceOpen(
        'Mine now',
        payloadOf(Collection(ingredients: [Ingredient('rye')])),
      );
      expect(collectionOf(container), stored);
      expect(seeded.savedBars, isEmpty);
      expect(seeded.snapshots, isEmpty, reason: 'no copy was staged either');
    });

    // FR-BAR-3: the one thing that stays the reader's on someone else's bar.
    test('the reading unit is still the reader\'s on a guest bar', () async {
      final seeded = MemoryBarStore.of(visiting, stored);
      final container = await started(seeded);
      await controllerOf(container).setDisplay(FixedUnit.oz);
      expect(container.read(openBarProvider)?.display, FixedUnit.oz);
      expect(seeded.savedShelf?.bars.single.display, FixedUnit.oz);
      expect(seeded.savedBars, isEmpty, reason: 'the collection is untouched');
    });

    test('a guest bar exports like any other (FR-DAT-1)', () async {
      final seeded = MemoryBarStore.of(visiting, stored);
      final container = await started(seeded);
      expect(await controllerOf(container).export(), isNotEmpty);
      expect(seeded.snapshots[ExportPurpose.share]?.$2, stored);
    });
  });

  group('persistence', () {
    test(
      'an edit reaches the store as the collection the app now holds',
      () async {
        final container = await started();
        await writerOf(container).setStock('campari', StockLevel.in_);
        expect(store.savedBars[bar.id]?.$2, collectionOf(container));
        expect(store.saveCount, 1);
      },
    );

    test('every edit is written, in the order it was made', () async {
      final container = await started();
      final writer = writerOf(container);
      await writer.upsertTag(
        TagKind.recipe,
        const Tag('bitter', color: TagColor.plum),
      );
      await writer.setStock('campari', StockLevel.low);
      await writer.removeRecipe('Negroni');
      expect(store.saveCount, 3);
      expect(store.savedBars[bar.id]?.$2, collectionOf(container));
    });

    test('an edit that changes nothing is not written', () async {
      final container = await started();
      final writer = writerOf(container);
      await writer.setStock('rye', StockLevel.in_);
      await writer.upsertTag(
        TagKind.recipe,
        const Tag('classic', color: TagColor.rose),
        replacing: 'classic',
      );
      await writer.removeRecipe('Sazerac');
      expect(store.saveCount, 0);
      expect(collectionOf(container), same(stored));
    });

    test(
      'export hands the store the collection on screen (FR-DAT-1)',
      () async {
        final container = await started();
        expect(await controllerOf(container).export(), isNotEmpty);
        expect(store.snapshots[ExportPurpose.share]?.$2, stored);
      },
    );

    test('an export asked for before the load waits for it', () async {
      final container = containerFor(store);
      await controllerOf(container).export();
      expect(store.snapshots[ExportPurpose.share]?.$2, stored);
    });

    test('a session recovered from a damaged file exports what it '
        'recovered, not that file (ADR 18)', () async {
      final damaged = MemoryBarStore((bars: [bar], openId: bar.id))
        ..barOutcomes[bar.id] = Rejected([
          issueAt(4),
        ], recovered: payloadOf(stored));
      final container = await started(damaged);
      await controllerOf(container).export();
      expect(damaged.snapshots[ExportPurpose.share]?.$2, stored);
    });

    test('an edit made before the load resolves lands on top of it', () async {
      final container = containerFor(store);
      await writerOf(container).setStock('campari', StockLevel.in_);
      expect(
        collectionOf(container).ingredientNamed('campari')?.stock,
        StockLevel.in_,
      );
      expect(
        collectionOf(container).ingredientNamed('gin')?.stock,
        StockLevel.in_,
      );
      expect(collectionOf(container).recipes, [negroni]);
    });
  });

  group('import', () {
    final incoming = Collection(
      ingredients: [Ingredient('rye', stock: StockLevel.low)],
      recipes: [
        Recipe(
          'Sazerac',
          lines: const [
            RecipeLine(Amount(2), 'part', ['rye']),
          ],
        ),
      ],
    );
    final incomingFile = const YamlCodec().encode(payloadOf(incoming));

    test('a file that decodes reviews as the collection it holds', () async {
      final container = await started();
      final review = controllerOf(container).review(incomingFile);
      expect(review.bar?.collection, incoming);
      expect(review.issues, isEmpty);
    });

    test('a review touches nothing on its own (FR-DAT-3)', () async {
      final container = await started();
      controllerOf(container).review(incomingFile);
      expect(collectionOf(container), stored);
      expect(store.saveCount, 0);
      expect(store.snapshots, isEmpty);
    });

    test('a file that does not decode reviews as issues, placed '
        '(FR-DAT-4)', () async {
      final container = await started();
      final review = controllerOf(container).review('''
format: 1
recipes:
  - name: Sazerac
    lines: ["2 parts rye"]
''');
      expect(review.bar, isNull);
      expect(review.issues, hasLength(1));
      expect(review.issues.single, contains('rye'));
      expect(review.issues.single, startsWith('line '));
    });

    test('a file that is not the format at all is refused, not crashed', () {
      final review = ShelfController().review('not a cocktail in sight');
      expect(review.bar, isNull);
      expect(review.issues, hasLength(1));
    });

    test('replacing keeps a copy of what it replaced first '
        '(FR-DAT-3)', () async {
      final container = await started();
      await controllerOf(container).replaceOpen(bar.name, payloadOf(incoming));
      // The copy is the collection that stood before, never the one arriving.
      expect(store.snapshots[ExportPurpose.beforeImport]?.$2, stored);
      expect(collectionOf(container), incoming);
      expect(store.savedBars[bar.id]?.$2, incoming);
    });

    test('the copy it keeps is not the one an export shares', () async {
      final container = await started();
      await controllerOf(container).export();
      await controllerOf(container).replaceOpen(bar.name, payloadOf(incoming));
      // Two copies, two purposes: the export slot still holds what went out to
      // a reader, so an import cannot write over it.
      expect(store.snapshots[ExportPurpose.share]?.$2, stored);
      expect(store.snapshots[ExportPurpose.beforeImport]?.$2, stored);
    });

    test('a replace asked for before the load waits for it', () async {
      final container = containerFor(store);
      await controllerOf(container).replaceOpen(bar.name, payloadOf(incoming));
      // Not the empty collection the copy would hold had it run before the
      // load.
      expect(store.snapshots[ExportPurpose.beforeImport]?.$2, stored);
      expect(collectionOf(container), incoming);
    });

    test(
      'an exported file imports as the same collection (FR-DAT-5)',
      () async {
        final container = await started();
        final controller = controllerOf(container);
        await controller.export();
        final (record, exported) = store.snapshots[ExportPurpose.share]!;
        final review = controller.review(
          const YamlCodec().encode(payloadOf(exported)),
        );
        expect(review.issues, isEmpty);
        expect(review.bar?.collection, stored);
        expect(
          record.id,
          bar.id,
          reason: 'the bar on screen is the one copied',
        );
      },
    );
  });

  /// A second owned bar and a guest one, so a crossing has somewhere to go and
  /// the guest refusals have something to refuse.
  final other = Bar(id: 'd4e5f6', name: 'Anna', mode: BarMode.owner);
  final otherCollection = Collection(ingredients: [Ingredient('white rum')]);
  final guest = Bar(
    id: 'g7h8i9',
    name: "Anna's bar",
    mode: BarMode.guest,
    source: const BarSource(via: Transport.file, at: 'anna.yaml', from: 'Anna'),
  );

  BarContent payloadFor(Bar bar, Collection collection) =>
      (name: bar.name, display: bar.display, collection: collection);

  /// A shelf of [bars] with the first open, each holding what [collections]
  /// gives it — the arrangement every crossing, rename and delete runs over.
  WriteLog shelfOf(List<Bar> bars, Map<String, Collection> collections) {
    Collection held(Bar bar) => collections[bar.id] ?? Collection();
    // Summarised as the index on a device that has run once already holds
    // them, so no test but the migration's own meets the counting pass.
    final store = WriteLog((
      bars: [
        for (final bar in bars)
          bar.summarised(held(bar), at: bar.isOwned ? now : null),
      ],
      openId: bars.first.id,
    ));
    for (final bar in bars) {
      store.barOutcomes[bar.id] = Ok(payloadFor(bar, held(bar)));
    }
    return store;
  }

  WriteLog twoBars() =>
      shelfOf([bar, other], {bar.id: stored, other.id: otherCollection});

  group('crossing to another bar', () {
    test('the other bar comes up and the first is left behind', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).openBar(other.id);
      expect(container.read(openBarProvider)?.id, other.id);
      expect(collectionOf(container), otherCollection);
      expect(store.savedShelf?.openId, other.id);
    });

    test('the index moves and no bar file is touched', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).openBar(other.id);
      // The collection came up from disk; writing it straight back would
      // rotate the backups of a bar nobody edited.
      expect(store.saveCount, 0);
      expect(store.calls, ['shelf']);
    });

    test('the bar already open is left alone', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).openBar(bar.id);
      expect(store.calls, isEmpty);
      expect(collectionOf(container), same(stored));
    });

    test('an id the shelf does not hold opens nothing', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).openBar('nosuch');
      expect(container.read(openBarProvider)?.id, bar.id);
      expect(store.calls, isEmpty);
    });

    test('a torn file opens on its backup and says what tore', () async {
      final store = twoBars();
      store.barOutcomes[other.id] = Rejected([
        issueAt(4),
      ], recovered: payloadFor(other, otherCollection));
      final container = await started(store);
      await controllerOf(container).openBar(other.id);
      expect(collectionOf(container), otherCollection);
      expect(container.read(loadIssuesProvider), [
        'line 4: Unknown ingredient: "rye"',
      ]);
    });

    test('a crossing onto a sound bar clears the last load\'s word', () async {
      final store = twoBars();
      store.barOutcomes[bar.id] = Rejected([
        issueAt(4),
      ], recovered: payloadOf(stored));
      final container = await started(store);
      expect(container.read(loadIssuesProvider), hasLength(1));
      await controllerOf(container).openBar(other.id);
      expect(container.read(loadIssuesProvider), isEmpty);
    });
  });

  group('a new bar', () {
    test('is founded empty and owned, and opened by the making', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).addOwnedBar('Cellar');
      final founded = container.read(openBarProvider);
      expect(founded?.name, 'Cellar');
      expect(founded?.mode, BarMode.owner);
      expect(collectionOf(container), Collection());
      expect(container.read(barsProvider), hasLength(3));
    });

    test('its file is written before the index names it', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).addOwnedBar('Cellar');
      final founded = container.read(openBarProvider)!;
      // A crash between the two must leave storage to reclaim rather than a
      // record opening onto nothing.
      expect(store.calls, ['bar:${founded.id}', 'shelf']);
      expect(store.savedShelf?.openId, founded.id);
    });

    /// FR-BAR-2's other half: an owned bar created *from a file* rather than
    /// empty — the third thing one picked file can become (FR-BAR-7).
    test('one founded from a file holds it, and stays the reader\'s', () async {
      final store = twoBars();
      final container = await started(store);
      final arrived = Collection(ingredients: [Ingredient('rye')]);
      await controllerOf(container).addOwnedBar(
        'Cellar',
        from: (name: "Ada's bar", display: FixedUnit.oz, collection: arrived),
      );
      final founded = container.read(openBarProvider)!;
      expect(founded.mode, BarMode.owner);
      // The reader's name, not the file's: the contents came from another bar
      // and the bar itself did not.
      expect(founded.name, 'Cellar');
      // Nothing links it back, so a refresh has nothing to ask.
      expect(founded.source, isNull);
      expect(founded.refreshed, isNull);
      expect(founded.updated, now);
      // An establishing is where the reader has no pick yet (ADR 21).
      expect(founded.display, FixedUnit.oz);
      expect(collectionOf(container), arrived);
      expect(founded.summary, summaryOf(arrived));
      expect(store.savedBars[founded.id]?.$2, arrived);
    });

    test('two bars may carry one name (FR-BAR-1)', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).addOwnedBar(bar.name);
      final names = [for (final b in container.read(barsProvider)) b.name];
      expect(names.where((name) => name == bar.name), hasLength(2));
    });
  });

  group('renaming a bar', () {
    test('the record moves and the collection stays put', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).renameBar(bar.id, 'Downstairs');
      expect(container.read(openBarProvider)?.name, 'Downstairs');
      expect(store.savedShelf?.bars.first.name, 'Downstairs');
      expect(store.saveCount, 0);
    });

    test('a bar not on show is renamed where it stands', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).renameBar(other.id, 'Upstairs');
      expect(store.savedShelf?.bars.last.name, 'Upstairs');
      expect(container.read(openBarProvider)?.id, bar.id);
    });

    /// FR-BAR-3: what a bar is called here is the reader's on a guest bar as on
    /// one of their own — a label on someone else's collection, and no refresh
    /// takes it back (ADR 21).
    test('a guest bar is renamed like any other', () async {
      final store = shelfOf([bar, guest], {bar.id: stored});
      final container = await started(store);
      await controllerOf(container).renameBar(guest.id, 'Mine now');
      expect(container.read(barsProvider).last.name, 'Mine now');
      // The record moved; the owner's collection was not touched to do it.
      expect(store.savedShelf?.bars.last.name, 'Mine now');
      expect(store.savedBars[guest.id], isNull);
    });

    test('the name it already carries writes nothing', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).renameBar(bar.id, bar.name);
      expect(store.calls, isEmpty);
    });
  });

  group('deleting a bar', () {
    test('the copy is kept before the bar goes (FR-BAR-2)', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar(bar.id);
      expect(store.snapshots[ExportPurpose.beforeDelete]?.$2, stored);
      expect(container.read(barsProvider).map((bar) => bar.id), [other.id]);
    });

    test('the record goes before the file it names', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar(other.id);
      expect(store.calls, ['shelf', 'remove:${other.id}']);
    });

    test('deleting the bar on show leaves none open', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar(bar.id);
      expect(container.read(openBarProvider), isNull);
      expect(store.savedShelf?.openId, isNull);
      expect(collectionOf(container), Collection());
    });

    test('deleting another leaves the bar on show alone', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar(other.id);
      expect(container.read(openBarProvider)?.id, bar.id);
      expect(collectionOf(container), same(stored));
    });

    test('a bar not on show is copied from its own file', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar(other.id);
      expect(store.snapshots[ExportPurpose.beforeDelete]?.$2, otherCollection);
    });

    test('a guest bar goes without a copy being kept', () async {
      final store = shelfOf([bar, guest], {bar.id: stored});
      final container = await started(store);
      await controllerOf(container).removeBar(guest.id);
      // Its contents are its owner's; FR-BAR-3 removes one touching nothing.
      expect(store.snapshots[ExportPurpose.beforeDelete], isNull);
      expect(container.read(barsProvider), [bar]);
    });

    test('a bar the shelf does not hold is not a deletion', () async {
      final store = twoBars();
      final container = await started(store);
      await controllerOf(container).removeBar('nosuch');
      expect(store.calls, isEmpty);
      expect(container.read(barsProvider), hasLength(2));
    });
  });

  group('what a bar holds', () {
    /// A record as an index written before summaries existed carries it.
    Bar uncountedRecord(Bar counted) => Bar(
      id: counted.id,
      name: counted.name,
      mode: counted.mode,
      display: counted.display,
      offers: counted.offers,
      source: counted.source,
      refreshed: counted.refreshed,
    );

    /// That shelf whole: two bars, neither counted, which is what the startup
    /// pass is there to meet.
    WriteLog uncounted() {
      final store = WriteLog((
        bars: [uncountedRecord(bar), uncountedRecord(other)],
        openId: bar.id,
      ));
      store.barOutcomes[bar.id] = Ok(payloadFor(bar, stored));
      store.barOutcomes[other.id] = Ok(payloadFor(other, otherCollection));
      return store;
    }

    test('a summarised shelf is left alone and read for nothing', () async {
      final store = twoBars();
      final container = await started(store);
      expect(store.calls, isEmpty, reason: 'no index rewritten');
      expect(container.read(barsProvider).first.summary, summaryOf(stored));
    });

    test('an index carrying no counts gains them at startup', () async {
      final store = uncounted();
      final container = await started(store);
      expect(container.read(barsProvider).map((bar) => bar.summary), [
        summaryOf(stored),
        summaryOf(otherCollection),
      ]);
      expect(store.calls, ['shelf'], reason: 'written back once, for all bars');
      expect(store.savedShelf?.bars.first.summary, summaryOf(stored));
    });

    test('counting a bar is not dating an edit to it', () async {
      final container = await started(uncounted());
      // Nobody edited these bars; the app merely counted what was already
      // there, and a stamp invented here would date an edit that never was.
      expect(container.read(barsProvider).map((bar) => bar.updated), [
        isNull,
        isNull,
      ]);
    });

    test('the bar on show is counted where it already stands', () async {
      final store = uncounted();
      final container = await started(store);
      expect(container.read(barsProvider).first.summary, summaryOf(stored));
      // Resident from the startup load (ADR 20), so counting it costs no
      // read of its own: one each, and the open bar's is the one it opened by.
      expect(store.loads, [bar.id, other.id]);
    });

    test('a file that will not read leaves the bar uncounted', () async {
      final store = uncounted();
      store.barOutcomes[other.id] = Rejected([issueAt(4)]);
      final container = await started(store);
      // Absent rather than a row of zeroes: the card says it could not be read
      // instead of claiming the bar holds nothing.
      expect(container.read(barsProvider).last.summary, isNull);
    });

    test('a torn file is counted from what its backup holds', () async {
      final store = uncounted();
      store.barOutcomes[other.id] = Rejected([
        issueAt(4),
      ], recovered: payloadFor(other, otherCollection));
      final container = await started(store);
      expect(
        container.read(barsProvider).last.summary,
        summaryOf(otherCollection),
      );
    });

    test('an edit recounts the bar and dates it', () async {
      final container = await started();
      await container
          .read(barWriterProvider)!
          .upsertIngredient(Ingredient('rye'));
      final written = container.read(barsProvider).single;
      expect(written.summary?[Holding.ingredient], 3);
      expect(written.updated, now);
    });
  });

  group('a shelf with nothing on it', () {
    test('an index listing no bars founds none (ADR 20)', () async {
      final store = WriteLog((bars: const [], openId: null));
      final container = await started(store);
      // A reader who deleted their last bar meets the bar list, where a device
      // holding no index at all is given one to write into.
      expect(container.read(barsProvider), isEmpty);
      expect(container.read(openBarProvider), isNull);
      expect(store.calls, isEmpty);
    });

    test('no index at all is a first run and is given a bar', () async {
      final store = WriteLog(null);
      final container = await started(store);
      expect(container.read(barsProvider), hasLength(1));
      expect(container.read(openBarProvider), isNotNull);
    });
  });

  /// The seam's own reading, over a file shaped the way `file_selector_android`
  /// answers: `XFile.fromData`, whose `readAsString` ignores the encoding asked
  /// of it. Overriding the picker with a plain `String` never reached this.
  group('a picked file reads as UTF-8', () {
    test('a name outside ASCII arrives as it left', () async {
      final picked = XFile.fromData(utf8.encode('Orange Curaçao'));
      expect(await pickedText(picked), 'Orange Curaçao');
    });

    test('an export picked back keeps the spelling it went out with', () async {
      final exported = Collection(ingredients: [Ingredient('Orange Curaçao')]);
      final onDisk = const YamlCodec().encode(payloadOf(exported));
      final container = await started();

      final text = await pickedText(XFile.fromData(utf8.encode(onDisk)));

      expect(controllerOf(container).review(text).bar?.collection, exported);
    });

    test('bytes that are not UTF-8 are refused, not guessed at', () async {
      final picked = XFile.fromData(Uint8List.fromList([0x61, 0xFF, 0x62]));
      await expectLater(pickedText(picked), throwsFormatException);
    });
  });
}
