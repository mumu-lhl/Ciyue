import "package:drift/drift.dart";

class DictGroup extends Table {
  TextColumn get dictIds => text()();
  TextColumn get hunspellIds => text().withDefault(const Constant(""))();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get order => integer().withDefault(const Constant(0))();
}

/// Type:
/// 0: Old way, needs database to store dictionary info.
/// 1: New way, does not need database to store dictionary info.
@TableIndex(name: "idx_dictionary_list_path", columns: {#path})
class DictionaryList extends Table {
  TextColumn get title => text().nullable()();
  TextColumn get fontPath => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  IntColumn get order => integer().nullable()();
  TextColumn get path => text()();
  IntColumn get type => integer().withDefault(const Constant(0))();
}

class HunspellSource extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get affPath => text()();
  TextColumn get dicPath => text()();
  TextColumn get language => text().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  BoolColumn get twoPassLookup =>
      boolean().withDefault(const Constant(false))();
}

/// Index on `word`: every lookup does `DELETE WHERE word = ?` followed by an
/// insert, so the delete must not scan the whole table.
@TableIndex(name: "idx_history_word", columns: {#word})
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

@TableIndex(name: "idx_mdd_audio_resource", columns: {#key, #mddAudioListId})
class MddAudioResource extends Table {
  IntColumn get blockOffset => integer()();
  IntColumn get compressedSize => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get key => text()();
  IntColumn get mddAudioListId => integer()();
  IntColumn get startOffset => integer()();
}

@TableIndex(name: "idx_wordbook", columns: {#word, #createdAt})
@TableIndex(name: "idx_wordbook_created_at", columns: {#createdAt})
@TableIndex(name: "idx_wordbook_word_tag", columns: {#word, #tag}, unique: true)
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

@TableIndex(name: "idx_ai_explanations", columns: {#word, #sourceLanguage})
class AiExplanations extends Table {
  TextColumn get word => text()();
  TextColumn get sourceLanguage => text().withDefault(const Constant("auto"))();
  TextColumn get explanation => text()();

  @override
  Set<Column> get primaryKey => {word, sourceLanguage};
}

class WritingCheckHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get inputText => text()();
  TextColumn get outputText => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(
  name: "idx_translate_history_input_text",
  columns: {#inputText},
  unique: true,
)
class TranslateHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get inputText => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: "idx_open_records", columns: {#word, #createdAt})
class OpenRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: "idx_flashcards_due", columns: {#due})
class Flashcards extends Table {
  TextColumn get word => text()();
  IntColumn get state => integer()();
  IntColumn get step => integer().nullable()();
  RealColumn get stability => real().nullable()();
  RealColumn get difficulty => real().nullable()();
  DateTimeColumn get due => dateTime()();
  DateTimeColumn get lastReview => dateTime().nullable()();
  DateTimeColumn get introducedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {word};
}

@TableIndex(name: "idx_flashcard_review_logs_word", columns: {#word})
@TableIndex(
  name: "idx_flashcard_review_logs_reviewed_at",
  columns: {#reviewedAt},
)
class FlashcardReviewLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  IntColumn get rating => integer()();
  DateTimeColumn get reviewedAt => dateTime()();
  IntColumn get durationMs => integer().nullable()();
}

/// Wrong answers from vocabulary quizzes, for mistake review.
@TableIndex(name: "idx_quiz_mistakes_word", columns: {#word})
class QuizMistakes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text()();
  // Question type: "choice", "spelling" or "cloze".
  TextColumn get questionType => text()();
  TextColumn get question => text()();
  TextColumn get correctAnswer => text()();
  TextColumn get userAnswer => text().nullable()();
  // JSON-encoded option list for choice/cloze questions, so mistake
  // review can rebuild the original question offline instead of
  // asking the AI to regenerate one. Null for spelling questions
  // and for rows written before schema v24.
  TextColumn get options => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// One user-authored article in a personal dictionary (schema v26).
///
/// [body] is the Markdown source, converted to HTML at read time; [source]
/// records where the article came from when it was imported (e.g. a DSL
/// file name), and is null for hand-written entries.
///
/// [dictionaryId] references [DictionaryList] with cascade delete (schema
/// v27): deleting the list row — however it happens — removes the
/// dictionary's articles instead of leaving orphan rows behind. The index
/// on [dictionaryId] keeps the per-dictionary article queries and the
/// cascade itself from scanning the whole table.
@TableIndex(name: "idx_personal_articles_dictionary", columns: {#dictionaryId})
class PersonalArticles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dictionaryId =>
      integer().references(DictionaryList, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get source => text().nullable()();
}

/// One headword filing an article of a personal dictionary (schema v26).
///
/// Several headwords (aliases) may share one [articleId]. [headword] keeps
/// the spelling the user typed for display; [normalizedHeadword] is the
/// NFC + lower-cased form ([normalizePersonalHeadword]) used for exact and
/// prefix lookup, so the same word in another case or composition form
/// still resolves. [dictionaryId] is denormalized so a lookup never has to
/// join back to the article first.
///
/// Both foreign keys cascade (schema v27): deleting the dictionary row
/// removes its headwords, and deleting an article removes the headwords
/// filed under it. No extra single-column index on [dictionaryId] is
/// needed: the composite `idx_personal_headwords_dict_normalized` index
/// already has [dictionaryId] as its leftmost column, so
/// dictionary-scoped lookups and deletes use it.
@TableIndex(
  name: "idx_personal_headwords_dict_normalized",
  columns: {#dictionaryId, #normalizedHeadword},
  unique: true,
)
@TableIndex(name: "idx_personal_headwords_article", columns: {#articleId})
class PersonalHeadwords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dictionaryId =>
      integer().references(DictionaryList, #id, onDelete: KeyAction.cascade)();
  IntColumn get articleId => integer().references(
    PersonalArticles,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get headword => text()();
  TextColumn get normalizedHeadword => text()();
}

/// Installed resource tracked by the in-app Store (schema v30).
class StoreInstalledItems extends Table {
  TextColumn get itemId => text()();
  TextColumn get type => text()();
  TextColumn get format => text()();
  TextColumn get installDir => text()();
  TextColumn get remoteVersion => text().nullable()();
  DateTimeColumn get installedAt => dateTime()();
  TextColumn get targetIds => text().withDefault(const Constant(""))();

  @override
  Set<Column<Object>> get primaryKey => {itemId};
}
