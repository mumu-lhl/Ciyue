import "dart:convert";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/backup/backup.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("BackupData", () {
    test("toJson and fromJson should work correctly", () {
      final now = DateTime.now();
      // Assuming WordbookData matches Wordbook table structure
      final words = [
        WordbookData(
          createdAt: now,
          tag: 1,
          word: "test",
        )
      ];
      final tags = [
        const WordbookTag(id: 1, tag: "tag1"),
      ];
      final history = ["history1", "history2"];
      final writingCheckHistory = [
        WritingCheckHistoryData(
          id: 1,
          inputText: "input",
          outputText: "output",
          createdAt: now,
        )
      ];
      final translateHistory = [
        TranslateHistoryData(
          id: 1,
          inputText: "input",
          createdAt: now,
        )
      ];
      final flashcards = [
        Flashcard(
          word: "test",
          state: 1,
          step: null,
          stability: 3,
          difficulty: 4,
          due: now,
          lastReview: now,
          introducedAt: now,
        ),
      ];
      final flashcardReviewLogs = [
        FlashcardReviewLog(
          id: 1,
          word: "test",
          rating: 2,
          reviewedAt: now,
          durationMs: 500,
        ),
      ];

      final backupData = BackupData(
        version: 1,
        wordbookWords: words,
        wordbookTags: tags,
        history: history,
        writingCheckHistory: writingCheckHistory,
        translateHistory: translateHistory,
        flashcards: flashcards,
        flashcardReviewLogs: flashcardReviewLogs,
      );

      final jsonString = backupData.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded["version"], 1);
      expect(decoded["wordbookWords"].length, 1);
      expect(decoded["wordbookTags"].length, 1);
      expect(decoded["history"].length, 2);
      expect(decoded["writingCheckHistory"].length, 1);
      expect(decoded["translateHistory"].length, 1);
      expect(decoded["flashcards"].length, 1);
      expect(decoded["flashcardReviewLogs"].length, 1);

      // Verify word data
      final wordJson = decoded["wordbookWords"][0];
      expect(wordJson["word"], "test");
      expect(wordJson["tag"], 1);
      // Drift usually serializes DateTime as millisecondsSinceEpoch or string depending on config.
      // We'll rely on fromJson to check consistency.

      final importedData = BackupData.fromJson(decoded);
      expect(importedData.version, 1);
      expect(importedData.wordbookWords.first.word, "test");
      expect(importedData.wordbookWords.first.tag, 1);
      // Compare dates with tolerance or exact depending on precision loss
      // drift default JSON for DateTime is unix timestamp (int) or string
      expect(importedData.wordbookWords.first.createdAt.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);

      expect(importedData.wordbookTags.first.tag, "tag1");
      expect(importedData.history, equals(history));
      expect(importedData.writingCheckHistory.first.inputText, "input");
      expect(importedData.translateHistory.first.inputText, "input");
      expect(importedData.flashcards.single.word, "test");
      expect(importedData.flashcardReviewLogs.single.rating, 2);
    });

    test("old backup defaults flashcard data to empty lists", () {
      final imported = BackupData.fromJson({
        "version": 1,
        "wordbookWords": <Object>[],
        "wordbookTags": <Object>[],
      });

      expect(imported.flashcards, isEmpty);
      expect(imported.flashcardReviewLogs, isEmpty);
    });
  });
}
