import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/personal_dictionary.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/manage_dictionaries/main.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_smart_dialog/flutter_smart_dialog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

/// Minimal fake: the card only calls entryCount from initState; anything
/// else is a test bug and throws through noSuchMethod — except
/// [deleteDictionary], which the delete flow calls.
class _FakePersonalDictionaryService implements PersonalDictionaryService {
  _FakePersonalDictionaryService({this.callOrder});

  /// Shared log with the model spy, so one list records the order of
  /// calls across both collaborators.
  final List<String>? callOrder;
  final deletedIds = <int>[];

  @override
  Future<int> entryCount(int dictionaryId) async => 3;

  @override
  Future<void> deleteDictionary(int id) async {
    deletedIds.add(id);
    callOrder?.add("delete:$id");
  }

  @override
  Future<void> Function(int)? get onDictionaryDeleted => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records what the card asks the dictionary manager to do, without
/// touching the real [dictManager]: the card's wiring is the part under
/// test, not the manager's own load.
class _SpyDictManagerModel extends DictManagerModel {
  _SpyDictManagerModel({this.callOrder});

  final List<String>? callOrder;
  final added = <({int id, String path})>[];
  final closedIds = <int>[];
  var updateDictIdsCalls = 0;
  var checkIsEmptyCalls = 0;

  @override
  Future<void> add(int id, String path) async {
    added.add((id: id, path: path));
    callOrder?.add("add:$id");
  }

  @override
  Future<void> close(int id) async {
    closedIds.add(id);
    callOrder?.add("close:$id");
  }

  @override
  Future<void> updateDictIds() async {
    updateDictIdsCalls++;
    callOrder?.add("updateDictIds");
  }

