import "dart:io";
import "dart:typed_data";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/online_pronunciation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:shared_preferences/shared_preferences.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

typedef _Handler = Future<OnlineHttpResponse> Function(
  Uri uri, {
  Map<String, String>? headers,
  required bool asBytes,
});

/// A fake HTTP fetcher that records every request. Zero network.
class _FakeHttp {
  _FakeHttp(this._handler);

  final _Handler _handler;
  final List<Uri> uris = [];
  final List<Map<String, String>?> headersList = [];
  final List<bool> asBytesList = [];

  Future<OnlineHttpResponse> fetch(
    Uri uri, {
    Map<String, String>? headers,
    required bool asBytes,
  }) async {
    uris.add(uri);
    headersList.add(headers);
    asBytesList.add(asBytes);
    return _handler(uri, headers: headers, asBytes: asBytes);
  }
}

class _FakeSource implements OnlinePronunciationSource {
  _FakeSource(this.id, {this.result, this.delay});

  @override
  final String id;
  Uint8List? result;
  Duration? delay;
  int calls = 0;
  String? lastWord;
  String? lastLanguage;

  @override
  Future<Uint8List?> fetchAudio(String word, String languageCode) async {
    calls++;
    lastWord = word;
    lastLanguage = languageCode;
    if (delay != null) await Future<void>.delayed(delay!);
    return result;
  }
}

OnlineHttpResponse _jsonResponse(int status, Object? data) =>
    OnlineHttpResponse(statusCode: status, data: data);

OnlineHttpResponse _bytesResponse(int status, List<int> bytes) =>
    OnlineHttpResponse(statusCode: status, bytes: Uint8List.fromList(bytes));

String _todayString([DateTime? date]) {
  final now = date ?? DateTime.now();
  final month = now.month.toString().padLeft(2, "0");
  final day = now.day.toString().padLeft(2, "0");
  return "${now.year}-$month-$day";
}

