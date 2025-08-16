import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/dictionary/dictionary.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/audio.dart";
import "package:ciyue/ui/core/ai_markdown.dart";
import "package:dict_reader/dict_reader.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_inappwebview/flutter_inappwebview.dart";
import "package:go_router/go_router.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

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
