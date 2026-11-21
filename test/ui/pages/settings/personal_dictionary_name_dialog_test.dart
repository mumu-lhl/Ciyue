import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/personal_dictionary.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter/services.dart";
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
  var updateCalls = 0;

  @override
  Future<void> add(int id, String path) async {
    added.add((id: id, path: path));
  }

  @override
  Future<void> updateDictIds() async {
    updateDictIdsCalls++;
  }

  @override
  void update() {
    updateCalls++;
    super.update();
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
  FakePersonalDictionaryService({Set<String> existingNames = const {}})
    : existingNames = Set.of(existingNames);

  final Set<String> existingNames;
  final createdNames = <String>[];
  final renamed = <({int id, String name})>[];

  @override
  AppDatabase get db => throw UnimplementedError("Fake has no database");

  @override
  Future<void> Function(int)? get onDictionaryDeleted => null;

  @override
  Future<bool> dictionaryExists(int id) async => true;

  @override
  Future<bool> dictionaryNameExists(String name, {int? exceptId}) async =>
      existingNames.any(
        (existing) => existing.toLowerCase() == name.trim().toLowerCase(),
      );

  @override
  Future<String?> findConflictingHeadword(
    int dictionaryId,
    List<String> headwords, {
    int? exceptArticleId,
  }) async => null;

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
    Set<String> existingNames = const {},
  }) async {
    fake = FakePersonalDictionaryService(existingNames: existingNames);
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

  testWidgets("renaming syncs the loaded dictionary title", (tester) async {
    const existing = DictionaryListData(
      id: 7,
      path: "personal:7",
      title: "Old",
      type: 4,
    );
    // The dictionary is loaded in the manager, so its in-memory title is
    // what the word page tabs show.
    final loaded = PersonalDictionary(path: "personal:7")..title = "Old";
    dictManager.dicts[7] = loaded;
    addTearDown(() => dictManager.dicts.remove(7));
    await pumpDialog(tester, dictionary: existing);

    expect(find.text("Rename"), findsOneWidget);

    await confirmName(tester, "New Name");

    expect(fake.renamed, [(id: 7, name: "New Name")]);
    // The loaded dictionary's title follows the rename at once, and the
    // manager notifies so the word page tabs rebuild with the new name.
    expect(loaded.title, "New Name");
    expect(dictModel.updateCalls, 1);
    expect(dictModel.added, isEmpty);
    expect(dictModel.updateDictIdsCalls, 0);
    expect(manageModel.updateCalls, 1);
    expect(find.text("Rename"), findsNothing);
  });

  testWidgets("a duplicate name is rejected inline and the dialog stays open", (
    tester,
  ) async {
    await pumpDialog(tester, existingNames: {"My Words"});

    await tester.enterText(find.byType(TextField), "my words");
    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(fake.createdNames, isEmpty);
    expect(dictModel.added, isEmpty);
    expect(
      find.text("A personal dictionary with this name already exists"),
      findsOneWidget,
    );
    expect(find.text("New personal dictionary"), findsOneWidget);
  });

  // P2-28: the field does not truncate over-long input — the 101-character
  // name reaches submit and is rejected with the inline error, the same
  // as a duplicate name. Silently truncating would create a name the user
  // never typed.
  testWidgets("a name over the length limit is rejected inline", (
    tester,
  ) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField), "a" * 101);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      "a" * 101,
    );
    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(fake.createdNames, isEmpty);
    expect(
      find.text("Dictionary name must be at most 100 characters"),
      findsOneWidget,
    );
    expect(find.text("New personal dictionary"), findsOneWidget);
  });

  testWidgets("renaming to a duplicate name is rejected inline", (
    tester,
  ) async {
    const existing = DictionaryListData(
      id: 7,
      path: "personal:7",
      title: "Old",
      type: 4,
    );
    await pumpDialog(tester, dictionary: existing, existingNames: {"Taken"});

    await tester.enterText(find.byType(TextField), "taken");
    await tester.tap(find.text("Confirm"));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(fake.renamed, isEmpty);
    expect(
      find.text("A personal dictionary with this name already exists"),
      findsOneWidget,
    );
    expect(find.text("Rename"), findsOneWidget);
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

  testWidgets("the name field declares the cap but does not truncate", (
    tester,
  ) async {
    await pumpDialog(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, personalDictionaryNameMaxLength);
    expect(field.maxLengthEnforcement, MaxLengthEnforcement.none);
    // No counter: the cap is a guard, not a budget the user tracks.
    expect(field.decoration?.counterText, "");

    // Over-long input stays in the field; the submit-time validation
    // rejects it instead of the field silently cutting it.
    await tester.enterText(find.byType(TextField), "a" * 150);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      "a" * 150,
    );
  });
}
