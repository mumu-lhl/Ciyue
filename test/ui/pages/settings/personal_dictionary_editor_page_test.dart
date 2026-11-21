import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entry_editor_page.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

/// In-memory fake of [PersonalDictionaryService]: no Drift, no DAO calls,
/// so it is safe inside testWidgets bodies.
class FakePersonalDictionaryService implements PersonalDictionaryService {
  FakePersonalDictionaryService(Map<int, List<PersonalEntry>> entries)
    : _entries = {for (final e in entries.entries) e.key: List.of(e.value)};

  final Map<int, List<PersonalEntry>> _entries;
  final created = <({int dictionaryId, List<String> headwords, String body})>[];
  final updated = <({int articleId, List<String> headwords, String body})>[];
  var _nextArticleId = 100;

  /// Delay applied to listEntries, so the loading state can be observed
  /// instead of completing before the first frame.
  Duration listEntriesDelay = Duration.zero;

  @override
  AppDatabase get db => throw UnimplementedError("Fake has no database");

  @override
  Future<void> Function(int)? get onDictionaryDeleted => null;

  @override
  Future<bool> dictionaryExists(int id) async => _entries.containsKey(id);

  @override
  Future<bool> dictionaryNameExists(String name, {int? exceptId}) async =>
      false;

  @override
  Future<String?> findConflictingHeadword(
    int dictionaryId,
    List<String> headwords, {
    int? exceptArticleId,
  }) async {
    final normalized = headwords.map((h) => h.trim().toLowerCase()).toSet();
    for (final entry in _entries[dictionaryId] ?? const []) {
      if (entry.articleId == exceptArticleId) continue;
      for (final headword in entry.headwords) {
        if (normalized.contains(headword.toLowerCase())) return headword;
      }
    }
    return null;
  }

  @override
  Future<int> createDictionary(String name) async => 1;

  @override
  Future<void> renameDictionary(int id, String name) async {}

  @override
  Future<void> deleteDictionary(int id) async {
    _entries.remove(id);
  }

  @override
  Future<List<PersonalEntry>> listEntries(
    int dictionaryId, {
    String? query,
  }) async {
    if (listEntriesDelay > Duration.zero) {
      await Future.delayed(listEntriesDelay);
    }
    return List.unmodifiable(_entries[dictionaryId] ?? const []);
  }

  @override
  Future<int> entryCount(int dictionaryId) async =>
      (_entries[dictionaryId] ?? const []).length;

  @override
  Future<int> createEntry(
    int dictionaryId, {
    required List<String> headwords,
    required String body,
  }) async {
    final id = _nextArticleId++;
    created.add((dictionaryId: dictionaryId, headwords: headwords, body: body));
    (_entries[dictionaryId] ??= []).add(
      PersonalEntry(
        articleId: id,
        dictionaryId: dictionaryId,
        headwords: headwords,
        body: body,
        updatedAt: DateTime(2026, 11, 18),
      ),
    );
    return id;
  }

  @override
  Future<void> updateEntry(
    int articleId, {
    required List<String> headwords,
    required String body,
  }) async {
    updated.add((articleId: articleId, headwords: headwords, body: body));
    for (final entries in _entries.values) {
      final index = entries.indexWhere((e) => e.articleId == articleId);
      if (index != -1) {
        entries[index] = PersonalEntry(
          articleId: articleId,
          dictionaryId: entries[index].dictionaryId,
          headwords: headwords,
          body: body,
          updatedAt: DateTime(2026, 11, 18),
        );
      }
    }
  }

  @override
  Future<void> deleteEntry(int articleId) async {
    for (final entries in _entries.values) {
      entries.removeWhere((e) => e.articleId == articleId);
    }
  }

  @override
  Future<String> exportDsl(int dictionaryId) async => "# test\n";

  @override
  Future<PersonalDslImportResult> importDsl(
    int dictionaryId,
    String content,
  ) async => const PersonalDslImportResult(imported: 0);

