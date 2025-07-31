import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

import "dart:ui" as ui;

class WritingCheckViewModel extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();

  String? _prompt;
  String? get prompt => _prompt;

  String? _outputText;
  String? get outputText => _outputText;

  void check() {
    final template =
        Provider.of<AIPrompts>(navigatorKey.currentContext!, listen: false)
            .writingCheckPrompt;
    _prompt = template
        .replaceAll(r"$text", textEditingController.text)
        .replaceAll(r"$targetLanguage",
            ui.PlatformDispatcher.instance.locale.toLanguageTag());
    _outputText = null;
    notifyListeners();
  }

  void loadFromHistory(WritingCheckHistoryData item) {
    textEditingController.text = item.inputText;
    _outputText = item.outputText;
    _prompt = null;
    notifyListeners();
  }

  Future<void> saveResult(String outputText) async {
    if (!settings.enableWritingCheckHistory) {
      return;
    }
    final inputText = textEditingController.text;
    await Provider.of<WritingCheckHistoryDao>(navigatorKey.currentContext!,
            listen: false)
        .addHistory(inputText, outputText);
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
