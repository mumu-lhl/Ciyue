import "package:ciyue/models/ai_explanation_data.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/ai_explanation_view.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("renders phonetic, meanings, examples and word chips", (
    tester,
  ) async {
    const data = AiExplanationData(
      phonetic: "/ˌser.ənˈdɪp.ə.ti/",
      partOfSpeech: "noun",
      meanings: ["finding something valuable by chance"],
      examples: [
        AiExample(
          sentence: "Finding that book was pure serendipity.",
          translation: "发现那本书纯属机缘巧合。",
        ),
      ],
      synonyms: ["chance", "fluke"],
      antonyms: ["design"],
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AiExplanationView(data: data)),
      ),
    );

    expect(find.text("/ˌser.ənˈdɪp.ə.ti/"), findsOneWidget);
    expect(find.text("noun"), findsOneWidget);
    expect(find.text("Meanings"), findsOneWidget);
    expect(find.text("finding something valuable by chance"), findsOneWidget);
    expect(find.text("Examples"), findsOneWidget);
    expect(
      find.text("Finding that book was pure serendipity."),
      findsOneWidget,
    );
    expect(find.text("发现那本书纯属机缘巧合。"), findsOneWidget);
    expect(find.text("Synonyms"), findsOneWidget);
    expect(find.text("chance"), findsOneWidget);
    expect(find.text("Antonyms"), findsOneWidget);
    expect(find.text("design"), findsOneWidget);
  });

  testWidgets("omits sections the data does not have", (tester) async {
    const data = AiExplanationData(meanings: ["only a meaning"]);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AiExplanationView(data: data)),
      ),
    );

    expect(find.text("only a meaning"), findsOneWidget);
    expect(find.text("Examples"), findsNothing);
    expect(find.text("Synonyms"), findsNothing);
    expect(find.text("Antonyms"), findsNothing);
  });
}
