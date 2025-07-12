import "package:ciyue/core/app_globals.dart";
import "package:flutter/foundation.dart";

class AIPrompts with ChangeNotifier {
  late String _explainPrompt;
  late String _translatePrompt;
  late String _writingCheckPrompt;

  static const String defaultExplainPrompt =
      """Generate a detailed explanation for the word "\$word". If it has multiple meanings, list as many as possible. Include pronunciation, part of speech, meaning(s), examples, synonyms, and antonyms.
The output is entirely and exclusively in \$targetLanguage.
NO OTHER WORD LIKE 'OK, here is...'""";
  static const String defaultTranslatePrompt =
      "Translate the following text from \$sourceLanguage to \$targetLanguage. Please provide multiple translation options if possible. You must output the translation entirely and exclusively in \$targetLanguage: \$text";
  static const String defaultWritingCheckPrompt =
      """Please check the following text for grammar, spelling, and style. Provide suggestions for improvement.

\$text

Suggestions:""";

  AIPrompts() {
    _explainPrompt =
        prefs.getString("customExplainPrompt") ?? defaultExplainPrompt;
    _translatePrompt =
        prefs.getString("customTranslatePrompt") ?? defaultTranslatePrompt;
    _writingCheckPrompt = prefs.getString("customWritingCheckPrompt") ??
        defaultWritingCheckPrompt;
  }

  String get explainPrompt => _explainPrompt;
  String get translatePrompt => _translatePrompt;
  String get writingCheckPrompt => _writingCheckPrompt;

  Future<void> setExplainPrompt(String prompt) async {
    _explainPrompt = prompt;
    await prefs.setString("customExplainPrompt", prompt);
    notifyListeners();
  }

  Future<void> resetExplainPrompt() async {
    _explainPrompt = defaultExplainPrompt;
    await prefs.remove("customExplainPrompt");
    notifyListeners();
  }

  Future<void> setTranslatePrompt(String prompt) async {
    _translatePrompt = prompt;
    await prefs.setString("customTranslatePrompt", prompt);
    notifyListeners();
  }

  Future<void> resetTranslatePrompt() async {
    _translatePrompt = defaultTranslatePrompt;
    await prefs.remove("customTranslatePrompt");
    notifyListeners();
  }

  Future<void> setWritingCheckPrompt(String prompt) async {
    _writingCheckPrompt = prompt;
    await prefs.setString("customWritingCheckPrompt", prompt);
    notifyListeners();
  }

  Future<void> resetWritingCheckPrompt() async {
    _writingCheckPrompt = defaultWritingCheckPrompt;
    await prefs.remove("customWritingCheckPrompt");
    notifyListeners();
  }
}
