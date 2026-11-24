import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/models/ai_explanation_data.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_widgets.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:drift/native.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _FakeAIExplanationModel extends AIExplanationModel {
  final String? text;
  int getCalls = 0;

  _FakeAIExplanationModel({this.text})
    : super(dao: AiExplanationDao(AppDatabase(NativeDatabase.memory())));

  @override
  String? get explanation => text;

  @override
  AiExplanationData? get structured => null;

  @override
  bool get isLoading => false;

  @override
  Future<void> getExplanation(String word) async {
    getCalls++;
    notifyListeners();
  }
}

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  setUp(() {
    settings.aiExplainWordManual = false;
  });

  tearDown(() {
    settings.aiExplainWordManual = false;
  });

  Widget buildTestWidget(AIExplanationModel model) {
    return ProviderScope(
      overrides: [
        aiExplanationModelProvider.overrideWith((ref, word) => model),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AIExplainView(word: "apple")),
      ),
    );
  }

  testWidgets("automatic mode requests an explanation on mount", (
    tester,
  ) async {
    final model = _FakeAIExplanationModel(text: "cached explanation");

    await tester.pumpWidget(buildTestWidget(model));
    await tester.pump();

    expect(model.getCalls, 1);
  });

  testWidgets("manual mode waits for a tap, then requests once", (
    tester,
  ) async {
    settings.aiExplainWordManual = true;
    final model = _FakeAIExplanationModel();

    await tester.pumpWidget(buildTestWidget(model));
    await tester.pump();

    expect(model.getCalls, 0);
    expect(find.text("Request AI explanation"), findsOneWidget);

    await tester.tap(find.text("Request AI explanation"));
    await tester.pump();

    expect(model.getCalls, 1);
  });

  testWidgets("manual mode still shows a cached explanation", (tester) async {
    settings.aiExplainWordManual = true;
    final model = _FakeAIExplanationModel(text: "cached explanation");

    await tester.pumpWidget(buildTestWidget(model));
    await tester.pump();

    expect(model.getCalls, 0);
    expect(find.text("Request AI explanation"), findsNothing);
  });
}