  @override
  bool checkIsEmpty() {
    checkIsEmptyCalls++;
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dictionary = DictionaryListData(
    id: 1,
    path: "personal:1",
    title: "My words",
    type: DictionaryType.personal,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    DictManagerModel? dictModel,
    PersonalDictionaryService? service,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalDictionaryServiceProvider.overrideWithValue(
            service ?? _FakePersonalDictionaryService(),
          ),
          if (dictModel != null)
            dictManagerModelProvider.overrideWith((ref) => dictModel),
        ],
        child: MaterialApp(
          builder: FlutterSmartDialog.init(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale("en"),
          home: Scaffold(
            body: ReorderableListView(
              buildDefaultDragHandles: false,
              onReorderItem: (_, _) {},
              children: const [
                DictionaryCard(
                  key: ValueKey(1),
                  dictionary: dictionary,
                  index: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets("a personal card has a drag handle for reordering", (
    tester,
  ) async {
    await pumpCard(tester);

    expect(find.byType(ReorderableDragStartListener), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);
    expect(find.text("My words"), findsOneWidget);
    expect(find.text("3 entries"), findsOneWidget);
  });

  testWidgets("a disabled personal card dims its title and icon", (
    tester,
  ) async {
    await pumpCard(tester);

    final element = tester.element(find.text("My words"));
    final colorScheme = Theme.of(element).colorScheme;
    final title = tester.widget<Text>(find.text("My words"));
    expect(title.style?.color, colorScheme.onSurface.withValues(alpha: 0.65));
    final icon = tester.widget<Icon>(find.byIcon(Icons.edit_note_rounded));
    expect(icon.color, colorScheme.onSurfaceVariant.withValues(alpha: 0.7));
  });

  testWidgets("an enabled personal card shows its title and icon at full "
      "strength", (tester) async {
    dictManager.dicts[1] = PersonalDictionary(path: "personal:1")
      ..title = "My words";
    addTearDown(() => dictManager.dicts.remove(1));
    await pumpCard(tester);

    final element = tester.element(find.text("My words"));
    final colorScheme = Theme.of(element).colorScheme;
    final title = tester.widget<Text>(find.text("My words"));
    expect(title.style?.color, colorScheme.onSurface);
    final icon = tester.widget<Icon>(find.byIcon(Icons.edit_note_rounded));
    expect(icon.color, colorScheme.onPrimaryContainer);
  });

  testWidgets("ticking a disabled personal card enables it through the "
      "manager (P2-34)", (tester) async {
    // The card is not loaded, so the checkbox is off. Another loaded
    // dictionary makes this the second enable, which skips the
    // first-enable search-focus path (homeModelProvider) — the wiring
    // under test is add/checkIsEmpty/updateDictIds, not the focus move.
    dictManager.dicts[99] = PersonalDictionary(path: "personal:99")
      ..title = "Other";
    addTearDown(() => dictManager.dicts.remove(99));
    dictManager.markLoaded();
    final model = _SpyDictManagerModel();
    await pumpCard(tester, dictModel: model);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(model.added, [(id: 1, path: "personal:1")]);
    expect(model.closedIds, isEmpty);
    expect(model.checkIsEmptyCalls, 1);
    expect(model.updateDictIdsCalls, 1);
  });

  testWidgets("unticking an enabled personal card closes it through the "
      "manager (P2-34)", (tester) async {
    dictManager.dicts[1] = PersonalDictionary(path: "personal:1")
      ..title = "My words";
    addTearDown(() => dictManager.dicts.remove(1));
    dictManager.markLoaded();
    final model = _SpyDictManagerModel();
    await pumpCard(tester, dictModel: model);

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(model.closedIds, [1]);
    expect(model.added, isEmpty);
    expect(model.checkIsEmptyCalls, 1);
    expect(model.updateDictIdsCalls, 1);
  });

  testWidgets("deleting a personal dictionary closes it before deleting "
      "its data (P2-24, P2-34)", (tester) async {
    // The delete handler runs the real card flow — actions sheet, confirm
    // dialog, handler — with a spy model and a fake service. It stalls
    // part-way: after deleteDictionary it awaits
    // `dictGroupDao.removeDictIdFromAllGroups`
    // (lib/ui/pages/settings/manage_dictionaries/main.dart:1065), and
    // that global DAO over mainDatabase
    // (lib/core/app_globals.dart:133, :11) never completes inside a
    // testWidgets body — a Drift await over the pre-opened database
    // still did not finish after ten 100ms pumps (probe, 2026-11-20).
    // So this test pins exactly what the handler does before that call
    // — close before delete, in that order — and records that
    // updateDictIds/checkIsEmpty never run here. The rest of the path is
    // covered below the widget layer: service delete clears groups and
    // fires the hook
    // (test/services/personal_dictionary_service_test.dart:769), and the
    // repository delete removes articles, headwords, the row and group
    // membership
    // (test/repositories/personal_dictionary_test.dart: "removeDictionary
    // deletes articles, headwords, the list row and group membership").
    dictManager.dicts[1] = PersonalDictionary(path: "personal:1")
      ..title = "My words";
    addTearDown(() => dictManager.dicts.remove(1));
    final callOrder = <String>[];
    final model = _SpyDictManagerModel(callOrder: callOrder);
    final service = _FakePersonalDictionaryService(callOrder: callOrder);
    await pumpCard(tester, dictModel: model, service: service);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    // The actions sheet overflows the 800x600 test viewport, so the
    // Delete row sits below the fold: bring it into view before tapping
    // (same viewport artifact as the cloud-sync confirm test).
    await tester.ensureVisible(find.text("Delete dictionary"));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Delete dictionary"));
    await tester.pumpAndSettle();

    expect(
      find.text("Delete this personal dictionary and all its entries?"),
      findsOneWidget,
    );
    await tester.tap(find.text("Confirm"));
    // Bounded pumps only: the handler never reaches the end, so
    // pumpAndSettle would wait out its timeout on the stalled DAO await.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(callOrder, ["close:1", "delete:1"]);
    expect(model.closedIds, [1]);
    expect(service.deletedIds, [1]);
    // The handler stalls at the global DAO await before updateDictIds,
    // so checkIsEmpty (which updateDictIds runs) never fires in this
    // test. If a widget-test DAO ever becomes possible, this assertion
    // must flip to updateDictIdsCalls == 1.
    expect(model.updateDictIdsCalls, 0);
    expect(model.checkIsEmptyCalls, 0);
  });
}
