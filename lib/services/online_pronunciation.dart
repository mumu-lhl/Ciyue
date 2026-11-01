import "dart:convert";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:simple_secure_storage/simple_secure_storage.dart";

/// The language to use for an online pronunciation lookup.
///
/// Returns [settingValue] when it is non-empty, otherwise the caller's
/// fallback (normally the UI locale, see
/// [onlinePronunciationFallbackLanguageCode]).
String resolveOnlinePronunciationLanguage(
  String settingValue,
  String fallbackLanguageCode,
) {
  final trimmed = settingValue.trim();
  return trimmed.isEmpty ? fallbackLanguageCode : trimmed;
}

/// The UI-locale fallback language code for online pronunciation.
///
/// Derived from `settings.language`, parsed exactly the way `main.dart`
/// parses it into a [Locale]: the part before the first `_` (or `-`) is
/// the language code. When the user follows the system locale
/// (`"system"`, null, or empty), there is no locale available here — the
/// coordinator has no [BuildContext] to read the OS locale from — so the
/// fallback is `"en"`, the default language of both Wiktionary and Forvo.
String onlinePronunciationFallbackLanguageCode() {
  final raw = settings.language;
  if (raw == null || raw.trim().isEmpty || raw.trim() == "system") {
    return "en";
  }
  final code = raw.split(RegExp(r"[-_]")).first.trim().toLowerCase();
  return code.isEmpty ? "en" : code;
}

/// The MIME type for online pronunciation [bytes], sniffed from the
/// container magic: `.wav` sources yield Ogg Vorbis derivatives, whose
/// bytes start with "OggS"; MP3 bytes start with an ID3 tag or a frame
/// sync. Defaults to MP3: every Forvo response is an mp3, and so are
/// Wiktionary's `.ogg`-source derivatives. Labeling Ogg bytes as
/// `audio/mpeg` risks the platform decoder rejecting them, so the
/// sniff matters whenever a `.wav` file wins the extraction.
String onlineAudioMimeType(Uint8List bytes) {
  const oggMagic = [0x4F, 0x67, 0x67, 0x53]; // "OggS"
  if (bytes.length >= oggMagic.length) {
    var matches = true;
    for (var i = 0; i < oggMagic.length; i++) {
      if (bytes[i] != oggMagic[i]) {
        matches = false;
        break;
      }
    }
    if (matches) return "audio/ogg";
  }
  return "audio/mpeg";
}

/// English Wiktionary section names, keyed by ISO 639-1 code.
///
/// Wiktionary pages carry one `==Language==` section per language, and
/// the section heading is the language's English name.
const Map<String, String> _wiktionarySectionNames = {
  "en": "English",
  "de": "German",
  "fr": "French",
  "es": "Spanish",
  "it": "Italian",
  "pt": "Portuguese",
  "ru": "Russian",
  "ja": "Japanese",
  "ko": "Korean",
  "zh": "Chinese",
  "nl": "Dutch",
  "sv": "Swedish",
  "da": "Danish",
  "no": "Norwegian",
  "nb": "Norwegian",
  "nn": "Norwegian",
  "fi": "Finnish",
  "pl": "Polish",
  "cs": "Czech",
  "hu": "Hungarian",
  "tr": "Turkish",
  "ar": "Arabic",
  "he": "Hebrew",
  "hi": "Hindi",
  "th": "Thai",
  "vi": "Vietnamese",
  "id": "Indonesian",
  "uk": "Ukrainian",
  "el": "Greek",
};

/// ISO 639-2 (three-letter) aliases for the codes in
/// [_wiktionarySectionNames], so template language codes such as `eng`
/// resolve the same way as `en`.
const Map<String, String> _iso639Aliases = {
  "eng": "en",
  "deu": "de",
  "ger": "de",
  "fra": "fr",
  "fre": "fr",
  "spa": "es",
  "ita": "it",
  "por": "pt",
  "rus": "ru",
  "jpn": "ja",
  "kor": "ko",
  "zho": "zh",
  "chi": "zh",
  "nld": "nl",
  "dut": "nl",
  "swe": "sv",
  "dan": "da",
  "nor": "no",
  "fin": "fi",
  "pol": "pl",
  "ces": "cs",
  "cze": "cs",
  "hun": "hu",
  "tur": "tr",
  "ara": "ar",
  "heb": "he",
  "hin": "hi",
  "tha": "th",
  "vie": "vi",
  "ind": "id",
  "ukr": "uk",
  "ell": "el",
  "gre": "el",
};

