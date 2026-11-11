import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/models/dictionary_links.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/services/text_encoding.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/ai_markdown.dart";
import "package:ciyue/ui/core/word_display/entry_anchor.dart";
import "package:ciyue/utils.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

export "package:ciyue/models/dictionary_links.dart"
    show entryLinkHref, normalizeDictionaryUrls;

DateTime? _lastOpenWordTime;
String? _lastOpenWordName;
String? _lastOpenWordAnchor;
bool? _lastOpenWordIsNewTab;

void handleOpenWordNavigation(
  BuildContext context,
  String rawWord, {
  required bool newTab,
  int? dictId,
  String? anchor,
}) {
  final word = rawWord.trim();
  if (word.isEmpty) return;

  final now = DateTime.now();
  if (_lastOpenWordName == word &&
      _lastOpenWordAnchor == anchor &&
      _lastOpenWordIsNewTab == newTab &&
      _lastOpenWordTime != null &&
      now.difference(_lastOpenWordTime!) < const Duration(milliseconds: 300)) {
    return;
  }
  _lastOpenWordName = word;
  _lastOpenWordAnchor = anchor;
  _lastOpenWordIsNewTab = newTab;
  _lastOpenWordTime = now;

  final navContext = navigatorKey.currentContext ?? context;

  // The anchor is a one-shot scroll request for the entry of the dictionary the
  // link came from; it deliberately stays out of the tab history. A link
  // without an anchor still reports in, which drops a request the page being
  // left behind never used.
  try {
    ProviderScope.containerOf(navContext, listen: false)
        .read(pendingAnchorProvider.notifier)
        .request(word: word, dictId: dictId, anchor: anchor);
  } catch (_) {}

  // Whether the lookup lands on the home page's pane or on the page that is
  // on screen is a question about the route, not about the window size: a
  // wide window can still show a pushed entry page, and that page has to
  // show the word that was looked up.
  bool isAlreadyInWordRoute = false;
  try {
    final currentRoute = GoRouterState.of(context).uri.toString();
    isAlreadyInWordRoute = currentRoute.startsWith("/word/");
  } catch (_) {
    isAlreadyInWordRoute = false;
  }

  if (isLargeScreen(context)) {
    if (isAlreadyInWordRoute) {
      // The reader is looking at an entry page of their own, and that is the
      // page the word has to appear on. Handing it to the home page's pane
      // instead would leave the reader staring at the old word until they
      // go back to the home page.
      final query = dictId != null ? "?dictId=$dictId" : "";
      if (context.mounted) {
        context.pushReplacement("/word/${Uri.encodeComponent(word)}$query");
      }
    }
    try {
      final container = ProviderScope.containerOf(navContext, listen: false);
      final homeModel = container.read(homeModelProvider);
      if (newTab) {
        homeModel.openWordInNewTab(word, dictId: dictId);
      } else {
        homeModel.selectedWord = word;
      }
      container.read(openRecordsRepositoryProvider).add(word);
      container.read(historyModelProvider).addHistory(word);
    } catch (_) {}
  } else {
    try {
      final container = ProviderScope.containerOf(navContext, listen: false);
      final homeModel = container.read(homeModelProvider);
      container.read(openRecordsRepositoryProvider).add(word);
      container.read(historyModelProvider).addHistory(word);
      if (newTab) {
        homeModel.openWordInNewTab(word, dictId: dictId);
      } else {
        homeModel.navigateInCurrentTab(word, dictId: dictId);
      }
    } catch (_) {}

    if (!isAlreadyInWordRoute && context.mounted) {
      final query = dictId != null ? "?dictId=$dictId" : "";
      context.push("/word/${Uri.encodeComponent(word)}$query");
    }
  }
}

bool _isEntryUrl(WebUri url) {
  // `bword://` is the Babylon spelling of the same thing; dictionaries
  // converted from `.bgl` use it for their cross references (クラウン独和).
  // The page script normally rewrites it to `entry://`, but a click that never
  // reaches that script would otherwise fall through to the WebView, which has
  // no handler for the scheme and silently ignores the tap.
  return url.scheme == "entry" ||
      url.scheme == "bword" ||
      url.scheme == "ciyue-open-new-tab" ||
      (url.scheme == "gdlookup" && url.host == "localhost");
}

final _entrySchemePrefix = RegExp(r"^(?:entry|bword)://", caseSensitive: false);

