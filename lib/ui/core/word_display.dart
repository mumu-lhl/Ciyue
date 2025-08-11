import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/dictionary/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/backup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:ciyue/ui/core/ai_markdown.dart";
import "package:ciyue/ui/core/search_bar.dart";
import "package:ciyue/ui/core/tags_list.dart";
import "package:ciyue/viewModels/ai_explanation.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:dict_reader/dict_reader.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:provider/provider.dart";

Future<CustomSchemeResponse?> Function(
        InAppWebViewController controller, WebResourceRequest request)
    onLoadResourceWithCustomSchemeWarpper(int dictId) {
  return (controller, request) async {
    final url = request.url;
    if (url.scheme == "sound") {
      final filename =
          Uri.decodeFull(url.toString()).replaceFirst("sound://", "");
      final results = await dictManager.dicts[dictId]!.readResource(filename);
      for (final result in results) {
        final info = RecordOffsetInfo(
          result.key,
          result.blockOffset,
          result.startOffset,
          result.endOffset,
          result.compressedSize,
        );
        try {
          final Uint8List data;
          if (result.part == null) {
            data = await dictManager.dicts[dictId]!.readerResources[0]
                .readOneMdd(info) as Uint8List;
          } else {
            data = await dictManager
                .dicts[dictId]!.readerResources[result.part!]
                .readOneMdd(info) as Uint8List;
          }
          talker.info(
            "Playing sound (2): $filename",
          );
          return CustomSchemeResponse(
              contentType: lookupMimeType(filename)!, data: data);
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  };
}

Future<NavigationActionPolicy?> Function(
  InAppWebViewController controller,
  NavigationAction navigationAction,
) shouldOverrideUrlLoadingWarpper(int dictId, BuildContext context) {
  return (controller, navigationAction) async {
    final url = navigationAction.request.url;
    final word = Uri.decodeFull(url.toString().replaceFirst("entry://", ""));

    if (url!.scheme == "entry") {
      if (!(await dictManager.dicts[dictId]!.wordExist(word))) {
        talker.info("Word not found: ${url.toString()}");
        return NavigationActionPolicy.CANCEL;
      }

      final content = await dictManager.dicts[dictId]!.readWord(word);

      if (context.mounted) {
        context.push("/word", extra: {"content": content, "word": word});
      }
    } else if (url.scheme == "sound") {
      final filename =
          Uri.decodeFull(url.toString()).replaceFirst("sound://", "");

      final results = await dictManager.dicts[dictId]!.readResource(filename);

      for (final result in results) {
        final info = RecordOffsetInfo(
          result.key,
          result.blockOffset,
          result.startOffset,
          result.endOffset,
          result.compressedSize,
        );
        final Uint8List data;
        try {
          if (result.part == null) {
            data = await dictManager.dicts[dictId]!.readerResources[0]
                .readOneMdd(info) as Uint8List;
          } else {
            data = await dictManager
                .dicts[dictId]!.readerResources[result.part!]
                .readOneMdd(info) as Uint8List;
          }
        } catch (e) {
          talker.error(
            "Failed to read sound resource (${result.part == null ? 0 : result.part!}): $filename",
            e,
          );
          continue;
        }

        await playSound(data, lookupMimeType(filename)!);
        talker.info(
          "Playing sound (1): $filename",
        );
        return NavigationActionPolicy.CANCEL;
      }
    }

    return NavigationActionPolicy.CANCEL;
  };
}

Widget? _buildTitle(String word) {
  if (settings.showSearchBarInWordDisplay) {
    return WordSearchBarWithSuggestions(
      word: word,
      controller: SearchController(),
    );
  } else {
    return null;
  }
}

class ExpansionWordDisplay extends StatefulWidget {
  final String word;
  final List<int> validDictIds;

  const ExpansionWordDisplay({
    super.key,
    required this.word,
    required this.validDictIds,
  });

  @override
  State<ExpansionWordDisplay> createState() => _ExpansionWordDisplayState();
}

class _ExpansionWordDisplayState extends State<ExpansionWordDisplay> {
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    final length = settings.aiExplainWord
        ? widget.validDictIds.length + 1
        : widget.validDictIds.length;
    _isExpanded = List<bool>.generate(
      length,
      (_) => true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final panels = <ExpansionPanel>[];
    int panelIndex = 0;

    if (settings.aiExplainWord) {
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return const ListTile(title: Text("AI"));
          },
          body: AIExplainView(
            word: widget.word,
            key: ValueKey(context
                .select<AIExplanationModel, int>((model) => model.refreshKey)),
          ),
          isExpanded: _isExpanded[panelIndex],
          canTapOnHeader: true,
        ),
      );
      panelIndex++;
    }

    for (final dictId in widget.validDictIds) {
      panels.add(
        ExpansionPanel(
          headerBuilder: (context, isExpanded) {
            return ListTile(title: Text(dictManager.dicts[dictId]!.title));
          },
          body: _buildWebView(widget.word, dictId, true),
          isExpanded: _isExpanded[panelIndex],
          canTapOnHeader: true,
        ),
      );
      panelIndex++;
    }

    final isAIExplainTabSelected =
        settings.aiExplainWord && _isExpanded.isNotEmpty && _isExpanded[0];

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.go("/"),
        ),
        title: _buildTitle(widget.word),
      ),
      floatingActionButton: Button(
        word: widget.word,
        showAIButtons: isAIExplainTabSelected,
      ),
      body: SingleChildScrollView(
        child: ExpansionPanelList(
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              _isExpanded[index] = isExpanded;
            });
          },
          children: panels,
        ),
      ),
    );
  }
}

