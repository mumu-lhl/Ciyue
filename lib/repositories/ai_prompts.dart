import "package:ciyue/core/app_globals.dart";
import "package:flutter/foundation.dart";

class AIPrompts with ChangeNotifier {
  late String _explainPrompt;
  late String _translatePrompt;
  late String _writingCheckPrompt;

  static const String defaultExplainPrompt = """Explain the word "\$word" in detail using markdown. Structure your response with these sections:

## Pronunciation
## Part of Speech
## Meanings
List each meaning with a brief definition. If the word has multiple meanings, list them all numbered.
## Examples
Give 1-2 example sentences for the most common meanings, with translations.
## Synonyms & Antonyms
List common synonyms and antonyms if any.

The output is entirely and exclusively in \$targetLanguage. Start directly with the first section header, no intro or outro text.""";
  static const String defaultTranslatePrompt =
      "Translate the following text from \$sourceLanguage to \$targetLanguage. Provide only the single most natural and accurate translation, no alternatives or explanations. Output the translation entirely and exclusively in \$targetLanguage: \$text";
  static const String defaultWritingCheckPrompt = """Please evaluate the text from a grammatical and orthographical standpoint, offering suggestions to enhance its composition for a more idiomatic and authentic expression in the given language.
Source language: auto detect
You must output the evaluation entirely, exclusively and naturally in \$targetLanguage.

Example:

## Evaluation
...

## How to Improve
...

## Better Expression
...

## Translation
...

Text:
\$text""";

  AIPrompts() {
    _explainPrompt =
        prefs.getString("customExplainPrompt") ?? defaultExplainPrompt;
    _translatePrompt =
        prefs.getString("customTranslatePrompt") ?? defaultTranslatePrompt;
    _writingCheckPrompt =
        prefs.getString("customWritingCheckPrompt") ??
        defaultWritingCheckPrompt;
  }

  String get explainPrompt => _explainPrompt;
  String get translatePrompt => _translatePrompt;
  String get writingCheckPrompt => _writingCheckPrompt;

  Future<void> setExplainPrompt(String prompt) async {
    _explainPrompt = prompt;
    await prefs.setString("customExplainPrompt", prompt);
  }

  Future<void> resetExplainPrompt() async {
    _explainPrompt = defaultExplainPrompt;
    await prefs.remove("customExplainPrompt");
    notifyListeners();
  }

  Future<void> setTranslatePrompt(String prompt) async {
    _translatePrompt = prompt;
    await prefs.setString("customTranslatePrompt", prompt);
  }

  Future<void> resetTranslatePrompt() async {
    _translatePrompt = defaultTranslatePrompt;
    await prefs.remove("customTranslatePrompt");
    notifyListeners();
  }

  Future<void> setWritingCheckPrompt(String prompt) async {
    _writingCheckPrompt = prompt;
    await prefs.setString("customWritingCheckPrompt", prompt);
  }

  Future<void> resetWritingCheckPrompt() async {
    _writingCheckPrompt = defaultWritingCheckPrompt;
    await prefs.remove("customWritingCheckPrompt");
    notifyListeners();
  }
}