/// Normalizes a language code for comparison: lower-cased, region suffix
/// dropped, three-letter codes mapped to their two-letter form.
String _normalizeLanguageCode(String code) {
  final base = code.trim().toLowerCase().split(RegExp(r"[-_]")).first;
  return _iso639Aliases[base] ?? base;
}

/// The English Wiktionary section name for [isoCode], or null when the
/// code is not covered. Accepts codes with region suffixes
/// (`"zh_CN"`, `"en-US"`) and three-letter codes (`"eng"`).
String? wiktionarySectionNameForLanguage(String isoCode) {
  return _wiktionarySectionNames[_normalizeLanguageCode(isoCode)];
}

/// One HTTP response, as seen by an online pronunciation source.
///
/// The default fetcher translates Dio errors that carry a response into
/// this shape, so sources can distinguish status codes (notably 401/403
/// for Forvo and 403/429/404 for Wiktionary) without depending on Dio.
/// Transport failures with no response surface as thrown errors instead.
class OnlineHttpResponse {
  const OnlineHttpResponse({required this.statusCode, this.data, this.bytes});

  /// The HTTP status code, or 0 when no response was received.
  final int statusCode;

  /// The decoded response body for JSON/text requests, if any.
  final Object? data;

  /// The raw response body for byte requests, if any.
  final Uint8List? bytes;
}

/// Fetches one URL for an online pronunciation source.
///
/// [asBytes] selects raw bytes (audio files, transcodes) versus a
/// decoded JSON body. All HTTP in this file goes through this seam so
/// tests run with zero network.
typedef OnlineHttpFetcher = Future<OnlineHttpResponse> Function(
  Uri uri, {
  Map<String, String>? headers,
  required bool asBytes,
});

/// A plain Dio with no interceptors.
///
/// The shared [AppHttp] Dio carries a TalkerDioLogger that prints
/// request data in debug mode; the Forvo API key sits in the request
/// URL path, so Forvo (and, for consistency, Wiktionary) requests must
/// never go through it. This fetcher is the only HTTP path used here.
OnlineHttpFetcher _plainDioFetcher() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  return (
    Uri uri, {
    Map<String, String>? headers,
    required bool asBytes,
  }) async {
    try {
      final response = await dio.getUri<Object?>(
        uri,
        options: Options(
          headers: headers,
          responseType: asBytes ? ResponseType.bytes : ResponseType.json,
        ),
      );
      return _responseFromDio(response, asBytes: asBytes);
    } on DioException catch (e) {
      final response = e.response;
      if (response != null) {
        return _responseFromDio(response, asBytes: asBytes);
      }
      rethrow;
    }
  };
}

OnlineHttpResponse _responseFromDio(
  Response<Object?> response, {
  required bool asBytes,
}) {
  final statusCode = response.statusCode ?? 0;
  final data = response.data;
  if (asBytes) {
    Uint8List? bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    }
    return OnlineHttpResponse(statusCode: statusCode, bytes: bytes);
  }
  return OnlineHttpResponse(statusCode: statusCode, data: data);
}

