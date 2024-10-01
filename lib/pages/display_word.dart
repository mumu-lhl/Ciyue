import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

import "../main.dart";

class DisplayWord extends StatelessWidget {
  final String content;
  final String word;

  const DisplayWord({super.key, required this.content, required this.word});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          context.pop();
        },
      )),
      floatingActionButton: Button(word: word),
      body: WebView(content: content),
    );
  }
}

class LocalResourcesathHandler extends CustomPathHandler {
  LocalResourcesathHandler({required super.path});

  @override
  Future<WebResourceResponse?> handle(String path) async {
    try {
      Uint8List? data;

      if (dictReaderResource == null) {
        // Find resource under dictory if no mdd
        final file = File("${dirname(currentDictionaryPath!)}/$path");
        data = await file.readAsBytes();
      } else {
        try {
          final result = await dictionary!.readResource(path);
          data = await dictReaderResource!.readOne(result.blockOffset,
              result.startOffset, result.endOffset, result.compressedSize);
        } catch (e) {
          // Find resource under dictory if resource is not in mdd
          final file = File("${dirname(currentDictionaryPath!)}/$path");
          data = await file.readAsBytes();
        }
      }
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}

class Button extends StatefulWidget {
  final String word;

  const Button({super.key, required this.word});

  @override
  State<Button> createState() => _ButtonState();
}

class WebView extends StatelessWidget {
  final String content;

  final settings = InAppWebViewSettings(
    useWideViewPort: false,
    algorithmicDarkeningAllowed: true,
    resourceCustomSchemes: ["entry"],
    transparentBackground: true,
    webViewAssetLoader: WebViewAssetLoader(
        domain: "ciyue.internal",
        httpAllowed: true,
        pathHandlers: [LocalResourcesathHandler(path: "/")]),
  );

  WebView({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    InAppWebViewController? webViewController;
    String selectedText = "";

    final locale = AppLocalizations.of(context);

    final contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      menuItems: [
        ContextMenuItem(
            id: 1,
            title: locale!.copy,
            action: () async {
              await webViewController!.clearFocus();
              Clipboard.setData(ClipboardData(text: selectedText));
            }),
        ContextMenuItem(
            id: 2,
            title: locale.lookup,
            action: () async {
              try {
                var word = await dictionary!.getOffset(selectedText);

                String content = await dictReader!.readOne(word.blockOffset,
                    word.startOffset, word.endOffset, word.compressedSize);

                if (content.startsWith("@@@LINK=")) {
                  // 8: remove @@@LINK=
                  // content.length - 3: remove \r\n\x00
                  word = await dictionary!.getOffset(
                      content.substring(8, content.length - 3).trimRight());
                  content = await dictReader!.readOne(word.blockOffset,
                      word.startOffset, word.endOffset, word.compressedSize);
                }

                if (context.mounted) {
                  context.push("/word",
                      extra: {"content": content, "word": word.key});
                }
              } catch (e) {
                final snackBar = SnackBar(
                  content: Text(locale.notFound),
                  duration: const Duration(seconds: 1),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                }
              }
            }),
        ContextMenuItem(
            id: 3,
            title: locale.readLoudly,
            action: () async {
              await webViewController!.clearFocus();
              await flutterTts.speak(selectedText);
            })
      ],
      onCreateContextMenu: (hitTestResult) async {
        selectedText = await webViewController?.getSelectedText() ?? "";
      },
    );

    return InAppWebView(
      initialData: InAppWebViewInitialData(
          data: content, baseUrl: WebUri("http://ciyue.internal/")),
      initialSettings: settings,
      contextMenu: contextMenu,
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final url = navigationAction.request.url;
        if (url!.scheme == "entry") {
          final word = await dictionary!.getOffset(
              Uri.decodeFull(url.toString().replaceFirst("entry://", "")));

          final String data = await dictReader!.readOne(word.blockOffset,
              word.startOffset, word.endOffset, word.compressedSize);

          if (context.mounted) {
            context.push("/word", extra: {"content": data, "word": word.key});
          }
        }

        return NavigationActionPolicy.CANCEL;
      },
      onWebViewCreated: (InAppWebViewController controller) {
        webViewController = controller;
      },
    );
  }
}

class _ButtonState extends State<Button> {
  Future<bool>? stared;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final futureWidget = FutureBuilder(
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

    final readLoudly = FloatingActionButton.small(
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      child: const Icon(Icons.volume_up),
      onPressed: () async {
        await flutterTts.speak(widget.word);
      },
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [readLoudly, futureWidget],
    );
  }

  @override
  void initState() {
    super.initState();

    stared = dictionary!.wordExist(widget.word);
  }
}
