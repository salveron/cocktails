/// Records what reached the store and in what order: a bar's file must land
/// before the index names it, and its record must go before the file is
/// dropped, or a crash between the two leaves a bar that opens onto nothing.
/// Shared by every test that watches the controller write.
library;

import 'package:cocktails/data/data.dart';
import 'package:cocktails/domain/domain.dart';

base class WriteLog extends MemoryBarStore {
  WriteLog(super.records);

  final calls = <String>[];

  /// Every bar whose bytes were asked for, so a test can show that counting a
  /// shelf costs one read per bar and none for the one already resident.
  final loads = <String>[];

  @override
  Future<LoadOutcome<BarPayload>> loadBar(String id) {
    loads.add(id);
    return super.loadBar(id);
  }

  @override
  Future<void> saveBar(Bar bar, Collection collection) {
    calls.add('bar:${bar.id}');
    return super.saveBar(bar, collection);
  }

  @override
  Future<void> saveShelf(Records records) {
    calls.add('shelf');
    return super.saveShelf(records);
  }

  @override
  Future<void> removeBar(String id) {
    calls.add('remove:$id');
    return super.removeBar(id);
  }
}
