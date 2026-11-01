import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
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

DateTime? _lastOpenWordTime;
String? _lastOpenWordName;
String? _lastOpenWordAnchor;
bool? _lastOpenWordIsNewTab;

final _bwordHrefPattern = RegExp(
  r'''(href\s*=\s*)(["'])bword://([^"']*)\2''',
  caseSensitive: false,
);

final _soundUrlPattern = RegExp(
  r'''((?:href|src)\s*=\s*)(["'])sound://([^"']*)\2''',
  caseSensitive: false,
);

String _percentEncodeAll(String value) {
  final encoded = <String>[];
  for (final byte in utf8.encode(value)) {
    encoded.add("%${byte.toRadixString(16).padLeft(2, "0").toUpperCase()}");
  }
  return encoded.join();
}

/// The canonical `gdlookup://` href for a parsed link, or an empty string when
/// there is no headword to look up.
///
/// The anchor rides as a `?gdanchor=` query item, never as a fragment: a `#`
/// in a URL is a same-document position, so a fragment would be swallowed
/// before the navigation handler ever sees it.
String entryLinkHref(EntryLinkTarget target) {
  if (target.word.isEmpty) return "";
  final href = StringBuffer(
    "gdlookup://localhost/${_percentEncodeAll(target.word)}",
  );
  final anchor = target.anchor;
  if (anchor != null && anchor.isNotEmpty) {
    href.write("?gdanchor=${_percentEncodeAll(anchor)}");
  }
  return href.toString();
}

/// Rewrites the two dictionary link shapes whose payload the URL parser
/// mangles, before the page is loaded:
///
/// * Babylon cross references, `bword://Word` → `gdlookup://localhost/<word>`
/// * audio references, `sound://FILE.spx` → `sound://localhost/<file>`
///
/// Both move the payload out of the **host** and into the path, because hosts
/// are folded to lower case on the way through the URL parser: `entry://Abend`
/// arrives as `abend`, and `sound://ID4107451.spx` arrives as
/// `id4107451_287466265.spx`, which matches neither a headword nor an `.mdd`
/// resource. Names that happen to be all lower case or all digits survive the
/// folding, which is why only some dictionaries were affected — and why the
/// same file plays in one dictionary and stays silent in the next.
///
/// A lone `#` in a Babylon link separates the headword from an anchor and `##`
/// escapes a literal `#`; see [parseEntryLink].
String normalizeDictionaryUrls(String html) {
  var result = html;

  if (result.toLowerCase().contains("bword:")) {
    result = result.replaceAllMapped(_bwordHrefPattern, (match) {
      final href = entryLinkHref(parseEntryLink(match[3] ?? ""));
      if (href.isEmpty) return match[0] ?? "";
      return '${match[1]}"$href"';
    });
  }

  if (result.toLowerCase().contains("sound://")) {
    result = result.replaceAllMapped(_soundUrlPattern, (match) {
      final file = (match[3] ?? "").split("#").first;
      if (file.isEmpty) return match[0] ?? "";
      // Already normalised: a second pass would encode the `localhost/` prefix
      // into the file name.
      if (file.toLowerCase().startsWith("localhost/")) return match[0] ?? "";
      return '${match[1]}"sound://localhost/${_percentEncodeAll(file)}"';
    });
  }

  return result;
}

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

      // Resolved before the first await: showing the message afterwards would
      // touch the context across an async gap.
      final unsupportedMessage = AppLocalizations.of(context)
          ?.pronunciationUnsupportedFormat;
      final messenger = ScaffoldMessenger.maybeOf(context);

      final dict = dictManager.dicts[dictId];
      if (dict != null) {
        final data = await dict.readResourceFile(filename);
        if (data == null) {
          talker.info("Sound resource not found: $filename");
          return NavigationActionPolicy.CANCEL;
        }
        final played = await playSound(
          data,
          lookupMimeType(filename) ?? "application/octet-stream",
          label: basenameWithoutExtension(filename),
        );
        talker.info("Playing sound (1): $filename");
        if (!played && unsupportedMessage != null) {
          messenger?.showSnackBar(SnackBar(content: Text(unsupportedMessage)));
        }
        return NavigationActionPolicy.CANCEL;
      }
    }

    return navigationPolicyForUrl(url);
  };
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

    final dict = dictManager.dicts[dictId]!;

    if (dict is Mdict && path == dict.fontName) {
      final file = File(dict.fontPath!);
      final data = await file.readAsBytes();
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    }

    try {
      final data = await dict.readResourceFile(path);
      return WebResourceResponse(data: data, contentType: lookupMimeType(path));
    } catch (e) {
      return WebResourceResponse(data: null);
    }
  }
}