/// Decodes [data] to a JSON map when it is a map already or a JSON
/// string; returns null for anything else or malformed JSON.
Map<String, dynamic>? _jsonMap(Object? data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Thrown internally by a source when a request was refused or
/// rate-limited (HTTP 403/429, and 5xx from Wiktionary) and the failure
/// must not be recorded as a cache miss: the next attempt may succeed,
/// so a miss entry would wrongly suppress retries for an hour.
///
/// This never escapes [OnlinePronunciationCoordinator.resolve], which
/// converts it to null; it is part of the internal source/coordinator
/// contract, not of the outward API. Direct callers of
/// [OnlinePronunciationSource.fetchAudio] other than the coordinator
/// should treat it the same way: as "no audio, do not cache a miss".
class OnlinePronunciationTransientException implements Exception {
  const OnlinePronunciationTransientException(this.statusCode);

  final int statusCode;

  @override
  String toString() =>
      "OnlinePronunciationTransientException(statusCode: $statusCode)";
}

/// One online source of pronunciation audio.
///
/// Every failure yields null: network and parse errors are caught,
/// logged via talker, and return null — except for refused/rate-limited
/// Wiktionary responses, which throw
/// [OnlinePronunciationTransientException] as documented there so the
/// coordinator does not record a cache miss.
abstract class OnlinePronunciationSource {
  /// Stable id used for cache filenames (`"wiktionary"`, `"forvo"`).
  String get id;

  /// Fetches audio bytes for [word] in the language [languageCode]
  /// (an ISO 639-1 code), or null when no audio is available.
  Future<Uint8List?> fetchAudio(String word, String languageCode);
}

/// Forvo standard pronunciations via the free Forvo API.
///
/// API shape: `GET
/// https://apifree.forvo.com/key/{key}/format/json/action/standard-pronunciation/word/{word}/language/{lang}`,
/// whose JSON carries `items[0].pathmp3`, the URL of the mp3 bytes.
/// The key is stored in secure storage under `"forvoApiKey"` and is
/// never logged: requests use a Dio without the Talker logger (see
/// [_plainDioFetcher]).
class ForvoPronunciationSource implements OnlinePronunciationSource {
  ForvoPronunciationSource({
    OnlineHttpFetcher? fetcher,
    this._preferences,
    this._apiKeyReader,
  }) : _fetcher = fetcher ?? _plainDioFetcher();

  @override
  String get id => "forvo";

  /// Free-tier daily request cap enforced client-side.
  static const int maxRequestsPerDay = 450;

  static const String quotaDateKey = "forvoPronunciationQuotaDate";
  static const String quotaCountKey = "forvoPronunciationQuotaCount";

  /// Secure-storage key for the Forvo API key. Never stored in prefs,
  /// never logged.
  static const String apiKeyStorageKey = "forvoApiKey";

  final OnlineHttpFetcher _fetcher;
  final SharedPreferencesWithCache? _preferences;
  final Future<String?> Function()? _apiKeyReader;

  /// Process-lifetime "this key was rejected" flag. Once set, no
  /// further request is made with the same key; observing a different
  /// key value resets it.
  static bool _keyInvalid = false;
  static String? _lastObservedKey;

  /// Whether the currently stored key has been rejected (401/403).
  bool get keyMarkedInvalid => _keyInvalid;

  @visibleForTesting
  static void resetKeyInvalidForTesting() {
    _keyInvalid = false;
    _lastObservedKey = null;
  }

  /// The exact API URL for [word] in [languageCode], with the word
  /// URL-encoded as one path segment. The key is encoded as a path
  /// segment too; callers must never log the result.
  static Uri apiUri({
    required String apiKey,
    required String word,
    required String languageCode,
  }) {
    final encodedKey = Uri.encodeComponent(apiKey);
    final encodedWord = Uri.encodeComponent(word);
    final encodedLanguage = Uri.encodeComponent(languageCode);
    return Uri.parse(
      "https://apifree.forvo.com/key/$encodedKey/format/json/"
      "action/standard-pronunciation/word/$encodedWord/"
      "language/$encodedLanguage",
    );
  }

  /// Extracts `items[0].pathmp3` from a Forvo API response body, or
  /// null when the body has no usable first item.
  static String? mp3PathFromJson(Object? data) {
    final json = _jsonMap(data);
    if (json == null) return null;
    final items = json["items"];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map) return null;
    final path = first["pathmp3"];
    if (path is! String || path.isEmpty) return null;
    return path;
  }

  static String _todayString() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, "0");
    final day = now.day.toString().padLeft(2, "0");
    return "${now.year}-$month-$day";
  }

  @override
  Future<Uint8List?> fetchAudio(String word, String languageCode) async {
    try {
      final key =
          await (_apiKeyReader?.call() ??
              SimpleSecureStorage.read(apiKeyStorageKey));
      if (key == null || key.isEmpty) return null;
      if (key != _lastObservedKey) {
        _lastObservedKey = key;
        _keyInvalid = false;
      }
      if (_keyInvalid) return null;

      final store = _preferences ?? prefs;
      final today = _todayString();
      var count = store.getInt(quotaCountKey) ?? 0;
      if (store.getString(quotaDateKey) != today) {
        count = 0;
        await store.setString(quotaDateKey, today);
        await store.setInt(quotaCountKey, 0);
      }
      if (count >= maxRequestsPerDay) return null;
      // The API call counts against the quota whether or not it
      // succeeds, so the count is incremented before requesting.
      await store.setInt(quotaCountKey, count + 1);

      final response = await _fetcher(
        apiUri(apiKey: key, word: word, languageCode: languageCode),
        asBytes: false,
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        _keyInvalid = true;
        return null;
      }
      if (response.statusCode != 200) return null;
      final mp3Url = mp3PathFromJson(response.data);
      if (mp3Url == null) return null;

      final audioResponse = await _fetcher(Uri.parse(mp3Url), asBytes: true);
      if (audioResponse.statusCode != 200) return null;
      final bytes = audioResponse.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      return bytes;
    } catch (e, stackTrace) {
      talker.error("Forvo pronunciation request failed", e, stackTrace);
      return null;
    }
  }
}

