import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/writing_check_history.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckViewModel extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();
  final WritingCheckHistoryRepository _repository;

  String? _prompt;
  String? get prompt => _prompt;

  String? _outputText;
  String? get outputText => _outputText;

  List<WritingCheckHistoryData> _history = [];
  List<WritingCheckHistoryData> get history => _history;

  WritingCheckViewModel()
      : _repository =
            WritingCheckHistoryRepository.of(navigatorKey.currentContext!) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    _history = await _repository.getAllHistory();
    notifyListeners();
  }

  void check() {
    final template =
        Provider.of<AIPrompts>(navigatorKey.currentContext!, listen: false)
            .writingCheckPrompt;
    _prompt = template.replaceAll(r"$text", textEditingController.text);
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
    final inputText = textEditingController.text;
    final newId = await _repository.addHistory(inputText, outputText);
    final newEntry = WritingCheckHistoryData(
      id: newId,
      inputText: inputText,
      outputText: outputText,
      createdAt: DateTime.now(),
    );
    _history.insert(0, newEntry);
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