  @override
  Future<PersonalDslImportResult> importDslBytes(
    int dictionaryId,
    Uint8List bytes,
    String filename,
  ) async => const PersonalDslImportResult(imported: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePersonalDictionaryService fake;

  setUp(() {
    fake = FakePersonalDictionaryService({
      1: [
        PersonalEntry(
          articleId: 7,
          dictionaryId: 1,
          headwords: ["apple", "Apple"],
          body: "A round fruit.",
          updatedAt: DateTime(2026, 11, 18),
        ),
      ],
    });
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    int? articleId,
    int dictionaryId = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: PersonalDictionaryEntryEditorPage(
            dictionaryId: dictionaryId,
            articleId: articleId,
            service: fake,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Pumps the editor on top of a home page, so the system back gesture
  /// has somewhere to go back to.
  Future<void> pumpEditorOnStack(
    WidgetTester tester, {
    int? articleId,
    int dictionaryId = 1,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PersonalDictionaryEntryEditorPage(
                        dictionaryId: dictionaryId,
                        articleId: articleId,
                        service: fake,
                      ),
                    ),
                  );
                },
                child: const Text("open"),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
  }

  TextField headwordsField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first);

  TextField bodyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).last);

  testWidgets("saving a new entry calls createEntry with parsed headwords", (
    tester,
  ) async {
    await pumpEditor(tester);

    expect(find.text("New entry"), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).first,
      "cherry, Cherry\ncherries",
    );
    await tester.enterText(find.byType(TextField).last, "A red fruit.");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, hasLength(1));
    expect(fake.created.single.dictionaryId, 1);
    expect(fake.created.single.headwords, ["cherry", "Cherry", "cherries"]);
    expect(fake.created.single.body, "A red fruit.");
    expect(find.text("Entry saved"), findsOneWidget);
    // Let the toast's auto-dismiss timer fire; a pending timer fails the
    // test at teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("empty headwords shows a validation error and does not save", (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).last, "Some body.");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, isEmpty);
    expect(find.text("Please enter at least one headword"), findsOneWidget);
    expect(find.text("Please enter a definition"), findsNothing);
  });

  testWidgets("empty body shows a validation error and does not save", (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, "cherry");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, isEmpty);
    expect(find.text("Please enter a definition"), findsOneWidget);
    expect(find.text("Please enter at least one headword"), findsNothing);
  });

  testWidgets("both fields empty shows both validation errors", (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, isEmpty);
    expect(find.text("Please enter at least one headword"), findsOneWidget);
    expect(find.text("Please enter a definition"), findsOneWidget);
  });

  testWidgets("edit mode prefills the fields and save calls updateEntry", (
    tester,
  ) async {
    await pumpEditor(tester, articleId: 7);

    expect(find.text("Edit entry"), findsOneWidget);
    expect(headwordsField(tester).controller?.text, "apple, Apple");
    expect(bodyField(tester).controller?.text, "A round fruit.");

    await tester.enterText(find.byType(TextField).last, "A round fruit!");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, isEmpty);
    expect(fake.updated, hasLength(1));
    expect(fake.updated.single.articleId, 7);
    expect(fake.updated.single.headwords, ["apple", "Apple"]);
    expect(fake.updated.single.body, "A round fruit!");
    expect(find.text("Entry saved"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("preview toggle renders the body as Markdown", (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, "cherry");
    await tester.enterText(
      find.byType(TextField).last,
      "# Cherry\nA red fruit.",
    );
    await tester.tap(find.byIcon(Icons.preview_outlined));
    await tester.pumpAndSettle();

    // The editor fields are gone; the Markdown heading is rendered.
    // GptMarkdown builds the heading as a Text.rich with extra spans, so
    // an exact find.text does not match — match the contained text.
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining("Cherry"), findsOneWidget);
    expect(find.textContaining("A red fruit."), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets("a duplicate headword shows an inline error and does not save", (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, "Apple");
    await tester.enterText(find.byType(TextField).last, "Another fruit.");
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, isEmpty);
    expect(
      find.text("Headword “apple” already exists in this dictionary"),
      findsOneWidget,
    );
    // No raw exception toast: the failure stays on the field.
    expect(find.textContaining("Bad state"), findsNothing);
  });

  testWidgets(
    "editing an entry to another entry's headword is rejected inline",
    (tester) async {
      fake = FakePersonalDictionaryService({
        1: [
          PersonalEntry(
            articleId: 7,
            dictionaryId: 1,
            headwords: ["apple"],
            body: "A round fruit.",
            updatedAt: DateTime(2026, 11, 18),
          ),
          PersonalEntry(
            articleId: 8,
            dictionaryId: 1,
            headwords: ["banana"],
            body: "A yellow fruit.",
            updatedAt: DateTime(2026, 11, 18),
          ),
        ],
      });
      await pumpEditor(tester, articleId: 7);

      await tester.enterText(find.byType(TextField).first, "banana");
      await tester.tap(find.text("Save"));
      await tester.pumpAndSettle();

      expect(fake.updated, isEmpty);
      expect(
        find.text("Headword “banana” already exists in this dictionary"),
        findsOneWidget,
      );
    },
  );

  testWidgets("going back with unsaved changes asks before discarding", (
    tester,
  ) async {
    await pumpEditorOnStack(tester);

    await tester.enterText(find.byType(TextField).first, "cherry");
    // Let the field listener's rebuild land, so the PopScope's canPop
    // reflects the edit before the back press (as a real frame would).
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The editor is still there, behind the discard prompt.
    expect(find.text("Discard unsaved changes?"), findsOneWidget);
    expect(find.text("New entry"), findsOneWidget);

    await tester.tap(find.text("Discard"));
    await tester.pumpAndSettle();

    expect(find.text("New entry"), findsNothing);
    expect(find.text("open"), findsOneWidget);
    expect(fake.created, isEmpty);
  });

  testWidgets("going back without changes pops straight away", (tester) async {
    await pumpEditorOnStack(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text("Discard unsaved changes?"), findsNothing);
    expect(find.text("New entry"), findsNothing);
    expect(find.text("open"), findsOneWidget);
  });

  testWidgets("going back after editing keeps the draft until discarded", (
    tester,
  ) async {
    await pumpEditorOnStack(tester, articleId: 7);

    await tester.enterText(find.byType(TextField).last, "A round fruit!");
    // Let the field listener's rebuild land, so the PopScope's canPop
    // reflects the edit before the back press (as a real frame would).
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text("Discard unsaved changes?"), findsOneWidget);
    // Staying keeps the edited text.
    await tester.tap(find.text("Cancel"));
    await tester.pumpAndSettle();

    expect(find.text("Edit entry"), findsOneWidget);
    expect(bodyField(tester).controller?.text, "A round fruit!");
  });

  testWidgets("a missing dictionary shows the not-found page", (tester) async {
    await pumpEditor(tester, dictionaryId: 999);

    expect(
      find.text("This personal dictionary no longer exists"),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  test("parsePersonalHeadwords splits on commas and new lines, trims, "
      "dedupes", () {
    expect(parsePersonalHeadwords(" apple,Apple\napple ,\n banana "), [
      "apple",
      "Apple",
      "banana",
    ]);
    expect(parsePersonalHeadwords(" , \n "), isEmpty);
  });

  test("parsePersonalHeadwords also splits on semicolons", () {
    expect(parsePersonalHeadwords("apple; banana；cherry"), [
      "apple",
      "banana",
      "cherry",
    ]);
    expect(parsePersonalHeadwords("apple;; banana；；cherry"), [
      "apple",
      "banana",
      "cherry",
    ]);
    expect(parsePersonalHeadwords("apple; ,；\nbanana"), ["apple", "banana"]);
  });

  testWidgets("preview with an empty body shows an empty-preview hint", (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.tap(find.byIcon(Icons.preview_outlined));
    await tester.pumpAndSettle();

    expect(
      find.text("Nothing to preview yet — write a definition first."),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets("preview with a body renders it and the hint is gone", (
    tester,
  ) async {
    await pumpEditor(tester);

    await tester.enterText(find.byType(TextField).first, "cherry");
    await tester.enterText(find.byType(TextField).last, "A red fruit.");
    await tester.tap(find.byIcon(Icons.preview_outlined));
    await tester.pumpAndSettle();

    expect(
      find.text("Nothing to preview yet — write a definition first."),
      findsNothing,
    );
    expect(find.textContaining("A red fruit."), findsOneWidget);
  });

  testWidgets("the preview toggle is disabled while the entry loads", (
    tester,
  ) async {
    fake.listEntriesDelay = const Duration(seconds: 5);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: PersonalDictionaryEntryEditorPage(
            dictionaryId: 1,
            articleId: 7,
            service: fake,
          ),
        ),
      ),
    );
    // One frame: the entry load is still pending behind the delay.
    await tester.pump();

    final toggle = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.preview_outlined),
    );
    expect(toggle.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Tapping the disabled toggle does nothing.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.preview_outlined));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text("Edit entry"), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