/// Wiktionary pronunciations via the MediaWiki parse API.
///
/// Two steps: fetch the page wikitext, extract the first in-language
/// `{{audio}}` filename from the target language's section, then fetch
/// the deterministic Commons transcode of that file. A 403/429/5xx
/// from Wikimedia throws [OnlinePronunciationTransientException]
/// (the coordinator converts it to null without recording a miss);
/// a 404 on the transcode, or a page with no in-language audio,
/// returns null.
class WiktionaryPronunciationSource implements OnlinePronunciationSource {
  WiktionaryPronunciationSource({OnlineHttpFetcher? fetcher})
    : _fetcher = fetcher ?? _plainDioFetcher();

  @override
  String get id => "wiktionary";

  /// Descriptive User-Agent sent on every Wiktionary request, as
  /// Wikimedia's API etiquette requires. No user email is included.
  static const String userAgent = "Ciyue (https://github.com/mumu-lhl/Ciyue)";

  final OnlineHttpFetcher _fetcher;

  static final RegExp _audioTemplatePattern = RegExp(
    r"\{\{\s*audio\s*\|(.*?)\}\}",
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _fileLinkPattern = RegExp(
    r"\[\[\s*(?:File|Image)\s*:\s*([^\]\|]+?)\s*(?:\|[^\]]*)?\]\]",
    caseSensitive: false,
  );
  static final RegExp _audioExtensionPattern = RegExp(
    r"\.(ogg|oga|wav|mp3)$",
    caseSensitive: false,
  );
  static final RegExp _languageCodePattern = RegExp(
    r"^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]+)?$",
  );

  /// Canonicalizes a Commons filename for hashing and URL building:
  /// spaces become underscores and the first letter is upper-cased.
  /// The md5 must be computed over this form, not the raw filename:
  /// `md5("Nl-konijnenverblijven.ogg")` is `3751bdf1...` (`3/37/`),
  /// while the raw lower-case form hashes elsewhere.
  static String canonicalizeCommonsFilename(String filename) {
    final underscored = filename.replaceAll(" ", "_");
    if (underscored.isEmpty) return underscored;
    final firstRune = underscored.runes.first;
    final first = String.fromCharCode(firstRune);
    return "${first.toUpperCase()}${underscored.substring(first.length)}";
  }

  /// The `h1/h2/` hash directory prefix for [filename], computed over
  /// the canonicalized form.
  static String commonsHashPrefix(String filename) {
    final canonical = canonicalizeCommonsFilename(filename);
    final digest = md5.convert(utf8.encode(canonical)).toString();
    return "${digest[0]}/${digest.substring(0, 2)}/";
  }

  /// Percent-encodes an (already underscored) Commons filename for a
  /// URL path segment: parentheses and non-ASCII bytes are encoded
  /// (`(` -> `%28`, `é` -> `%C3%A9`), `_` and other unreserved
  /// characters pass through.
  static String encodeCommonsFilename(String underscoredFilename) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(underscoredFilename)) {
      final isUnreserved =
          (byte >= 0x30 && byte <= 0x39) || // 0-9
          (byte >= 0x41 && byte <= 0x5A) || // A-Z
          (byte >= 0x61 && byte <= 0x7A) || // a-z
          byte == 0x2D || // -
          byte == 0x2E || // .
          byte == 0x5F || // _
          byte == 0x7E; // ~
      if (isUnreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer.write(
          "%${byte.toRadixString(16).padLeft(2, "0").toUpperCase()}",
        );
      }
    }
    return buffer.toString();
  }

  /// The deterministic Commons transcode URL for [filename]:
  /// `.ogg`/`.oga` sources get an `.mp3` derivative, `.wav` sources
  /// get an `.ogg` derivative. Returns null for other extensions
  /// (`.mp3` sources use the imageinfo API instead; see [_audioUrlFor]).
  static String? commonsTranscodeUrl(String filename) {
    final lower = filename.toLowerCase();
    final String derivativeExtension;
    if (lower.endsWith(".ogg") || lower.endsWith(".oga")) {
      derivativeExtension = "mp3";
    } else if (lower.endsWith(".wav")) {
      derivativeExtension = "ogg";
    } else {
      return null;
    }
    final canonical = canonicalizeCommonsFilename(filename);
    final encoded = encodeCommonsFilename(canonical);
    return "https://upload.wikimedia.org/wikipedia/commons/transcoded/"
        "${commonsHashPrefix(filename)}$encoded/$encoded.$derivativeExtension";
  }

  /// The parse-API URL for page [title].
  static Uri parseApiUri(String title) {
    return Uri.https("en.wiktionary.org", "/w/api.php", {
      "action": "parse",
      "page": title,
      "prop": "wikitext",
      "format": "json",
    });
  }

  /// The imageinfo-API URL for `File:[filename]`, used as the
  /// authoritative URL source for `.mp3` files (no derivative is
  /// guessed for them).
  static Uri imageInfoApiUri(String filename) {
    return Uri.https("en.wiktionary.org", "/w/api.php", {
      "action": "query",
      "prop": "imageinfo",
      "titles": "File:$filename",
      "iiprop": "url",
      "format": "json",
    });
  }

  /// Page titles tried, in order: the word as-is, then with its first
  /// letter upper-cased (MediaWiki titles are case-sensitive only in
  /// the first letter, so the two usually resolve to the same page,
  /// but both spellings are tried).
  static List<String> titleVariants(String word) {
    if (word.isEmpty) return const [];
    final firstRune = word.runes.first;
    final first = String.fromCharCode(firstRune);
    final uppercased = "${first.toUpperCase()}${word.substring(first.length)}";
    if (uppercased == word) return [word];
    return [word, uppercased];
  }

  /// Extracts the wikitext string from a parse-API response body, or
  /// null when the page is missing or the body is unusable.
  static String? wikitextFromJson(Object? data) {
    final json = _jsonMap(data);
    if (json == null || json.containsKey("error")) return null;
    final parse = json["parse"];
    if (parse is! Map) return null;
    final wikitext = parse["wikitext"];
    if (wikitext is String) return wikitext;
    if (wikitext is Map) {
      final text = wikitext["*"];
      if (text is String) return text;
    }
    return null;
  }

  /// Extracts the imageinfo URL from an imageinfo-API response body,
  /// or null when no file URL is reported.
  static String? imageInfoUrlFromJson(Object? data) {
    final json = _jsonMap(data);
    if (json == null) return null;
    final query = json["query"];
    if (query is! Map) return null;
    final pages = query["pages"];
    if (pages is! Map) return null;
    for (final page in pages.values) {
      if (page is! Map) continue;
      final imageInfo = page["imageinfo"];
      if (imageInfo is! List || imageInfo.isEmpty) continue;
      final first = imageInfo.first;
      if (first is! Map) continue;
      final url = first["url"];
      if (url is String && url.isNotEmpty) return url;
    }
    return null;
  }

  /// The part of [wikitext] under the `==[sectionName]==` heading, up
  /// to (but excluding) the next level-2 heading, or null when the
  /// section is absent.
  static String? scopeWikitextToSection(String wikitext, String sectionName) {
    final heading = RegExp(
      "^==\\s*${RegExp.escape(sectionName)}\\s*==[ \\t]*\$",
      multiLine: true,
    );
    final match = heading.firstMatch(wikitext);
    if (match == null) return null;
    final start = match.end;
    final nextHeading = RegExp(r"^==[^=]", multiLine: true);
    final next = nextHeading.firstMatch(wikitext.substring(start));
    final end = next == null ? wikitext.length : start + next.start;
    return wikitext.substring(start, end);
  }

  static bool _looksLikeAudioFilename(String value) {
    if (value.contains("[") ||
        value.contains("]") ||
        value.contains("{") ||
        value.contains("}") ||
        value.contains("|") ||
        value.contains("\n")) {
      return false;
    }
    return _audioExtensionPattern.hasMatch(value);
  }

  /// The filename carried by one `{{audio}}` template body, or null
  /// when the template has no in-language audio file.
  ///
  /// The `{{audio}}` argument order is not fixed, so all parameters
  /// are scanned: the filename is the parameter (positional or
  /// named) whose value looks like an audio filename, and the
  /// language is param 1 when it looks like a language code, or the
  /// named `lang=` value. A template whose explicit language code
  /// does not match [languageCode] is skipped; a template with no
  /// explicit language code is accepted on the strength of the
  /// section scoping alone.
  static String? _audioTemplateFilename(String body, String languageCode) {
    final params = body.split("|").map((part) => part.trim()).toList();
    String? explicitLanguage;
    final candidates = <String>[];
    for (var i = 0; i < params.length; i++) {
      final param = params[i];
      final equals = param.indexOf("=");
      if (equals > 0) {
        final key = param.substring(0, equals).trim().toLowerCase();
        final value = param.substring(equals + 1).trim();
        if (key == "lang" || key == "language") {
          explicitLanguage = value;
        }
        candidates.add(value);
      } else {
        if (i == 0 && _languageCodePattern.hasMatch(param)) {
          explicitLanguage ??= param;
        }
        candidates.add(param);
      }
    }
    if (explicitLanguage != null &&
        _normalizeLanguageCode(explicitLanguage) !=
            _normalizeLanguageCode(languageCode)) {
      return null;
    }
    for (final candidate in candidates) {
      if (_looksLikeAudioFilename(candidate)) return candidate;
    }
    return null;
  }

  /// The first in-language audio filename in [wikitext]'s target
  /// language section, or null when there is none.
  ///
  /// `{{audio}}` templates are scanned first; `[[File:]]` links are
  /// a secondary fallback and never outrank a template match. The
  /// first in-language match in the section wins (v1 has no accent
  /// preference): one spelling can carry several files — e.g. the
  /// noun and verb entries for "house" have different recordings —
  /// and the section's first file is the one that plays.
  static String? extractAudioFilename(String wikitext, String languageCode) {
    final sectionName = wiktionarySectionNameForLanguage(languageCode);
    if (sectionName == null) return null;
    final scoped = scopeWikitextToSection(wikitext, sectionName);
    if (scoped == null) return null;
    for (final match in _audioTemplatePattern.allMatches(scoped)) {
      final filename = _audioTemplateFilename(
        match.group(1) ?? "",
        languageCode,
      );
      if (filename != null) return filename;
    }
    for (final match in _fileLinkPattern.allMatches(scoped)) {
      final filename = (match.group(1) ?? "").trim();
      if (_looksLikeAudioFilename(filename)) return filename;
    }
    return null;
  }

  Future<String?> _fetchWikitext(String title) async {
    final response = await _fetcher(
      parseApiUri(title),
      headers: {"User-Agent": userAgent},
      asBytes: false,
    );
    if (response.statusCode == 403 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw OnlinePronunciationTransientException(response.statusCode);
    }
    if (response.statusCode != 200) return null;
    return wikitextFromJson(response.data);
  }

  Future<String?> _audioUrlFor(String filename) async {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".mp3")) {
      final response = await _fetcher(
        imageInfoApiUri(filename),
        headers: {"User-Agent": userAgent},
        asBytes: false,
      );
      if (response.statusCode == 403 ||
          response.statusCode == 429 ||
          response.statusCode >= 500) {
        throw OnlinePronunciationTransientException(response.statusCode);
      }
      if (response.statusCode != 200) return null;
      return imageInfoUrlFromJson(response.data);
    }
    return commonsTranscodeUrl(filename);
  }

  Future<Uint8List?> _fetchBytes(Uri url) async {
    final response = await _fetcher(url, asBytes: true);
    if (response.statusCode == 403 ||
        response.statusCode == 429 ||
        response.statusCode >= 500) {
      throw OnlinePronunciationTransientException(response.statusCode);
    }
    if (response.statusCode != 200) return null;
    final bytes = response.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }

  @override
  Future<Uint8List?> fetchAudio(String word, String languageCode) async {
    if (word.isEmpty) return null;
    if (wiktionarySectionNameForLanguage(languageCode) == null) return null;
    try {
      for (final title in titleVariants(word)) {
        final wikitext = await _fetchWikitext(title);
        if (wikitext == null) continue;
        final filename = extractAudioFilename(wikitext, languageCode);
        if (filename == null) continue;
        final url = await _audioUrlFor(filename);
        if (url == null) continue;
        final bytes = await _fetchBytes(Uri.parse(url));
        if (bytes != null) return bytes;
        // A 404 on the transcode means this file has no usable
        // derivative in v1: no ogg/wav-original fallback. The other
        // title variant resolves to the same page, so stop here.
        return null;
      }
      return null;
    } on OnlinePronunciationTransientException {
      rethrow;
    } catch (e, stackTrace) {
      talker.error("Wiktionary pronunciation request failed", e, stackTrace);
      return null;
    }
  }
}

