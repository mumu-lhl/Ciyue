import "dart:async";
import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/dictionary_lookup_instance.dart";
import "package:mime/mime.dart";

/// Service providing a local HTTP server for Web UI and REST API.
///
/// Enables external browser extensions and local/LAN web browsers to search
/// dictionaries, query suggestions, view definitions, and sync wordbooks.
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
      } else if (path == "/api/status") {
        await _handleStatus(request);
      } else if (path == "/api/dictionaries") {
        await _handleDictionaries(request);
      } else if (path == "/api/suggest") {
        await _handleSuggest(request);
      } else if (path == "/api/lookup") {
        await _handleLookup(request);
      } else if (path.startsWith("/api/resource/")) {
        await _handleResource(request);
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

  Future<void> _handleStatus(HttpRequest request) async {
    _sendJson(request, {
      "status": "ok",
      "app": "Ciyue",
      "port": port,
      "allowLan": settings.webServerAllowLan,
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
    if (word.isEmpty) {
      _sendJson(request, {"word": "", "results": const []});
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
          "headword": entry.headword,
          "content": content,
          "resourceBase": "/api/resource/${dict.id}/",
        });
      }
    }

    final stared = await wordbookDao.wordExist(word);

    _sendJson(request, {"word": word, "stared": stared, "results": results});
  }

  Future<void> _handleResource(HttpRequest request) async {
    final path = request.uri.path;
    // Format: /api/resource/{dictId}/{resourcePath...}
    final prefix = "/api/resource/";
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
      --md-sys-color-primary: #6750A4;
      --md-sys-color-on-primary: #FFFFFF;
      --md-sys-color-primary-container: #EADDFF;
      --md-sys-color-on-primary-container: #21005D;
      --md-sys-color-surface: #FEF7FF;
      --md-sys-color-on-surface: #1D1B20;
      --md-sys-color-surface-container: #F3EDF7;
      --md-sys-color-surface-container-high: #ECE6F0;
      --md-sys-color-outline: #79747E;
      --md-sys-color-outline-variant: #CAC4D0;
      --border-radius-m: 16px;
      --border-radius-l: 24px;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --md-sys-color-primary: #D0BCFF;
        --md-sys-color-on-primary: #381E72;
        --md-sys-color-primary-container: #4F378B;
        --md-sys-color-on-primary-container: #EADDFF;
        --md-sys-color-surface: #141218;
        --md-sys-color-on-surface: #E6E0E9;
        --md-sys-color-surface-container: #211F26;
        --md-sys-color-surface-container-high: #2B2930;
        --md-sys-color-outline: #938F99;
        --md-sys-color-outline-variant: #49454F;
      }
    }

    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      background-color: var(--md-sys-color-surface);
      color: var(--md-sys-color-on-surface);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 24px 16px;
    }

    .container {
      width: 100%;
      max-width: 860px;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }

    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 8px 4px;
    }

    .logo-badge {
      display: flex;
      align-items: center;
      gap: 10px;
      font-size: 1.4rem;
      font-weight: 700;
      color: var(--md-sys-color-primary);
    }

    .badge {
      font-size: 0.75rem;
      font-weight: 600;
      padding: 3px 8px;
      border-radius: 12px;
      background-color: var(--md-sys-color-primary-container);
      color: var(--md-sys-color-on-primary-container);
    }

    .search-wrapper {
      position: relative;
      width: 100%;
    }

    .search-box {
      width: 100%;
      display: flex;
      align-items: center;
      background-color: var(--md-sys-color-surface-container-high);
      border: 1px solid var(--md-sys-color-outline-variant);
      border-radius: var(--border-radius-l);
      padding: 6px 16px;
      transition: all 0.2s;
    }

    .search-box:focus-within {
      border-color: var(--md-sys-color-primary);
      box-shadow: 0 0 0 2px var(--md-sys-color-primary-container);
    }

    .search-icon {
      width: 22px;
      height: 22px;
      fill: var(--md-sys-color-outline);
      margin-right: 12px;
    }

    input#query-input {
      flex: 1;
      border: none;
      background: transparent;
      outline: none;
      font-size: 1.1rem;
      color: inherit;
      padding: 8px 0;
    }

    .clear-btn, .search-btn {
      background: none;
      border: none;
      cursor: pointer;
      padding: 8px;
      display: flex;
      align-items: center;
      color: var(--md-sys-color-outline);
      border-radius: 50%;
    }

    .clear-btn:hover, .search-btn:hover {
      background-color: rgba(128, 128, 128, 0.15);
      color: var(--md-sys-color-primary);
    }

    .dropdown-suggestions {
      position: absolute;
      top: calc(100% + 6px);
      left: 0;
      right: 0;
      background-color: var(--md-sys-color-surface-container-high);
      border: 1px solid var(--md-sys-color-outline-variant);
      border-radius: var(--border-radius-m);
      box-shadow: 0 4px 16px rgba(0,0,0,0.15);
      z-index: 100;
      overflow: hidden;
      display: none;
    }

    .suggestion-item {
      padding: 10px 18px;
      cursor: pointer;
      display: flex;
      align-items: center;
      font-size: 1rem;
      border-bottom: 1px solid var(--md-sys-color-outline-variant);
    }
    .suggestion-item:last-child { border-bottom: none; }
    .suggestion-item:hover, .suggestion-item.active {
      background-color: var(--md-sys-color-primary-container);
      color: var(--md-sys-color-on-primary-container);
    }

    .word-header-card {
      background-color: var(--md-sys-color-surface-container);
      border-radius: var(--border-radius-m);
      padding: 16px 20px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      border: 1px solid var(--md-sys-color-outline-variant);
    }

    .word-title-area {
      display: flex;
      align-items: baseline;
      gap: 12px;
    }

    .word-title {
      font-size: 1.8rem;
      font-weight: bold;
    }

    .action-btn {
      display: flex;
      align-items: center;
      gap: 6px;
      background-color: var(--md-sys-color-primary-container);
      color: var(--md-sys-color-on-primary-container);
      border: none;
      padding: 8px 16px;
      border-radius: 20px;
      font-weight: 600;
      cursor: pointer;
      transition: transform 0.1s, background-color 0.2s;
    }

    .action-btn:active { transform: scale(0.96); }
    .action-btn.active {
      background-color: #E8B931;
      color: #211B00;
    }

    .dict-card {
      background-color: var(--md-sys-color-surface-container);
      border-radius: var(--border-radius-m);
      border: 1px solid var(--md-sys-color-outline-variant);
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }

    .dict-card-header {
      padding: 12px 18px;
      background-color: var(--md-sys-color-surface-container-high);
      font-weight: 600;
      font-size: 0.95rem;
      color: var(--md-sys-color-primary);
      border-bottom: 1px solid var(--md-sys-color-outline-variant);
    }

    .dict-card-content {
      padding: 0;
      position: relative;
      min-height: 120px;
    }

    iframe.dict-frame {
      width: 100%;
      height: 380px;
      border: none;
      display: block;
      background-color: #FFFFFF;
    }

    @media (prefers-color-scheme: dark) {
      iframe.dict-frame {
        filter: invert(0.9) hue-rotate(180deg);
      }
    }

    .empty-state {
      text-align: center;
      padding: 60px 20px;
      color: var(--md-sys-color-outline);
    }

    .loading-spinner {
      display: none;
      text-align: center;
      padding: 40px;
    }
    .spinner {
      display: inline-block;
      width: 36px;
      height: 36px;
      border: 4px solid var(--md-sys-color-outline-variant);
      border-top-color: var(--md-sys-color-primary);
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="logo-badge">
        <span>📖 词悦</span>
        <span class="badge" id="conn-badge">Desktop Web API</span>
      </div>
    </header>

    <div class="search-wrapper">
      <div class="search-box">
        <svg class="search-icon" viewBox="0 0 24 24"><path d="M15.5 14h-.79l-.28-.27A6.471 6.471 0 0 0 16 9.5 6.5 6.5 0 1 0 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z"/></svg>
        <input type="text" id="query-input" placeholder="输入单词或词组进行查词..." autocomplete="off" autofocus>
        <button class="clear-btn" id="clear-btn" title="清空" style="display:none;">✕</button>
        <button class="search-btn" id="search-btn" title="搜索">➔</button>
      </div>
      <div class="dropdown-suggestions" id="suggestions-box"></div>
    </div>

    <div class="loading-spinner" id="spinner">
      <div class="spinner"></div>
    </div>

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

    let currentWord = '';
    let suggestDebounce = null;

    input.addEventListener('input', () => {
      const val = input.value.trim();
      clearBtn.style.display = val ? 'block' : 'none';
      if (!val) {
        suggestionsBox.style.display = 'none';
        return;
      }
      clearTimeout(suggestDebounce);
      suggestDebounce = setTimeout(() => fetchSuggestions(val), 200);
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
      } catch (e) {
        console.error('Suggest error:', e);
      }
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
        resultsArea.innerHTML = `<div class="empty-state">未在已启用的词典中找到 “<b>${escapeHtml(data.word)}</b>”</div>`;
        return;
      }

      let html = `
        <div class="word-header-card">
          <div class="word-title-area">
            <span class="word-title">${escapeHtml(data.word)}</span>
          </div>
          <button class="action-btn ${data.stared ? 'active' : ''}" id="star-btn" onclick="toggleWordbook('${escapeHtml(data.word)}')">
            <span>${data.stared ? '★ 已在生词本' : '☆ 存入生词本'}</span>
          </button>
        </div>
      `;

      data.results.forEach((item, index) => {
        html += `
          <div class="dict-card">
            <div class="dict-card-header">${escapeHtml(item.dictTitle || '词典')}</div>
            <div class="dict-card-content">
              <iframe class="dict-frame" id="frame-${index}" sandbox="allow-same-origin allow-scripts"></iframe>
            </div>
          </div>
        `;
      });

      resultsArea.innerHTML = html;

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
          </head>
          <body>
            ${item.content}
            <script>
              document.addEventListener('click', (e) => {
                const a = e.target.closest('a');
                if (!a) return;
                const href = a.getAttribute('href');
                if (!href) return;
                if (href.startsWith('sound://')) {
                  e.preventDefault();
                  const soundFile = href.replace('sound://', '');
                  const audio = new Audio('${window.location.origin}${item.resourceBase}' + soundFile);
                  audio.play();
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

        // Auto-adjust iframe height
        frame.onload = () => {
          try {
            const h = frameDoc.body.scrollHeight;
            if (h > 100) frame.style.height = Math.min(Math.max(h + 20, 160), 600) + 'px';
          } catch (_) {}
        };
      });
    }

    window.addEventListener('message', (e) => {
      if (e.data && e.data.type === 'LOOKUP' && e.data.word) {
        input.value = e.data.word;
        doLookup(e.data.word);
      }
    });

    async function toggleWordbook(word) {
      const btn = document.getElementById('star-btn');
      const isStared = btn.classList.contains('active');
      try {
        if (isStared) {
          await fetch(`/api/wordbook?word=${encodeURIComponent(word)}`, { method: 'DELETE' });
          btn.classList.remove('active');
          btn.querySelector('span').textContent = '☆ 存入生词本';
        } else {
          await fetch(`/api/wordbook?word=${encodeURIComponent(word)}`, { method: 'POST' });
          btn.classList.add('active');
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
