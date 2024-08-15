import "dart:typed_data";

import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:html/parser.dart";
import "package:mime/mime.dart";

import "../main.dart";

class DisplayWord extends StatelessWidget {
  final String content;
  final String word;

  const DisplayWord({super.key, required this.content, required this.word});

  @override
  Widget build(BuildContext context) {
    final document = parse(content);
    document.head?.append(parse(
        '<meta name="viewport" content="width=device-width, initial-scale=1.0">'));
    final mobileContent = document.outerHtml;

    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          context.pop();
        },
      )),
      floatingActionButton: StarButton(word: word),
      body: WebView(mobileContent: mobileContent),
    );
  }
}

class StarButton extends StatefulWidget {
  final String word;

  const StarButton({super.key, required this.word});

  @override
  State<StarButton> createState() => _StarButtonState();
}

class _StarButtonState extends State<StarButton> {
  Future<bool>? stared;

  @override
  void initState() {
    super.initState();

    stared = dictionary!.wordExist(widget.word);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder(
        future: stared,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (snapshot.hasData) {
            return FloatingActionButton.small(
              foregroundColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              child: Icon(snapshot.data! ? Icons.star : Icons.star_outline),
              onPressed: () async {
                if (snapshot.data!) {
                  await dictionary!.removeWord(widget.word);
                } else {
                  await dictionary!.addWord(widget.word);
                }
                setState(() {
                  stared = dictionary!.wordExist(widget.word);
                });
              },
            );
          }

          return FloatingActionButton.small(
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            child: const Icon(Icons.star_outline),
            onPressed: () {},
          );
        });
  }
}

class WebView extends StatelessWidget {
  final settings = InAppWebViewSettings(
    algorithmicDarkeningAllowed: true,
    resourceCustomSchemes: ["entry"],
    transparentBackground: true,
    webViewAssetLoader: WebViewAssetLoader(
        domain: "dictionary.internal",
        httpAllowed: true,
        pathHandlers: [LocalResourcesathHandler(path: "/")]),
  );

  WebView({super.key, required this.mobileContent});

  final String mobileContent;

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(
          data: mobileContent, baseUrl: WebUri("http://dictionary.internal/")),
      initialSettings: settings,
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        if (url!.scheme == "entry") {
          final word = await dictionary!
              .getOffset(url.toString().replaceFirst("entry://", ""));
          final String data = await dictReader!.readOne(word.blockOffset,
              word.startOffset, word.endOffset, word.compressedSize);

          if (context.mounted) {
            context.push("/word", extra: {"content": data, "word": word.key});
          }
        }

        return NavigationActionPolicy.CANCEL;
      },
    );
  }
}

class LocalResourcesathHandler extends CustomPathHandler {
  LocalResourcesathHandler({required super.path});

  @override
  Future<WebResourceResponse?> handle(String path) async {
    try {
      final result = await dictionary!.readResource(path);
      final Uint8List data = await dictReaderResource!.readOne(
          result.blockOffset,
          result.startOffset,
          result.endOffset,
          result.compressedSize);

      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}
