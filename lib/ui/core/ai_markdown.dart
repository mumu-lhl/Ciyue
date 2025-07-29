import "package:ciyue/services/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";

class AIMarkdown extends StatefulWidget {
  final String prompt;
  final Function(String)? onResult;

  const AIMarkdown({super.key, required this.prompt, this.onResult});

  @override
  State<AIMarkdown> createState() => _AIMarkdownState();
}

class _AIMarkdownState extends State<AIMarkdown> {
  late final AI ai;
  late Future<String> _requestFuture;
  bool _isResultReported = false;

  @override
  void initState() {
    super.initState();
    ai = AI(
      provider: settings.aiProvider,
      model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
      apikey: settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
    );
    _requestFuture = ai.request(widget.prompt);
  }

  @override
  void didUpdateWidget(covariant AIMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt) {
      setState(() {
        _isResultReported = false;
        _requestFuture = ai.request(widget.prompt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _requestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData) {
            if (!_isResultReported) {
              _isResultReported = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onResult?.call(snapshot.data!);
              });
            }
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SelectionArea(child: GptMarkdown(snapshot.data!)),
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }
        }
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
}