/// The target a dictionary link points at: the headword plus its anchor.
///
/// Anchors normally arrive in the `?gdanchor=` query item (see
/// [entryLinkHref]); an `entry://` / `bword://` link the page script never
/// rewrote still carries its anchor after a `#`, so both spellings are read.
@visibleForTesting
EntryLinkTarget wordFromEntryUrl(WebUri url) {
  if (url.scheme == "ciyue-open-new-tab") {
    final raw = url.host.isNotEmpty ? url.host : url.path;
    return EntryLinkTarget(
      word: Uri.decodeComponent(raw.replaceFirst(RegExp(r"^/"), "")),
    );
  }

  if (url.scheme == "gdlookup") {
    final encodedWord = url.path.replaceFirst(RegExp(r"^/"), "");
    final anchor = url.queryParameters["gdanchor"];
    return EntryLinkTarget(
      word: Uri.decodeComponent(encodedWord),
      anchor: (anchor == null || anchor.isEmpty) ? null : anchor,
    );
  }

  // The page script rewrites entry links before navigation, so this branch only
  // runs when a click bypassed it. `toString()` re-encodes a `#` that already
  // sat inside the fragment, so the payload is decoded back before the `##`
  // rules are applied; otherwise `tag##sumeru` would arrive as `tag#%23sumeru`.
  final payload = url.toString().replaceFirst(_entrySchemePrefix, "");
  String decoded;
  try {
    decoded = Uri.decodeComponent(payload);
  } catch (_) {
    decoded = payload;
  }
  return parseEntryLink(decoded);
}

/// The script that scrolls the entry on screen to [anchor].
///
/// `scrollIntoView` is used instead of assigning `location.hash`, which would
/// push a history entry into the WebView's own back stack.
String scrollToAnchorScript(String anchor) =>
    "(function(){var a=${jsonEncode(anchor)};if(!a)return false;"
    "var el=document.getElementById(a)||document.getElementsByName(a)[0];"
    "if(!el)return false;el.scrollIntoView({block:'start'});return true;})()";

/// The file name of a `sound://` link. New pages carry it percent-encoded in
/// the path (`sound://localhost/<file>`); entries that still reach us in the
/// old `sound://<file>` shape keep the historical parsing.
String _soundFileName(WebUri url) {
  if (url.host == "localhost") {
    final path = url.path.replaceFirst(RegExp(r"^/"), "");
    if (path.isEmpty) return "";
    try {
      return Uri.decodeComponent(path);
    } catch (_) {
      return path;
    }
  }
  return Uri.decodeFull(url.toString()).replaceFirst("sound://", "");
}

NavigationActionPolicy navigationPolicyForUrl(WebUri url) {
  if (_isEntryUrl(url) || url.scheme == "sound") {
    return NavigationActionPolicy.CANCEL;
  }
  if (!const {
    "http",
    "https",
    "file",
    "about",
    "blob",
    "data",
    "javascript",
    "mailto",
    "tel",
  }.contains(url.scheme)) {
    talker.info("Unhandled link scheme: ${url.scheme} (${url.toString()})");
  }
  return NavigationActionPolicy.ALLOW;
}

Future<CustomSchemeResponse?> Function(
  InAppWebViewController controller,
  WebResourceRequest request,
)
onLoadResourceWithCustomSchemeWarpper(int dictId) {
  return (controller, request) async {
    final url = request.url;
    if (url.scheme == "sound") {
      final dict = dictManager.dicts[dictId];
      if (dict == null) return null;
      final filename = _soundFileName(url);

      final data = await dict.readResourceFile(filename);
      if (data == null) return null;
      talker.info("Playing sound (2): $filename");
      return CustomSchemeResponse(
        contentType: lookupMimeType(filename) ?? "application/octet-stream",
        data: data,
      );
    }
    return null;
  };
}

