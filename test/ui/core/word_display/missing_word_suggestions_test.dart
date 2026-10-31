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
  testWidgets("shows every group with its heading", (tester) async {
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: const MissingWordSuggestions(
            spellingSuggestions: ["abschieben"],
            splits: [
              WordSplit(["Anime", "Cover"]),
            ],
            phrases: ["pick up"],
            longVowelReadings: ["ふうぞく"],
          ),
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text("Phrasal verbs"), findsOneWidget);
    expect(find.text("pick up"), findsOneWidget);
    expect(find.text("Spelling suggestions"), findsOneWidget);
    expect(find.text("abschieben"), findsOneWidget);
    expect(find.text("Split into words"), findsOneWidget);
    expect(find.text("Anime"), findsOneWidget);
    expect(find.text("Cover"), findsOneWidget);
    expect(find.text("+"), findsOneWidget);
    expect(find.text("Long vowels spelled out"), findsOneWidget);
    expect(find.text("ふうぞく"), findsOneWidget);

    // The groups the dictionaries answer on their own arrive first, so they
    // must sit above: a group that appears later can then only extend the page
    // downwards.
    final phrasesTop = tester.getTopLeft(find.text("Phrasal verbs")).dy;
    final splitsTop = tester.getTopLeft(find.text("Split into words")).dy;
    final longVowelTop = tester
        .getTopLeft(find.text("Long vowels spelled out"))
        .dy;
    final spellingTop = tester.getTopLeft(find.text("Spelling suggestions")).dy;
    expect(phrasesTop, lessThan(splitsTop));
    expect(splitsTop, lessThan(longVowelTop));
    expect(longVowelTop, lessThan(spellingTop));
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

  testWidgets("a long-vowel reading opens the word it stands for", (
    tester,
  ) async {
    final tapped = <String>[];
    await tester.pumpWidget(
      wrap(
        MissingWordSuggestionsView(
          suggestions: const MissingWordSuggestions(
            spellingSuggestions: [],
            splits: [],
            longVowelReadings: ["ふうぞく"],
          ),
          onSelected: tapped.add,
        ),
      ),
    );

    expect(find.text("Long vowels spelled out"), findsOneWidget);
    expect(find.text("Spelling suggestions"), findsNothing);

    await tester.tap(find.text("ふうぞく"));

    expect(tapped, ["ふうぞく"]);
  });
}
