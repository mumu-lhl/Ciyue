import "package:ciyue/ui/core/word_display/entry_anchor.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("parseEntryLink", () {
    test("splits a headword from its anchor at a single hash", () {
      expect(
        parseEntryLink("tag#sumeru"),
        const EntryLinkTarget(word: "tag", anchor: "sumeru"),
      );
    });

    test("treats a doubled hash as a literal hash", () {
      expect(
        parseEntryLink("tag##sumeru"),
        const EntryLinkTarget(word: "tag#sumeru"),
      );
    });

    test("unescapes a doubled hash before the separator", () {
      expect(
        parseEntryLink("tag##sumeru#x"),
        const EntryLinkTarget(word: "tag#sumeru", anchor: "x"),
      );
    });

    test("reads a triple hash as an escaped hash plus a separator", () {
      expect(
        parseEntryLink("tag###sumeru"),
        const EntryLinkTarget(word: "tag#", anchor: "sumeru"),
      );
    });

    test("keeps a link that is only an anchor", () {
      expect(
        parseEntryLink("#foo"),
        const EntryLinkTarget(word: "", anchor: "foo"),
      );
    });

    test("reads a leading doubled hash as a literal hash headword", () {
      expect(parseEntryLink("##foo"), const EntryLinkTarget(word: "#foo"));
    });

    test("returns the headword alone when there is no separator", () {
      expect(parseEntryLink("tag"), const EntryLinkTarget(word: "tag"));
    });

    test("ignores a trailing separator", () {
      expect(parseEntryLink("tag#"), const EntryLinkTarget(word: "tag"));
    });

    test("unescapes several literal hashes", () {
      expect(parseEntryLink("a####b"), const EntryLinkTarget(word: "a##b"));
    });

    test("handles empty input", () {
      expect(parseEntryLink(""), const EntryLinkTarget(word: ""));
    });
  });
}
