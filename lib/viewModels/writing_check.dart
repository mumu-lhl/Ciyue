import "dart:ui" as ui;

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";

class WritingCheckViewModel extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();
  final AIPrompts _aiPrompts;
  final WritingCheckHistoryDao _historyDao;

  WritingCheckViewModel({
    required this._aiPrompts,
    WritingCheckHistoryDao? historyDao,
  }) : _historyDao = historyDao ?? writingCheckHistoryDao;

  String? _prompt;
  String? get prompt => _prompt;

  String? _outputText;
  String? get outputText => _outputText;

  void check() {
    final template = _aiPrompts.writingCheckPrompt;
    _prompt = template
        .replaceAll(r"$text", textEditingController.text)
        .replaceAll(
          r"$targetLanguage",
          ui.PlatformDispatcher.instance.locale.toLanguageTag(),
        );
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
    await _historyDao.addHistory(inputText, outputText);
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
