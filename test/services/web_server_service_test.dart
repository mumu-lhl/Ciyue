import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/web_server_service.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel("plugins.flutter.io/path_provider"),
          (call) async => Directory.systemTemp.path,
        );
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  tearDown(() async {
    await webServerService.stop();
  });

  test("webServerService lifecycle and port binding", () async {
    expect(webServerService.isRunning, isFalse);

    // Pick an ephemeral port for testing to avoid collisions
    settings.webServerPort = 0;
    settings.webServerAllowLan = false;

    final started = await webServerService.start();
    expect(started, isTrue);
    expect(webServerService.isRunning, isTrue);
    expect(webServerService.port, isNonZero);
    expect(webServerService.url, contains("http://127.0.0.1:"));

    await webServerService.stop();
    expect(webServerService.isRunning, isFalse);
  });

  test("webServerService serves Web UI at / and index.html", () async {
    settings.webServerPort = 0;
    await webServerService.start();

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(webServerService.url));
    final response = await request.close();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType?.mimeType, "text/html");

    final body = await utf8.decoder.bind(response).join();
    expect(body, contains("词悦"));
    expect(body, contains("Web 查词"));
    client.close();
  });

  test("webServerService handles /api/status with CORS headers", () async {
    settings.webServerPort = 0;
    await webServerService.start();

    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse("${webServerService.url}/api/status"),
    );
    final response = await request.close();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value("Access-Control-Allow-Origin"), "*");

    final body = await utf8.decoder.bind(response).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    expect(json["status"], "ok");
    expect(json["app"], "Ciyue");
    client.close();
  });

  test("webServerService handles OPTIONS preflight request", () async {
    settings.webServerPort = 0;
    await webServerService.start();

    final client = HttpClient();
    final request = await client.openUrl(
      "OPTIONS",
      Uri.parse("${webServerService.url}/api/lookup"),
    );
    final response = await request.close();

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.value("Access-Control-Allow-Origin"), "*");
    expect(
      response.headers.value("Access-Control-Allow-Methods"),
      contains("GET, POST, DELETE, OPTIONS"),
    );
    client.close();
  });

  test(
    "webServerService handles /api/suggest and /api/lookup gracefully",
    () async {
      settings.webServerPort = 0;
      await webServerService.start();

      final client = HttpClient();

      // Suggest empty
      final reqSuggest = await client.getUrl(
        Uri.parse("${webServerService.url}/api/suggest"),
      );
      final resSuggest = await reqSuggest.close();
      expect(resSuggest.statusCode, HttpStatus.ok);
      final bodySuggest = await utf8.decoder.bind(resSuggest).join();
      final jsonSuggest = jsonDecode(bodySuggest) as Map<String, dynamic>;
      expect(jsonSuggest["dictionarySuggestions"], isEmpty);

      // Lookup empty
      final reqLookup = await client.getUrl(
        Uri.parse("${webServerService.url}/api/lookup"),
      );
      final resLookup = await reqLookup.close();
      expect(resLookup.statusCode, HttpStatus.ok);
      final bodyLookup = await utf8.decoder.bind(resLookup).join();
      final jsonLookup = jsonDecode(bodyLookup) as Map<String, dynamic>;
      expect(jsonLookup["results"], isEmpty);

      client.close();
    },
  );

  test("webServerService serves /assets/darkreader.js", () async {
    settings.webServerPort = 0;
    await webServerService.start();

    final client = HttpClient();
    final req = await client.getUrl(
      Uri.parse("${webServerService.url}/assets/darkreader.js"),
    );
    final res = await req.close();
    expect(res.statusCode, HttpStatus.ok);
    expect(res.headers.contentType?.mimeType, "application/javascript");
    client.close();
  });

  test("webServerService handles /api/groups and /api/ai/status", () async {
    settings.webServerPort = 0;
    await webServerService.start();

    final client = HttpClient();

    // Groups
    final reqGroups = await client.getUrl(
      Uri.parse("${webServerService.url}/api/groups"),
    );
    final resGroups = await reqGroups.close();
    expect(resGroups.statusCode, HttpStatus.ok);
    final bodyGroups = await utf8.decoder.bind(resGroups).join();
    expect(jsonDecode(bodyGroups), isA<List>());

    // AI Status
    final reqAi = await client.getUrl(
      Uri.parse("${webServerService.url}/api/ai/status"),
    );
    final resAi = await reqAi.close();
    expect(resAi.statusCode, HttpStatus.ok);
    final bodyAi = await utf8.decoder.bind(resAi).join();
    final jsonAi = jsonDecode(bodyAi) as Map<String, dynamic>;
    expect(jsonAi, contains("configured"));

    // AI Explain without word -> 400
    final reqExplain = await client.getUrl(
      Uri.parse("${webServerService.url}/api/ai/explain"),
    );
    final resExplain = await reqExplain.close();
    expect(resExplain.statusCode, HttpStatus.badRequest);

    client.close();
  });
}
