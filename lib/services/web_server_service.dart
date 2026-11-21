import "dart:async";
import "dart:convert";
import "dart:io";

import "package:flutter/services.dart";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_links.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/base_dictionary.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:ciyue/services/text_encoding.dart";

/// Service providing a local HTTP server for Web UI and REST API.
///
/// Enables external browser extensions and local/LAN web browsers to search
/// dictionaries, query suggestions, view definitions, switch groups,
/// invoke AI explanations/translations, and sync wordbooks.
class WebServerService {
  HttpServer? _server;
  bool _isStarting = false;

  bool get isRunning => _server != null;

  int get port => _server?.port ?? settings.webServerPort;

  String get host => settings.webServerAllowLan ? "0.0.0.0" : "127.0.0.1";

  String get url =>
      "http://${settings.webServerAllowLan ? "localhost" : "127.0.0.1"}:$port";

  Future<bool> start() async {
    if (isRunning || _isStarting) return true;
    _isStarting = true;

    try {
      final bindAddress = settings.webServerAllowLan
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4;

      _server = await HttpServer.bind(
        bindAddress,
        settings.webServerPort,
        shared: true,
      );

      talker.info(
        "Ciyue WebServer started on $bindAddress:${_server!.port} "
        "(LAN allowed: ${settings.webServerAllowLan})",
      );

      _server!.listen(
        _handleRequest,
        onError: (e, st) {
          talker.error("Ciyue WebServer error: $e", e, st);
        },
      );
      _isStarting = false;
      return true;
    } catch (e, st) {
      talker.error("Failed to start Ciyue WebServer: $e", e, st);
      _server = null;
      _isStarting = false;
      return false;
    }
  }

