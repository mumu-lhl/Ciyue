import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/missing_word_suggestions.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

Widget wrap(Widget child) {
  return MaterialApp(
    locale: const Locale("en"),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets("shows both groups with their headings", (tester) async {
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: const MissingWordSuggestions(
            spellingSuggestions: ["abschieben"],
            splits: [
              WordSplit(["Anime", "Cover"]),
            ],
          ),
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text("Spelling suggestions"), findsOneWidget);
    expect(find.text("abschieben"), findsOneWidget);
    expect(find.text("Split into words"), findsOneWidget);
    expect(find.text("Anime"), findsOneWidget);
    expect(find.text("Cover"), findsOneWidget);
    expect(find.text("+"), findsOneWidget);

    // The splits arrive first, so they must sit above: a group that appears
    // later can then only extend the page downwards.
    expect(
      tester.getTopLeft(find.text("Split into words")).dy,
      lessThan(tester.getTopLeft(find.text("Spelling suggestions")).dy),
    );
  });

  testWidgets("draws nothing when there is nothing to suggest", (tester) async {
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: MissingWordSuggestions.empty,
          onSelected: (_) {},
        ),
      ),
    );

    // No empty headings, no leftover spacing: the page keeps its old look.
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets("a chip reports the word it stands for", (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: const MissingWordSuggestions(
            spellingSuggestions: ["abschieben"],
            splits: [
              WordSplit(["Anime", "Cover"]),
            ],
          ),
          onSelected: tapped.add,
        ),
      ),
    );

    await tester.tap(find.text("Cover"));
    await tester.tap(find.text("abschieben"));

    expect(tapped, ["Cover", "abschieben"]);
  });

  testWidgets("keeps a single group when only one applies", (tester) async {
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: const MissingWordSuggestions(
            spellingSuggestions: [],
            splits: [
              WordSplit(["倾奇", "者"]),
            ],
          ),
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text("Spelling suggestions"), findsNothing);
    expect(find.text("Split into words"), findsOneWidget);
    expect(find.text("倾奇"), findsOneWidget);
  });
}
