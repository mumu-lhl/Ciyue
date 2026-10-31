import "dart:async";
import "dart:collection";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/entry_anchor.dart";
import "package:ciyue/ui/core/word_display/entry_link_script.dart";
import "package:ciyue/ui/core/word_display/resource_url_script.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";

typedef DesktopWebViewLoad = ({
  InAppWebViewInitialData deferredData,
  InAppWebViewInitialData? initialData,
});

DesktopWebViewLoad desktopWebViewLoad(String content, String baseUrl) {
  return (
    deferredData: InAppWebViewInitialData(
      data: normalizeDictionaryUrls(content),
      baseUrl: WebUri(baseUrl),
    ),
    initialData: null,
  );
}

/// The POST body the Windows WebView uses to load dictionary content: the
/// whole HTML JSON-encoded under the `content` key, as served by the
/// dictionary's loopback server.
Uint8List windowsContentPostBody(String content) {
  return Uint8List.fromList(utf8.encode(json.encode({"content": content})));
}

/// Builds the POST request the Windows WebView uses to load dictionary
/// content. Windows cannot reload through [InAppWebViewController.loadData]:
/// the WebView2 backend implements it as `NavigateToString`, which has no
/// base URL, so relative `res/` resource links would not resolve. The
/// initial load therefore POSTs the content to the dictionary's loopback
/// server, and content updates must use the same request.
URLRequest windowsContentPostRequest(String content, String baseUrl) {
  return URLRequest(
    url: WebUri(baseUrl),
    method: "POST",
    body: windowsContentPostBody(content),
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

/// Cache for the DarkReader wrapper script. The 346KB `darkReaderSource` is
/// loaded once and reused as the same String instance, so an identity check
/// avoids re-interpolating it on every WebView build.
String? _cachedDarkReaderSource;
String? _cachedDarkReaderScript;

String _darkReaderScript(String darkReaderSource) {
  if (!identical(_cachedDarkReaderSource, darkReaderSource)) {
    _cachedDarkReaderSource = darkReaderSource;
    _cachedDarkReaderScript =
        """
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
""";
  }
  return _cachedDarkReaderScript!;
}

UnmodifiableListView<UserScript> dictionaryUserScripts({
  String customCss = "",
  Color? background,
  bool enableDarkReader = false,
  String darkReaderSource = "",
  bool isDarkTheme = false,
}) {
  // Tell the page which theme the app is in: the WebView's own night mode
  // follows the OS, not the app, so dictionary stylesheets cannot react to
  // the in-app theme through prefers-color-scheme. They can key off this
  // class instead: `html.ciyue-dark { ... }`.
  final themeScript =
      """
(function() {
  var dark = ${isDarkTheme ? "true" : "false"};
  function apply() {
    var root = document.documentElement;
    if (!root) return false;
    root.classList.toggle("ciyue-dark", dark);
    return true;
  }
  if (!apply()) {
    var observer = new MutationObserver(function() {
      if (apply()) observer.disconnect();
    });
    observer.observe(document, { childList: true, subtree: true });
  }
})();
""";
  final encodedCss = jsonEncode(customCss);
  final color = background;
  final backgroundColor = color == null
      ? "null"
      : jsonEncode(
          "#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, "0")}",
        );
  final darkReaderScript = enableDarkReader && darkReaderSource.isNotEmpty
      ? _darkReaderScript(darkReaderSource)
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
    UserScript(
      source: resourceUrlScript,
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    ),
    UserScript(
      source: themeScript,
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

/// Scrolls the loaded page to [anchor].
///
/// The anchor target only exists once the document is in the DOM, and images
/// or fonts that arrive afterwards can move it, so a miss earns one retry.
/// Beyond that the miss is reported back: polling a page that has no such
/// element would only burn frames.
///
/// Returns whether the element was found (and scrolled).
Future<bool> _scrollToAnchor(
  InAppWebViewController controller,
  String anchor, {
  int attempt = 0,
}) async {
  var found = false;
  try {
    found =
        await controller.evaluateJavascript(
          source: scrollToAnchorScript(anchor),
        ) ==
        true;
  } catch (e) {
    talker.warning("Failed to scroll to anchor $anchor: $e");
  }
  if (found || attempt >= 1) return found;
  await Future<void>.delayed(const Duration(milliseconds: 150));
  return _scrollToAnchor(controller, anchor, attempt: attempt + 1);
}

/// Applies [anchor] to the entry rendered by [dictId] and consumes the pending
/// request, so a rebuild does not scroll the entry a second time.
///
/// The request is only consumed when the anchor was actually found. A group can
/// answer one headword from several dictionaries, and the sibling entries are
/// built at the same time; dropping the request on a miss would let a
/// dictionary that has the headword but not the anchor take it away from the
/// entry that does have it.
Future<void> _applyPendingAnchor(
  InAppWebViewController controller,
  WidgetRef ref,
  int dictId,
  String word,
  String? anchor,
) async {
  if (anchor == null || anchor.isEmpty) return;
  final found = await _scrollToAnchor(controller, anchor);
  if (!found) return;
  try {
    final pending = ref.read(pendingAnchorProvider);
    if (pending?.word == word &&
        pending?.dictId == dictId &&
        pending?.anchor == anchor) {
      ref.read(pendingAnchorProvider.notifier).clear();
    }
  } catch (_) {
    // The widget was disposed while the scroll was in flight; dropping the
    // request is harmless, a later entry can ask for its own anchor.
  }
}

class WebviewAndroid extends ConsumerStatefulWidget {
  final String word;
  final String content;
  final int dictId;
  final bool isExpansion;

  /// Entry anchor to scroll to once the page has loaded, if any.
  final String? anchor;

  const WebviewAndroid({
    super.key,
    this.word = "",
    required this.content,
    required this.dictId,
    required this.isExpansion,
    this.anchor,
  });

  @override
  ConsumerState<WebviewAndroid> createState() => _WebviewAndroidState();
}

class _WebviewAndroidState extends ConsumerState<WebviewAndroid> {
  InAppWebViewController? _webViewController;
  String _selectedText = "";

  @override
  void didUpdateWidget(WebviewAndroid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the word/content changes, reload the WebView with new data.
    // Without this, the WebView keeps showing the previous word's content
    // (initialData is only used at creation time).
    if (widget.content != oldWidget.content && _webViewController != null) {
      _webViewController!.loadData(
        // A reload has to be normalised like the initial load. Without this,
        // `sound://` and `bword://` links lose their rewriting every time the
        // word changes, and an entry shown on the second lookup stops playing
        // its audio while the same entry played fine right after startup.
        data: normalizeDictionaryUrls(widget.content),
        mimeType: "text/html",
        encoding: "utf-8",
        baseUrl: WebUri("http://ciyue.internal/"),
      );
      return;
    }

    // The same entry can be asked to scroll again, because a second anchor
    // link was tapped without the content changing; there is no reload whose
    // completion could carry the anchor.
    if (widget.anchor != oldWidget.anchor && widget.anchor != null) {
      final controller = _webViewController;
      if (controller != null) {
        unawaited(
          _applyPendingAnchor(
            controller,
            ref,
            widget.dictId,
            widget.word,
            widget.anchor,
          ),
        );
      }
    }
  }

  // Memoized build objects (3.8): avoid recreating on every build.
  InAppWebViewSettings? _cachedSettings;
  bool? _cachedIsLightTheme;
  int? _cachedSettingsDictId;
  ContextMenu? _cachedContextMenu;
  String? _cachedMenuLocaleKey;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final dictManager = ref.watch(dictManagerProvider);
    final height =
        ref.watch(
          webviewHeightsProvider.select(
            (m) => m["${widget.word}:${widget.dictId}"],
          ),
        ) ??
        0;

    final isLightTheme =
        settings.themeMode == ThemeMode.light ||
        settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light;

    // Rebuild settings only when dependencies change.
    var webviewSettings = _cachedSettings;
    if (webviewSettings == null ||
        _cachedIsLightTheme != isLightTheme ||
        _cachedSettingsDictId != widget.dictId) {
      webviewSettings = InAppWebViewSettings(
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
      _cachedSettings = webviewSettings;
      _cachedIsLightTheme = isLightTheme;
      _cachedSettingsDictId = widget.dictId;
    }

    final locale = AppLocalizations.of(context)!;
    final localeKey = "${locale.copy}|${locale.lookup}|${locale.readLoudly}";

    // Rebuild context menu only when locale strings change.
    var contextMenu = _cachedContextMenu;
    if (contextMenu == null || _cachedMenuLocaleKey != localeKey) {
      contextMenu = ContextMenu(
        settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
        menuItems: [
          ContextMenuItem(
            id: 1,
            title: locale.copy,
            action: () async {
              await _webViewController!.clearFocus();
              Clipboard.setData(ClipboardData(text: _selectedText));
            },
          ),
          ContextMenuItem(
            id: 2,
            title: locale.lookup,
            action: () async {
              context.push(
                "/word/${Uri.encodeComponent(_selectedText)}?dictId=${widget.dictId}",
              );
            },
          ),
          ContextMenuItem(
            id: 3,
            title: locale.readLoudly,
            action: () async {
              await _webViewController!.clearFocus();
              if (context.mounted) {
                await playSoundOfWord(
                  _selectedText,
                  ref.read(audioModelProvider).mddAudioList,
                );
              }
            },
          ),
        ],
        onCreateContextMenu: (hitTestResult) async {
          _selectedText = await _webViewController?.getSelectedText() ?? "";
        },
      );
      _cachedContextMenu = contextMenu;
      _cachedMenuLocaleKey = localeKey;
    }

    final webview = InAppWebView(
      initialUserScripts: dictionaryUserScripts(
        customCss: settings.dictionaryCustomCss,
        background: settings.dictionaryBackgroundColor,
        isDarkTheme: !isLightTheme,
      ),
      initialData: InAppWebViewInitialData(
        data: normalizeDictionaryUrls(widget.content),
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
      onLoadStop: (controller, url) async {
        await _applyPendingAnchor(
          controller,
          ref,
          widget.dictId,
          widget.word,
          widget.anchor,
        );
      },
      onWebViewCreated: (controller) async {
        _webViewController = controller;

        controller.addJavaScriptHandler(
          handlerName: "openInNewTab",
          callback: (args) {
            if (args.isNotEmpty && args[0] is String) {
              handleOpenWordNavigation(
                context,
                args[0] as String,
                newTab: true,
                dictId: widget.dictId,
              );
            }
          },
        );

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
        // Only the expansion panels need live height reports, and only they
        // register the 'WebViewHeight' handler. Use MutationObserver +
        // ResizeObserver instead of a requestAnimationFrame loop so there is
        // zero JS cost once the content settles (images/fonts loading late
        // still trigger an update via these observers).
        if (widget.isExpansion) {
          controller.evaluateJavascript(
            source: """
(function() {
  if (!document.body) return;
  var lastHeight = 0;
  function reportHeight() {
    var currentHeight = document.body.scrollHeight;
    if (currentHeight !== lastHeight) {
      lastHeight = currentHeight;
      window.flutter_inappwebview.callHandler('WebViewHeight', currentHeight);
    }
  }
  new MutationObserver(reportHeight).observe(document.body, {
    childList: true, subtree: true, attributes: true, characterData: true
  });
  if (window.ResizeObserver) {
    new ResizeObserver(reportHeight).observe(document.body);
  }
  reportHeight();
})();
""",
          );
        }

        final loadedDict = dictManager.dicts[widget.dictId];
        if (loadedDict is Mdict && loadedDict.fontName != null) {
          await controller.evaluateJavascript(
            source:
                """
const font = new FontFace('Custom Font', 'url(/${loadedDict.fontName})');
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

  Widget _buildDescription(LoadedDictionary dict) {
    var html = dict.description;
    html = HtmlUnescape().convert(html);
    html = dict.wrapContentWithResources(html);

    return Scaffold(
      appBar: AppBar(),
      body: WebviewAndroid(content: html, dictId: dictId, isExpansion: false),
    );
  }

  Future<String> getDescriptionFromInactiveDict() async {
    final path = await dictionaryListDao.getPath(dictId);
    if (path == null) {
      return "";
    }
    final type = await dictionaryListDao.getType(dictId);
    final dict = createLoadedDictionary(path: path, type: type);
    await dict.initOnlyMetadata(dictId);
    var html = dict.description;
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

class WebviewWindows extends ConsumerStatefulWidget {
  final String word;
  final String content;
  final int dictId;
  final bool isExpansion;

  /// Entry anchor to scroll to once the page has loaded, if any.
  final String? anchor;

  const WebviewWindows({
    super.key,
    this.word = "",
    required this.content,
    required this.dictId,
    this.isExpansion = false,
    this.anchor,
  });

  @override
  ConsumerState<WebviewWindows> createState() => _WebviewWindowsState();
}

class _WebviewWindowsState extends ConsumerState<WebviewWindows> {
  Uint8List? _postData;
  String? _postDataContent;
  InAppWebViewController? _desktopController;
  Future<void> _desktopContentLoad = Future<void>.value();

  @override
  void didUpdateWidget(WebviewWindows oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contentChanged =
        widget.content != oldWidget.content ||
        widget.dictId != oldWidget.dictId;
    if (contentChanged) {
      final controller = _desktopController;
      if (controller != null) {
        unawaited(_scheduleDesktopContentLoad(controller));
      }
      return;
    }

    // A new anchor for the entry already on screen: no reload will happen, so
    // the scroll is applied straight away.
    if (widget.anchor != oldWidget.anchor && widget.anchor != null) {
      final controller = _desktopController;
      if (controller != null) {
        unawaited(
          _applyPendingAnchor(
            controller,
            ref,
            widget.dictId,
            widget.word,
            widget.anchor,
          ),
        );
      }
    }
  }

  Future<void> _scheduleDesktopContentLoad(InAppWebViewController controller) {
    final requestedContent = widget.content;
    final requestedDictId = widget.dictId;
    final load = _desktopContentLoad
        .catchError((Object error) {
          talker.warning("Previous dictionary content load failed: $error");
        })
        .then((_) async {
          if (!mounted ||
              !identical(_desktopController, controller) ||
              requestedContent != widget.content ||
              requestedDictId != widget.dictId) {
            return;
          }

          final dict = ref.read(dictManagerProvider).dicts[requestedDictId];
          if (dict == null || dict.port == 0) return;
          final baseUrl = "http://127.0.0.1:${dict.port}/";
          if (Platform.isWindows) {
            // Same POST request the initial Windows load uses; loadData
            // would drop the base URL on WebView2.
            await controller.loadUrl(
              urlRequest: windowsContentPostRequest(requestedContent, baseUrl),
            );
            return;
          }
          final desktopLoad = desktopWebViewLoad(requestedContent, baseUrl);
          await controller.loadData(
            data: desktopLoad.deferredData.data,
            mimeType: desktopLoad.deferredData.mimeType,
            encoding: desktopLoad.deferredData.encoding,
            baseUrl: desktopLoad.deferredData.baseUrl,
          );
        })
        .catchError((Object error) {
          talker.warning("Failed to update dictionary content: $error");
        });
    _desktopContentLoad = load;
    return load;
  }

  /// Cached future for Windows WebView setup. Creating a new future on every
  /// build causes the FutureBuilder to restart and the WebView to be destroyed
  /// and recreated. Only recreate when useDarkReader changes.
  Future<_WindowsWebViewSetup>? _setupFuture;
  bool? _setupFutureDarkReader;

  /// The POST body is the whole dictionary HTML (up to MBs) JSON-encoded.
  /// Recompute only when the content actually changes, not on every build.
  Uint8List _getPostData() {
    if (_postDataContent != widget.content) {
      _postDataContent = widget.content;
      _postData = windowsContentPostBody(widget.content);
    }
    return _postData!;
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final content = widget.content;
    final dictId = widget.dictId;
    final dictManager = ref.watch(dictManagerProvider);
    final settings = ref.watch(settingsProvider);
    final darkReaderSetting = ref.watch(dictionaryDarkReaderProvider);
    final port = dictManager.dicts[dictId]!.port;
    final Widget webview;

    if (port == 0) {
      webview = const Center(child: CircularProgressIndicator());
    } else {
      final url = "http://127.0.0.1:$port/";

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
              isDarkTheme: !isLightTheme,
            ),
            initialSettings: webviewSettings,
            initialData: load.initialData,
            onLoadResourceWithCustomScheme:
                onLoadResourceWithCustomSchemeWarpper(dictId),
            shouldOverrideUrlLoading: shouldOverrideUrlLoadingWarpper(
              dictId,
              context,
            ),
            onLoadStop: (controller, url) async {
              await _applyPendingAnchor(
                controller,
                ref,
                widget.dictId,
                widget.word,
                widget.anchor,
              );
            },
            onWebViewCreated: (controller) async {
              _desktopController = controller;
              controller.addJavaScriptHandler(
                handlerName: "openInNewTab",
                callback: (args) {
                  if (args.isNotEmpty && args[0] is String) {
                    handleOpenWordNavigation(
                      context,
                      args[0] as String,
                      newTab: true,
                      dictId: dictId,
                    );
                  }
                },
              );
              if (widget.isExpansion) {
                controller.addJavaScriptHandler(
                  handlerName: "WebViewHeight",
                  callback: (args) {
                    double newHeight = (args[0] as num).toDouble();
                    ref
                        .read(webviewHeightsProvider.notifier)
                        .setHeight(widget.word, dictId, newHeight);
                  },
                );
              }
              await _scheduleDesktopContentLoad(controller);
            },
            onPageCommitVisible: (controller, url) async {
              // Report content height for expansion panels so the WebView is
              // sized to its content (like Android). This avoids nested scrolling
              // (WebView internal scroll + Flutter outer scroll fighting).
              if (widget.isExpansion) {
                controller.evaluateJavascript(
                  source: """
(function() {
  if (!document.body) return;
  var lastHeight = 0;
  var isMouseDown = false;
  window.addEventListener('mousedown', function() { isMouseDown = true; }, true);
  window.addEventListener('mouseup', function() {
    if (isMouseDown) {
      isMouseDown = false;
      reportHeight();
    }
  }, true);
  function reportHeight() {
    if (isMouseDown) return;
    var currentHeight = document.body.scrollHeight;
    // Only report if changed by more than 2px to avoid micro-oscillation
    // feedback loops (resize -> relayout -> slightly different height).
    if (Math.abs(currentHeight - lastHeight) > 2) {
      lastHeight = currentHeight;
      window.flutter_inappwebview.callHandler('WebViewHeight', currentHeight);
    }
  }
  new MutationObserver(reportHeight).observe(document.body, {
    childList: true, subtree: true, attributes: true, characterData: true
  });
  if (window.ResizeObserver) {
    new ResizeObserver(reportHeight).observe(document.body);
  }
  reportHeight();
})();
""",
                );
              }
            },
            onRenderProcessGone: (controller, detail) async {
              talker.warning("InAppWebView render process gone, reloading...");
              await controller.reload();
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
        // Cache the setup future to avoid recreating the WebView on every
        // rebuild. Only recreate when useDarkReader changes.
        if (_setupFuture == null || _setupFutureDarkReader != useDarkReader) {
          _setupFutureDarkReader = useDarkReader;
          _setupFuture = _prepareWindowsWebView(useDarkReader: useDarkReader);
        }
        webview = FutureBuilder<_WindowsWebViewSetup>(
          future: _setupFuture,
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
                  isDarkTheme: !isLightTheme,
                ),
                webViewEnvironment: snapshot.data?.environment,
                initialSettings: webviewSettings,
                initialUrlRequest: URLRequest(
                  url: WebUri(url),
                  method: "POST",
                  body: _getPostData(),
                ),
                initialData: InAppWebViewInitialData(
                  data: normalizeDictionaryUrls(content),
                  baseUrl: WebUri(url),
                ),
                onLoadResourceWithCustomScheme:
                    onLoadResourceWithCustomSchemeWarpper(dictId),
                shouldOverrideUrlLoading: shouldOverrideUrlLoadingWarpper(
                  dictId,
                  context,
                ),
                onLoadStop: (controller, url) async {
                  await _applyPendingAnchor(
                    controller,
                    ref,
                    widget.dictId,
                    widget.word,
                    widget.anchor,
                  );
                },
                onWebViewCreated: (controller) async {
                  // The initial load is covered by initialUrlRequest; keep
                  // the controller so didUpdateWidget can reload content
                  // through the same POST request.
                  _desktopController = controller;
                  controller.addJavaScriptHandler(
                    handlerName: "openInNewTab",
                    callback: (args) {
                      if (args.isNotEmpty && args[0] is String) {
                        handleOpenWordNavigation(
                          context,
                          args[0] as String,
                          newTab: true,
                          dictId: dictId,
                        );
                      }
                    },
                  );
                },
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      }
    }

    // In expansion mode, size the WebView to its content height (reported via
    // JS) so only the outer Flutter SingleChildScrollView scrolls. This avoids
    // nested scrolling where the WebView's internal scroll fights the outer
    // scroll, causing rapid jitter on tall pages.
    // In non-expansion mode (full page), constrain to screen height and let
    // the WebView scroll internally.
    if (widget.isExpansion) {
      final height =
          ref.watch(
            webviewHeightsProvider.select(
              (m) => m["${widget.word}:${widget.dictId}"],
            ),
          ) ??
          0;
      // ExpansionPanelList gives unbounded height; the Linux platform view
      // uses SizedBox.expand internally so it needs a finite constraint.
      // Use at least 1 to avoid zero-size issues before JS reports height.
      return SizedBox(height: height > 0 ? height : 1, child: webview);
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height),
      child: webview,
    );
  }
}
