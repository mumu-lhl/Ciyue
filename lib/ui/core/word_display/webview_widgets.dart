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

/// Enable Dark Reader only on supported platforms in dark mode, and only when
/// the user has not chosen a custom dictionary background.
bool shouldUseDarkReaderForDictionary({
  required bool isWindows,
  required bool isLinux,
  required bool isLightTheme,
  required bool enabled,
  required bool hasCustomBackground,
}) {
  return (isWindows || isLinux) &&
      !isLightTheme &&
      enabled &&
      !hasCustomBackground;
}

Color? resolveDictionaryBackgroundColor({
  required bool isWindows,
  required bool isLightTheme,
  required Color? customColor,
  bool darkReaderEnabled = false,
}) {
  if (customColor != null) return customColor;
  return isWindows && !isLightTheme && !darkReaderEnabled ? Colors.white : null;
}

UnmodifiableListView<UserScript> dictionaryUserScripts({
  String customCss = "",
  Color? background,
  bool enableDarkReader = false,
  String darkReaderSource = "",
}) {
  final encodedCss = jsonEncode(customCss);
  final color = background;
  final backgroundColor = color == null
      ? "null"
      : jsonEncode(
          "#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, "0")}",
        );
  final darkReaderScript = enableDarkReader && darkReaderSource.isNotEmpty
      ? """
$darkReaderSource
(function() {
  const darkReader = window.DarkReader;
  if (darkReader && !darkReader.isEnabled()) {
    darkReader.enable({
      mode: 1,
      brightness: 100,
      contrast: 100,
      sepia: 0,
      darkSchemeBackgroundColor: "#181a1b",
      darkSchemeTextColor: "#e8e6e3",
      styleSystemControls: true
    });
  }
})();
"""
      : null;
  final customCssScript =
      """
(function() {
  const css = $encodedCss;
  const backgroundColor = $backgroundColor;
  if (!css && !backgroundColor) return;
  const applyCss = function() {
    const root = document.head || document.documentElement;
    if (!root) return false;
    let style = document.getElementById('ciyue-custom-dictionary-css');
    if (!style) {
      style = document.createElement('style');
      style.id = 'ciyue-custom-dictionary-css';
      root.appendChild(style);
    }
    style.textContent = (backgroundColor
      ? 'html, body { background-color: ' + backgroundColor + ' !important; }'
      : '') + css;
    return true;
  };
  if (!applyCss()) {
    const observer = new MutationObserver(function() {
      if (applyCss()) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
  }
})();
""";

  return UnmodifiableListView([
    UserScript(
      source: dictionaryEntryLinkScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    ),
    if (darkReaderScript != null)
      UserScript(
        source: darkReaderScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
    if (customCss.isNotEmpty || color != null)
      UserScript(
        source: customCssScript,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
      ),
  ]);
}

class WebviewAndroid extends ConsumerStatefulWidget {
  final String word;
  final String content;
  final int dictId;
  final bool isExpansion;

  const WebviewAndroid({
    super.key,
    this.word = "",
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
    final height = heights["${widget.word}:${widget.dictId}"] ?? 0;

    final isLightTheme =
        settings.themeMode == ThemeMode.light ||
        settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light;
    final webviewSettings = InAppWebViewSettings(
      useWideViewPort: false,
      algorithmicDarkeningAllowed: !isLightTheme,
      resourceCustomSchemes: ["entry", "gdlookup", "sound"],
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
            context.push(
              "/word/${Uri.encodeComponent(selectedText)}?dictId=${widget.dictId}",
            );
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
      initialUserScripts: dictionaryUserScripts(
        customCss: settings.dictionaryCustomCss,
        background: settings.dictionaryBackgroundColor,
      ),
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
                  .setHeight(widget.word, widget.dictId, newHeight);
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

typedef _WindowsWebViewSetup = ({
  WebViewEnvironment environment,
  String darkReaderSource,
});

Future<WebViewEnvironment>? _windowsWebViewEnvironmentFuture;
Future<String>? _darkReaderSourceFuture;

Future<String> _loadDarkReaderSource() => _darkReaderSourceFuture ??= rootBundle
    .loadString("assets/third_party/darkreader/darkreader.js");

Future<_WindowsWebViewSetup> _prepareWindowsWebView({
  required bool useDarkReader,
}) async {
  final environment = await (_windowsWebViewEnvironmentFuture ??=
      WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: windowsWebview2Directory,
        ),
      ));
  final darkReaderSource = useDarkReader ? await _loadDarkReaderSource() : "";
  return (environment: environment, darkReaderSource: darkReaderSource);
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
    final darkReaderSetting = ref.watch(dictionaryDarkReaderProvider);
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

      final useDarkReader = shouldUseDarkReaderForDictionary(
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
        isLightTheme: isLightTheme,
        enabled: darkReaderSetting,
        hasCustomBackground: settings.dictionaryBackgroundColor != null,
      );
      final dictionaryBackgroundColor = resolveDictionaryBackgroundColor(
        isWindows: Platform.isWindows,
        isLightTheme: isLightTheme,
        customColor: settings.dictionaryBackgroundColor,
        darkReaderEnabled: useDarkReader,
      );

      final webviewSettings = InAppWebViewSettings(
        useWideViewPort: false,
        algorithmicDarkeningAllowed: !isLightTheme,
        resourceCustomSchemes: ["entry", "gdlookup", "sound"],
        transparentBackground: true,
      );

      // macOS uses the same local-server load path as Linux; only Windows
      // loads through a WebView2 environment.
      if (!Platform.isWindows) {
        final load = desktopWebViewLoad(content, url);

        Widget buildDesktopWebView(String darkReaderSource) {
          final darkReaderReady = useDarkReader && darkReaderSource.isNotEmpty;
          return InAppWebView(
            key: ValueKey("dark-reader-$darkReaderReady"),
            initialUserScripts: dictionaryUserScripts(
              customCss: settings.dictionaryCustomCss,
              background: dictionaryBackgroundColor,
              enableDarkReader: darkReaderReady,
              darkReaderSource: darkReaderSource,
            ),
            initialSettings: webviewSettings,
            initialData: load.initialData,
            onLoadResourceWithCustomScheme:
                onLoadResourceWithCustomSchemeWarpper(dictId),
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
        }

        if (useDarkReader) {
          webview = FutureBuilder<String>(
            future: _loadDarkReaderSource(),
            builder: (context, snapshot) {
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(child: CircularProgressIndicator());
              }
              return buildDesktopWebView(snapshot.data ?? "");
            },
          );
        } else {
          webview = buildDesktopWebView("");
        }
      } else {
        webview = FutureBuilder<_WindowsWebViewSetup>(
          future: _prepareWindowsWebView(useDarkReader: useDarkReader),
          builder: (context, snapshot) {
            if (snapshot.hasData || snapshot.hasError) {
              final darkReaderSource = snapshot.data?.darkReaderSource ?? "";
              final darkReaderReady =
                  useDarkReader && darkReaderSource.isNotEmpty;
              final background = resolveDictionaryBackgroundColor(
                isWindows: true,
                isLightTheme: isLightTheme,
                customColor: settings.dictionaryBackgroundColor,
                darkReaderEnabled: darkReaderReady,
              );
              return InAppWebView(
                key: ValueKey("dark-reader-$darkReaderReady"),
                initialUserScripts: dictionaryUserScripts(
                  customCss: settings.dictionaryCustomCss,
                  background: background,
                  enableDarkReader: darkReaderReady,
                  darkReaderSource: darkReaderSource,
                ),
                webViewEnvironment: snapshot.data?.environment,
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
