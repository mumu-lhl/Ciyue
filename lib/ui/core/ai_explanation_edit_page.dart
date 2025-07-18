import "package:ciyue/viewModels/ai_explanation.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";

class AIExplanationEditPage extends StatefulWidget {
  final String word;
  final String initialExplanation;
  final AIExplanationModel aiExplanationModel;

  const AIExplanationEditPage({
    super.key,
    required this.word,
    required this.initialExplanation,
    required this.aiExplanationModel,
  });

  @override
  State<AIExplanationEditPage> createState() => _AIExplanationEditPageState();
}

class _AIExplanationEditPageState extends State<AIExplanationEditPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialExplanation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale.editAIExplanation),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    decoration: InputDecoration(
                      hintText: locale.enterAIExplanation,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: () {
                    widget.aiExplanationModel.updateExplanation(
                      widget.word,
                      _controller.text,
                    );
                    context.pop();
                  },
                  child: Text(locale.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