Future<Directory> _tempDir() =>
    Directory.systemTemp.createTemp("online_pronunciation_test_");

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // No allowList: the Settings singleton reads dozens of keys.
    prefs = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  });

  setUp(() async {
    ForvoPronunciationSource.resetKeyInvalidForTesting();
    await prefs.remove(ForvoPronunciationSource.quotaDateKey);
    await prefs.remove(ForvoPronunciationSource.quotaCountKey);
    settings.wiktionaryPronunciationEnabled = false;
    settings.forvoPronunciationEnabled = false;
    settings.wiktionaryPronunciationLanguage = "";
    settings.forvoPronunciationLanguage = "";
    settings.language = "system";
  });

  group("resolveOnlinePronunciationLanguage", () {
    test("explicit setting wins over the fallback", () {
      expect(resolveOnlinePronunciationLanguage("fr", "en"), "fr");
      expect(resolveOnlinePronunciationLanguage("de", "zh"), "de");
    });

    test("empty or blank setting falls back", () {
      expect(resolveOnlinePronunciationLanguage("", "en"), "en");
      expect(resolveOnlinePronunciationLanguage("  ", "ja"), "ja");
    });
  });

  group("onlinePronunciationFallbackLanguageCode", () {
    test("parses settings.language like main.dart does", () {
      settings.language = "zh_CN";
      expect(onlinePronunciationFallbackLanguageCode(), "zh");
      settings.language = "en-US";
      expect(onlinePronunciationFallbackLanguageCode(), "en");
      settings.language = "pt_BR";
      expect(onlinePronunciationFallbackLanguageCode(), "pt");
    });

    test("system, null, and empty fall back to en", () {
      settings.language = "system";
      expect(onlinePronunciationFallbackLanguageCode(), "en");
      settings.language = null;
      expect(onlinePronunciationFallbackLanguageCode(), "en");
      settings.language = "";
      expect(onlinePronunciationFallbackLanguageCode(), "en");
    });
  });

  group("wiktionarySectionNameForLanguage", () {
    test("covers the required languages", () {
      expect(wiktionarySectionNameForLanguage("en"), "English");
      expect(wiktionarySectionNameForLanguage("de"), "German");
      expect(wiktionarySectionNameForLanguage("fr"), "French");
      expect(wiktionarySectionNameForLanguage("es"), "Spanish");
      expect(wiktionarySectionNameForLanguage("it"), "Italian");
      expect(wiktionarySectionNameForLanguage("pt"), "Portuguese");
      expect(wiktionarySectionNameForLanguage("ru"), "Russian");
      expect(wiktionarySectionNameForLanguage("ja"), "Japanese");
      expect(wiktionarySectionNameForLanguage("ko"), "Korean");
      expect(wiktionarySectionNameForLanguage("zh"), "Chinese");
      expect(wiktionarySectionNameForLanguage("nl"), "Dutch");
      expect(wiktionarySectionNameForLanguage("sv"), "Swedish");
      expect(wiktionarySectionNameForLanguage("da"), "Danish");
      expect(wiktionarySectionNameForLanguage("no"), "Norwegian");
      expect(wiktionarySectionNameForLanguage("fi"), "Finnish");
      expect(wiktionarySectionNameForLanguage("pl"), "Polish");
      expect(wiktionarySectionNameForLanguage("cs"), "Czech");
      expect(wiktionarySectionNameForLanguage("hu"), "Hungarian");
      expect(wiktionarySectionNameForLanguage("tr"), "Turkish");
      expect(wiktionarySectionNameForLanguage("ar"), "Arabic");
      expect(wiktionarySectionNameForLanguage("he"), "Hebrew");
      expect(wiktionarySectionNameForLanguage("hi"), "Hindi");
      expect(wiktionarySectionNameForLanguage("th"), "Thai");
      expect(wiktionarySectionNameForLanguage("vi"), "Vietnamese");
      expect(wiktionarySectionNameForLanguage("id"), "Indonesian");
      expect(wiktionarySectionNameForLanguage("uk"), "Ukrainian");
      expect(wiktionarySectionNameForLanguage("el"), "Greek");
    });

    test("unknown codes return null", () {
      expect(wiktionarySectionNameForLanguage("xx"), isNull);
      expect(wiktionarySectionNameForLanguage(""), isNull);
    });

    test("region suffixes, case, and three-letter codes normalize", () {
      expect(wiktionarySectionNameForLanguage("EN"), "English");
      expect(wiktionarySectionNameForLanguage("zh_CN"), "Chinese");
      expect(wiktionarySectionNameForLanguage("en-US"), "English");
      expect(wiktionarySectionNameForLanguage("eng"), "English");
      expect(wiktionarySectionNameForLanguage("deu"), "German");
    });
  });

  group("Commons filename canonicalization and URLs", () {
    test("canonical form underscores spaces and upper-cases first letter", () {
      expect(
        WiktionaryPronunciationSource.canonicalizeCommonsFilename(
          "hello world.ogg",
        ),
        "Hello_world.ogg",
      );
      expect(
        WiktionaryPronunciationSource.canonicalizeCommonsFilename(
          "Nl-konijnenverblijven.ogg",
        ),
        "Nl-konijnenverblijven.ogg",
      );
      expect(
        WiktionaryPronunciationSource.canonicalizeCommonsFilename(
          "nl-konijnenverblijven.ogg",
        ),
        "Nl-konijnenverblijven.ogg",
      );
    });

    test("md5 is computed over the canonical form (probe vectors)", () {
      // Verified vector: md5("Nl-konijnenverblijven.ogg") = 3751bdf1...
      expect(
        WiktionaryPronunciationSource.commonsHashPrefix(
          "Nl-konijnenverblijven.ogg",
        ),
        "3/37/",
      );
      // A lower-case input must hash to the same canonical segment.
      expect(
        WiktionaryPronunciationSource.commonsHashPrefix(
          "nl-konijnenverblijven.ogg",
        ),
        "3/37/",
      );
      expect(
        WiktionaryPronunciationSource.commonsHashPrefix("en-us-house-noun.ogg"),
        "5/55/",
      );
      // Raw spaced form hashes to 7/78/; the underscored form to b/b5/.
      expect(
        WiktionaryPronunciationSource.commonsHashPrefix(
          "LL-Q1860 (eng)-Nattes à chat-apple.wav",
        ),
        "b/b5/",
      );
    });

    test("filename segments are percent-encoded, underscores kept", () {
      expect(
        WiktionaryPronunciationSource.encodeCommonsFilename("Nl-appél.ogg"),
        "Nl-app%C3%A9l.ogg",
      );
      expect(
        WiktionaryPronunciationSource.encodeCommonsFilename(
          "De-Weißen_Hauses.ogg",
        ),
        "De-Wei%C3%9Fen_Hauses.ogg",
      );
      expect(
        WiktionaryPronunciationSource.encodeCommonsFilename(
          "LL-Q1860_(eng)-Nattes_à_chat-apple.wav",
        ),
        "LL-Q1860_%28eng%29-Nattes_%C3%A0_chat-apple.wav",
      );
    });

    test("ogg sources get an mp3 derivative URL", () {
      expect(
        WiktionaryPronunciationSource.commonsTranscodeUrl("De-Haus.ogg"),
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/"
        "7/7e/De-Haus.ogg/De-Haus.ogg.mp3",
      );
      expect(
        WiktionaryPronunciationSource.commonsTranscodeUrl(
          "Nl-konijnenverblijven.ogg",
        ),
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/"
        "3/37/Nl-konijnenverblijven.ogg/Nl-konijnenverblijven.ogg.mp3",
      );
    });

    test("wav sources get an ogg derivative URL", () {
      expect(
        WiktionaryPronunciationSource.commonsTranscodeUrl(
          "LL-Q1860 (eng)-Nattes à chat-apple.wav",
        ),
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/"
        "b/b5/LL-Q1860_%28eng%29-Nattes_%C3%A0_chat-apple.wav/"
        "LL-Q1860_%28eng%29-Nattes_%C3%A0_chat-apple.wav.ogg",
      );
    });

    test("mp3 sources have no deterministic transcode URL", () {
      expect(
        WiktionaryPronunciationSource.commonsTranscodeUrl("En-word.mp3"),
        isNull,
      );
    });

    test("title variants try the word as-is, then capitalized", () {
      expect(WiktionaryPronunciationSource.titleVariants("apple"), [
        "apple",
        "Apple",
      ]);
      expect(WiktionaryPronunciationSource.titleVariants("Apple"), ["Apple"]);
      expect(WiktionaryPronunciationSource.titleVariants(""), isEmpty);
    });
  });

  group("Wiktionary extraction", () {
    const twoSections = """
==English==
===Noun===
{{audio|en|En-house.ogg}}
==German==
===Noun===
{{audio|de|De-Haus.ogg|a=Standard}}
""";

    test("scopes to the target language section", () {
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(twoSections, "de"),
        "De-Haus.ogg",
      );
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(twoSections, "en"),
        "En-house.ogg",
      );
      // A language with no section on the page has no audio here.
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(twoSections, "fr"),
        isNull,
      );
    });

    test("accepts the documented argument order", () {
      const wikitext = """
==English==
{{audio|en|LL-Q1860 (eng)-Nattes à chat-apple.wav|a=Southern England}}
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "en"),
        "LL-Q1860 (eng)-Nattes à chat-apple.wav",
      );
    });

    test("accepts the older filename-first argument order", () {
      const wikitext = """
==English==
{{audio|en-us-portmanteau-1.ogg|Audio 1 (US)|lang=en}}
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "en"),
        "en-us-portmanteau-1.ogg",
      );
    });

    test("skips templates whose language code does not match", () {
      const wikitext = """
==German==
{{audio|fr|Fr-mot.ogg}}
{{audio|de|De-Wort.ogg}}
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "de"),
        "De-Wort.ogg",
      );
      // Only a wrong-language template: no in-language audio.
      const onlyWrong = """
==German==
{{audio|fr|Fr-mot.ogg}}
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(onlyWrong, "de"),
        isNull,
      );
    });

    test("a page with no audio yields null (Haus-like)", () {
      const wikitext = """
==English==
===Proper noun===
A surname.
==German==
===Noun===
# A house.
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "de"),
        isNull,
      );
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "en"),
        isNull,
      );
    });

    test("File links are a secondary fallback only", () {
      const wikitext = """
==German==
[[File:De-Wort.ogg]]
{{audio|de|De-Wort-template.ogg}}
""";
      // The template match wins even though the File link comes first.
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "de"),
        "De-Wort-template.ogg",
      );
      const onlyFile = """
==German==
[[File:De-Wort.ogg|Some caption]]
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(onlyFile, "de"),
        "De-Wort.ogg",
      );
    });

    test("first in-language match wins; no accent preference in v1", () {
      const wikitext = """
==English==
{{audio|en|En-us-house-noun.ogg}}
{{audio|en|En-us-house-verb.ogg}}
""";
      expect(
        WiktionaryPronunciationSource.extractAudioFilename(wikitext, "en"),
        "En-us-house-noun.ogg",
      );
    });
  });

  group("WiktionaryPronunciationSource fetching", () {
    const wavWikitext = """
==English==
{{audio|en|LL-Q1860 (eng)-Nattes à chat-apple.wav|a=Southern England}}
""";

    Future<OnlineHttpResponse> wavHandler(
      Uri uri, {
      Map<String, String>? headers,
      required bool asBytes,
    }) async {
      if (uri.host == "en.wiktionary.org") {
        return _jsonResponse(200, {
          "parse": {
            "wikitext": {"*": wavWikitext},
          },
        });
      }
      return _bytesResponse(200, [1, 2, 3]);
    }

    test("fetches wikitext then the encoded wav->ogg transcode URL", () async {
      final http = _FakeHttp(wavHandler);
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      final bytes = await source.fetchAudio("apple", "en");

      expect(bytes, [1, 2, 3]);
      expect(http.uris, hasLength(2));
      final parseUri = http.uris[0];
      expect(parseUri.host, "en.wiktionary.org");
      expect(parseUri.queryParameters["action"], "parse");
      expect(parseUri.queryParameters["page"], "apple");
      expect(parseUri.queryParameters["prop"], "wikitext");
      // Descriptive User-Agent, no user email.
      expect(
        http.headersList[0]?["User-Agent"],
        WiktionaryPronunciationSource.userAgent,
      );
      expect(
        http.uris[1].toString(),
        "https://upload.wikimedia.org/wikipedia/commons/transcoded/"
        "b/b5/LL-Q1860_%28eng%29-Nattes_%C3%A0_chat-apple.wav/"
        "LL-Q1860_%28eng%29-Nattes_%C3%A0_chat-apple.wav.ogg",
      );
    });

    test("falls back to the capitalized title variant", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        if (uri.host == "en.wiktionary.org") {
          if (uri.queryParameters["page"] == "apple") {
            return _jsonResponse(200, {
              "error": {"code": "missingtitle"},
            });
          }
          return _jsonResponse(200, {
            "parse": {
              "wikitext": {"*": wavWikitext},
            },
          });
        }
        return _bytesResponse(200, [4, 5]);
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      expect(await source.fetchAudio("apple", "en"), [4, 5]);
      expect(
        http.uris
            .where((u) => u.host == "en.wiktionary.org")
            .map((u) => u.queryParameters["page"]),
        ["apple", "Apple"],
      );
    });

    test("unknown language makes no request", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(200, {});
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      expect(await source.fetchAudio("apple", "xx"), isNull);
      expect(http.uris, isEmpty);
    });

    test("transcode 404 returns null without fallback", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        if (uri.host == "en.wiktionary.org") {
          return _jsonResponse(200, {
            "parse": {
              "wikitext": {"*": wavWikitext},
            },
          });
        }
        return _bytesResponse(404, []);
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, hasLength(2));
    });

    test("403 is transient: no bytes, and the coordinator must not "
        "record a miss", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(403, "forbidden");
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      await expectLater(
        source.fetchAudio("apple", "en"),
        throwsA(isA<OnlinePronunciationTransientException>()),
      );

      // At the coordinator boundary the same failure is null with no
      // miss recorded, so a later attempt retries the source.
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final coordinator = OnlinePronunciationCoordinator(
        sources: [source],
        cache: OnlinePronunciationCache(dir),
      );
      settings.wiktionaryPronunciationEnabled = true;

      expect(await coordinator.resolve("apple"), isNull);
      final cache = OnlinePronunciationCache(dir);
      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isFalse);
      expect(await coordinator.resolve("apple"), isNull);
      expect(http.uris, hasLength(3));
    });

    test("429 is transient too", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(429, "slow down");
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      await expectLater(
        source.fetchAudio("apple", "en"),
        throwsA(isA<OnlinePronunciationTransientException>()),
      );
    });

    test(
      "mp3 sources use the imageinfo URL, never a guessed derivative",
      () async {
        const mp3Wikitext = """
==English==
{{audio|en|En-word.mp3}}
""";
        final http = _FakeHttp((uri, {headers, required asBytes}) async {
          if (uri.host == "en.wiktionary.org") {
            if (uri.queryParameters["action"] == "parse") {
              return _jsonResponse(200, {
                "parse": {
                  "wikitext": {"*": mp3Wikitext},
                },
              });
            }
            expect(uri.queryParameters["titles"], "File:En-word.mp3");
            expect(uri.queryParameters["prop"], "imageinfo");
            return _jsonResponse(200, {
              "query": {
                "pages": {
                  "42": {
                    "imageinfo": [
                      {"url": "https://upload.wikimedia.org/w/mp3/En-word.mp3"},
                    ],
                  },
                },
              },
            });
          }
          expect(
            uri.toString(),
            "https://upload.wikimedia.org/w/mp3/En-word.mp3",
          );
          return _bytesResponse(200, [7, 7, 7]);
        });
        final source = WiktionaryPronunciationSource(fetcher: http.fetch);

        expect(await source.fetchAudio("word", "en"), [7, 7, 7]);
      },
    );

    test("mp3 source with no imageinfo URL returns null", () async {
      const mp3Wikitext = """
==English==
{{audio|en|En-word.mp3}}
""";
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        if (uri.host == "en.wiktionary.org") {
          if (uri.queryParameters["action"] == "parse") {
            return _jsonResponse(200, {
              "parse": {
                "wikitext": {"*": mp3Wikitext},
              },
            });
          }
          return _jsonResponse(200, {
            "query": {
              "pages": {
                "-1": {"missing": ""},
              },
            },
          });
        }
        return _bytesResponse(200, [1]);
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      expect(await source.fetchAudio("word", "en"), isNull);
    });

    test("transport errors return null", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        throw StateError("boom");
      });
      final source = WiktionaryPronunciationSource(fetcher: http.fetch);

      expect(await source.fetchAudio("apple", "en"), isNull);
    });
  });

  group("ForvoPronunciationSource", () {
    test("API URL has exact path segments and encodes the word", () {
      final uri = ForvoPronunciationSource.apiUri(
        apiKey: "KEY123",
        word: "ice cream",
        languageCode: "en",
      );
      expect(uri.scheme, "https");
      expect(uri.host, "apifree.forvo.com");
      expect(uri.pathSegments, [
        "key",
        "KEY123",
        "format",
        "json",
        "action",
        "standard-pronunciation",
        "word",
        "ice cream",
        "language",
        "en",
      ]);
      expect(uri.toString(), contains("ice%20cream"));
      final slashy = ForvoPronunciationSource.apiUri(
        apiKey: "k",
        word: "a/b",
        languageCode: "en",
      );
      expect(slashy.toString(), contains("a%2Fb"));
    });

    test("parses items[0].pathmp3 and fetches the mp3 bytes", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        if (!asBytes) {
          return _jsonResponse(200, {
            "items": [
              {
                "pathmp3": "https://apifree.forvo.com/audio/mp3/apple.mp3",
                "word": "apple",
              },
            ],
          });
        }
        return _bytesResponse(200, [9, 8, 7]);
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );

      expect(await source.fetchAudio("apple", "en"), [9, 8, 7]);
      expect(http.uris, hasLength(2));
      expect(http.uris[0].host, "apifree.forvo.com");
      expect(
        http.uris[1].toString(),
        "https://apifree.forvo.com/audio/mp3/apple.mp3",
      );
      expect(prefs.getInt(ForvoPronunciationSource.quotaCountKey), 1);
      expect(
        prefs.getString(ForvoPronunciationSource.quotaDateKey),
        _todayString(),
      );
    });

    test("empty items returns null without fetching audio", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(200, {"items": []});
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );

      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, hasLength(1));
    });

    test("no stored key returns null without any request", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(200, {"items": []});
      });
      for (final missing in <String?>[null, ""]) {
        final source = ForvoPronunciationSource(
          fetcher: http.fetch,
          preferences: prefs,
          apiKeyReader: () async => missing,
        );
        expect(await source.fetchAudio("apple", "en"), isNull);
      }
      expect(http.uris, isEmpty);
      expect(prefs.getInt(ForvoPronunciationSource.quotaCountKey), isNull);
    });

    test("quota cap returns null without requesting", () async {
      await prefs.setString(
        ForvoPronunciationSource.quotaDateKey,
        _todayString(),
      );
      await prefs.setInt(ForvoPronunciationSource.quotaCountKey, 450);
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(200, {"items": []});
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );

      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, isEmpty);
    });

    test("quota rolls over on date change", () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await prefs.setString(
        ForvoPronunciationSource.quotaDateKey,
        _todayString(yesterday),
      );
      await prefs.setInt(ForvoPronunciationSource.quotaCountKey, 450);
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        if (!asBytes) {
          return _jsonResponse(200, {
            "items": [
              {"pathmp3": "https://example.test/a.mp3"},
            ],
          });
        }
        return _bytesResponse(200, [1]);
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );

      expect(await source.fetchAudio("apple", "en"), [1]);
      expect(http.uris, hasLength(2));
      expect(
        prefs.getString(ForvoPronunciationSource.quotaDateKey),
        _todayString(),
      );
      expect(prefs.getInt(ForvoPronunciationSource.quotaCountKey), 1);
    });

    test("401 marks the key invalid: no retry with the same key, "
        "retry after the key changes", () async {
      var currentKey = "key-one";
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(401, {"error": "unauthorized"});
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => currentKey,
      );

      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(source.keyMarkedInvalid, isTrue);
      expect(http.uris, hasLength(1));

      // Same key: no further request.
      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, hasLength(1));

      // A different key resets the flag and is tried.
      currentKey = "key-two";
      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, hasLength(2));
      expect(source.keyMarkedInvalid, isTrue);
    });

    test("403 also marks the key invalid", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(403, {"error": "forbidden"});
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "bad-key",
      );

      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(source.keyMarkedInvalid, isTrue);
      expect(await source.fetchAudio("apple", "en"), isNull);
      expect(http.uris, hasLength(1));
    });

    test("other failures return null", () async {
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(500, "error");
      });
      final source = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );
      expect(await source.fetchAudio("apple", "en"), isNull);

      final throwing = _FakeHttp((uri, {headers, required asBytes}) async {
        throw StateError("boom");
      });
      final throwingSource = ForvoPronunciationSource(
        fetcher: throwing.fetch,
        preferences: prefs,
        apiKeyReader: () async => "test-key",
      );
      expect(await throwingSource.fetchAudio("apple", "en"), isNull);
    });
  });

  group("OnlinePronunciationCache", () {
    test("md5 filename has no extension and uses the pipe-joined key", () {
      // md5("wiktionary|en|apple") = 21524b8f1890dcc88e728d14eda494f7
      expect(
        OnlinePronunciationCache.cacheFilename("wiktionary", "en", "apple"),
        "21524b8f1890dcc88e728d14eda494f7",
      );
    });

    test("put then get returns the bytes; unknown keys miss", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final cache = OnlinePronunciationCache(dir);

      expect(await cache.get("wiktionary", "en", "apple"), isNull);
      await cache.put(
        "wiktionary",
        "en",
        "apple",
        Uint8List.fromList([1, 2, 3]),
      );
      expect(await cache.get("wiktionary", "en", "apple"), [1, 2, 3]);
      expect(await cache.get("wiktionary", "en", "pear"), isNull);
      expect(await cache.get("forvo", "en", "apple"), isNull);
    });

    test("misses are remembered for about an hour, then expire", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final cache = OnlinePronunciationCache(dir);

      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isFalse);
      await cache.putMiss("wiktionary", "en", "apple");
      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isTrue);

      final missFile = File(
        p.join(
          dir.path,
          "${OnlinePronunciationCache.cacheFilename("wiktionary", "en", "apple")}.miss",
        ),
      );
      await missFile.setLastModified(
        DateTime.now().subtract(const Duration(minutes: 61)),
      );
      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isFalse);

      await cache.putMiss("wiktionary", "en", "apple");
      await missFile.setLastModified(
        DateTime.now().subtract(const Duration(minutes: 59)),
      );
      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isTrue);
    });

    test("a hit supersedes a recorded miss", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final cache = OnlinePronunciationCache(dir);

      await cache.putMiss("wiktionary", "en", "apple");
      await cache.put("wiktionary", "en", "apple", Uint8List.fromList([5]));
      expect(await cache.hasRecentMiss("wiktionary", "en", "apple"), isFalse);
      expect(await cache.get("wiktionary", "en", "apple"), [5]);
    });

    test(
      "evicts the least recently modified file under the file cap",
      () async {
        final dir = await _tempDir();
        addTearDown(() => dir.delete(recursive: true));
        final cache = OnlinePronunciationCache(dir, maxFiles: 3);
        final bytes = Uint8List.fromList([1]);

        await cache.put("wiktionary", "en", "a", bytes);
        final fileA = File(
          p.join(
            dir.path,
            OnlinePronunciationCache.cacheFilename("wiktionary", "en", "a"),
          ),
        );
        await fileA.setLastModified(
          DateTime.now().subtract(const Duration(days: 1)),
        );
        await cache.put("wiktionary", "en", "b", bytes);
        await cache.put("wiktionary", "en", "c", bytes);
        await cache.put("wiktionary", "en", "d", bytes);

        expect(await cache.get("wiktionary", "en", "a"), isNull);
        expect(await cache.get("wiktionary", "en", "b"), isNotNull);
        expect(await cache.get("wiktionary", "en", "c"), isNotNull);
        expect(await cache.get("wiktionary", "en", "d"), isNotNull);
      },
    );

    test("evicts under the byte cap", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final cache = OnlinePronunciationCache(dir, maxBytes: 10);

      await cache.put(
        "wiktionary",
        "en",
        "a",
        Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      );
      await cache.put(
        "wiktionary",
        "en",
        "b",
        Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      );

      expect(await cache.get("wiktionary", "en", "a"), isNull);
      expect(await cache.get("wiktionary", "en", "b"), isNotNull);
    });
  });

  group("OnlinePronunciationCoordinator", () {
    test("tries wiktionary first, then forvo", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final wiktionary = _FakeSource(
        "wiktionary",
        result: Uint8List.fromList([1]),
      );
      final forvo = _FakeSource("forvo", result: Uint8List.fromList([2]));
      final coordinator = OnlinePronunciationCoordinator(
        sources: [wiktionary, forvo],
        cache: OnlinePronunciationCache(dir),
      );
      settings.wiktionaryPronunciationEnabled = true;
      settings.forvoPronunciationEnabled = true;

      expect(await coordinator.resolve("apple"), [1]);
      expect(wiktionary.calls, 1);
      expect(forvo.calls, 0);
    });

    test("falls through to forvo when wiktionary has nothing", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final wiktionary = _FakeSource("wiktionary");
      final forvo = _FakeSource("forvo", result: Uint8List.fromList([2]));
      final coordinator = OnlinePronunciationCoordinator(
        sources: [wiktionary, forvo],
        cache: OnlinePronunciationCache(dir),
      );
      settings.wiktionaryPronunciationEnabled = true;
      settings.forvoPronunciationEnabled = true;

      expect(await coordinator.resolve("apple"), [2]);
      expect(wiktionary.calls, 1);
      expect(forvo.calls, 1);
    });

    test("disabled sources are never consulted", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final wiktionary = _FakeSource(
        "wiktionary",
        result: Uint8List.fromList([1]),
      );
      final forvo = _FakeSource("forvo", result: Uint8List.fromList([2]));
      final coordinator = OnlinePronunciationCoordinator(
        sources: [wiktionary, forvo],
        cache: OnlinePronunciationCache(dir),
      );

      expect(await coordinator.resolve("apple"), isNull);
      expect(wiktionary.calls, 0);
      expect(forvo.calls, 0);
    });

    test(
      "resolves each source language from its setting or the fallback",
      () async {
        final dir = await _tempDir();
        addTearDown(() => dir.delete(recursive: true));
        final wiktionary = _FakeSource("wiktionary");
        final forvo = _FakeSource("forvo");
        final coordinator = OnlinePronunciationCoordinator(
          sources: [wiktionary, forvo],
          cache: OnlinePronunciationCache(dir),
        );
        settings.wiktionaryPronunciationEnabled = true;
        settings.forvoPronunciationEnabled = true;
        settings.language = "de";
        settings.forvoPronunciationLanguage = "fr";

        await coordinator.resolve("apple");
        expect(wiktionary.lastLanguage, "de");
        expect(forvo.lastLanguage, "fr");
      },
    );

    test("cache hits skip the source; misses skip it for an hour", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final wiktionary = _FakeSource(
        "wiktionary",
        result: Uint8List.fromList([1]),
      );
      final coordinator = OnlinePronunciationCoordinator(
        sources: [wiktionary],
        cache: OnlinePronunciationCache(dir),
      );
      settings.wiktionaryPronunciationEnabled = true;

      expect(await coordinator.resolve("apple"), [1]);
      expect(await coordinator.resolve("apple"), [1]);
      expect(wiktionary.calls, 1);

      wiktionary.result = null;
      expect(await coordinator.resolve("pear"), isNull);
      expect(wiktionary.calls, 2);
      expect(await coordinator.resolve("pear"), isNull);
      expect(wiktionary.calls, 2);
    });

    test("concurrent resolutions of the same lookup share one fetch", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final wiktionary = _FakeSource(
        "wiktionary",
        result: Uint8List.fromList([1]),
        delay: const Duration(milliseconds: 50),
      );
      final coordinator = OnlinePronunciationCoordinator(
        sources: [wiktionary],
        cache: OnlinePronunciationCache(dir),
      );
      settings.wiktionaryPronunciationEnabled = true;

      final results = await Future.wait([
        coordinator.resolve("apple"),
        coordinator.resolve("apple"),
        coordinator.resolve("apple"),
      ]);
      expect(results, [
        [1],
        [1],
        [1],
      ]);
      expect(wiktionary.calls, 1);
    });

    test("a rejected Forvo key is not recorded as a miss", () async {
      final dir = await _tempDir();
      addTearDown(() => dir.delete(recursive: true));
      final http = _FakeHttp((uri, {headers, required asBytes}) async {
        return _jsonResponse(401, {"error": "unauthorized"});
      });
      final forvo = ForvoPronunciationSource(
        fetcher: http.fetch,
        preferences: prefs,
        apiKeyReader: () async => "bad-key",
      );
      final coordinator = OnlinePronunciationCoordinator(
        sources: [forvo],
        cache: OnlinePronunciationCache(dir),
      );
      settings.forvoPronunciationEnabled = true;

      expect(await coordinator.resolve("apple"), isNull);
      final cache = OnlinePronunciationCache(dir);
      expect(await cache.hasRecentMiss("forvo", "en", "apple"), isFalse);
    });
  });

  group("settings persistence", () {
    test(
      "online pronunciation settings default off/empty and persist",
      () async {
        await prefs.remove("wiktionaryPronunciationEnabled");
        await prefs.remove("forvoPronunciationEnabled");
        await prefs.remove("wiktionaryPronunciationLanguage");
        await prefs.remove("forvoPronunciationLanguage");

        final fresh = Settings();
        expect(fresh.wiktionaryPronunciationEnabled, isFalse);
        expect(fresh.forvoPronunciationEnabled, isFalse);
        expect(fresh.wiktionaryPronunciationLanguage, "");
        expect(fresh.forvoPronunciationLanguage, "");

        await settings.setWiktionaryPronunciationEnabled(true);
        await settings.setForvoPronunciationEnabled(true);
        await settings.setWiktionaryPronunciationLanguage("de");
        await settings.setForvoPronunciationLanguage("fr");
        expect(prefs.getBool("wiktionaryPronunciationEnabled"), isTrue);
        expect(prefs.getBool("forvoPronunciationEnabled"), isTrue);
        expect(prefs.getString("wiktionaryPronunciationLanguage"), "de");
        expect(prefs.getString("forvoPronunciationLanguage"), "fr");

        final reloaded = Settings();
        expect(reloaded.wiktionaryPronunciationEnabled, isTrue);
        expect(reloaded.forvoPronunciationEnabled, isTrue);
        expect(reloaded.wiktionaryPronunciationLanguage, "de");
        expect(reloaded.forvoPronunciationLanguage, "fr");

        await settings.setWiktionaryPronunciationEnabled(false);
        await settings.setForvoPronunciationEnabled(false);
        await settings.setWiktionaryPronunciationLanguage("");
        await settings.setForvoPronunciationLanguage("");
      },
    );
  });

  test("preferences allowlist covers the online pronunciation keys", () {
    expect(
      preferencesAllowList,
      containsAll([
        "wiktionaryPronunciationEnabled",
        "forvoPronunciationEnabled",
        "wiktionaryPronunciationLanguage",
        "forvoPronunciationLanguage",
        "forvoPronunciationQuotaDate",
        "forvoPronunciationQuotaCount",
      ]),
    );
  });

  group("onlineAudioMimeType", () {
    test("OggS magic sniffs to audio/ogg (.wav sources yield .ogg)", () {
      final bytes = Uint8List.fromList([0x4F, 0x67, 0x67, 0x53, 0, 2]);
      expect(onlineAudioMimeType(bytes), "audio/ogg");
    });

    test("ID3 and other bytes default to audio/mpeg", () {
      expect(
        onlineAudioMimeType(Uint8List.fromList([0x49, 0x44, 0x33, 3])),
        "audio/mpeg",
      );
      expect(onlineAudioMimeType(Uint8List(0)), "audio/mpeg");
    });
  });
}
