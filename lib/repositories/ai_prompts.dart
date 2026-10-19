import "package:ciyue/core/app_globals.dart";
import "package:flutter/foundation.dart";

class AIPrompts with ChangeNotifier {
  late String _explainPrompt;
  late String _translatePrompt;
  late String _writingCheckPrompt;
  late String _quizPrompt;
  late String _vocabularyPrompt;
  late String _scenarioPrompt;

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

  static const String defaultQuizPrompt = """Generate a vocabulary quiz with \$count questions using these words: \$words.
Mix the following question types:
\$types

Respond with ONLY a JSON object, no other text:
{"questions": [{"word": "...", "type": "choice|spelling|cloze", "question": "...", "options": ["...", "...", "...", "..."], "correctIndex": 0, "explanation": "..."}]}

For "choice" and "cloze" provide 4 options (1 correct, 3 plausible distractors). For "spelling" set "options" to [] and "correctIndex" to 0.
The explanation should briefly explain the correct answer in \$targetLanguage.""";

  static const String defaultVocabularyPrompt = """From the following text, extract up to \$count vocabulary words that are worth learning for a language learner. Focus on \$difficulty words/phrases. Skip basic words.

Text:
\$text

Respond with ONLY a JSON array of strings, no other text. Example: ["word1", "word2"]""";

  static const String defaultScenarioPrompt =
      """You are roleplaying the following scenario: \$scenarioTitle.
\$scenarioDescription
Stay in character throughout the conversation. Gently correct the user's language mistakes and suggest more natural expressions when appropriate.""";

  AIPrompts() {
    _explainPrompt =
        prefs.getString("customExplainPrompt") ?? defaultExplainPrompt;
    _translatePrompt =
        prefs.getString("customTranslatePrompt") ?? defaultTranslatePrompt;
    _writingCheckPrompt =
        prefs.getString("customWritingCheckPrompt") ??
        defaultWritingCheckPrompt;
    _quizPrompt = prefs.getString("customQuizPrompt") ?? defaultQuizPrompt;
    _vocabularyPrompt =
        prefs.getString("customVocabularyPrompt") ?? defaultVocabularyPrompt;
    _scenarioPrompt =
        prefs.getString("customScenarioPrompt") ?? defaultScenarioPrompt;
  }

  String get explainPrompt => _explainPrompt;
  String get translatePrompt => _translatePrompt;
  String get writingCheckPrompt => _writingCheckPrompt;
  String get quizPrompt => _quizPrompt;
  String get vocabularyPrompt => _vocabularyPrompt;
  String get scenarioPrompt => _scenarioPrompt;

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

  Future<void> setQuizPrompt(String prompt) async {
    _quizPrompt = prompt;
    await prefs.setString("customQuizPrompt", prompt);
  }

  Future<void> resetQuizPrompt() async {
    _quizPrompt = defaultQuizPrompt;
    await prefs.remove("customQuizPrompt");
    notifyListeners();
  }

  Future<void> setVocabularyPrompt(String prompt) async {
    _vocabularyPrompt = prompt;
    await prefs.setString("customVocabularyPrompt", prompt);
  }

  Future<void> resetVocabularyPrompt() async {
    _vocabularyPrompt = defaultVocabularyPrompt;
    await prefs.remove("customVocabularyPrompt");
    notifyListeners();
  }

  Future<void> setScenarioPrompt(String prompt) async {
    _scenarioPrompt = prompt;
    await prefs.setString("customScenarioPrompt", prompt);
  }

  Future<void> resetScenarioPrompt() async {
    _scenarioPrompt = defaultScenarioPrompt;
    await prefs.remove("customScenarioPrompt");
    notifyListeners();
  }
}
