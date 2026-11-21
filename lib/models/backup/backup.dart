import "dart:convert";

import "package:ciyue/database/app/app.dart";

/// One personal dictionary in a backup: its title plus every article with
/// its headwords.
///
/// Ids are deliberately not stored: import assigns fresh ids and remaps
/// each article's headwords onto the new article id, so a backup restores
/// cleanly into a database where those ids are already taken.
class PersonalDictionaryBackup {
  final String title;
  final List<PersonalArticleBackup> articles;

  const PersonalDictionaryBackup({
    required this.title,
    this.articles = const [],
  });

  factory PersonalDictionaryBackup.fromJson(Map<String, dynamic> json) {
    return PersonalDictionaryBackup(
      title: json["title"] as String? ?? "",
      articles:
          (json["articles"] as List<dynamic>?)
              ?.map(
                (e) =>
                    PersonalArticleBackup.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    "title": title,
    "articles": articles.map((e) => e.toJson()).toList(),
  };
}

/// One article of a personal dictionary in a backup: its headwords and its
/// Markdown body, plus the import source when it had one.
class PersonalArticleBackup {
  final List<String> headwords;
  final String body;
  final String? source;

  const PersonalArticleBackup({
    required this.headwords,
    required this.body,
    this.source,
  });

  factory PersonalArticleBackup.fromJson(Map<String, dynamic> json) {
    return PersonalArticleBackup(
      headwords: (json["headwords"] as List<dynamic>?)?.cast<String>() ?? [],
      body: json["body"] as String? ?? "",
      source: json["source"] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    "headwords": headwords,
    "body": body,
    if (source != null) "source": source,
  };
}

class BackupData {
  static const currentVersion = 2;

  final int version;
  final List<WordbookData> wordbookWords;
  final List<WordbookTag> wordbookTags;
  final List<String> history;
  final List<WritingCheckHistoryData> writingCheckHistory;
  final List<TranslateHistoryData> translateHistory;
  final List<Flashcard> flashcards;
  final List<FlashcardReviewLog> flashcardReviewLogs;

  /// Personal dictionaries. A personal dictionary's only copy lives in
  /// the app database, so without this a backup/restore silently drops
  /// every user-authored entry (P1-2).
  final List<PersonalDictionaryBackup> personalDictionaries;

  BackupData({
    required this.version,
    required this.wordbookWords,
    required this.wordbookTags,
    this.history = const [],
    this.writingCheckHistory = const [],
    this.translateHistory = const [],
    this.flashcards = const [],
    this.flashcardReviewLogs = const [],
    this.personalDictionaries = const [],
  });

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      version: json["version"] as int,
      wordbookWords: (json["wordbookWords"] as List<dynamic>)
          .map((e) => WordbookData.fromJson(e as Map<String, dynamic>))
          .toList(),
      wordbookTags: (json["wordbookTags"] as List<dynamic>)
          .map((e) => WordbookTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      history: (json["history"] as List<dynamic>?)?.cast<String>() ?? [],
      writingCheckHistory:
          (json["writingCheckHistory"] as List<dynamic>?)
              ?.map(
                (e) =>
                    WritingCheckHistoryData.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      translateHistory:
          (json["translateHistory"] as List<dynamic>?)
              ?.map(
                (e) => TranslateHistoryData.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      flashcards:
          (json["flashcards"] as List<dynamic>?)
              ?.map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      flashcardReviewLogs:
          (json["flashcardReviewLogs"] as List<dynamic>?)
              ?.map(
                (e) => FlashcardReviewLog.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      personalDictionaries:
          (json["personalDictionaries"] as List<dynamic>?)
              ?.map(
                (e) => PersonalDictionaryBackup.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
    );
  }

  String toJson() {
    return jsonEncode({
      "version": version,
      "wordbookWords": wordbookWords.map((e) => e.toJson()).toList(),
      "wordbookTags": wordbookTags.map((e) => e.toJson()).toList(),
      "history": history,
      "writingCheckHistory": writingCheckHistory
          .map((e) => e.toJson())
          .toList(),
      "translateHistory": translateHistory.map((e) => e.toJson()).toList(),
      "flashcards": flashcards.map((e) => e.toJson()).toList(),
      "flashcardReviewLogs": flashcardReviewLogs
          .map((e) => e.toJson())
          .toList(),
      "personalDictionaries": personalDictionaries
          .map((e) => e.toJson())
          .toList(),
    });
  }
}
