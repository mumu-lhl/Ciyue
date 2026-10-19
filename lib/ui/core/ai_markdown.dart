import "package:ciyue/services/ai.dart";
import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";
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
  late Stream<String> _requestStream;
  bool _isResultReported = false;
  String _accumulated = "";

  @override
  void initState() {
    super.initState();
    ai = AI(
      provider: settings.aiProvider,
      model: settings.getAiProviderConfig(settings.aiProvider)["model"] ?? "",
      apikey: settings.getAiProviderConfig(settings.aiProvider)["apiKey"] ?? "",
    );
    _requestStream = _streamText(widget.prompt);
  }

  /// Accumulate chunks so the markdown renders progressively.
  /// Calls [onResult] once with the full text when the stream closes.
  Stream<String> _streamText(String prompt) async* {
    final buffer = StringBuffer();
    await for (final chunk in ai.requestStream(prompt)) {
      buffer.write(chunk);
      _accumulated = buffer.toString();
      yield _accumulated;
    }
    final fullText = buffer.toString();
    if (!_isResultReported) {
      _isResultReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onResult?.call(fullText);
      });
    }
  }

  @override
  void didUpdateWidget(covariant AIMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt) {
      setState(() {
        _isResultReported = false;
        _accumulated = "";
        _requestStream = _streamText(widget.prompt);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _requestStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
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
            child: Text(
              snapshot.error.toString(),
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
