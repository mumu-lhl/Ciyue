import "dart:convert";
import "dart:io";
import "dart:ui" as ui;

import "package:ciyue/main.dart";
import "package:ciyue/pages/main/wordbook.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/services/dictionary.dart";
import "package:ciyue/services/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/viewModels/home.dart";
import "package:ciyue/widget/ai_markdown.dart";
import "package:ciyue/widget/search_bar.dart";
import "package:ciyue/widget/tags_list.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
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
    String template;
    if (settings.explainPromptMode == "custom" &&
        settings.customExplainPrompt.isNotEmpty) {
      template = settings.customExplainPrompt;
    } else {
      template =
          """Generate a detailed explanation for the word "$word". If it has multiple meanings, list as many as possible. Include pronunciation, part of speech, meaning(s), examples, synonyms, and antonyms.
The output is entirely and exclusively in \$targetLanguage.
NO OTHER WORD LIKE 'OK, here is...'""";
    }
    final prompt = template
        .replaceAll(r"$word", word)
        .replaceAll(r"$targetLanguage", targetLanguage);

    return AIMarkdown(prompt: prompt);
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
              if (context.mounted) {
                await playSoundOfWord(
                    selectedText, context.read<AudioModel>().mddAudioList);
              }
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
    return FutureBuilder(
        future: WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
                userDataFolder: windowsWebview2Directory)),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return InAppWebView(
              webViewEnvironment: snapshot.data,
              initialUrlRequest:
                  URLRequest(url: WebUri(url), method: "POST", body: postData),
              initialData:
                  InAppWebViewInitialData(data: content, baseUrl: WebUri(url)),
            );
          }
          return const Center(child: CircularProgressIndicator());
        });
  }
}

class WordDisplay extends StatelessWidget {
  final String word;

  const WordDisplay({super.key, required this.word});

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
              return showTab
                  ? DefaultTabController(
                      initialIndex: 0,
                      length: dictsLength,
                      child: Scaffold(
                        appBar: buildAppBar(context, showTab),
                        floatingActionButton: Button(word: word),
                        body: Column(
                          children: [
                            Expanded(
                              child: buildTabView(context,
                                  validDictIds: snapshot.data!),
                            ),
                            if (settings.tabBarPosition ==
                                    TabBarPosition.bottom &&
                                showTab)
                              buildTabBar(context),
                          ],
                        ),
                      ))
                  : Scaffold(
                      appBar: AppBar(
                        title: settings.showSearchBarInWordDisplay
                            ? WordSearchBarWithSuggestions(
                                word: word,
                                controller: SearchController(),
                              )
                            : null,
                      ),
                      floatingActionButton: Button(word: word),
                      body: settings.aiExplainWord
                          ? AIExplainView(word: word)
                          : buildWebView(snapshot.data![0]));
            } else {
              final fromProcessText = !context.canPop();
              return Scaffold(
                appBar: AppBar(leading: BackButton(
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      // When opened from context menu
                      SystemNavigator.pop();
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
                          final model =
                              Provider.of<HomeModel>(context, listen: false);
                          model.searchWord = word;
                          model.focusSearchBar();
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

  AppBar buildAppBar(BuildContext context, bool showTab) {
    return AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              // When opened from context menu
              SystemNavigator.pop();
            }
          },
        ),
        title: settings.showSearchBarInWordDisplay
            ? WordSearchBarWithSuggestions(
                word: word,
                controller: SearchController(),
              )
            : null,
        bottom: (showTab && settings.tabBarPosition == TabBarPosition.top)
            ? buildTabBar(context)
            : null);
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
                return TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    tabs: [
                      if (settings.aiExplainWord) Tab(text: "AI"),
                      for (int i = 0; i < snapshot.data!.length; i++)
                        if (snapshot.data![i])
                          Tab(
                              text: dictManager
                                  .dicts[dictManager.dictIds[i]]!.title)
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
      for (final id in validDictIds) buildWebView(id)
    ]);
  }

  Widget buildWebView(int id) {
    return FutureBuilder(
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
        });
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

class _ButtonState extends State<Button> {
  Future<bool>? stared;

  Future<void> autoExport() async {
    if (settings.autoExport &&
        (settings.exportDirectory != null || settings.exportPath != null)) {
      Backup.export(true);
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

  Widget buildReadLoudlyButton(BuildContext context, String word) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.volume_up),
      onPressed: () async {
        await playSoundOfWord(word, context.read<AudioModel>().mddAudioList);
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
