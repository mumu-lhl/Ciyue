import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/ai_prompts.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/ai.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:mime/mime.dart";

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
    request.response.close();
  }

  void _sendMethodNotAllowed(HttpRequest request) {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    request.response.write("Method Not Allowed");
    request.response.close();
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
        final content = dict.wrapContentWithResources(entry.content);
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

    String mime = lookupMimeType(resourcePath) ?? "application/octet-stream";
    if (resourcePath.endsWith(".spx")) {
      mime = "audio/ogg";
    } else if (resourcePath.endsWith(".css")) {
      mime = "text/css; charset=utf-8";
    } else if (resourcePath.endsWith(".js")) {
      mime = "application/javascript; charset=utf-8";
    }

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
    request.response.headers.contentType = ContentType.html;
    request.response.write(_webUiHtml);
    await request.response.close();
  }
}

final webServerService = WebServerService();

const String _webUiHtml = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>词悦 Ciyue - Web 查词</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%236750A4'><path d='M18 2H6c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2zM6 4h5v8l-2.5-1.5L6 12V4z'/></svg>">
  <style>
    :root {
      --primary: #6750A4;
      --on-primary: #FFFFFF;
      --primary-container: #EADDFF;
      --on-primary-container: #21005D;
      --surface: #FEF7FF;
      --on-surface: #1D1B20;
      --surface-container: #F3EDF7;
      --surface-container-high: #ECE6F0;
      --outline: #79747E;
      --outline-variant: #CAC4D0;
      --card-radius: 16px;
    }

    [data-theme="dark"] {
      --primary: #D0BCFF;
      --on-primary: #381E72;
      --primary-container: #4F378B;
      --on-primary-container: #EADDFF;
      --surface: #141218;
      --on-surface: #E6E0E9;
      --surface-container: #211F26;
      --surface-container-high: #2B2930;
      --outline: #938F99;
      --outline-variant: #49454F;
    }

    @media (prefers-color-scheme: dark) {
      :root:not([data-theme="light"]) {
        --primary: #D0BCFF;
        --on-primary: #381E72;
        --primary-container: #4F378B;
        --on-primary-container: #EADDFF;
        --surface: #141218;
        --on-surface: #E6E0E9;
        --surface-container: #211F26;
        --surface-container-high: #2B2930;
        --outline: #938F99;
        --outline-variant: #49454F;
      }
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--surface);
      color: var(--on-surface);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
      transition: background-color 0.2s, color 0.2s;
    }

    .container {
      width: 100%;
      max-width: 900px;
      display: flex;
      flex-direction: column;
      gap: 16px;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 10px;
      padding: 4px;
    }

    .brand-area {
      display: flex;
      align-items: center;
      gap: 12px;
      font-size: 1.4rem;
      font-weight: 700;
      color: var(--primary);
    }

    .header-controls {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .group-selector, .btn-icon-toggle {
      background-color: var(--surface-container);
      color: var(--on-surface);
      border: 1px solid var(--outline-variant);
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 0.88rem;
      font-weight: 500;
      cursor: pointer;
      outline: none;
    }

    .btn-icon-toggle:hover, .group-selector:hover {
      background-color: var(--surface-container-high);
      border-color: var(--primary);
    }

    .search-wrapper { position: relative; width: 100%; }
    .search-box {
      width: 100%;
      display: flex;
      align-items: center;
      background-color: var(--surface-container-high);
      border: 1px solid var(--outline-variant);
      border-radius: 28px;
      padding: 6px 18px;
      transition: all 0.2s;
    }
    .search-box:focus-within {
      border-color: var(--primary);
      box-shadow: 0 0 0 2px var(--primary-container);
    }
    .search-icon { width: 22px; height: 22px; fill: var(--outline); margin-right: 10px; }
    input#query-input {
      flex: 1;
      border: none;
      background: transparent;
      outline: none;
      font-size: 1.15rem;
      color: inherit;
      padding: 8px 0;
    }
    .clear-btn, .search-btn {
      background: none;
      border: none;
      cursor: pointer;
      padding: 8px;
      color: var(--outline);
      border-radius: 50%;
    }
    .clear-btn:hover, .search-btn:hover { color: var(--primary); }

    .dropdown-suggestions {
      position: absolute;
      top: calc(100% + 6px);
      left: 0; right: 0;
      background-color: var(--surface-container-high);
      border: 1px solid var(--outline-variant);
      border-radius: var(--card-radius);
      box-shadow: 0 4px 16px rgba(0,0,0,0.18);
      z-index: 100;
      overflow: hidden;
      display: none;
    }
    .suggestion-item {
      padding: 10px 18px;
      cursor: pointer;
      border-bottom: 1px solid var(--outline-variant);
    }
    .suggestion-item:last-child { border-bottom: none; }
    .suggestion-item:hover {
      background-color: var(--primary-container);
      color: var(--on-primary-container);
    }

    /* AI Translation Drawer */
    .ai-translate-drawer {
      background-color: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--card-radius);
      padding: 16px;
      display: none;
      flex-direction: column;
      gap: 10px;
    }
    .ai-translate-drawer textarea {
      width: 100%;
      height: 80px;
      padding: 10px;
      border-radius: 8px;
      border: 1px solid var(--outline-variant);
      background: var(--surface);
      color: inherit;
      resize: vertical;
      font-family: inherit;
      outline: none;
    }
    .ai-translate-drawer textarea:focus { border-color: var(--primary); }
    .ai-translate-actions {
      display: flex;
      justify-content: flex-end;
      gap: 10px;
      align-items: center;
    }
    .ai-result-box {
      margin-top: 8px;
      padding: 12px;
      background: var(--surface);
      border-radius: 8px;
      border: 1px solid var(--outline-variant);
      line-height: 1.5;
      white-space: pre-wrap;
    }

    /* Word Header Card */
    .word-header-card {
      background-color: var(--surface-container);
      border-radius: var(--card-radius);
      padding: 14px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border: 1px solid var(--outline-variant);
      flex-wrap: wrap;
      gap: 10px;
    }
    .word-title { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
    .word-actions { display: flex; align-items: center; gap: 8px; }

    .btn-action {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background-color: var(--primary-container);
      color: var(--on-primary-container);
      border: none;
      padding: 8px 16px;
      border-radius: 20px;
      font-weight: 600;
      font-size: 0.9rem;
      cursor: pointer;
      transition: transform 0.1s, opacity 0.2s;
    }
    .btn-action:active { transform: scale(0.96); }
    .btn-action.star-active { background-color: #E8B931; color: #211B00; }
    .btn-action.ai-active { background: linear-gradient(135deg, #6750A4, #9C27B0); color: white; }

    /* AI Explanation Card */
    .ai-explain-card {
      background-color: var(--surface-container);
      border: 1px solid var(--outline-variant);
      border-radius: var(--card-radius);
      padding: 18px;
      display: none;
      flex-direction: column;
      gap: 10px;
      box-shadow: 0 2px 12px rgba(103, 80, 164, 0.08);
    }
    .ai-explain-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-weight: 600;
      color: var(--primary);
      padding-bottom: 8px;
      border-bottom: 1px solid var(--outline-variant);
    }
    .ai-content {
      line-height: 1.6;
      white-space: pre-wrap;
      font-size: 0.95rem;
    }
    .ai-content h2, .ai-content h3 { margin: 10px 0 6px 0; color: var(--primary); font-size: 1.1rem; }
    .ai-content strong { color: var(--primary); }

    /* Dictionaries Toolbar */
    .dicts-toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 2px 6px;
      font-size: 0.88rem;
      color: var(--outline);
    }
    .toggle-all-btn {
      background: none;
      border: none;
      color: var(--primary);
      font-weight: 600;
      cursor: pointer;
      padding: 4px 8px;
    }

    /* Collapsible Dictionary Card */
    .dict-card {
      background-color: var(--surface-container);
      border-radius: var(--card-radius);
      border: 1px solid var(--outline-variant);
      overflow: hidden;
      display: flex;
      flex-direction: column;
      transition: all 0.2s ease;
    }

    .dict-card-header {
      padding: 12px 18px;
      background-color: var(--surface-container-high);
      font-weight: 600;
      font-size: 0.95rem;
      color: var(--on-surface);
      cursor: pointer;
      user-select: none;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .dict-card-header:hover {
      background-color: rgba(103, 80, 164, 0.08);
    }
    .dict-title-group {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .collapse-icon {
      transition: transform 0.2s ease;
      font-size: 0.8rem;
      color: var(--primary);
    }
    .dict-card.collapsed .collapse-icon {
      transform: rotate(-90deg);
    }
    .dict-card.collapsed .dict-card-content {
      display: none;
    }

    .dict-badge {
      font-size: 0.72rem;
      padding: 2px 8px;
      border-radius: 10px;
      background-color: var(--primary-container);
      color: var(--on-primary-container);
      font-weight: 600;
    }

    .dict-card-content {
      padding: 0;
      position: relative;
    }

    iframe.dict-frame {
      width: 100%;
      height: 380px;
      border: none;
      display: block;
      background-color: #FFFFFF;
    }

    .empty-state { text-align: center; padding: 60px 20px; color: var(--outline); }
    .loading-spinner { display: none; text-align: center; padding: 30px; }
    .spinner {
      display: inline-block;
      width: 32px; height: 32px;
      border: 3px solid var(--outline-variant);
      border-top-color: var(--primary);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
  <script src="/assets/darkreader.js"></script>
</head>
<body>
  <div class="container">
    <header>
      <div class="brand-area">
        <span>📖 词悦</span>
      </div>
      <div class="header-controls">
        <select class="group-selector" id="group-select" title="词典分组"></select>
        <button class="btn-icon-toggle" id="toggle-translate-btn">🌐 翻译</button>
        <button class="btn-icon-toggle" id="theme-btn" title="切换深色/浅色模式">🌓 模式</button>
      </div>
    </header>

    <!-- AI Translate Drawer -->
    <div class="ai-translate-drawer" id="translate-drawer">
      <textarea id="translate-input" placeholder="输入需要翻译的文本、句子或段落..."></textarea>
      <div class="ai-translate-actions">
        <select class="group-selector" id="translate-lang">
          <option value="Simplified Chinese">简体中文</option>
          <option value="English">English</option>
          <option value="Japanese">日本語</option>
          <option value="French">Français</option>
          <option value="German">Deutsch</option>
        </select>
        <button class="btn-action" id="do-translate-btn">开始翻译</button>
      </div>
      <div class="ai-result-box" id="translate-result" style="display:none;"></div>
    </div>

    <!-- Search Box -->
    <div class="search-wrapper">
      <div class="search-box">
        <svg class="search-icon" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
        <input type="text" id="query-input" placeholder="输入单词或词组进行查词..." autocomplete="off" autofocus>
        <button class="clear-btn" id="clear-btn" style="display:none;">✕</button>
        <button class="search-btn" id="search-btn">➔</button>
      </div>
      <div class="dropdown-suggestions" id="suggestions-box"></div>
    </div>

    <div class="loading-spinner" id="spinner"><div class="spinner"></div></div>

    <div id="results-area">
      <div class="empty-state" id="empty-state">
        输入任意单词，即刻通过词悦本地词典集群查询。
      </div>
    </div>
  </div>

  <script>
    const input = document.getElementById('query-input');
    const clearBtn = document.getElementById('clear-btn');
    const searchBtn = document.getElementById('search-btn');
    const suggestionsBox = document.getElementById('suggestions-box');
    const resultsArea = document.getElementById('results-area');
    const spinner = document.getElementById('spinner');
    const groupSelect = document.getElementById('group-select');
    const themeBtn = document.getElementById('theme-btn');
    const toggleTranslateBtn = document.getElementById('toggle-translate-btn');
    const translateDrawer = document.getElementById('translate-drawer');
    const translateInput = document.getElementById('translate-input');
    const doTranslateBtn = document.getElementById('do-translate-btn');
    const translateResult = document.getElementById('translate-result');

    let currentWord = '';
    let suggestDebounce = null;
    let isAllCollapsed = false;

    // Theme Management
    let currentTheme = localStorage.getItem('ciyue_theme') || 'auto';
    applyTheme(currentTheme);

    themeBtn.addEventListener('click', () => {
      if (currentTheme === 'auto') currentTheme = 'dark';
      else if (currentTheme === 'dark') currentTheme = 'light';
      else currentTheme = 'auto';
      localStorage.setItem('ciyue_theme', currentTheme);
      applyTheme(currentTheme);
      updateIframesTheme();
    });

    function isDarkModeActive() {
      if (currentTheme === 'dark') return true;
      if (currentTheme === 'light') return false;
      return window.matchMedia('(prefers-color-scheme: dark)').matches;
    }

    function applyTheme(theme) {
      if (theme === 'dark') {
        document.documentElement.setAttribute('data-theme', 'dark');
        themeBtn.textContent = '🌙 深色';
      } else if (theme === 'light') {
        document.documentElement.setAttribute('data-theme', 'light');
        themeBtn.textContent = '☀️ 浅色';
      } else {
        document.documentElement.removeAttribute('data-theme');
        themeBtn.textContent = '🌓 自动';
      }
    }

    // Load Groups
    async function loadGroups() {
      try {
        const res = await fetch('/api/groups');
        const groups = await res.json();
        groupSelect.innerHTML = groups.map(g =>
          `<option value="${g.id}" ${g.isCurrent ? 'selected' : ''}>📚 ${escapeHtml(g.name)}</option>`
        ).join('');
      } catch (_) {}
    }
    loadGroups();

    groupSelect.addEventListener('change', async () => {
      const groupId = groupSelect.value;
      try {
        await fetch(`/api/groups/switch?id=${groupId}`, { method: 'POST' });
        if (currentWord) doLookup(currentWord);
      } catch (_) {}
    });

    // Translation Drawer
    toggleTranslateBtn.addEventListener('click', () => {
      const show = translateDrawer.style.display !== 'flex';
      translateDrawer.style.display = show ? 'flex' : 'none';
      if (show) translateInput.focus();
    });

    doTranslateBtn.addEventListener('click', async () => {
      const text = translateInput.value.trim();
      if (!text) return;
      translateResult.style.display = 'block';
      translateResult.textContent = '正在翻译...';

      try {
        const lang = document.getElementById('translate-lang').value;
        const res = await fetch(`/api/ai/translate?stream=true&targetLang=${encodeURIComponent(lang)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ text })
        });

        if (!res.ok) {
          const err = await res.json();
          translateResult.textContent = '翻译失败: ' + (err.error || '未配置 AI 提供商');
          return;
        }

        translateResult.textContent = '';
        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n\n');
          buffer = lines.pop();

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const payload = line.substring(6);
              if (payload === '[DONE]') break;
              try {
                const parsed = JSON.parse(payload);
                if (parsed.chunk) translateResult.textContent += parsed.chunk;
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        translateResult.textContent = '翻译出错: ' + e.message;
      }
    });

    // Search events
    input.addEventListener('input', () => {
      const val = input.value.trim();
      clearBtn.style.display = val ? 'block' : 'none';
      if (!val) {
        suggestionsBox.style.display = 'none';
        return;
      }
      clearTimeout(suggestDebounce);
      suggestDebounce = setTimeout(() => fetchSuggestions(val), 180);
    });

    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        suggestionsBox.style.display = 'none';
        const q = input.value.trim();
        if (q) doLookup(q);
      } else if (e.key === 'Escape') {
        suggestionsBox.style.display = 'none';
      }
    });

    clearBtn.addEventListener('click', () => {
      input.value = '';
      clearBtn.style.display = 'none';
      suggestionsBox.style.display = 'none';
      input.focus();
    });

    searchBtn.addEventListener('click', () => {
      const q = input.value.trim();
      if (q) doLookup(q);
    });

    document.addEventListener('click', (e) => {
      if (!e.target.closest('.search-wrapper')) {
        suggestionsBox.style.display = 'none';
      }
    });

    async function fetchSuggestions(q) {
      try {
        const res = await fetch(`/api/suggest?q=${encodeURIComponent(q)}`);
        const data = await res.json();
        const items = (data.dictionarySuggestions || []).concat(data.spellingSuggestions || []);
        const unique = [...new Set(items)].slice(0, 10);

        if (unique.length === 0) {
          suggestionsBox.style.display = 'none';
          return;
        }

        suggestionsBox.innerHTML = unique.map(item => `<div class="suggestion-item">${escapeHtml(item)}</div>`).join('');
        suggestionsBox.style.display = 'block';

        suggestionsBox.querySelectorAll('.suggestion-item').forEach(el => {
          el.addEventListener('click', () => {
            const word = el.textContent;
            input.value = word;
            suggestionsBox.style.display = 'none';
            doLookup(word);
          });
        });
      } catch (_) {}
    }

    async function doLookup(word) {
      currentWord = word;
      spinner.style.display = 'block';
      resultsArea.innerHTML = '';
      suggestionsBox.style.display = 'none';

      try {
        const res = await fetch(`/api/lookup?word=${encodeURIComponent(word)}`);
        const data = await res.json();
        spinner.style.display = 'none';
        renderResults(data);
      } catch (e) {
        spinner.style.display = 'none';
        resultsArea.innerHTML = `<div class="empty-state">查询失败: ${escapeHtml(e.message)}</div>`;
      }
    }

    function renderResults(data) {
      if (!data.results || data.results.length === 0) {
        resultsArea.innerHTML = `<div class="empty-state">未在当前分组词典中找到 “<b>${escapeHtml(data.word)}</b>”</div>`;
        return;
      }

      let html = `
        <div class="word-header-card">
          <span class="word-title">${escapeHtml(data.word)}</span>
          <div class="word-actions">
            <button class="btn-action" id="ai-explain-btn">
              <span>🤖 AI 深度解析</span>
            </button>
            <button class="btn-action ${data.stared ? 'star-active' : ''}" id="star-btn" onclick="toggleWordbook('${escapeHtml(data.word)}')">
              <span>${data.stared ? '★ 已在生词本' : '☆ 存入生词本'}</span>
            </button>
          </div>
        </div>

        <div class="ai-explain-card" id="ai-explain-card">
          <div class="ai-explain-header">
            <span>🤖 AI 深度解析 - ${escapeHtml(data.word)}</span>
            <button class="toggle-all-btn" id="close-ai-btn">✕ 关闭</button>
          </div>
          <div class="ai-content" id="ai-explain-content">正在请求 AI 解析...</div>
        </div>

        <div class="dicts-toolbar">
          <span>共找到 ${data.results.length} 个词典释义</span>
          <button class="toggle-all-btn" id="toggle-all-btn">折叠全部</button>
        </div>
      `;

      data.results.forEach((item, index) => {
        html += `
          <div class="dict-card" id="card-${index}">
            <div class="dict-card-header" onclick="toggleCard(${index})">
              <div class="dict-title-group">
                <span class="collapse-icon">▼</span>
                <span>${escapeHtml(item.dictTitle || '词典')}</span>
              </div>
              <span class="dict-badge">${escapeHtml(item.headword || '')}</span>
            </div>
            <div class="dict-card-content">
              <iframe class="dict-frame" id="frame-${index}" sandbox="allow-same-origin allow-scripts"></iframe>
            </div>
          </div>
        `;
      });

      resultsArea.innerHTML = html;

      // Wire AI explain button
      const aiBtn = document.getElementById('ai-explain-btn');
      const aiCard = document.getElementById('ai-explain-card');
      const aiContent = document.getElementById('ai-explain-content');
      const closeAiBtn = document.getElementById('close-ai-btn');

      aiBtn.addEventListener('click', () => {
        aiCard.style.display = 'flex';
        aiBtn.classList.add('ai-active');
        fetchAiExplanation(data.word, aiContent);
      });
      closeAiBtn.addEventListener('click', () => {
        aiCard.style.display = 'none';
        aiBtn.classList.remove('ai-active');
      });

      // Wire Toggle All button
      const toggleAllBtn = document.getElementById('toggle-all-btn');
      toggleAllBtn.addEventListener('click', () => {
        isAllCollapsed = !isAllCollapsed;
        toggleAllBtn.textContent = isAllCollapsed ? '展开全部' : '折叠全部';
        data.results.forEach((_, i) => {
          const card = document.getElementById(`card-${i}`);
          if (card) {
            if (isAllCollapsed) card.classList.add('collapsed');
            else card.classList.remove('collapsed');
          }
        });
      });

      // Fill iframes
      data.results.forEach((item, index) => {
        const frame = document.getElementById(`frame-${index}`);
        if (!frame) return;
        const frameDoc = frame.contentDocument || frame.contentWindow.document;

        const docHtml = `
          <!DOCTYPE html>
          <html>
          <head>
            <base href="${window.location.origin}${item.resourceBase}">
            <meta charset="utf-8">
            <style>
              body { font-family: sans-serif; padding: 14px; margin: 0; line-height: 1.5; color: #202124; }
              a { color: #1a73e8; text-decoration: none; cursor: pointer; }
              a:hover { text-decoration: underline; }
            </style>
            <script src="/assets/darkreader.js"><\/script>
          </head>
          <body>
            ${item.content}
            <script>
              function syncTheme(isDark) {
                if (!window.DarkReader) return;
                if (isDark) {
                  window.DarkReader.setFetchMethod(window.fetch);
                  window.DarkReader.enable({
                    brightness: 100, contrast: 100, sepia: 0,
                    darkSchemeBackgroundColor: "#1e1e24",
                    darkSchemeTextColor: "#e6e0e9"
                  });
                } else if (window.DarkReader.isEnabled()) {
                  window.DarkReader.disable();
                }
              }

              syncTheme(${isDarkModeActive()});

              window.addEventListener('message', (e) => {
                if (e.data && e.data.type === 'THEME_SYNC') {
                  syncTheme(e.data.isDark);
                }
              });

              document.addEventListener('click', (e) => {
                const a = e.target.closest('a');
                if (!a) return;
                const href = a.getAttribute('href');
                if (!href) return;
                if (href.startsWith('sound://')) {
                  e.preventDefault();
                  const soundFile = href.replace('sound://', '');
                  new Audio('${window.location.origin}${item.resourceBase}' + soundFile).play();
                } else if (href.startsWith('entry://')) {
                  e.preventDefault();
                  const targetWord = href.replace('entry://', '');
                  window.parent.postMessage({ type: 'LOOKUP', word: targetWord }, '*');
                }
              });
            <\/script>
          </body>
          </html>
        `;

        frameDoc.open();
        frameDoc.write(docHtml);
        frameDoc.close();

        frame.onload = () => {
          try {
            const h = frameDoc.body.scrollHeight;
            if (h > 100) frame.style.height = Math.min(Math.max(h + 20, 160), 650) + 'px';
          } catch (_) {}
        };
      });
    }

    window.toggleCard = function(index) {
      const card = document.getElementById(`card-${index}`);
      if (card) card.classList.toggle('collapsed');
    };

    function updateIframesTheme() {
      const isDark = isDarkModeActive();
      document.querySelectorAll('iframe.dict-frame').forEach(f => {
        try {
          f.contentWindow.postMessage({ type: 'THEME_SYNC', isDark }, '*');
        } catch (_) {}
      });
    }

    async function fetchAiExplanation(word, targetEl) {
      targetEl.textContent = '🤖 正在向 AI 请求解析...';

      try {
        const res = await fetch(`/api/ai/explain?word=${encodeURIComponent(word)}&stream=true`);
        if (!res.ok) {
          const err = await res.json();
          targetEl.innerHTML = `<span style="color:#d32f2f;">${escapeHtml(err.error || 'AI 未配置')}</span>`;
          return;
        }

        targetEl.textContent = '';
        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let buffer = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split('\n\n');
          buffer = lines.pop();

          for (const line of lines) {
            if (line.startsWith('data: ')) {
              const payload = line.substring(6);
              if (payload === '[DONE]') break;
              try {
                const parsed = JSON.parse(payload);
                if (parsed.chunk) targetEl.textContent += parsed.chunk;
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        targetEl.textContent = '请求失败: ' + e.message;
      }
    }

    window.addEventListener('message', (e) => {
      if (e.data && e.data.type === 'LOOKUP' && e.data.word) {
        input.value = e.data.word;
        doLookup(e.data.word);
      }
    });

    async function toggleWordbook(word) {
      const btn = document.getElementById('star-btn');
      const isStared = btn.classList.contains('star-active');
      try {
        if (isStared) {
          await fetch(`/api/wordbook?word=${encodeURIComponent(word)}`, { method: 'DELETE' });
          btn.classList.remove('star-active');
          btn.querySelector('span').textContent = '☆ 存入生词本';
        } else {
          await fetch(`/api/wordbook?word=${encodeURIComponent(word)}`, { method: 'POST' });
          btn.classList.add('star-active');
          btn.querySelector('span').textContent = '★ 已在生词本';
        }
      } catch (e) {
        alert('生词本操作失败: ' + e.message);
      }
    }

    function escapeHtml(str) {
      if (!str) return '';
      return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
    }
  </script>
</body>
</html>
''';
