import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_io.dart";
import "package:flutter_test/flutter_test.dart";

/// The empty import/export decisions are pure functions over the service
/// result, so they are covered here instead of through the file pickers
/// (which have no widget-test harness).
void main() {
  group("isEmptyPersonalDictionaryImport", () {
    test("an empty input file is an empty import", () {
      expect(
        isEmptyPersonalDictionaryImport(
          const PersonalDslImportResult(imported: 0, isEmptyInput: true),
        ),
        isTrue,
      );
    });

    test("a whitespace-only input is an empty import even with warnings", () {
      // The parser records an orphan-body warning for the space-only
      // lines, but the file still had no content: the empty-file message
      // wins, and the warnings dialog still shows afterwards.
      expect(
        isEmptyPersonalDictionaryImport(
          const PersonalDslImportResult(
            imported: 0,
            isEmptyInput: true,
            warnings: [
              PersonalDslWarning(PersonalDslWarningKind.noBody, "apple"),
            ],
          ),
        ),
        isTrue,
      );
    });

    test("a successful import is not empty", () {
      expect(
        isEmptyPersonalDictionaryImport(
          const PersonalDslImportResult(imported: 3),
        ),
        isFalse,
      );
    });

    test("zero entries with warnings but real content is not empty", () {
      // The file had entries, they were all skipped: the warnings dialog
      // explains that, so the empty-file message must not claim otherwise.
      expect(
        isEmptyPersonalDictionaryImport(
          const PersonalDslImportResult(
            imported: 0,
            warnings: [
              PersonalDslWarning(PersonalDslWarningKind.noBody, "apple"),
            ],
          ),
        ),
        isFalse,
      );
    });

    test("a metadata-only file is not an empty file", () {
      // It has content (#NAME etc.) but zero entries: "Imported 0
      // entries" is the accurate message, not "the file is empty".
      expect(
        isEmptyPersonalDictionaryImport(
          const PersonalDslImportResult(imported: 0),
        ),
        isFalse,
      );
    });
  });

  group("isEmptyPersonalDictionaryExport", () {
    test("an empty document is an empty export", () {
      expect(isEmptyPersonalDictionaryExport(""), isTrue);
      expect(isEmptyPersonalDictionaryExport("  \n\t "), isTrue);
    });

    test("any entry content is not an empty export", () {
      expect(isEmptyPersonalDictionaryExport("apple\n\tA fruit.\n"), isFalse);
    });
  });
}