  Future<void> stop() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
        talker.info("Ciyue WebServer stopped");
      } catch (e) {
        talker.error("Error stopping Ciyue WebServer: $e");
      } finally {
        _server = null;
      }
    }
  }

  Future<bool> restart() async {
    await stop();
    return start();
  }

  void _applyCors(HttpRequest request) {
    request.response.headers.set("Access-Control-Allow-Origin", "*");
    request.response.headers.set(
      "Access-Control-Allow-Methods",
      "GET, POST, DELETE, OPTIONS",
    );
    request.response.headers.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Authorization, X-Requested-With",
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    _applyCors(request);

    if (request.method == "OPTIONS") {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == "/" || path == "/index.html") {
        await _serveWebUi(request);
      } else if (path == "/assets/darkreader.js") {
        await _handleDarkReaderAsset(request);
      } else if (path == "/api/status") {
        await _handleStatus(request);
      } else if (path == "/api/groups") {
        await _handleGroups(request);
      } else if (path == "/api/groups/switch") {
        await _handleGroupSwitch(request);
      } else if (path == "/api/dictionaries") {
        await _handleDictionaries(request);
      } else if (path == "/api/suggest") {
        await _handleSuggest(request);
      } else if (path == "/api/lookup") {
        await _handleLookup(request);
      } else if (path.startsWith("/api/resource/")) {
        await _handleResource(request);
      } else if (path == "/api/ai/status") {
        await _handleAiStatus(request);
      } else if (path == "/api/ai/explain") {
        await _handleAiExplain(request);
      } else if (path == "/api/ai/translate") {
        await _handleAiTranslate(request);
      } else if (path == "/api/wordbook/check") {
        await _handleWordbookCheck(request);
      } else if (path == "/api/wordbook") {
        if (request.method == "POST") {
          await _handleWordbookAdd(request);
        } else if (request.method == "DELETE") {
          await _handleWordbookDelete(request);
        } else {
          _sendMethodNotAllowed(request);
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write("Not Found");
        await request.response.close();
      }
    } catch (e, st) {
      talker.error("WebServer handler error: $e", e, st);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({"error": "$e"}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _sendJson(HttpRequest request, Object data, {int statusCode = 200}) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    unawaited(request.response.close());
  }

  void _sendMethodNotAllowed(HttpRequest request) {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    request.response.write("Method Not Allowed");
    unawaited(request.response.close());
  }

  Future<void> _handleDarkReaderAsset(HttpRequest request) async {
    final file = File("assets/third_party/darkreader/darkreader.js");
    if (await file.exists()) {
      request.response.headers.contentType = ContentType(
        "application",
        "javascript",
        charset: "utf-8",
      );
      request.response.headers.set(
        "Cache-Control",
        "public, max-age=86400, immutable",
      );
      await file.openRead().pipe(request.response);
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  Future<void> _handleStatus(HttpRequest request) async {
    _sendJson(request, {
      "status": "ok",
      "app": "Ciyue",
      "port": port,
      "allowLan": settings.webServerAllowLan,
      "currentGroupId": dictManager.groupId,
      "dictionariesCount": dictManager.dictIds.length,
      "aiConfigured": isAiProviderConfigured(settings.aiProvider),
    });
  }

  Future<void> _handleGroups(HttpRequest request) async {
    final groups = await dictGroupDao.getAllGroups();
    final currentId = dictManager.groupId;
    final list = [
      for (final g in groups)
        {"id": g.id, "name": g.name, "isCurrent": g.id == currentId},
    ];
    _sendJson(request, list);
  }

  Future<void> _handleGroupSwitch(HttpRequest request) async {
    final idParam = request.uri.queryParameters["id"];
    final id = int.tryParse(idParam ?? "");
    if (id == null) {
      _sendJson(request, {
        "error": "Missing or invalid id parameter",
      }, statusCode: 400);
      return;
    }

    await dictManager.setCurrentGroup(id);
    _sendJson(request, {
      "status": "ok",
      "currentGroupId": dictManager.groupId,
      "dictionariesCount": dictManager.dictIds.length,
    });
  }

  Future<void> _handleDictionaries(HttpRequest request) async {
    final list = <Map<String, dynamic>>[];
    for (final id in dictManager.dictIds) {
      final dict = dictManager.dicts[id];
      if (dict != null) {
        list.add({
          "id": dict.id,
          "title": dict.title,
          "type": dict.type,
          "entriesTotal": dict.entriesTotal,
          "isLoading": dict.isLoading,
        });
      }
    }
    _sendJson(request, list);
  }

  Future<void> _handleSuggest(HttpRequest request) async {
    final query = request.uri.queryParameters["q"]?.trim() ?? "";
    if (query.isEmpty) {
      _sendJson(request, {
        "query": "",
        "dictionarySuggestions": const <String>[],
        "spellingSuggestions": const <String>[],
      });
      return;
    }

    final suggestions = await dictionaryLookup.searchSuggestions(query);
    _sendJson(request, {
      "query": query,
      "dictionarySuggestions": suggestions.dictionarySuggestions,
      "spellingSuggestions": suggestions.spellingSuggestions,
    });
  }

  Future<void> _handleLookup(HttpRequest request) async {
    final word = request.uri.queryParameters["word"]?.trim() ?? "";
    final groupIdParam = request.uri.queryParameters["groupId"];
    if (groupIdParam != null) {
      final targetGroupId = int.tryParse(groupIdParam);
      if (targetGroupId != null && targetGroupId != dictManager.groupId) {
        await dictManager.setCurrentGroup(targetGroupId);
      }
    }

    if (word.isEmpty) {
      _sendJson(request, {
        "word": "",
        "currentGroupId": dictManager.groupId,
        "results": const [],
      });
      return;
    }

    final lookupResult = await dictionaryLookup.lookup(word);
    final results = <Map<String, dynamic>>[];

    for (final dictId in lookupResult.validDictionaryIds) {
      final dict = dictManager.dicts[dictId];
      if (dict == null) continue;

      final entries = lookupResult.entriesFor(dictId);
      for (final entry in entries) {
        // The Web UI is rendered by an external browser, so it never goes
        // through the in-app WebView's url normalisation: apply it here too,
        // otherwise bword:// and sound:// links stay unclickable in the frames.
        final content = normalizeDictionaryUrls(
          dict.wrapContentWithResources(entry.content),
        );
        results.add({
          "dictId": dict.id,
          "dictTitle": dict.title,
          "dictType": dict.type,
          "headword": entry.headword,
          "content": content,
          "resourceBase": "/api/resource/${dict.id}/",
        });
      }
    }

    final stared = await wordbookDao.wordExist(word);

    _sendJson(request, {
      "word": word,
      "currentGroupId": dictManager.groupId,
      "stared": stared,
      "results": results,
    });
  }

  Future<void> _handleResource(HttpRequest request) async {
    final path = request.uri.path;
    const prefix = "/api/resource/";
    if (!path.startsWith(prefix)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final remaining = path.substring(prefix.length);
    final slashIndex = remaining.indexOf("/");
    if (slashIndex == -1) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final dictIdStr = remaining.substring(0, slashIndex);
    final dictId = int.tryParse(dictIdStr);
    if (dictId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final resourcePath = Uri.decodeComponent(
      remaining.substring(slashIndex + 1),
    );
    final dict = dictManager.dicts[dictId];
    if (dict == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final bytes = await dict.readResourceFile(resourcePath);
    if (bytes == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final declaredMime = await declaredResourceMimeType(dict, resourcePath);
    final mime = resourcePath.endsWith(".spx")
        ? "audio/ogg"
        : (declaredMime ?? resourceContentType(resourcePath, bytes));

    request.response.headers.set("Content-Type", mime);
    request.response.headers.set(
      "Cache-Control",
      "public, max-age=86400, immutable",
    );
    request.response.add(bytes);
    await request.response.close();
  }

  Future<void> _handleAiStatus(HttpRequest request) async {
    final provider = settings.aiProvider;
    final configured = isAiProviderConfigured(provider);
    final config = settings.getAiProviderConfig(provider);
    _sendJson(request, {
      "configured": configured,
      "provider": provider,
      "model": config["model"] ?? "",
    });
  }

  Future<void> _handleAiExplain(HttpRequest request) async {
    final word = request.uri.queryParameters["word"]?.trim() ?? "";
    final stream = request.uri.queryParameters["stream"] == "true";
    final targetLang =
        request.uri.queryParameters["lang"] ?? "Simplified Chinese";

    if (word.isEmpty) {
      _sendJson(request, {"error": "Missing word parameter"}, statusCode: 400);
      return;
    }

    final provider = settings.aiProvider;
    if (!isAiProviderConfigured(provider)) {
      _sendJson(request, {
        "configured": false,
        "error":
            "AI provider '$provider' is not configured in Ciyue AI settings.",
      }, statusCode: 400);
      return;
    }

    final config = settings.getAiProviderConfig(provider);
    final ai = AI(
      provider: provider,
      model: config["model"] ?? "",
      apikey: config["apiKey"] ?? "",
    );

    final promptTemplate =
        prefs.getString("customExplainPrompt") ??
        AIPrompts.defaultExplainPrompt;
    final prompt = promptTemplate
        .replaceAll(r"$word", word)
        .replaceAll(r"$targetLanguage", targetLang);

    if (stream) {
      request.response.headers.set(
        "Content-Type",
        "text/event-stream; charset=utf-8",
      );
      request.response.headers.set("Cache-Control", "no-cache");
      request.response.headers.set("Connection", "keep-alive");
      request.response.bufferOutput = false;

      try {
        await for (final chunk in ai.requestStream(prompt)) {
          request.response.write("data: ${jsonEncode({"chunk": chunk})}\n\n");
          await request.response.flush();
        }
        request.response.write("data: [DONE]\n\n");
      } catch (e) {
        request.response.write("data: ${jsonEncode({"error": "$e"})}\n\n");
      } finally {
        await request.response.close();
      }
    } else {
      try {
        final explanation = await ai.request(prompt);
        _sendJson(request, {
          "configured": true,
          "word": word,
          "explanation": explanation,
        });
      } catch (e) {
        _sendJson(request, {"error": "$e"}, statusCode: 500);
      }
    }
  }

  Future<void> _handleAiTranslate(HttpRequest request) async {
    String text = request.uri.queryParameters["text"]?.trim() ?? "";
    final stream = request.uri.queryParameters["stream"] == "true";
    final targetLang =
        request.uri.queryParameters["targetLang"] ?? "Simplified Chinese";

    if (text.isEmpty && request.method == "POST") {
      try {
        final content = await utf8.decoder.bind(request).join();
        if (content.isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map && data["text"] != null) {
            text = data["text"].toString().trim();
          }
        }
      } catch (_) {}
    }

    if (text.isEmpty) {
      _sendJson(request, {"error": "Missing text parameter"}, statusCode: 400);
      return;
    }

    final provider = settings.aiProvider;
    if (!isAiProviderConfigured(provider)) {
      _sendJson(request, {
        "configured": false,
        "error":
            "AI provider '$provider' is not configured in Ciyue AI settings.",
      }, statusCode: 400);
      return;
    }

    final config = settings.getAiProviderConfig(provider);
    final ai = AI(
      provider: provider,
      model: config["model"] ?? "",
      apikey: config["apiKey"] ?? "",
    );

    final promptTemplate =
        prefs.getString("customTranslatePrompt") ??
        AIPrompts.defaultTranslatePrompt;
    final prompt = promptTemplate
        .replaceAll(r"$sourceLanguage", "auto detect")
        .replaceAll(r"$targetLanguage", targetLang)
        .replaceAll(r"$text", text);

    if (stream) {
      request.response.headers.set(
        "Content-Type",
        "text/event-stream; charset=utf-8",
      );
      request.response.headers.set("Cache-Control", "no-cache");
      request.response.headers.set("Connection", "keep-alive");
      request.response.bufferOutput = false;

      try {
        await for (final chunk in ai.requestStream(prompt)) {
          request.response.write("data: ${jsonEncode({"chunk": chunk})}\n\n");
          await request.response.flush();
        }
        request.response.write("data: [DONE]\n\n");
      } catch (e) {
        request.response.write("data: ${jsonEncode({"error": "$e"})}\n\n");
      } finally {
        await request.response.close();
      }
    } else {
      try {
        final translation = await ai.request(prompt);
        _sendJson(request, {
          "configured": true,
          "text": text,
          "translation": translation,
        });
      } catch (e) {
        _sendJson(request, {"error": "$e"}, statusCode: 500);
      }
    }
  }

  Future<void> _handleWordbookCheck(HttpRequest request) async {
    final word = request.uri.queryParameters["word"]?.trim() ?? "";
    if (word.isEmpty) {
      _sendJson(request, {"word": "", "stared": false});
      return;
    }

    final exists = await wordbookDao.wordExist(word);
    _sendJson(request, {"word": word, "stared": exists});
  }

  Future<void> _handleWordbookAdd(HttpRequest request) async {
    String word = request.uri.queryParameters["word"]?.trim() ?? "";
    if (word.isEmpty) {
      try {
        final content = await utf8.decoder.bind(request).join();
        if (content.isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map && data["word"] != null) {
            word = data["word"].toString().trim();
          }
        }
      } catch (_) {}
    }

    if (word.isEmpty) {
      _sendJson(request, {"error": "Missing word parameter"}, statusCode: 400);
      return;
    }

    await wordbookDao.addWord(word);
    _sendJson(request, {"status": "ok", "word": word, "stared": true});
  }

  Future<void> _handleWordbookDelete(HttpRequest request) async {
    String word = request.uri.queryParameters["word"]?.trim() ?? "";
    if (word.isEmpty) {
      try {
        final content = await utf8.decoder.bind(request).join();
        if (content.isNotEmpty) {
          final data = jsonDecode(content);
          if (data is Map && data["word"] != null) {
            word = data["word"].toString().trim();
          }
        }
      } catch (_) {}
    }

    if (word.isEmpty) {
      _sendJson(request, {"error": "Missing word parameter"}, statusCode: 400);
      return;
    }

    await wordbookDao.removeWordWithAllTags(word);
    _sendJson(request, {"status": "ok", "word": word, "stared": false});
  }

  Future<void> _serveWebUi(HttpRequest request) async {
    final devFile = File("assets/web/index.html");
    if (await devFile.exists()) {
      request.response.headers.contentType = ContentType(
        "text",
        "html",
        charset: "utf-8",
      );
      await devFile.openRead().pipe(request.response);
      return;
    }

    final altDevFile = File("web_ui/dist/index.html");
    if (await altDevFile.exists()) {
      request.response.headers.contentType = ContentType(
        "text",
        "html",
        charset: "utf-8",
      );
      await altDevFile.openRead().pipe(request.response);
      return;
    }

    try {
      final bytes = await rootBundle.load("assets/web/index.html");
      request.response.headers.contentType = ContentType(
        "text",
        "html",
        charset: "utf-8",
      );
      request.response.add(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      await request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write("Ciyue Web UI asset not found");
      await request.response.close();
    }
  }
}

final webServerService = WebServerService();
