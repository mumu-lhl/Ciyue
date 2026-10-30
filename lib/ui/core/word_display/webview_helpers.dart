import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/stardict.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
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
String normalizeDictionaryUrls(String html) {
  var result = html;

  if (result.toLowerCase().contains("bword:")) {
    result = result.replaceAllMapped(_bwordHrefPattern, (match) {
      final word = match[3] ?? "";
      final hash = word.indexOf("#");
      final target = hash >= 0 ? word.substring(0, hash) : word;
      if (target.isEmpty) return match[0] ?? "";
      return '${match[1]}"gdlookup://localhost/${_percentEncodeAll(target)}"';
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
      final filename = _soundFileName(url);

      // A StarDict dictionary keeps entry audio in `res/` or a resource
      // archive rather than in an MDD, so the same click has to be served
      // from there.
      if (dict is Stardict) {
        final data = await dict.readResourceFile(filename);
        if (data == null) return null;
        talker.info("Playing sound (2): $filename");
        return CustomSchemeResponse(
          contentType: lookupMimeType(filename) ?? "application/octet-stream",
          data: data,
        );
      }
      if (dict is! Mdict) return null;
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
      final zipped = await dict.readZipResource(filename);
      if (zipped != null) {
        talker.info("Playing sound (2): $filename");
        return CustomSchemeResponse(
          contentType: lookupMimeType(filename) ?? "application/octet-stream",
          data: zipped,
        );
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

      // No lookup check against this one dictionary: the destination page
      // searches the whole group, so a link this file cannot answer may still
      // be answered by a sibling. Navigating anyway also turns a dead link
      // into the usual "not found" page -- with a search bar and this word in
      // it -- instead of a tap that silently does nothing.
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
      final filename = _soundFileName(url);

      // Resolved before the first await: showing the message afterwards would
      // touch the context across an async gap.
      final unsupportedMessage = AppLocalizations.of(context)
          ?.pronunciationUnsupportedFormat;
      final messenger = ScaffoldMessenger.maybeOf(context);

      final dict = dictManager.dicts[dictId];

      // A StarDict dictionary keeps entry audio in `res/` or a resource
      // archive rather than in an MDD. A miss stays in the log; a hit the
      // device cannot decode says so, exactly as MDD audio does.
      if (dict is Stardict) {
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

          final played = await playSound(
            data,
            lookupMimeType(filename) ?? "application/octet-stream",
            label: basenameWithoutExtension(filename),
          );
          talker.info("Playing sound (1): $filename");
          if (!played && unsupportedMessage != null) {
            messenger?.showSnackBar(
              SnackBar(content: Text(unsupportedMessage)),
            );
          }
          return NavigationActionPolicy.CANCEL;
        }

        final zipped = await dict.readZipResource(filename);
        if (zipped != null) {
          final played = await playSound(
            zipped,
            lookupMimeType(filename) ?? "application/octet-stream",
            label: basenameWithoutExtension(filename),
          );
          talker.info("Playing sound (1): $filename");
          if (!played && unsupportedMessage != null) {
            messenger?.showSnackBar(
              SnackBar(content: Text(unsupportedMessage)),
            );
          }
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
        // keep their resources, e.g. res/ images, as plain files), else in
        // a zip archive.
        if (dict is Stardict) {
          data = await dict.readResourceFile(path);
        } else {
          try {
            final file = File("${dirname(dict.path)}/$path");
            data = await file.readAsBytes();
          } catch (_) {
            if (dict is Mdict) data = await dict.readZipResource(path);
          }
        }
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
          // Find resource under directory if resource is not in mdd, else
          // in a zip audio pack.
          try {
            final file = File("${dirname(dict.path)}/$path");
            data = await file.readAsBytes();
          } catch (_) {
            data = await dict.readZipResource(path);
          }
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
