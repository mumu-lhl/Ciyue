import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/models/ai/ai.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/model_setting.dart";
import "package:ciyue/ui/pages/settings/ai_settings/selection_modal.dart";
import "package:ciyue/viewModels/ai_settings_view_model.dart";
import "package:ciyue/viewModels/home.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  testWidgets(
    "ModelSetting renders text field and sync button for custom model provider",
    (tester) async {
      settings.aiProvider = "openai";
      final homeModel = HomeModel();
      final prompts = AIPrompts();
      final viewModel = AISettingsViewModel(prompts, homeModel);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: viewModel,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ModelSetting()),
          ),
        ),
      );

      await tester.pump();

      // Check for TextFormField
      expect(find.byType(TextFormField), findsOneWidget);

      // Check for sync button
      expect(find.byIcon(Icons.sync), findsOneWidget);

      // Check for dropdown icon button
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    },
  );

  testWidgets("showSelectionModal filters models with search bar", (
    tester,
  ) async {
    const models = [
      ModelInfo("gpt-4o", "GPT-4o"),
      ModelInfo("gpt-4o-mini", "GPT-4o mini"),
      ModelInfo("o1", "o1"),
      ModelInfo("o3-mini", "o3-mini"),
      ModelInfo("claude-3-7-sonnet", "Claude 3.7 Sonnet"),
      ModelInfo("deepseek-chat", "DeepSeek Chat"),
    ];

    String? selectedModel;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showSelectionModal<ModelInfo>(
                    context: context,
                    title: "Select Model",
                    items: models,
                    currentItem: models.first,
                    itemText: (m) => m.shownName,
                    onItemSelected: (m) => selectedModel = m.originName,
                  );
                },
                child: const Text("Open Modal"),
              );
            },
          ),
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text("Open Modal"));
    await tester.pumpAndSettle();

    expect(find.text("Select Model"), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // Search bar

    // Search for "claude"
    await tester.enterText(find.byType(TextField), "claude");
    await tester.pump();

    expect(find.text("Claude 3.7 Sonnet"), findsOneWidget);
    expect(find.text("GPT-4o"), findsNothing);

    // Select the filtered item
    await tester.tap(find.text("Claude 3.7 Sonnet"));
    await tester.pumpAndSettle();

    expect(selectedModel, equals("claude-3-7-sonnet"));
  });
}
