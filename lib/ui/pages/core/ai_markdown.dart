import "package:ciyue/services/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AIMarkdown extends StatefulWidget {
  final String prompt;

  const AIMarkdown({super.key, required this.prompt});

  @override
  State<AIMarkdown> createState() => _AIMarkdownState();
}

class _AIMarkdownState extends State<AIMarkdown> {
  final ai = AI(
    provider: settings.aiProvider,
    model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
    apikey: settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: ai.request(widget.prompt),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectionArea(child: GptMarkdown(snapshot.data!)),
                ),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text(snapshot.error.toString()),
          );
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