Widget _buildWebView(String word, int id, bool isExpansion) {
  return FutureBuilder(
    future: dictManager.dicts[id]!.readWord(word),
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        if (Platform.isAndroid) {
          return WebviewAndroid(
              content: snapshot.data!, dictId: id, isExpansion: isExpansion);
        } else if (Platform.isWindows) {
          return WebviewWindows(content: snapshot.data!, dictId: id);
        } else {
          return FakeWebViewByAI(html: snapshot.data!);
        }
      } else {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
    },
  );
}

class AIExplainView extends StatelessWidget {
  final String word;

  const AIExplainView({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AIExplanationModel>().getExplanation(word);
    });

    return Consumer<AIExplanationModel>(
      builder: (context, model, child) {
        if (model.isLoading || model.explanation == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SelectionArea(child: GptMarkdown(model.explanation!)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class Button extends StatefulWidget {
  final String word;
  final bool showAIButtons;

  const Button({super.key, required this.word, this.showAIButtons = false});

  @override
  State<Button> createState() => _ButtonState();
}

class FakeWebViewByAI extends StatelessWidget {
  final String html;

  const FakeWebViewByAI({super.key, required this.html});

  @override
  Widget build(BuildContext context) {
    final prompt =
        "Extract the content from the following HTML into Markdown format: $html";

    return AIMarkdown(prompt: prompt);
  }
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

      if (dictManager.dicts[dictId]!.readerResources.isEmpty) {
        // Find resource under directory if no mdd
        final file = File("${dirname(dictManager.dicts[dictId]!.path)}/$path");
        data = await file.readAsBytes();
      } else {
        List<ResourceData> results;
        results = await dictManager.dicts[dictId]!.readResource(path);

        if (results.isEmpty) {
          // Find resource under directory if resource is not in mdd
          final file = File(
            "${dirname(dictManager.dicts[dictId]!.path)}/$path",
          );
          data = await file.readAsBytes();
          return WebResourceResponse(
              data: data, contentType: lookupMimeType(path));
        }

        for (var i = 0; i < results.length;) {
          final result = results[i];
          final info = RecordOffsetInfo(
            result.key,
            result.blockOffset,
            result.startOffset,
            result.endOffset,
            result.compressedSize,
          );
          try {
            if (result.part == null) {
              data = await dictManager.dicts[dictId]!.readerResources[0]
                  .readOneMdd(info) as Uint8List;
            } else {
              data = await dictManager
                  .dicts[dictId]!.readerResources[result.part!]
                  .readOneMdd(info) as Uint8List;
            }
            break;
          } on FileSystemException catch (_) {
            await Future.delayed(const Duration(milliseconds: 50));
            continue;
          } catch (e) {
            i++;
            continue;
          }
        }
      }
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}

class WebviewAndroid extends StatefulWidget {
  final String content;
  final int dictId;
  final bool isExpansion;

  const WebviewAndroid({
    super.key,
    required this.content,
    required this.dictId,
    required this.isExpansion,
  });

  @override
  State<WebviewAndroid> createState() => _WebviewAndroidState();
}

class _WebviewAndroidState extends State<WebviewAndroid> {
  double height = 0;

  @override
  Widget build(BuildContext context) {
    final isLightTheme = settings.themeMode == ThemeMode.light ||
        settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light;
    final webviewSettings = InAppWebViewSettings(
      useWideViewPort: false,
      algorithmicDarkeningAllowed: !isLightTheme,
      resourceCustomSchemes: ["entry", "sound"],
      transparentBackground: true,
      webViewAssetLoader: WebViewAssetLoader(
        domain: "ciyue.internal",
        httpAllowed: true,
        pathHandlers: [
          LocalResourcesPathHandler(path: "/", dictId: widget.dictId)
        ],
      ),
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
          },
        ),
        ContextMenuItem(
          id: 2,
          title: locale.lookup,
          action: () async {
            context.push("/word", extra: {"word": selectedText});
          },
        ),
        ContextMenuItem(
          id: 3,
          title: locale.readLoudly,
          action: () async {
            await webViewController!.clearFocus();
            if (context.mounted) {
              await playSoundOfWord(
                selectedText,
                context.read<AudioModel>().mddAudioList,
              );
            }
          },
        ),
      ],
      onCreateContextMenu: (hitTestResult) async {
        selectedText = await webViewController?.getSelectedText() ?? "";
      },
    );

    final webview = InAppWebView(
      initialData: InAppWebViewInitialData(
        data: widget.content,
        baseUrl: WebUri("http://ciyue.internal/"),
      ),
      initialSettings: webviewSettings,
      contextMenu: contextMenu,
      gestureRecognizers: {
        // Flutter inappwebview scroll not working inside the NestedScrollView TabBarView
        // https://stackoverflow.com/a/67345391
        if (!widget.isExpansion)
          Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(),
          ),
        Factory<LongPressGestureRecognizer>(() => LongPressGestureRecognizer(
              duration: Duration(milliseconds: 200),
            )),
      },
      onLoadResourceWithCustomScheme:
          onLoadResourceWithCustomSchemeWarpper(widget.dictId),
      shouldOverrideUrlLoading:
          shouldOverrideUrlLoadingWarpper(widget.dictId, context),
      onWebViewCreated: (controller) async {
        webViewController = controller;

        if (widget.isExpansion) {
          controller.addJavaScriptHandler(
            handlerName: "WebViewHeight",
            callback: (args) {
              double newHeight = args[0].toDouble();
              setState(() {
                height = newHeight;
              });
            },
          );
        }
      },
      onPageCommitVisible: (controller, url) async {
        controller.evaluateJavascript(source: """
var lastHeight = 0;
function checkHeight() {
  var currentHeight = document.body.scrollHeight;
  if (currentHeight !== lastHeight) {
    lastHeight = currentHeight;
    window.flutter_inappwebview.callHandler('WebViewHeight', currentHeight);
  }
  requestAnimationFrame(checkHeight);
}
checkHeight();
""");

        if (dictManager.dicts[widget.dictId]!.fontName != null) {
          await controller.evaluateJavascript(
            source: """
      const font = new FontFace('Custom Font', 'url(/${dictManager.dicts[widget.dictId]!.fontName})');
      font.load();
      document.fonts.add(font);
      document.body.style.fontFamily = 'Custom Font';
            """,
          );
        }
      },
    );

    if (widget.isExpansion) {
      return SizedBox(
        height: height,
        child: webview,
      );
    } else {
      return webview;
    }
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
        appBar: AppBar(),
        body: WebviewAndroid(
          content: html,
          dictId: dictId,
          isExpansion: false,
        ),
      );
    } else {
      final html = getDescriptionFromInactiveDict();
      return FutureBuilder(
        future: html,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(),
              body: WebviewAndroid(
                content: snapshot.data!,
                dictId: dictId,
                isExpansion: false,
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      );
    }
  }