Future<NavigationActionPolicy?> Function(
  InAppWebViewController controller,
  NavigationAction navigationAction,
)
shouldOverrideUrlLoadingWarpper(int dictId, BuildContext context) {
  return (controller, navigationAction) async {
    final url = navigationAction.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;

    if (_isEntryUrl(url)) {
      final isNewTab = url.scheme == "ciyue-open-new-tab";
      final target = wordFromEntryUrl(url);
      final anchor = target.anchor;
      talker.info(
        "Entry link: ${url.scheme} -> ${target.word}"
        "${anchor == null ? "" : " #$anchor"}",
      );

      // A link that only names an anchor scrolls the entry already on screen:
      // there is no word to look up and no page to load.
      if (target.word.isEmpty) {
        if (anchor != null) {
          await controller.evaluateJavascript(
            source: scrollToAnchorScript(anchor),
          );
        }
        return NavigationActionPolicy.CANCEL;
      }

      // No lookup check against this one dictionary: the destination page
      // searches the whole group, so a link this file cannot answer may still
      // be answered by a sibling. Navigating anyway also turns a dead link
      // into the usual "not found" page -- with a search bar and this word in
      // it -- instead of a tap that silently does nothing.
      if (context.mounted) {
        handleOpenWordNavigation(
          context,
          target.word,
          newTab: isNewTab,
          dictId: dictId,
          anchor: anchor,
        );
      }
      return NavigationActionPolicy.CANCEL;
    } else if (url.scheme == "sound") {
      final filename = _soundFileName(url);
      if (context.mounted) {
        await playDictionarySound(
          context: context,
          dictId: dictId,
          filename: filename,
        );
      }
      return NavigationActionPolicy.CANCEL;
    }

    // A navigation to this dictionary's own local server is an article, not
    // an external URL: a `meta refresh` redirect lands here with the raw
    // dictionary HTML. Resolve it back to a headword so it renders through
    // the normal pipeline (link rewriting, history, sibling dictionaries).
    final localTitle = await _localArticleTitle(dictId, url);
    if (localTitle != null) {
      if (context.mounted) {
        handleOpenWordNavigation(
          context,
          localTitle,
          newTab: false,
          dictId: dictId,
          anchor: _fragmentOf(url),
        );
      }
      return NavigationActionPolicy.CANCEL;
    }

    return navigationPolicyForUrl(url);
  };
}

/// The headword behind a navigation to this dictionary's own local server,
/// or null when the URL is external or points at a resource.
Future<String?> _localArticleTitle(int dictId, WebUri url) async {
  if (url.scheme != "http") return null;
  final dict = dictManager.dicts[dictId];
  if (dict == null) return null;

  final isLoopback =
      url.host == "127.0.0.1" && dict.port != 0 && url.port == dict.port;
  // The Android asset loader serves every dictionary from this host; the
  // per-dictionary path lookup below decides whether it is an article.
  final isAssetLoader = url.host == "ciyue.internal";
  if (!isLoopback && !isAssetLoader) return null;

  final rawPath = url.path.startsWith("/") ? url.path.substring(1) : url.path;
  if (rawPath.isEmpty) return null;
  return declaredEntryTitleAtPath(dict, _decodeURIComponent(rawPath));
}

String _decodeURIComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

String? _fragmentOf(WebUri url) {
  final fragment = url.fragment;
  if (fragment.isEmpty) return null;
  return _decodeURIComponent(fragment);
}

/// Plays a pronunciation resource referenced by a `sound://` link.
///
/// Shared by the WebView navigation handler (macOS/Linux, where
/// `shouldOverrideUrlLoading` sees the navigation) and the JS-bridge handler
/// (`playSoundResource`, used on Windows where that navigation is never
/// reported) so a plain click plays audio on every platform.
Future<void> playDictionarySound({
  required BuildContext context,
  required int dictId,
  required String filename,
}) async {
  final unsupportedMessage = AppLocalizations.of(context)
      ?.pronunciationUnsupportedFormat;
  final messenger = ScaffoldMessenger.maybeOf(context);

  final dict = dictManager.dicts[dictId];
  if (dict == null) return;
  final data = await dict.readResourceFile(filename);
  if (data == null) {
    talker.info("Sound resource not found: $filename");
    return;
  }
  final played = await playSound(
    data,
    lookupMimeType(filename) ?? "application/octet-stream",
    label: basenameWithoutExtension(filename),
  );
  talker.info("Playing sound (bridge): $filename");
  if (!played && unsupportedMessage != null) {
    messenger?.showSnackBar(SnackBar(content: Text(unsupportedMessage)));
  }
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

    final dict = dictManager.dicts[dictId];
    // The dictionary can be gone while a resource request from its old
    // WebView is still in flight (group switch / removal).
    if (dict == null) {
      return WebResourceResponse(data: null);
    }

    if (dict is Mdict && path == dict.fontName) {
      final file = File(dict.fontPath!);
      final data = await file.readAsBytes();
      return WebResourceResponse(
        data: data,
        contentType: resourceContentType(path, data),
      );
    }

    try {
      final data = await dict.readResourceFile(path);
      final declaredMime = await declaredResourceMimeType(dict, path);
      return WebResourceResponse(
        data: data,
        contentType: declaredMime ?? resourceContentType(path, data),
      );
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}
