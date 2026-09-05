import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/entry_link_script.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:provider/provider.dart" as legacy_provider;

typedef DesktopWebViewLoad = ({
  InAppWebViewInitialData deferredData,
  InAppWebViewInitialData? initialData,
});

DesktopWebViewLoad desktopWebViewLoad(String content, String baseUrl) {
  return (
    deferredData: InAppWebViewInitialData(
      data: content,
      baseUrl: WebUri(baseUrl),
    ),
    initialData: null,
  );
}

UnmodifiableListView<UserScript> dictionaryUserScripts() {
  return UnmodifiableListView([
    UserScript(
      source: dictionaryEntryLinkScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    ),
  ]);
}

class WebviewAndroid extends ConsumerStatefulWidget {
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
  ConsumerState<WebviewAndroid> createState() => _WebviewAndroidState();
}

class _WebviewAndroidState extends ConsumerState<WebviewAndroid> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final dictManager = ref.watch(dictManagerProvider);
    final heights = ref.watch(webviewHeightsProvider);
    final height = heights[widget.dictId] ?? 0;

    final isLightTheme =
        settings.themeMode == ThemeMode.light ||
        settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light;
    final webviewSettings = InAppWebViewSettings(
      useWideViewPort: false,
      algorithmicDarkeningAllowed: !isLightTheme,
      resourceCustomSchemes: ["entry", "sound"],
      transparentBackground: true,
      useHybridComposition: true,
      webViewAssetLoader: WebViewAssetLoader(
        domain: "ciyue.internal",
        httpAllowed: true,
        pathHandlers: [
          LocalResourcesPathHandler(path: "/", dictId: widget.dictId),
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
            context.push("/word/${Uri.encodeComponent(selectedText)}");
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
                legacy_provider.Provider.of<AudioModel>(
                  context,
                  listen: false,
                ).mddAudioList,
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
      initialUserScripts: dictionaryUserScripts(),
      initialData: InAppWebViewInitialData(
        data: widget.content,
        baseUrl: WebUri("http://ciyue.internal/"),
      ),
      initialSettings: webviewSettings,
      contextMenu: contextMenu,
      gestureRecognizers: {
        if (!widget.isExpansion)
          Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer(),
          ),
        Factory<LongPressGestureRecognizer>(
          () =>
              LongPressGestureRecognizer(duration: Duration(milliseconds: 200)),
        ),
      },
      onLoadResourceWithCustomScheme: onLoadResourceWithCustomSchemeWarpper(
        widget.dictId,
      ),
      shouldOverrideUrlLoading: shouldOverrideUrlLoadingWarpper(
        widget.dictId,
        context,
      ),
      onWebViewCreated: (controller) async {
        webViewController = controller;

        if (widget.isExpansion) {
          controller.addJavaScriptHandler(
            handlerName: "WebViewHeight",
            callback: (args) {
              double newHeight = args[0].toDouble();
              ref
                  .read(webviewHeightsProvider.notifier)
                  .setHeight(widget.dictId, newHeight);
            },
          );
        }
      },
      onPageCommitVisible: (controller, url) async {
        controller.evaluateJavascript(
          source: """
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
""",
        );

        if (dictManager.dicts[widget.dictId]!.fontName != null) {
          await controller.evaluateJavascript(
            source:
                """
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
      return SizedBox(height: height, child: webview);
    } else {
      return webview;
    }
  }
}

class WebviewDisplayDescription extends ConsumerWidget {
  final int dictId;

  const WebviewDisplayDescription({super.key, required this.dictId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictManager = ref.watch(dictManagerProvider);
    final dict = dictManager.dicts[dictId];
    if (dict != null) {
      return FutureBuilder<void>(
        future: dict.waitForLoading(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          return _buildDescription(dict);
        },
      );
    }

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

  Widget _buildDescription(Mdict dict) {
    var html = dict.reader.header["Description"]!;
    html = HtmlUnescape().convert(html);
    html = dict.wrapContentWithResources(html);

    return Scaffold(
      appBar: AppBar(),
      body: WebviewAndroid(content: html, dictId: dictId, isExpansion: false),
    );
  }

  Future<String> getDescriptionFromInactiveDict() async {
    final dict = Mdict(path: await dictionaryListDao.getPath(dictId));
    await dict.initOnlyMetadata(dictId);
    var html = dict.reader.header["Description"]!;
    html = HtmlUnescape().convert(html);
    html = dict.wrapContentWithResources(html);
    await dict.close();
    return html;
  }
}

class WebviewWindows extends ConsumerWidget {
  final String content;
  final int dictId;

  const WebviewWindows({
    super.key,
    required this.content,
    required this.dictId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictManager = ref.watch(dictManagerProvider);
    final settings = ref.watch(settingsProvider);
    final port = dictManager.dicts[dictId]!.port;
    final Widget webview;

    if (port == 0) {
      webview = const Center(child: CircularProgressIndicator());
    } else {
      final url = "http://127.0.0.1:$port/";

      final Uint8List postData = Uint8List.fromList(
        utf8.encode(json.encode({"content": content})),
      );

      final isLightTheme =
          settings.themeMode == ThemeMode.light ||
          settings.themeMode == ThemeMode.system &&
              MediaQuery.of(context).platformBrightness == Brightness.light;

      final webviewSettings = InAppWebViewSettings(
        useWideViewPort: false,
        algorithmicDarkeningAllowed: !isLightTheme,
        resourceCustomSchemes: ["entry", "sound"],
        transparentBackground: true,
      );

      // macOS uses the same local-server load path as Linux; only Windows
      // loads through a WebView2 environment.
      if (!Platform.isWindows) {
        final load = desktopWebViewLoad(content, url);
        webview = InAppWebView(
          initialUserScripts: dictionaryUserScripts(),
          initialSettings: webviewSettings,
          initialData: load.initialData,
          onLoadResourceWithCustomScheme: onLoadResourceWithCustomSchemeWarpper(
            dictId,
          ),
          shouldOverrideUrlLoading: shouldOverrideUrlLoadingWarpper(
            dictId,
            context,
          ),
          onWebViewCreated: (controller) async {
            await controller.loadData(
              data: load.deferredData.data,
              mimeType: load.deferredData.mimeType,
              encoding: load.deferredData.encoding,
              baseUrl: load.deferredData.baseUrl,
            );
          },
        );
      } else {
        webview = FutureBuilder(
          future: WebViewEnvironment.create(
            settings: WebViewEnvironmentSettings(
              userDataFolder: windowsWebview2Directory,
            ),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData || snapshot.hasError) {
              return InAppWebView(
                initialUserScripts: dictionaryUserScripts(),
                webViewEnvironment: snapshot.data,
                initialSettings: webviewSettings,
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
                shouldOverrideUrlLoading: shouldOverrideUrlLoadingWarpper(
                  dictId,
                  context,
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      }
    }

    // ExpansionPanelList lays out panel bodies with unbounded height. The
    // Linux platform view uses SizedBox.expand internally, so it must receive
    // a finite constraint; the WebView can scroll its own content.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height),
      child: webview,
    );
  }
}
