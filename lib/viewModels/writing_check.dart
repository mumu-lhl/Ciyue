import "package:flutter/material.dart";

class WritingCheckViewModel extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();

  String? _prompt;
  String? get prompt => _prompt;

  void check() {
    const template =
        """Please check the following text for grammar, spelling, and style. Provide suggestions for improvement.

\$text

Suggestions:""";
    _prompt = template.replaceAll(r"$text", textEditingController.text);
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