/// A file-backed cache of online pronunciation audio.
///
/// Hits are stored under the md5 of `"$sourceId|$language|$word"` with
/// no extension; misses under the same name plus `.miss`. The cache
/// is rebuildable (like the full-text-search database): deleting the
/// directory only loses cached audio. Files are evicted oldest-first
/// by mtime when the file or byte cap is exceeded on write.
class OnlinePronunciationCache {
  OnlinePronunciationCache(
    this.directory, {
    this.maxFiles = 1000,
    this.maxBytes = 200 * 1024 * 1024,
    this.missTtl = const Duration(hours: 1),
  });

  /// Creates (or opens) the cache under the application cache
  /// directory's `online_pronunciation` subdirectory.
  static Future<OnlinePronunciationCache> create() async {
    final cacheDirectory = await getApplicationCacheDirectory();
    final directory = Directory(
      p.join(cacheDirectory.path, "online_pronunciation"),
    );
    await directory.create(recursive: true);
    return OnlinePronunciationCache(directory);
  }

  final Directory directory;

  /// Maximum number of files (hits and misses together).
  final int maxFiles;

  /// Maximum total bytes of cached files.
  final int maxBytes;

  /// How long a recorded miss suppresses re-requesting the same word.
  final Duration missTtl;

  /// The cache filename for a lookup, with no extension.
  static String cacheFilename(String sourceId, String language, String word) {
    final digest = md5.convert(utf8.encode("$sourceId|$language|$word"));
    return digest.toString();
  }

