import "dart:convert";
import "dart:io";

import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/settings.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_gen/gen_l10n/app_localizations.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

class Button extends StatefulWidget {
  final String word;

  const Button({super.key, required this.word});

  @override
  State<Button> createState() => _ButtonState();
}

class LocalResourcesPathHandler extends CustomPathHandler {
  LocalResourcesPathHandler({required super.path});

  @override
  Future<WebResourceResponse?> handle(String path) async {
    if (path == "favicon.ico") {
      return WebResourceResponse(data: null);
    }

    if (path == dict.fontName) {
      final file = File(dict.fontPath!);
      final data = await file.readAsBytes();
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    }

    try {
      Uint8List? data;

      if (dict.readerResource == null) {
        // Find resource under directory if no mdd
        final file = File("${dirname(dict.path!)}/$path");
        data = await file.readAsBytes();
      } else {
        try {
          final result = await dict.db!.readResource(path);
          data = await dict.readerResource!.readOne(result.blockOffset,
              result.startOffset, result.endOffset, result.compressedSize);
        } catch (e) {
          // Find resource under directory if resource is not in mdd
          final file = File("${dirname(dict.path!)}/$path");
          data = await file.readAsBytes();
        }
      }
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
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
        pathHandlers: [LocalResourcesPathHandler(path: "/")]),
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
                var word = await dict.db!.getOffset(selectedText);

                String content = await dict.reader!.readOne(word.blockOffset,
                    word.startOffset, word.endOffset, word.compressedSize);

                if (content.startsWith("@@@LINK=")) {
                  // 8: remove @@@LINK=
                  // content.length - 3: remove \r\n\x00
                  word = await dict.db!.getOffset(
                      content.substring(8, content.length - 3).trimRight());
                  content = await dict.reader!.readOne(word.blockOffset,
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
          final word = await dict.db!.getOffset(
              Uri.decodeFull(url.toString().replaceFirst("entry://", "")));

          final String data = await dict.reader!.readOne(word.blockOffset,
              word.startOffset, word.endOffset, word.compressedSize);

          if (context.mounted) {
            context.push("/word", extra: {"content": data, "word": word.key});
          }
        }

        return NavigationActionPolicy.CANCEL;
      },
      onWebViewCreated: (controller) {
        webViewController = controller;
      },
      onPageCommitVisible: (controller, url) async {
        if (dict.fontName != null) {
          await controller.evaluateJavascript(source: """
const font = new FontFace('Custom Font', 'url(/${dict.fontName})');
font.load();
document.fonts.add(font);
document.body.style.fontFamily = 'Custom Font';
          """);
        }
      },
    );
  }
}

class WebviewDisplay extends StatelessWidget {
  final String content;
  final String word;
  final bool description;

  const WebviewDisplay(
      {super.key,
      required this.content,
      required this.word,
      required this.description});

  @override
  Widget build(BuildContext context) {
    Widget? floatingActionButton;
    late String html;
    if (description) {
      html = HtmlUnescape().convert(content);
    } else {
      html = content;
      floatingActionButton = Button(word: word);
    }

    return Scaffold(
      appBar: AppBar(leading: BackButton(
        onPressed: () {
          context.pop();
        },
      )),
      floatingActionButton: floatingActionButton,
      body: WebView(content: html),
    );
  }
}

class _ButtonState extends State<Button> {
  Future<bool>? stared;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        buildReadLoudlyButton(context, widget.word),
        buildStarButton(context)
      ],
    );
  }

  Widget buildReadLoudlyButton(BuildContext context, word) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      child: const Icon(Icons.volume_up),
      onPressed: () async {
        await flutterTts.speak(word);
      },
    );
  }

  Widget buildStarButton(BuildContext context) {
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
                  await dict.db!.removeWord(widget.word);
                } else {
                  await dict.db!.addWord(widget.word);
                }

                if (settings.autoExport && dict.backupPath != null) {
                  final words = await dict.db!.getAllWords();
                  final output = jsonEncode(words);
                  final file = File(dict.backupPath!);
                  await file.writeAsString(output);
                }

                setState(() {
                  stared = dict.db!.wordExist(widget.word);
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

  @override
  void initState() {
    super.initState();

    stared = dict.db!.wordExist(widget.word);
  }
}
