import "package:drift/drift.dart";

@TableIndex(name: "idx_word", columns: {#key})
class Dictionary extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get startOffset => integer()();
}

@TableIndex(name: "idx_data", columns: {#key})
class Resource extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get startOffset => integer()();
  IntColumn get part => integer().nullable()();
}