  File _hitFile(String sourceId, String language, String word) {
    return File(
      p.join(directory.path, cacheFilename(sourceId, language, word)),
    );
  }

  File _missFile(String sourceId, String language, String word) {
    return File(
      p.join(directory.path, "${cacheFilename(sourceId, language, word)}.miss"),
    );
  }

  /// Cached bytes for a lookup, or null on a miss. A hit refreshes
  /// the file's mtime so eviction stays least-recently-used.
  Future<Uint8List?> get(String sourceId, String language, String word) async {
    try {
      final file = _hitFile(sourceId, language, word);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      return bytes;
    } catch (e, stackTrace) {
      talker.error("Online pronunciation cache read failed", e, stackTrace);
      return null;
    }
  }

  /// Stores [bytes] for a lookup, dropping any miss record for it.
  Future<void> put(
    String sourceId,
    String language,
    String word,
    Uint8List bytes,
  ) async {
    try {
      await directory.create(recursive: true);
      final file = _hitFile(sourceId, language, word);
      await file.writeAsBytes(bytes, flush: true);
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      final miss = _missFile(sourceId, language, word);
      if (await miss.exists()) {
        try {
          await miss.delete();
        } catch (_) {}
      }
      await _enforceLimits(exceptPath: file.path);
    } catch (e, stackTrace) {
      talker.error("Online pronunciation cache write failed", e, stackTrace);
    }
  }

