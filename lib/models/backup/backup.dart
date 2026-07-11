import "dart:convert";

import "package:ciyue/database/app/app.dart";

class BackupData {
  final int version;
  final List<WordbookData> wordbookWords;
  final List<WordbookTag> wordbookTags;
  final List<String> history;
  final List<WritingCheckHistoryData> writingCheckHistory;
  final List<TranslateHistoryData> translateHistory;
  final List<Flashcard> flashcards;
  final List<FlashcardReviewLog> flashcardReviewLogs;

  BackupData({
    required this.version,
    required this.wordbookWords,
    required this.wordbookTags,
    this.history = const [],
    this.writingCheckHistory = const [],
    this.translateHistory = const [],
    this.flashcards = const [],
    this.flashcardReviewLogs = const [],
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
      writingCheckHistory: (json["writingCheckHistory"] as List<dynamic>?)
              ?.map((e) =>
                  WritingCheckHistoryData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      translateHistory: (json["translateHistory"] as List<dynamic>?)
              ?.map((e) =>
                  TranslateHistoryData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      flashcards: (json["flashcards"] as List<dynamic>?)
              ?.map((e) => Flashcard.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      flashcardReviewLogs: (json["flashcardReviewLogs"] as List<dynamic>?)
              ?.map(
                  (e) => FlashcardReviewLog.fromJson(e as Map<String, dynamic>))
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
      "writingCheckHistory":
          writingCheckHistory.map((e) => e.toJson()).toList(),
      "translateHistory": translateHistory.map((e) => e.toJson()).toList(),
      "flashcards": flashcards.map((e) => e.toJson()).toList(),
      "flashcardReviewLogs":
          flashcardReviewLogs.map((e) => e.toJson()).toList(),
    });
  }
}
