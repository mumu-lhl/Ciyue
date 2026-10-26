import "package:ciyue/database/app/app.dart";
import "package:ciyue/viewModels/home.dart";
import "package:dict_reader/dict_reader.dart" show normalizeKey;
import "package:flutter_test/flutter_test.dart";

void main() {
  group("HistoryModel.mergedHistory", () {
    test("one word typed two ways leaves a single row", () {
      // What `addHistory` does: both spellings are stored as NFC, so the second
      // search has to replace the first row rather than shadow it.
      final first = HistoryData(id: 1, word: normalizeKey("ingle\u0301s"));
      final afterFirst = HistoryModel.mergedHistory(first, const []);

      final second = HistoryData(id: 2, word: normalizeKey("ingl\u00E9s"));
      final afterSecond = HistoryModel.mergedHistory(second, afterFirst);

      expect(afterSecond, hasLength(1));
      expect(afterSecond.single.word, "ingl\u00E9s");
      expect(afterSecond.single.id, 2);
    });

    test("a raw spelling that differs from the stored one is not kept", () {
      // Regression: the list used to compare the raw input against the stored
      // rows, so the NFD query added a second entry next to the NFC one.
      final existing = [HistoryData(id: 7, word: normalizeKey("ingl\u00E9s"))];
      final raw = HistoryData(id: 8, word: normalizeKey("ingle\u0301s"));

      final merged = HistoryModel.mergedHistory(raw, existing);

      expect(merged, hasLength(1));
      expect(merged.single.word, "ingl\u00E9s");
    });

    test("keeps unrelated rows, newest first", () {
      final existing = [
        HistoryData(id: 3, word: "cafe\u0301"),
        HistoryData(id: 2, word: "apple"),
      ];

      final merged = HistoryModel.mergedHistory(
        HistoryData(id: 4, word: "banana"),
        existing,
      );

      expect(merged.map((row) => row.word), ["banana", "cafe\u0301", "apple"]);
      expect(merged.map((row) => row.id), [4, 3, 2]);
    });
  });
}
