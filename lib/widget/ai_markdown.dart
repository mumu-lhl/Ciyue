import "package:ciyue/services/ai.dart";
import "package:ciyue/services/settings.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AIMarkdown extends StatefulWidget {
  final String prompt;

  const AIMarkdown({super.key, required this.prompt});

  @override
  State<AIMarkdown> createState() => _AIMarkdownState();
}

class _AIMarkdownState extends State<AIMarkdown> {
  bool _isLoading = true;

  final controller = TextEditingController();
  final ai = AI(
    provider: settings.aiProvider,
    model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
    apikey: settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
  );

  @override
  Widget build(BuildContext context) {
    Future(() async {
      try {
        await for (final textChunk in ai.requestStream(widget.prompt)) {
          if (_isLoading) {
            setState(() {
              _isLoading = false;
            });
          }

          controller.text += textChunk;
        }
      } catch (e) {
        controller.text = e.toString();
      }
    });

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SelectionArea(
              child: AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return GptMarkdown(controller.text);
                  }),
            ),
          ),
        ),
      );
    }
  }
}
