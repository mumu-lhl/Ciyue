import "dart:typed_data";

import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

/// Records what the name dialog asks the dictionary manager to do, without
/// touching the real [dictManager]: the dialog's wiring is the part under
/// test, not the manager's own load.
class SpyDictManagerModel extends DictManagerModel {
  final added = <({int id, String path})>[];
  var updateDictIdsCalls = 0;

  @override
  Future<void> add(int id, String path) async {
    added.add((id: id, path: path));
  }

  @override
  Future<void> updateDictIds() async {
    updateDictIdsCalls++;
  }
}

class SpyManageDictionariesModel extends ManageDictionariesModel {
  var updateCalls = 0;

  @override
  void update() {
    updateCalls++;
  }
}

/// Fake service: only create/rename matter to the name dialog; the rest
/// is never called from it.
class FakePersonalDictionaryService implements PersonalDictionaryService {
  final createdNames = <String>[];
  final renamed = <({int id, String name})>[];

  @override
  AppDatabase get db => throw UnimplementedError("Fake has no database");

  @override
  Future<int> createDictionary(String name) async {
    createdNames.add(name);
    return 7;
  }

  @override
  Future<void> renameDictionary(int id, String name) async {
    renamed.add((id: id, name: name));
  }

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
  ) async => const PersonalDslImportResult(imported: 0, warnings: []);

  @override
  Future<PersonalDslImportResult> importDslBytes(
    int dictionaryId,
    Uint8List bytes,
    String filename,
  ) async => const PersonalDslImportResult(imported: 0, warnings: []);
}

void main() {
  late FakePersonalDictionaryService fake;
  late SpyDictManagerModel dictModel;
  late SpyManageDictionariesModel manageModel;

  Future<void> pumpDialog(
    WidgetTester tester, {
    DictionaryListData? dictionary,
  }) async {
    fake = FakePersonalDictionaryService();
    dictModel = SpyDictManagerModel();
    manageModel = SpyManageDictionariesModel();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalDictionaryServiceProvider.overrideWithValue(fake),
          dictManagerModelProvider.overrideWith((ref) => dictModel),
          manageDictionariesModelProvider.overrideWith((ref) => manageModel),
        ],
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () =>
                  showPersonalDictionaryNameDialog(context, dictionary),
              child: const Text("open"),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("open"));
    await tester.pumpAndSettle();
  }

  Future<void> confirmName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    // The success toast leaves a 2s auto-dismiss timer behind.
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets("creating a dictionary loads it into the manager", (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text("New personal dictionary"), findsOneWidget);

    await confirmName(tester, "My Words");

    expect(fake.createdNames, ["My Words"]);
    // This is the wiring the word lookup depends on: without the add,
    // the dictionary exists in the list but no query ever sees it.
    expect(dictModel.added, [(id: 7, path: "personal:7")]);
    expect(dictModel.updateDictIdsCalls, 1);
    expect(manageModel.updateCalls, 1);
    expect(find.text("New personal dictionary"), findsNothing);
  });

  testWidgets("renaming does not reload the dictionary", (tester) async {
    const existing = DictionaryListData(
      id: 7,
      path: "personal:7",
      title: "Old",
      type: 4,
    );
    await pumpDialog(tester, dictionary: existing);

    expect(find.text("Rename"), findsOneWidget);

    await confirmName(tester, "New Name");

    expect(fake.renamed, [(id: 7, name: "New Name")]);
    expect(dictModel.added, isEmpty);
    expect(dictModel.updateDictIdsCalls, 0);
    expect(manageModel.updateCalls, 1);
    expect(find.text("Rename"), findsNothing);
  });

  testWidgets("an empty name is rejected and the dialog stays open", (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(fake.createdNames, isEmpty);
    expect(dictModel.added, isEmpty);
    expect(dictModel.updateDictIdsCalls, 0);
    expect(find.text("New personal dictionary"), findsOneWidget);
  });
}