  /// Records that a lookup had no audio, suppressing re-requests
  /// until [missTtl] passes. Never overwrites an existing hit.
  Future<void> putMiss(String sourceId, String language, String word) async {
    try {
      await directory.create(recursive: true);
      if (await _hitFile(sourceId, language, word).exists()) return;
      final file = _missFile(sourceId, language, word);
      await file.writeAsBytes(const [], flush: true);
      try {
        await file.setLastModified(DateTime.now());
      } catch (_) {}
      await _enforceLimits(exceptPath: file.path);
    } catch (e, stackTrace) {
      talker.error(
        "Online pronunciation cache miss write failed",
        e,
        stackTrace,
      );
    }
  }

  /// Whether a miss was recorded for a lookup within [missTtl].
  /// Stale miss records are removed when noticed.
  Future<bool> hasRecentMiss(
    String sourceId,
    String language,
    String word,
  ) async {
    try {
      final file = _missFile(sourceId, language, word);
      if (!await file.exists()) return false;
      final modified = await file.lastModified();
      if (DateTime.now().difference(modified) <= missTtl) return true;
      try {
        await file.delete();
      } catch (_) {}
      return false;
    } catch (e, stackTrace) {
      talker.error(
        "Online pronunciation cache miss check failed",
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _enforceLimits({required String exceptPath}) async {
    try {
      final entries = <({String path, int size, DateTime modified})>[];
      var totalBytes = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          entries.add((
            path: entity.path,
            size: stat.size,
            modified: stat.modified,
          ));
          totalBytes += stat.size;
        } catch (_) {}
      }
      entries.sort((a, b) => a.modified.compareTo(b.modified));
      var count = entries.length;
      for (final entry in entries) {
        if (count <= maxFiles && totalBytes <= maxBytes) break;
        if (entry.path == exceptPath) continue;
        try {
          await File(entry.path).delete();
          count--;
          totalBytes -= entry.size;
        } catch (_) {}
      }
    } catch (e, stackTrace) {
      talker.error("Online pronunciation cache eviction failed", e, stackTrace);
    }
  }
}

/// Resolves a word's pronunciation from the enabled online sources,
/// in the fixed order Wiktionary then Forvo.
///
/// The coordinator reads the enabled flags and per-source languages
/// from the global [settings] singleton (resolving an empty language
/// setting against the UI locale) and the Forvo key from secure
/// storage (via [ForvoPronunciationSource]). The cache is consulted
/// first: a hit returns bytes, a recent miss skips the source, and a
/// successful fetch is cached while a definitive miss is recorded.
/// Concurrent resolutions of the same (source, language, word) share
/// one in-flight fetch.
class OnlinePronunciationCoordinator {
  OnlinePronunciationCoordinator({
    List<OnlinePronunciationSource>? sources,
    OnlinePronunciationCache? cache,
    this._cacheFactory,
  }) : _sources = sources ?? _defaultSources(),
       _providedCache = cache;

