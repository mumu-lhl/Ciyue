import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckViewModel extends ChangeNotifier {
  final TextEditingController textEditingController = TextEditingController();

  String? _prompt;
  String? get prompt => _prompt;

  void check() {
    final template =
        Provider.of<AIPrompts>(navigatorKey.currentContext!, listen: false)
            .writingCheckPrompt;
    _prompt = template.replaceAll(r"$text", textEditingController.text);
    notifyListeners();
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }
}