  Future<String> getDescriptionFromInactiveDict() async {
    final dict = Mdict(path: await dictionaryListDao.getPath(dictId));
    await dict.initOnlyMetadata(dict.id);
    final html = dict.reader.header["Description"]!;
    await dict.close();
    return HtmlUnescape().convert(html);
  }
}

class WebviewWindows extends StatelessWidget {
  final String content;
  final int dictId;

  const WebviewWindows({
    super.key,
    required this.content,
    required this.dictId,
  });

  @override
  Widget build(BuildContext context) {
    final port = dictManager.dicts[dictId]!.port;
    final url = "http://localhost:$port/";

    final Uint8List postData = Uint8List.fromList(
      utf8.encode(json.encode({"content": content})),
    );
    return FutureBuilder(
      future: WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: windowsWebview2Directory,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return InAppWebView(
            webViewEnvironment: snapshot.data,
            initialUrlRequest: URLRequest(
              url: WebUri(url),
              method: "POST",
              body: postData,
            ),
            initialData: InAppWebViewInitialData(
              data: content,
              baseUrl: WebUri(url),
            ),
            onLoadResourceWithCustomScheme:
                onLoadResourceWithCustomSchemeWarpper(dictId),
            shouldOverrideUrlLoading:
                shouldOverrideUrlLoadingWarpper(dictId, context),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class WordDisplay extends StatefulWidget {
  final String word;

  const WordDisplay({super.key, required this.word});

  @override
  State<WordDisplay> createState() => _WordDisplayState();
}

class _WordDisplayState extends State<WordDisplay> {
  List<int> validDictIds = [];

  @override
  void initState() {
    super.initState();

    _validDictionaryIds();
  }

  @override
  Widget build(BuildContext context) {
    if (validDictIds.isEmpty) {
      return Scaffold(
        appBar: buildAppBar(context, false),
        body: Center(
            child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        )),
      );
    }

    if (!(validDictIds.isNotEmpty || settings.aiExplainWord)) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context)!.notFound,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      );
    }

    final dictsLength =
        settings.aiExplainWord ? validDictIds.length + 1 : validDictIds.length;
    final showTab = dictsLength > 1;

    if (!showTab) {
      return ChangeNotifierProvider(
        create: (_) => AIExplanationModel(),
        child: Scaffold(
          appBar: buildAppBar(context, showTab),
          floatingActionButton: Button(
            word: widget.word,
            showAIButtons: settings.aiExplainWord,
          ),
          body: settings.aiExplainWord
              ? AIExplainView(word: widget.word)
              : buildWebView(validDictIds[0]),
        ),
      );
    }

    if (settings.dictionarySwitchStyle == DictionarySwitchStyle.tag) {
      return ChangeNotifierProvider(
        create: (_) => AIExplanationModel(),
        child: DefaultTabController(
          initialIndex: 0,
          length: dictsLength,
          child: Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);
              return Scaffold(
                appBar: buildAppBar(context, showTab),
                floatingActionButton: ListenableBuilder(
                  listenable: tabController,
                  builder: (context, child) {
                    final isAIExplainTabSelected =
                        settings.aiExplainWord && tabController.index == 0;
                    return Button(
                      word: widget.word,
                      showAIButtons: isAIExplainTabSelected,
                    );
                  },
                ),
                body: Column(
                  children: [
                    Expanded(
                      child: buildTabView(
                        context,
                        validDictIds: validDictIds,
                      ),
                    ),
                    if (settings.tabBarPosition == TabBarPosition.bottom &&
                        showTab)
                      buildTabBar(context),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => AIExplanationModel(),
      child: ExpansionWordDisplay(
        word: widget.word,
        validDictIds: validDictIds,
      ),
    );
  }

  AppBar buildAppBar(BuildContext context, bool showTab) {
    return AppBar(
      leading: BackButton(
        onPressed: () => context.go("/"),
      ),
      title: _buildTitle(widget.word),
      bottom: (showTab && settings.tabBarPosition == TabBarPosition.top)
          ? buildTabBar(context)
          : null,
    );
  }

  PreferredSizeWidget buildTabBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: FutureBuilder(
        future: Future.wait([
          for (final id in dictManager.dictIds)
            dictManager.dicts[id]!.wordExist(widget.word),
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
                    Tab(text: dictManager.dicts[dictManager.dictIds[i]]!.title),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget buildTabView(
    BuildContext context, {
    List<int> validDictIds = const [],
  }) {
    final children = <Widget>[
      if (settings.aiExplainWord)
        _KeepAlive(
          key: const ValueKey("ai_tab"),
          child: AIExplainView(
            word: widget.word,
            key: ValueKey(
              context
                  .select<AIExplanationModel, int>((model) => model.refreshKey),
            ),
          ),
        ),
      for (final id in validDictIds)
        _KeepAlive(
          key: ValueKey("dict_$id"),
          child: buildWebView(id),
        ),
    ];
    return TabBarView(children: children);
  }

  Widget buildWebView(int id) {
    return _buildWebView(widget.word, id, false);
  }

  Future<void> _validDictionaryIds() async {
    for (final id in dictManager.dictIds) {
      if (await dictManager.dicts[id]!.wordExist(widget.word)) {
        validDictIds.add(id);
      }
    }

    setState(() {});
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
        if (widget.showAIButtons) RefreshAIExplainButton(word: widget.word),
        if (widget.showAIButtons)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: EditAIExplainButton(
              word: widget.word,
              initialExplanation:
                  context.watch<AIExplanationModel>().explanation ?? "",
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: buildReadLoudlyButton(context, widget.word),
        ),
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
      heroTag: "readLoudly_$word",
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
            heroTag: "star_${widget.word}",
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.surface,
            child: const Icon(Icons.star_outline),
            onPressed: () {},
          );
        }

        return FloatingActionButton.small(
          heroTag: "star_${widget.word}",
          foregroundColor: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(snapshot.data! ? Icons.star : Icons.star_outline),
          onPressed: () async {
            Future<void> star() async {
              if (snapshot.data!) {
                await context.read<WordbookModel>().delete(widget.word);
              } else {
                await context.read<WordbookModel>().add(widget.word);
              }

              await autoExport();
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
                          await context
                              .read<WordbookModel>()
                              .removeWordWithAllTags(widget.word);

                          if (context.mounted) {
                            context.pop();
                          }

                          await autoExport();

                          checkStared();
                        },
                      ),
                      TextButton(
                        child: Text(locale.confirm),
                        onPressed: () async {
                          if (!snapshot.data!) {
                            await context
                                .read<WordbookModel>()
                                .add(widget.word);
                          }

                          if (!context.mounted) return;

                          for (final tag in toAdd) {
                            await context
                                .read<WordbookModel>()
                                .add(widget.word, tag: tag);
                          }

                          if (!context.mounted) return;

                          for (final tag in toDel) {
                            await context
                                .read<WordbookModel>()
                                .delete(widget.word, tag: tag);
                          }

                          if (context.mounted) {
                            context.pop();
                          }

                          await autoExport();

                          checkStared();
                        },
                      ),
                    ],
                  );
                },
              );
            } else {
              await star();
            }
          },
        );
      },
    );
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

class RefreshAIExplainButton extends StatelessWidget {
  final String word;

  const RefreshAIExplainButton({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: "refresh_ai_explain_$word",
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.refresh),
      onPressed: () {
        context.read<AIExplanationModel>().refreshExplanation(word);
      },
    );
  }
}

class _KeepAlive extends StatefulWidget {
  final Widget child;

  const _KeepAlive({super.key, required this.child});

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class EditAIExplainButton extends StatelessWidget {
  final String word;
  final String initialExplanation;

  const EditAIExplainButton({
    super.key,
    required this.word,
    required this.initialExplanation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FloatingActionButton.small(
      heroTag: "edit_ai_explain_$word",
      foregroundColor: colorScheme.primary,
      backgroundColor: colorScheme.primaryContainer,
      child: const Icon(Icons.edit),
      onPressed: () {
        context.push(
          "/edit_ai_explanation",
          extra: {
            "word": word,
            "initialExplanation": initialExplanation,
            "aiExplanationModel": context.read<AIExplanationModel>(),
          },
        );
      },
    );
  }
}
