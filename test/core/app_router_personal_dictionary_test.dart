import "dart:typed_data";

import "package:ciyue/core/app_router.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

/// Minimal fake: the router only builds the entries/editor pages, which
/// need [PersonalDictionaryService.dictionaryExists] and [listEntries].
class FakePersonalDictionaryService implements PersonalDictionaryService {
  @override
  AppDatabase get db => throw UnimplementedError("Fake has no database");

  @override
  Future<void> Function(int)? get onDictionaryDeleted => null;

  @override
  Future<bool> dictionaryExists(int id) async => id == 1;

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
  Future<void> deleteDictionary(int id) async {}

  @override
  Future<List<PersonalEntry>> listEntries(
    int dictionaryId, {
    String? query,
  }) async => const [];

  @override
  Future<int> entryCount(int dictionaryId) async => 0;

  @override
  Future<int> createEntry(
    int dictionaryId, {
    required List<String> headwords,
    required String body,
  }) async => 0;

  @override
  Future<void> updateEntry(
    int articleId, {
    required List<String> headwords,
    required String body,
  }) async {}

  @override
  Future<void> deleteEntry(int articleId) async {}

  @override
  Future<String> exportDsl(int dictionaryId) async => "";

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

  Future<void> pumpAt(WidgetTester tester, String location) async {
    // Navigate before the first build so the "/" home page is never built.
    router.go(location);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalDictionaryServiceProvider.overrideWithValue(
            FakePersonalDictionaryService(),
          ),
        ],
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

  testWidgets("a non-numeric dictionary id shows the not-found page", (
    tester,
  ) async {
    await pumpAt(tester, "/settings/personal_dictionary/abc");

    expect(
      find.text("This personal dictionary no longer exists"),
      findsOneWidget,
    );
  });

  testWidgets("a missing dictionary id shows the not-found page", (
    tester,
  ) async {
    await pumpAt(tester, "/settings/personal_dictionary/999");

    expect(
      find.text("This personal dictionary no longer exists"),
      findsOneWidget,
    );
    expect(find.text("No entries yet"), findsNothing);
  });

  testWidgets("an existing dictionary id still opens the entries page", (
    tester,
  ) async {
    await pumpAt(tester, "/settings/personal_dictionary/1");

    expect(find.text("Entries"), findsOneWidget);
    expect(find.text("No entries yet"), findsOneWidget);
  });

  testWidgets("a non-numeric article id shows the not-found page", (
    tester,
  ) async {
    await pumpAt(tester, "/settings/personal_dictionary/1/entry/xyz");

    expect(
      find.text("This personal dictionary no longer exists"),
      findsOneWidget,
    );
  });
}
