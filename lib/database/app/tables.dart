import "package:drift/drift.dart";

class DictGroup extends Table {
  TextColumn get dictIds => text()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class DictionaryList extends Table {
  TextColumn get alias => text().nullable()();
  TextColumn get fontPath => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
}

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
}

@TableIndex(name: "idx_wordbook", columns: {#word, #createdAt})
class Wordbook extends Table {
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get tag => integer().nullable()();
  TextColumn get word => text()();
}

@TableIndex(name: "idx_wordbook_tags", columns: {#tag})
class WordbookTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tag => text().unique()();
}