  static List<OnlinePronunciationSource> _defaultSources() => [
    WiktionaryPronunciationSource(),
    ForvoPronunciationSource(),
  ];

  final List<OnlinePronunciationSource> _sources;
  final OnlinePronunciationCache? _providedCache;
  final Future<OnlinePronunciationCache> Function()? _cacheFactory;
  Future<OnlinePronunciationCache?>? _cacheFuture;
  final Map<String, Future<Uint8List?>> _inFlight = {};

  OnlinePronunciationSource? _sourceById(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  Future<OnlinePronunciationCache?> _cacheInstance() async {
    try {
      _cacheFuture ??= () async {
        if (_providedCache != null) return _providedCache;
        if (_cacheFactory != null) return await _cacheFactory.call();
        return await OnlinePronunciationCache.create();
      }();
      return await _cacheFuture;
    } catch (e, stackTrace) {
      // Don't cache a failed open: the next call retries, mirroring
      // the full-text-search store's handling of a failed open.
      _cacheFuture = null;
      talker.error("Failed to open online pronunciation cache", e, stackTrace);
      return null;
    }
  }

  Future<Uint8List?> _resolveOne(
    OnlinePronunciationSource source,
    String language,
    String word,
  ) async {
    final cache = await _cacheInstance();
    if (cache != null) {
      final hit = await cache.get(source.id, language, word);
      if (hit != null) return hit;
      if (await cache.hasRecentMiss(source.id, language, word)) {
        return null;
      }
    }
    Uint8List? bytes;
    try {
      bytes = await source.fetchAudio(word, language);
    } on OnlinePronunciationTransientException {
      // Refused/rate-limited: no audio, and no miss record.
      return null;
    } catch (e, stackTrace) {
      talker.error("Online pronunciation source failed", e, stackTrace);
      return null;
    }
    if (bytes == null || bytes.isEmpty) {
      // A rejected Forvo key is not a property of this word: don't
      // let a miss record suppress the retry after the key changes.
      final keyRejected =
          source is ForvoPronunciationSource && source.keyMarkedInvalid;
      if (cache != null && !keyRejected) {
        await cache.putMiss(source.id, language, word);
      }
      return null;
    }
    if (cache != null) {
      await cache.put(source.id, language, word, bytes);
    }
    return bytes;
  }

  /// Returns audio bytes for [word] from the first enabled source
  /// that has them, or null when no enabled source does.
  Future<Uint8List?> resolve(String word) async {
    if (word.isEmpty) return null;
    final fallback = onlinePronunciationFallbackLanguageCode();
    final attempts = <(OnlinePronunciationSource, String)>[];
    if (settings.wiktionaryPronunciationEnabled) {
      final source = _sourceById("wiktionary");
      if (source != null) {
        attempts.add((
          source,
          resolveOnlinePronunciationLanguage(
            settings.wiktionaryPronunciationLanguage,
            fallback,
          ),
        ));
      }
    }
    if (settings.forvoPronunciationEnabled) {
      final source = _sourceById("forvo");
      if (source != null) {
        attempts.add((
          source,
          resolveOnlinePronunciationLanguage(
            settings.forvoPronunciationLanguage,
            fallback,
          ),
        ));
      }
    }
    for (final (source, language) in attempts) {
      final key = "${source.id}|$language|$word";
      final existing = _inFlight[key];
      if (existing != null) {
        final bytes = await existing;
        if (bytes != null) return bytes;
        continue;
      }
      final future = _resolveOne(source, language, word);
      _inFlight[key] = future;
      try {
        final bytes = await future;
        if (bytes != null) return bytes;
      } finally {
        _inFlight.remove(key);
      }
    }
    return null;
  }
}

OnlinePronunciationCoordinator? _defaultCoordinator;

/// Test override for the shared coordinator used by
/// [resolveOnlinePronunciation]. Production code leaves this null so
/// the lazily created default coordinator is used; tests set a
/// coordinator with fake sources/cache and clear it in tearDown.
@visibleForTesting
OnlinePronunciationCoordinator? onlinePronunciationCoordinatorOverride;

/// Resolves [word] through the shared online pronunciation
/// coordinator (see [OnlinePronunciationCoordinator]). Never throws.
Future<Uint8List?> resolveOnlinePronunciation(String word) async {
  final coordinator =
      onlinePronunciationCoordinatorOverride ??
      (_defaultCoordinator ??= OnlinePronunciationCoordinator());
  return coordinator.resolve(word);
}
