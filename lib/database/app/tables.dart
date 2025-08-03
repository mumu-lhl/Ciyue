import "package:drift/drift.dart";

class DictGroup extends Table {
  TextColumn get dictIds => text()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

/// Type:
/// 0: Old way, needs database to store dictionary info.
/// 1: New way, does not need database to store dictionary info.
class DictionaryList extends Table {
  TextColumn get alias => text().nullable()();
  TextColumn get fontPath => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  IntColumn get type => integer().withDefault(const Constant(0))();
}

class History extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
}

class MddAudioList extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text()();
  TextColumn get title => text()();
  IntColumn get order => integer()();
}

@TableIndex(name: "idx_mdd_audio_resource", columns: {#key})
class MddAudioResource extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get mddAudioListId => integer()();
  IntColumn get startOffset => integer()();
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

@TableIndex(name: "idx_ai_explanations", columns: {#word})
class AiExplanations extends Table {
  TextColumn get word => text().unique()();
  TextColumn get explanation => text()();
}

class WritingCheckHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get inputText => text()();
  TextColumn get outputText => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class TranslateHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get inputText => text()();
  DateTimeColumn get createdAt => dateTime()();
}
