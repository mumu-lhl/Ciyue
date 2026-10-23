import "package:ciyue/core/app_globals.dart";
import "package:flutter/foundation.dart";

/// Static description of one customizable prompt: where it is
/// stored, its default text, and the variables the app substitutes
/// into it. Drives the generic accessors on [AIPrompts] and the
/// prompt management UI, so a prompt is defined in exactly one
/// place instead of six parallel field/getter/setter quadruples.
class AiPromptDefinition {
  final String id;
  final String prefsKey;
  final String defaultText;

  /// Variables substituted by the app, e.g. `$word`. Shown in the
  /// editor as tap-to-insert chips.
  final List<String> variables;

  const AiPromptDefinition({
    required this.id,
    required this.prefsKey,
    required this.defaultText,
    required this.variables,
  });
}

class AIPrompts with ChangeNotifier {
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
  static const String defaultExplainStructuredPrompt = """Explain the word "\$word" for a language learner. Respond with ONLY a JSON object — no markdown fences, no intro or outro text — using exactly this structure:

{"phonetic": "...", "partOfSpeech": "...", "meanings": ["...", "..."], "examples": [{"sentence": "...", "translation": "..."}], "synonyms": ["..."], "antonyms": ["..."]}

- phonetic: the IPA transcription of the word.
- partOfSpeech: the part(s) of speech, e.g. "noun" or "verb / noun".
- meanings: every common meaning, one concise definition each, most frequent first.
- examples: 1-2 example sentences for the most common meanings, each with a translation.
- synonyms / antonyms: the common ones only; use an empty array when there are none.

Write the definitions, the part of speech and the translations entirely in \$targetLanguage. Example sentences stay in the language of the word itself.""";
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

  static const explainDefinition = AiPromptDefinition(
    id: "explain",
    prefsKey: "customExplainPrompt",
    defaultText: defaultExplainPrompt,
    variables: [r"$word", r"$targetLanguage"],
  );
  static const explainStructuredDefinition = AiPromptDefinition(
    id: "explainStructured",
    prefsKey: "customExplainStructuredPrompt",
    defaultText: defaultExplainStructuredPrompt,
    variables: [r"$word", r"$targetLanguage"],
  );
  static const translateDefinition = AiPromptDefinition(
    id: "translate",
    prefsKey: "customTranslatePrompt",
    defaultText: defaultTranslatePrompt,
    variables: [r"$sourceLanguage", r"$targetLanguage", r"$text"],
  );
  static const writingCheckDefinition = AiPromptDefinition(
    id: "writingCheck",
    prefsKey: "customWritingCheckPrompt",
    defaultText: defaultWritingCheckPrompt,
    variables: [r"$text", r"$targetLanguage"],
  );
  static const quizDefinition = AiPromptDefinition(
    id: "quiz",
    prefsKey: "customQuizPrompt",
    defaultText: defaultQuizPrompt,
    variables: [r"$count", r"$words", r"$types", r"$targetLanguage"],
  );
  static const vocabularyDefinition = AiPromptDefinition(
    id: "vocabulary",
    prefsKey: "customVocabularyPrompt",
    defaultText: defaultVocabularyPrompt,
    variables: [r"$count", r"$difficulty", r"$text"],
  );
  static const scenarioDefinition = AiPromptDefinition(
    id: "scenario",
    prefsKey: "customScenarioPrompt",
    defaultText: defaultScenarioPrompt,
    variables: [r"$scenarioTitle", r"$scenarioDescription"],
  );

  /// All customizable prompts, in management-page display order.
  static const allDefinitions = <AiPromptDefinition>[
    explainDefinition,
    explainStructuredDefinition,
    translateDefinition,
    writingCheckDefinition,
    quizDefinition,
    vocabularyDefinition,
    scenarioDefinition,
  ];

  final Map<String, String> _values = {};

  AIPrompts() {
    for (final definition in allDefinitions) {
      _values[definition.id] =
          prefs.getString(definition.prefsKey) ?? definition.defaultText;
    }
  }

  String promptFor(AiPromptDefinition definition) =>
      _values[definition.id] ?? definition.defaultText;

  /// Whether the current text differs from the default. Content
  /// based, so re-typing the default text counts as back-to-default
  /// regardless of what is stored.
  bool isCustomized(AiPromptDefinition definition) =>
      promptFor(definition) != definition.defaultText;

  int get customizedCount => allDefinitions.where(isCustomized).length;

  Future<void> setPrompt(AiPromptDefinition definition, String prompt) async {
    _values[definition.id] = prompt;
    if (prompt == definition.defaultText) {
      // Storing the default verbatim is indistinguishable from
      // never having customized — keep storage clean.
      await prefs.remove(definition.prefsKey);
    } else {
      await prefs.setString(definition.prefsKey, prompt);
    }
    notifyListeners();
  }

  Future<void> resetPrompt(AiPromptDefinition definition) async {
    _values[definition.id] = definition.defaultText;
    await prefs.remove(definition.prefsKey);
    notifyListeners();
  }

  Future<void> resetAllPrompts() async {
    for (final definition in allDefinitions) {
      _values[definition.id] = definition.defaultText;
      await prefs.remove(definition.prefsKey);
    }
    notifyListeners();
  }

  String get explainPrompt => promptFor(explainDefinition);
  String get explainStructuredPrompt => promptFor(explainStructuredDefinition);
  String get translatePrompt => promptFor(translateDefinition);
  String get writingCheckPrompt => promptFor(writingCheckDefinition);
  String get quizPrompt => promptFor(quizDefinition);
  String get vocabularyPrompt => promptFor(vocabularyDefinition);
  String get scenarioPrompt => promptFor(scenarioDefinition);

  Future<void> setExplainPrompt(String prompt) =>
      setPrompt(explainDefinition, prompt);

  Future<void> resetExplainPrompt() => resetPrompt(explainDefinition);

  Future<void> setExplainStructuredPrompt(String prompt) =>
      setPrompt(explainStructuredDefinition, prompt);

  Future<void> resetExplainStructuredPrompt() =>
      resetPrompt(explainStructuredDefinition);

  Future<void> setTranslatePrompt(String prompt) =>
      setPrompt(translateDefinition, prompt);

  Future<void> resetTranslatePrompt() => resetPrompt(translateDefinition);

  Future<void> setWritingCheckPrompt(String prompt) =>
      setPrompt(writingCheckDefinition, prompt);

  Future<void> resetWritingCheckPrompt() => resetPrompt(writingCheckDefinition);

  Future<void> setQuizPrompt(String prompt) =>
      setPrompt(quizDefinition, prompt);

  Future<void> resetQuizPrompt() => resetPrompt(quizDefinition);

  Future<void> setVocabularyPrompt(String prompt) =>
      setPrompt(vocabularyDefinition, prompt);

  Future<void> resetVocabularyPrompt() => resetPrompt(vocabularyDefinition);

  Future<void> setScenarioPrompt(String prompt) =>
      setPrompt(scenarioDefinition, prompt);

  Future<void> resetScenarioPrompt() => resetPrompt(scenarioDefinition);
}
