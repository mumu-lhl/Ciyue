import "dart:convert";
import "dart:io";
import "dart:ui" as ui;

import "package:ciyue/ai.dart";
import "package:ciyue/dictionary.dart";
import "package:ciyue/main.dart";
import "package:ciyue/pages/main/home.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/platform.dart";
import "package:ciyue/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/widget/tags_list.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:provider/provider.dart";

class AIExplainView extends StatelessWidget {
  final String word;

  const AIExplainView({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final targetLanguage = settings.language! == "system"
        ? ui.PlatformDispatcher.instance.locale.languageCode
        : settings.language!;
    final prompt =
        """You are a AI explain word tool called Ciyue(词悦). Generate a detailed explanation of the word "$word", including the following sections:

Pronunciation: Provide the pronunciation using the International Phonetic Alphabet (IPA).
Part of Speech: Specify the part of speech (e.g., noun, verb, adjective).
Meaning: Explain the meaning of the word.
Example Sentences: Include at least three example sentences that demonstrate the word's usage.
Synonyms: List at least three synonyms.
Antonyms: List at least three antonyms.

Format the response using Markdown to ensure each section is clearly organized with appropriate headings.
The output is entirely and exclusively in $targetLanguage.""";
    final ai = AI(
      provider: settings.aiProvider,
      model: settings.getAiProviderConfig(settings.aiProvider)['model'] ?? '',
      apikey: settings.getAiProviderConfig(settings.aiProvider)['apiKey'] ?? '',
    );

    return FutureBuilder(
      future: ai.request(prompt),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                  child: SelectionArea(child: GptMarkdown(snapshot.data!))),
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

class Button extends StatefulWidget {
  final String word;

  const Button({super.key, required this.word});

  @override
  State<Button> createState() => _ButtonState();
}

class LocalResourcesPathHandler extends CustomPathHandler {
  final int dictId;

  LocalResourcesPathHandler({required super.path, required this.dictId});

  @override
  Future<WebResourceResponse?> handle(String path) async {
    if (path == "favicon.ico") {
      return WebResourceResponse(data: null);
    }

    if (path == dictManager.dicts[dictId]!.fontName) {
      final file = File(dictManager.dicts[dictId]!.fontPath!);
      final data = await file.readAsBytes();
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    }

    try {
      Uint8List? data;

      if (dictManager.dicts[dictId]!.readerResource == null) {
        // Find resource under directory if no mdd
        final file = File("${dirname(dictManager.dicts[dictId]!.path)}/$path");
        data = await file.readAsBytes();
      } else {
        try {
          final result = await dictManager.dicts[dictId]!.db.readResource(path);
          data = await dictManager.dicts[dictId]!.readerResource!.readOne(
              result.blockOffset,
              result.startOffset,
              result.endOffset,
              result.compressedSize);
        } catch (e) {
          // Find resource under directory if resource is not in mdd
          final file =
              File("${dirname(dictManager.dicts[dictId]!.path)}/$path");
          data = await file.readAsBytes();
        }
      }
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}

class WebviewAndroid extends StatelessWidget {
  final String content;
  final int dictId;

  const WebviewAndroid(
      {super.key, required this.content, required this.dictId});

  @override
  Widget build(BuildContext context) {
    final settings = InAppWebViewSettings(
      useWideViewPort: false,
      algorithmicDarkeningAllowed: true,
      resourceCustomSchemes: ["entry"],
      transparentBackground: true,
      webViewAssetLoader: WebViewAssetLoader(
          domain: "ciyue.internal",
          httpAllowed: true,
          pathHandlers: [LocalResourcesPathHandler(path: "/", dictId: dictId)]),
    );

    InAppWebViewController? webViewController;
    String selectedText = "";

    final locale = AppLocalizations.of(context)!;

    final contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      menuItems: [
        ContextMenuItem(
            id: 1,
            title: locale.copy,
            action: () async {
              await webViewController!.clearFocus();
              Clipboard.setData(ClipboardData(text: selectedText));
            }),
        ContextMenuItem(
            id: 2,
            title: locale.lookup,
            action: () async {
              context.push("/word", extra: {"word": selectedText});
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
          final word = await dictManager.dicts[dictId]!.db.getOffset(
              Uri.decodeFull(url.toString().replaceFirst("entry://", "")));

          final String data = await dictManager.dicts[dictId]!.reader.readOne(
              word.blockOffset,
              word.startOffset,
              word.endOffset,
              word.compressedSize);

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
        if (dictManager.dicts[dictId]!.fontName != null) {
          await controller.evaluateJavascript(source: """
const font = new FontFace('Custom Font', 'url(/${dictManager.dicts[dictId]!.fontName})');
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
  final String word;

  const WebviewDisplay({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: validDictionaryIds(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data!.isNotEmpty || settings.aiExplainWord) {
              final dictsLength = settings.aiExplainWord
                  ? snapshot.data!.length + 1
                  : snapshot.data!.length;
              final showTab = dictsLength > 1;
              return DefaultTabController(
                  initialIndex: 0,
                  length: showTab ? dictsLength : 0,
                  child: Scaffold(
                      appBar: AppBar(
                          leading: BackButton(
                            onPressed: () {
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                // When opened from context menu
                                SystemChannels.platform
                                    .invokeMethod('SystemNavigator.pop');
                              }
                            },
                          ),
                          bottom: showTab ? buildTabBar(context) : null),
                      floatingActionButton: Button(word: word),
                      body:
                          buildTabView(context, validDictIds: snapshot.data!)));
            } else {
              final fromProcessText = !context.canPop();
              return Scaffold(
                appBar: AppBar(leading: BackButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      // When opened from context menu
                      SystemChannels.platform
                          .invokeMethod('SystemNavigator.pop');
                    }
                  },
                )),
                body: Center(
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppLocalizations.of(context)!.notFound,
                        style: Theme.of(context).textTheme.titleLarge),
                    Visibility(
                      visible: fromProcessText,
                      child: TextButton(
                        onPressed: () {
                          context.go("/");
                          HomePage.callEnableAutofocusOnce = true;
                          HomePage.setSearchWord(word);
                        },
                        child: Text(AppLocalizations.of(context)!.editWord),
                      ),
                    ),
                  ],
                )),
              );
            }
          } else {
            return const SizedBox.shrink();
          }
        });
  }

  PreferredSizeWidget buildTabBar(BuildContext context) {
    return PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: FutureBuilder(
            future: Future.wait([
              for (final id in dictManager.dictIds)
                dictManager.dicts[id]!.db.wordExist(word)
            ]),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return TabBar(tabs: [
                  if (settings.aiExplainWord) Tab(text: "AI"),
                  for (int i = 0; i < snapshot.data!.length; i++)
                    if (snapshot.data![i])
                      Tab(
                          text:
                              dictManager.dicts[dictManager.dictIds[i]]!.title)
                ]);
              } else {
                return const SizedBox.shrink();
              }
            }));
  }

  Widget buildTabView(BuildContext context,
      {List<int> validDictIds = const []}) {
    return TabBarView(physics: NeverScrollableScrollPhysics(), children: [
      if (settings.aiExplainWord) AIExplainView(word: word),
      for (final id in validDictIds)
        FutureBuilder(
            future: dictManager.dicts[id]!.readWord(word),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                if (Platform.isAndroid) {
                  return WebviewAndroid(content: snapshot.data!, dictId: id);
                } else {
                  return WebviewWindows(content: snapshot.data!, dictId: id);
                }
              } else {
                return const SizedBox.shrink();
              }
            })
    ]);
  }

  Future<List<int>> validDictionaryIds() async {
    final validIds = <int>[];
    for (final id in dictManager.dictIds) {
      if (await dictManager.dicts[id]!.db.wordExist(word)) {
        validIds.add(id);
      }
    }
    return validIds;
  }
}

class WebviewDisplayDescription extends StatelessWidget {
  final int dictId;

  const WebviewDisplayDescription({super.key, required this.dictId});

  @override
  Widget build(BuildContext context) {
    String html;
    if (dictManager.dicts.containsKey(dictId)) {
      html = dictManager.dicts[dictId]!.reader.header["Description"]!;
      html = HtmlUnescape().convert(html);

      return Scaffold(
          appBar: AppBar(leading: BackButton(
            onPressed: () {
              context.pop();
            },
          )),
          body: WebviewAndroid(content: html, dictId: dictId));
    } else {
      final html = getDescriptionFromInactiveDict();
      return FutureBuilder(
          future: html,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Scaffold(
                  appBar: AppBar(leading: BackButton(
                    onPressed: () {
                      context.pop();
                    },
                  )),
                  body:
                      WebviewAndroid(content: snapshot.data!, dictId: dictId));
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          });
    }
  }

  Future<String> getDescriptionFromInactiveDict() async {
    final dict = Mdict(path: await dictionaryListDao.getPath(dictId));
    await dict.init();
    final html = dict.reader.header["Description"]!;
    await dict.close();
    return HtmlUnescape().convert(html);
  }
}

class WebviewWindows extends StatelessWidget {
  final String content;
  final int dictId;

  const WebviewWindows(
      {super.key, required this.content, required this.dictId});

  @override
  Widget build(BuildContext context) {
    final port = dictManager.dicts[dictId]!.port;
    final url = "http://localhost:$port/";

    final Uint8List postData =
        Uint8List.fromList(utf8.encode(json.encode({"content": content})));
    return InAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri(url), method: "POST", body: postData),
      initialData: InAppWebViewInitialData(data: content, baseUrl: WebUri(url)),
    );
  }
}

class _ButtonState extends State<Button> {
  Future<bool>? stared;

  Future<void> autoExport() async {
    if (settings.autoExport &&
        (settings.exportDirectory != null || settings.exportPath != null)) {
      final words = await wordbookDao.getAllWords(),
          tags = await wordbookTagsDao.getAllTags();

      final wordsOutput = jsonEncode(words), tagsOutput = jsonEncode(tags);
      final fileName = setExtension(settings.exportFileName, ".json");

      if (Platform.isAndroid) {
        await PlatformMethod.writeFile({
          "path": join(settings.exportDirectory!, fileName),
          "directory": settings.exportDirectory,
          "filename": fileName,
          "content": "$wordsOutput\n$tagsOutput"
        });
      } else {
        final file = File(join(settings.exportPath!));
        await file.writeAsString("$wordsOutput\n$tagsOutput");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        buildReadLoudlyButton(context, widget.word),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: buildStarButton(context),
        ),
      ],
    );
  }

  Widget buildReadLoudlyButton(BuildContext context, word) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.volume_up),
      onPressed: () async {
        await flutterTts.speak(word);
      },
    );
  }

  Widget buildStarButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = AppLocalizations.of(context)!;

    return FutureBuilder(
        future: stared,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) {
            return FloatingActionButton.small(
              foregroundColor: colorScheme.primary,
              backgroundColor: colorScheme.surface,
              child: const Icon(Icons.star_outline),
              onPressed: () {},
            );
          }

          return FloatingActionButton.small(
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(snapshot.data! ? Icons.star : Icons.star_outline),
            onPressed: () async {
              Future<void> star() async {
                if (snapshot.data!) {
                  await wordbookDao.removeWord(widget.word);
                } else {
                  await wordbookDao.addWord(widget.word);
                }

                await autoExport();
                if (context.mounted) {
                  context.read<WordbookModel>().updateWordList();
                }
                checkStared();
              }

              if (wordbookTagsDao.tagExist) {
                final tagsOfWord = await wordbookDao.tagsOfWord(widget.word),
                    tags = await wordbookTagsDao.getAllTags();

                final toAdd = <int>[], toDel = <int>[];

                if (!context.mounted) return;

                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text(locale.tags),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TagsList(
                              tags: tags,
                              tagsOfWord: tagsOfWord,
                              toAdd: toAdd,
                              toDel: toDel,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            child: Text(locale.remove),
                            onPressed: () async {
                              await wordbookDao
                                  .removeWordWithAllTags(widget.word);

                              if (context.mounted) context.pop();

                              await autoExport();
                              if (context.mounted) {
                                context.read<WordbookModel>().updateWordList();
                              }
                              checkStared();
                            },
                          ),
                          TextButton(
                            child: Text(locale.confirm),
                            onPressed: () async {
                              if (!snapshot.data!) {
                                await wordbookDao.addWord(widget.word);
                              }

                              for (final tag in toAdd) {
                                await wordbookDao.addWord(widget.word,
                                    tag: tag);
                              }

                              for (final tag in toDel) {
                                await wordbookDao.removeWord(widget.word,
                                    tag: tag);
                              }

                              if (context.mounted) context.pop();

                              await autoExport();
                              if (context.mounted) {
                                context.read<WordbookModel>().updateWordList();
                              }
                              checkStared();
                            },
                          ),
                        ],
                      );
                    });
              } else {
                await star();
              }
            },
          );
        });
  }

  void checkStared() {
    setState(() {
      stared = wordbookDao.wordExist(widget.word);
    });
  }

  @override
  void initState() {
    super.initState();

    stared = wordbookDao.wordExist(widget.word);
  }
}
