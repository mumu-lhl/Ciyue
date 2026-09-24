import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await initPrefs();
  });

  testWidgets(
    "search bar selects all text on open and does not refill text when cleared while view is open",
    (tester) async {
      final controller = SearchController();
      addTearDown(controller.dispose);

      Widget buildHost({required String word}) {
        return MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WordSearchBarWithSuggestions(
              word: word,
              controller: controller,
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost(word: "apple"));
      expect(controller.text, "apple");

      // Tap the search bar to open view
      await tester.tap(find.byType(SearchBar));
      await tester.pumpAndSettle();
      expect(controller.isOpen, isTrue);

      // Verify text is selected on open (Issue #420 recommendation)
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      // Tap clear ("X") button
      final clearButton = find.byTooltip("Clear text");
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();
      expect(controller.text, "");

      // Rebuild occurs (simulating async dictionary loading completion or parent rebuild)
      await tester.pumpWidget(buildHost(word: "apple"));
      await tester.pump();

      // Controller text should remain empty while the view is open (Issue #420 bug fix)
      expect(
        controller.text,
        "",
        reason: "Controller text must not be overwritten while view is open",
      );

      // Close the view without searching
      controller.closeView(null);
      await tester.pumpAndSettle();

      // After closing, the search bar restores the word for the current page
      expect(controller.text, "apple");
    },
  );
}
