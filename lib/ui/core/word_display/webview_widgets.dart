import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/word_display/webview_helpers.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:html_unescape/html_unescape_small.dart";
import "package:provider/provider.dart";

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
      html = dictManager.dicts[dictId]!.wrapContentWithResources(html);

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
    var html = dict.reader.header["Description"]!;
    html = HtmlUnescape().convert(html);
    html = dict.wrapContentWithResources(html);
    await dict.close();
    return html;
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

    if (port == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    final url = "http://127.0.0.1:$port/";

    final Uint8List postData = Uint8List.fromList(
      utf8.encode(json.encode({"content": content})),
    );

    final isLightTheme = settings.themeMode == ThemeMode.light ||
        settings.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.light;

    final webviewSettings = InAppWebViewSettings(
      useWideViewPort: false,
      algorithmicDarkeningAllowed: !isLightTheme,
      resourceCustomSchemes: ["entry", "sound"],
      transparentBackground: true,
    );

    if (Platform.isLinux) {
      return InAppWebView(
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
        shouldOverrideUrlLoading:
            shouldOverrideUrlLoadingWarpper(dictId, context),
      );
    }

    return FutureBuilder(
      future: WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: windowsWebview2Directory,
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData || snapshot.hasError) {
          return InAppWebView(
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
            shouldOverrideUrlLoading:
                shouldOverrideUrlLoadingWarpper(dictId, context),
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
