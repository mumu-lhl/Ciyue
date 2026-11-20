import "dart:typed_data";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entries_page.dart";
import "package:ciyue/ui/pages/settings/personal_dictionary/personal_dictionary_entry_editor_page.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

/// In-memory fake of [PersonalDictionaryService]: no Drift, no DAO calls,
/// so it is safe inside testWidgets bodies.
class FakePersonalDictionaryService implements PersonalDictionaryService {
  FakePersonalDictionaryService(Map<int, List<PersonalEntry>> entries)
    : _entries = {for (final e in entries.entries) e.key: List.of(e.value)};

  final Map<int, List<PersonalEntry>> _entries;
  final created = <({int dictionaryId, List<String> headwords, String body})>[];
  final updated = <({int articleId, List<String> headwords, String body})>[];
  final deletedArticleIds = <int>[];
  String? lastQuery;
  var _nextArticleId = 100;

  List<PersonalEntry> entriesOf(int dictionaryId) =>
      List.unmodifiable(_entries[dictionaryId] ?? const []);

  @override
  AppDatabase get db => throw UnimplementedError("Fake has no database");

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
  }) async => null;

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
    lastQuery = query;
    final entries = entriesOf(dictionaryId);
    if (query == null || query.isEmpty) return entries;
    final prefix = query.toLowerCase();
    return entries
        .where(
          (e) => e.headwords.any((h) => h.toLowerCase().startsWith(prefix)),
        )
        .toList();
  }

  @override
  Future<int> entryCount(int dictionaryId) async =>
      entriesOf(dictionaryId).length;

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
    deletedArticleIds.add(articleId);
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

PersonalEntry entry(int articleId, List<String> headwords, String body) =>
    PersonalEntry(
      articleId: articleId,
      dictionaryId: 1,
      headwords: headwords,
      body: body,
      updatedAt: DateTime(2026, 11, 18),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePersonalDictionaryService fake;

  setUp(() {
    fake = FakePersonalDictionaryService({
      1: [
        entry(1, ["apple"], "A round fruit."),
        entry(2, ["application", "app"], "A computer program."),
        entry(3, ["banana"], "A yellow fruit."),
      ],
    });
  });

  Future<void> pumpPage(WidgetTester tester, {int dictionaryId = 1}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: PersonalDictionaryEntriesPage(
            dictionaryId: dictionaryId,
            title: "My words",
            service: fake,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpRouterPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: "/settings/personal_dictionary/1",
      routes: [
        GoRoute(
          path: "/settings/personal_dictionary/:dictionaryId",
          builder: (context, state) => PersonalDictionaryEntriesPage(
            dictionaryId: int.parse(state.pathParameters["dictionaryId"]!),
            title: "My words",
            service: fake,
          ),
        ),
        GoRoute(
          path: "/settings/personal_dictionary/:dictionaryId/entry/new",
          builder: (context, state) => PersonalDictionaryEntryEditorPage(
            dictionaryId: int.parse(state.pathParameters["dictionaryId"]!),
            service: fake,
          ),
        ),
        GoRoute(
          path: "/settings/personal_dictionary/:dictionaryId/entry/:articleId",
          builder: (context, state) => PersonalDictionaryEntryEditorPage(
            dictionaryId: int.parse(state.pathParameters["dictionaryId"]!),
            articleId: int.parse(state.pathParameters["articleId"]!),
            service: fake,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("renders entries with headwords and body preview", (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text("My words"), findsOneWidget);
    expect(find.text("apple"), findsOneWidget);
    expect(find.text("A round fruit."), findsOneWidget);
    expect(find.text("application, app"), findsOneWidget);
    expect(find.text("A computer program."), findsOneWidget);
    expect(find.text("banana"), findsOneWidget);
    expect(find.text("No entries yet"), findsNothing);
  });

  testWidgets("search filter narrows the list by headword prefix", (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), "app");
    // The filter is debounced 300ms.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(fake.lastQuery, "app");
    expect(find.text("apple"), findsOneWidget);
    expect(find.text("application, app"), findsOneWidget);
    expect(find.text("banana"), findsNothing);
  });

  testWidgets("empty dictionary shows the empty state", (tester) async {
    fake = FakePersonalDictionaryService({1: []});
    await pumpPage(tester);

    expect(find.text("No entries yet"), findsOneWidget);
    expect(find.text("apple"), findsNothing);
  });

  testWidgets("tapping an entry opens the editor for that entry", (
    tester,
  ) async {
    await pumpRouterPage(tester);

    await tester.tap(find.text("banana"));
    await tester.pumpAndSettle();

    expect(find.text("Edit entry"), findsOneWidget);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.first.controller?.text, "banana");
    expect(fields.last.controller?.text, "A yellow fruit.");
  });

  testWidgets("FAB opens the editor for a new entry", (tester) async {
    await pumpRouterPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text("New entry"), findsOneWidget);
  });

  testWidgets("deleting an entry asks for confirmation, then removes it", (
    tester,
  ) async {
    await pumpPage(tester);

    final tile = find.ancestor(
      of: find.text("banana"),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Delete"), findsOneWidget);

    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();

    expect(fake.deletedArticleIds, [3]);
    expect(find.text("banana"), findsNothing);
    expect(find.text("apple"), findsOneWidget);
    expect(find.text("Entry deleted"), findsOneWidget);
    // Let the toast's auto-dismiss timer fire; a pending timer fails the
    // test at teardown.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("saving a new entry from the editor adds it to the list", (
    tester,
  ) async {
    await pumpRouterPage(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, "Headwords"),
      "cherry",
    );
    await tester.enterText(
      find.widgetWithText(TextField, "Definition (Markdown)"),
      "A red fruit.",
    );
    await tester.tap(find.text("Save"));
    await tester.pumpAndSettle();

    expect(fake.created, hasLength(1));
    expect(fake.created.single.headwords, ["cherry"]);
    expect(fake.created.single.body, "A red fruit.");
    // The editor popped back to the list, which reloaded.
    expect(find.text("My words"), findsOneWidget);
    expect(find.text("cherry"), findsOneWidget);
    expect(find.text("Entry saved"), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("deleting an entry confirms with the delete-entry wording", (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text("Delete this entry?"), findsOneWidget);
    expect(find.text("apple"), findsWidgets);
  });

  testWidgets("a missing dictionary shows the not-found page", (tester) async {
    await pumpPage(tester, dictionaryId: 999);

    expect(
      find.text("This personal dictionary no longer exists"),
      findsOneWidget,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text("My words"), findsNothing);
  });
}
