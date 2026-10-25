import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/ui/core/ai_markdown.dart";
import "package:ciyue/utils.dart";
import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:ciyue/core/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

DateTime? _lastOpenWordTime;
String? _lastOpenWordName;
bool? _lastOpenWordIsNewTab;

final _bwordHrefPattern = RegExp(
  r'''(href\s*=\s*)(["'])bword://([^"']*)\2''',
  caseSensitive: false,
);

/// Dictionaries converted from Babylon write their cross references as
/// `bword://word`, which the WebView cannot load and nothing else accepts
/// until the page script rewrites it. Rewriting the href before the page loads
/// makes those links work even when the script does not run, or when a click
/// never reaches it.
///
/// The word goes into the path as `gdlookup://localhost/<encoded>`, not into
/// the host as `entry://<word>`: the URL parser folds hosts to lower case, so
/// `entry://Abend` arrives as `abend` and lands on the wrong entry, and
/// `entry://A.D.` is read as a host with a port and resolves to nothing.
/// Percent-encoding the whole word keeps `/`, `?`, `#` and `:` out of the path.
String normalizeEntryLinks(String html) {
  if (!html.toLowerCase().contains("bword:")) return html;
  return html.replaceAllMapped(_bwordHrefPattern, (match) {
    final word = match[3] ?? "";
    final hash = word.indexOf("#");
    final target = hash >= 0 ? word.substring(0, hash) : word;
    if (target.isEmpty) return match[0] ?? "";
    final encoded = <String>[];
    for (final byte in utf8.encode(target)) {
      encoded.add("%${byte.toRadixString(16).padLeft(2, "0").toUpperCase()}");
    }
    return '${match[1]}"gdlookup://localhost/${encoded.join()}"';
  });
}

void handleOpenWordNavigation(
  BuildContext context,
  String rawWord, {
  required bool newTab,
  int? dictId,
}) {
  final word = rawWord.trim();
  if (word.isEmpty) return;

  final now = DateTime.now();
  if (_lastOpenWordName == word &&
      _lastOpenWordIsNewTab == newTab &&
      _lastOpenWordTime != null &&
      now.difference(_lastOpenWordTime!) < const Duration(milliseconds: 300)) {
    return;
  }
  _lastOpenWordName = word;
  _lastOpenWordIsNewTab = newTab;
  _lastOpenWordTime = now;

  final navContext = navigatorKey.currentContext ?? context;

  if (isLargeScreen(context)) {
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

    bool isAlreadyInWordRoute = false;
    try {
      final currentRoute = GoRouterState.of(context).uri.toString();
      isAlreadyInWordRoute = currentRoute.startsWith("/word/");
    } catch (_) {
      isAlreadyInWordRoute = false;
    }

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

@visibleForTesting
String wordFromEntryUrl(WebUri url) {
  if (url.scheme == "ciyue-open-new-tab") {
    final raw = url.host.isNotEmpty ? url.host : url.path;
    return Uri.decodeComponent(raw.replaceFirst(RegExp(r"^/"), ""));
  }
  final encodedWord = url.scheme == "gdlookup"
      ? url.path.replaceFirst(RegExp(r"^/"), "")
      : url.toString().replaceFirst(_entrySchemePrefix, "");
  return Uri.decodeComponent(encodedWord);
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
      // Pronunciation audio lives in MDD resources; other dictionary
      // formats have none to serve here.
      if (dict is! Mdict) return null;
      final filename = Uri.decodeFull(url.toString())
          .replaceFirst("sound://", "");
      final results = await dict.readResource(filename);
      for (final result in results) {
        final info = result.offsetInfo;
        try {
          final Uint8List data;
          if (result.part == null) {
            data = await dict.readerResources[0].readOneMdd(info) as Uint8List;
          } else {
            data = await dict.readerResources[result.part!].readOneMdd(
              info,
            ) as Uint8List;
          }
          talker.info("Playing sound (2): $filename");
          return CustomSchemeResponse(
            contentType: lookupMimeType(filename) ?? "application/octet-stream",
            data: data,
          );
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
)
shouldOverrideUrlLoadingWarpper(int dictId, BuildContext context) {
  return (controller, navigationAction) async {
    final url = navigationAction.request.url;
    if (url == null) return NavigationActionPolicy.CANCEL;

    if (_isEntryUrl(url)) {
      final isNewTab = url.scheme == "ciyue-open-new-tab";
      final word = wordFromEntryUrl(url);
      talker.info("Entry link: ${url.scheme} -> $word");
      if (!isNewTab &&
          (await dictManager.dicts[dictId]!.resolveExactKey(word)) == null) {
        talker.info("Word not found: ${url.toString()}");
        return NavigationActionPolicy.CANCEL;
      }

      if (context.mounted) {
        handleOpenWordNavigation(
          context,
          word,
          newTab: isNewTab,
          dictId: dictId,
        );
      }
      return NavigationActionPolicy.CANCEL;
    } else if (url.scheme == "sound") {
      final filename = Uri.decodeFull(url.toString())
          .replaceFirst("sound://", "");

      // Pronunciation audio lives in MDD resources; other dictionary
      // formats have none to play here.
      final dict = dictManager.dicts[dictId];
      if (dict is Mdict) {
        final results = await dict.readResource(filename);

        for (final result in results) {
          final info = result.offsetInfo;
          final Uint8List data;
          try {
            if (result.part == null) {
              data =
                  await dict.readerResources[0].readOneMdd(info) as Uint8List;
            } else {
              data = await dict.readerResources[result.part!].readOneMdd(
                info,
              ) as Uint8List;
            }
          } catch (e) {
            talker.error(
              "Failed to read sound resource (${result.part == null ? 0 : result.part!}): $filename",
              e,
            );
            continue;
          }

          await playSound(
            data,
            lookupMimeType(filename) ?? "application/octet-stream",
            label: basenameWithoutExtension(filename),
          );
          talker.info("Playing sound (1): $filename");
          return NavigationActionPolicy.CANCEL;
        }
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
      Uint8List? data;

      if (dict is! Mdict || dict.readerResources.isEmpty) {
        // Find resource under directory if no mdd (StarDict dictionaries
        // keep their resources, e.g. res/ images, as plain files).
        final file = File("${dirname(dict.path)}/$path");
        data = await file.readAsBytes();
      } else {
        // An external .css/.js next to the dictionary overrides the copy
        // packed inside the .mdd (see readExternalResourceOverride).
        final override = await readExternalResourceOverride(dict.path, path);
        if (override != null) {
          return WebResourceResponse(
            data: override,
            contentType: lookupMimeType(path),
          );
        }

        List<MddResourceData> results;
        results = await dict.readResource(path);

        if (results.isEmpty) {
          // Find resource under directory if resource is not in mdd
          final file = File("${dirname(dict.path)}/$path");
          data = await file.readAsBytes();
          return WebResourceResponse(
            data: data,
            contentType: lookupMimeType(path),
          );
        }

        for (var i = 0; i < results.length;) {
          final result = results[i];
          final info = result.offsetInfo;
          try {
            if (result.part == null) {
              data =
                  await dict.readerResources[0].readOneMdd(info) as Uint8List;
            } else {
              data = await dict.readerResources[result.part!].readOneMdd(
                info,
              ) as Uint8List;
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
