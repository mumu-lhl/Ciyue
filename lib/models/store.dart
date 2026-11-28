import "dart:convert";

import "package:yaml/yaml.dart";

const defaultStoreCatalogUrl =
    "https://raw.githubusercontent.com/mumu-lhl/Ciyue-Store/main/catalog.yaml";
const officialStoreSourceId = "official";

enum StoreItemType {
  dictionary,
  hunspell,
  audio;

  static StoreItemType? tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      "dictionary" => StoreItemType.dictionary,
      "hunspell" => StoreItemType.hunspell,
      "audio" => StoreItemType.audio,
      _ => null,
    };
  }
}

enum StoreSourceType {
  githubRelease,
  githubRaw,
  direct;

  static StoreSourceType? tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      "github_release" => StoreSourceType.githubRelease,
      "github_raw" => StoreSourceType.githubRaw,
      "direct" => StoreSourceType.direct,
      _ => null,
    };
  }
}

enum StoreMirrorMode {
  none,
  jsdelivr,
  custom;

  static StoreMirrorMode tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      "jsdelivr" => StoreMirrorMode.jsdelivr,
      "custom" => StoreMirrorMode.custom,
      _ => StoreMirrorMode.none,
    };
  }
}

enum StoreItemFormat {
  mdx,
  stardict,
  zim,
  hunspell,
  audioMdd,
  audioZip,
  audioZips;

  static StoreItemFormat? tryParse(String? value) {
    return switch (value?.trim().toLowerCase()) {
      "mdx" => StoreItemFormat.mdx,
      "stardict" => StoreItemFormat.stardict,
      "zim" => StoreItemFormat.zim,
      "hunspell" => StoreItemFormat.hunspell,
      "audio_mdd" => StoreItemFormat.audioMdd,
      "audio_zip" => StoreItemFormat.audioZip,
      "audio_zips" => StoreItemFormat.audioZips,
      _ => null,
    };
  }
}

class StoreDirectFile {
  final String url;
  final String filename;

  const StoreDirectFile({required this.url, required this.filename});
}

class StoreSourceConfig {
  final StoreSourceType type;
  final String? repo;
  final String? tag;
  final List<String> assetPatterns;
  final String? branch;
  final List<String> rawFiles;
  final List<StoreDirectFile> directFiles;

  const StoreSourceConfig({
    required this.type,
    this.repo,
    this.tag,
    this.assetPatterns = const [],
    this.branch,
    this.rawFiles = const [],
    this.directFiles = const [],
  });
}

class StoreTranslation {
  final String? name;
  final String? description;

  const StoreTranslation({this.name, this.description});
}

/// Normalizes a locale tag for comparison against catalog `translations` keys.
///
/// Catalog keys and UI locale tags are treated case-insensitively, with `-`
/// and `_` as equivalent separators.
String normalizeStoreLocaleTag(String localeTag) {
  return localeTag.trim().toLowerCase().replaceAll("-", "_");
}

class StoreItem {
  final String id;
  final StoreItemType type;
  final String name;
  final String description;
  final String author;
  final String license;
  final String sourceUrl;
  final List<String> languages;
  final StoreItemFormat format;
  final bool extract;
  final StoreSourceConfig source;
  final Map<String, StoreTranslation> translations;

  const StoreItem({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.author,
    required this.license,
    required this.sourceUrl,
    required this.languages,
    required this.format,
    required this.extract,
    required this.source,
    this.translations = const {},
  });

  /// Returns the translation for [localeTag], falling back from a
  /// region-specific tag (e.g. `zh_TW`) to its base language (`zh`).
  StoreTranslation? _translationFor(String localeTag) {
    final normalized = normalizeStoreLocaleTag(localeTag);
    if (normalized.isEmpty) return null;

    final exact = translations[normalized];
    if (exact != null) return exact;

    final separator = normalized.indexOf("_");
    if (separator <= 0) return null;
    return translations[normalized.substring(0, separator)];
  }

  String localizedName(String localeTag) {
    return _translationFor(localeTag)?.name ?? name;
  }

  String localizedDescription(String localeTag) {
    return _translationFor(localeTag)?.description ?? description;
  }

  /// Returns a copy with [name] and [description] resolved for [localeTag].
  ///
  /// Used when installing so the database records the name in the language
  /// active at install time.
  StoreItem localized(String localeTag) {
    final translation = _translationFor(localeTag);
    if (translation == null) return this;
    return StoreItem(
      id: id,
      type: type,
      name: translation.name ?? name,
      description: translation.description ?? description,
      author: author,
      license: license,
      sourceUrl: sourceUrl,
      languages: languages,
      format: format,
      extract: extract,
      source: source,
      translations: translations,
    );
  }
}

class StoreCatalogSource {
  final String id;
  final String name;
  final String url;
  final bool enabled;

  const StoreCatalogSource({
    required this.id,
    required this.name,
    required this.url,
    this.enabled = true,
  });

  factory StoreCatalogSource.official({bool enabled = true}) {
    return StoreCatalogSource(
      id: officialStoreSourceId,
      name: "",
      url: defaultStoreCatalogUrl,
      enabled: enabled,
    );
  }

  bool get isOfficial => id == officialStoreSourceId;

  String displayName(String officialLabel) {
    if (isOfficial) return officialLabel;
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) return trimmedName;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    return url;
  }

  StoreCatalogSource copyWith({
    String? id,
    String? name,
    String? url,
    bool? enabled,
  }) {
    return StoreCatalogSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "url": url,
    "enabled": enabled,
  };

  static StoreCatalogSource? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw["id"]?.toString().trim() ?? "";
    final url = raw["url"]?.toString().trim() ?? "";
    if (id.isEmpty || id == officialStoreSourceId || url.isEmpty) return null;
    final name = raw["name"]?.toString().trim() ?? "";
    final enabled = raw["enabled"] is bool ? raw["enabled"] as bool : true;
    return StoreCatalogSource(id: id, name: name, url: url, enabled: enabled);
  }

  static String encodeList(List<StoreCatalogSource> sources) {
    return jsonEncode(sources.map((s) => s.toJson()).toList(growable: false));
  }

  static List<StoreCatalogSource> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <StoreCatalogSource>[];
      final seenIds = <String>{};
      final seenUrls = <String>{};
      for (final entry in decoded) {
        final parsed = tryFromJson(entry);
        if (parsed == null) continue;
        if (!seenIds.add(parsed.id)) continue;
        if (!seenUrls.add(parsed.url)) continue;
        result.add(parsed);
      }
      return List<StoreCatalogSource>.unmodifiable(result);
    } catch (_) {
      return const [];
    }
  }
}

class StoreItemEntry {
  final StoreCatalogSource source;
  final StoreItem item;
  final String? catalogName;

  const StoreItemEntry({
    required this.source,
    required this.item,
    this.catalogName,
  });

  /// Storage key used to track installed items, active downloads, and updates
  /// without colliding across different catalog sources.
  String get storageKey =>
      source.isOfficial ? item.id : "${source.id}::${item.id}";

  String displaySourceName(String officialLabel) {
    if (source.isOfficial) return officialLabel;
    if (source.name.trim().isNotEmpty) return source.name.trim();
    if (catalogName != null && catalogName!.trim().isNotEmpty) {
      return catalogName!.trim();
    }
    return source.displayName(officialLabel);
  }
}

class StoreCatalog {
  final int schemaVersion;
  final String? name;
  final List<StoreItem> items;

  const StoreCatalog({
    required this.schemaVersion,
    this.name,
    required this.items,
  });
}

class StoreCatalogParser {
  static StoreCatalog parse(
    String content, {
    void Function(String message)? onWarning,
  }) {
    final doc = loadYaml(content);
    if (doc is! Map) {
      throw const FormatException("Catalog root must be a YAML mapping");
    }

    final schemaVersion = _asInt(doc["schemaVersion"]) ?? 1;
    final name = _nonEmptyString(doc["name"]);
    final rawItems = doc["items"];
    if (rawItems == null) {
      return StoreCatalog(
        schemaVersion: schemaVersion,
        name: name,
        items: const [],
      );
    }
    if (rawItems is! List) {
      throw const FormatException("Catalog 'items' must be a list");
    }

    final items = <StoreItem>[];
    final seenIds = <String>{};
    for (var i = 0; i < rawItems.length; i++) {
      final raw = rawItems[i];
      if (raw is! Map) {
        onWarning?.call("Skipping item at index $i: not a mapping");
        continue;
      }

      final parsed = _parseItem(raw, i, onWarning);
      if (parsed == null) continue;
      if (!seenIds.add(parsed.id)) {
        onWarning?.call("Skipping duplicate item id '${parsed.id}'");
        continue;
      }
      items.add(parsed);
    }

    return StoreCatalog(schemaVersion: schemaVersion, name: name, items: items);
  }

  static StoreItem? _parseItem(
    Map<dynamic, dynamic> raw,
    int index,
    void Function(String message)? onWarning,
  ) {
    final id = _nonEmptyString(raw["id"]);
    final type = StoreItemType.tryParse(_nonEmptyString(raw["type"]));
    final name = _nonEmptyString(raw["name"]);
    final author = _nonEmptyString(raw["author"]);
    final license = _nonEmptyString(raw["license"]);
    final sourceUrl = _nonEmptyString(raw["sourceUrl"]);
    final format = StoreItemFormat.tryParse(_nonEmptyString(raw["format"]));

    if (id == null ||
        type == null ||
        name == null ||
        author == null ||
        license == null ||
        sourceUrl == null ||
        format == null) {
      onWarning?.call(
        "Skipping item ${id ?? '#$index'}: missing required metadata "
        "(id, type, name, author, license, sourceUrl, format)",
      );
      return null;
    }

    final parsedSourceUri = Uri.tryParse(sourceUrl);
    if (parsedSourceUri == null ||
        !(parsedSourceUri.isScheme("http") ||
            parsedSourceUri.isScheme("https"))) {
      onWarning?.call("Skipping item '$id': invalid sourceUrl '$sourceUrl'");
      return null;
    }

    final rawSource = raw["source"];
    if (rawSource is! Map) {
      onWarning?.call("Skipping item '$id': missing 'source' mapping");
      return null;
    }

    final source = _parseSource(id, rawSource, onWarning);
    if (source == null) return null;

    final description = _asString(raw["description"])?.trim() ?? "";
    final languages = _parseStringList(raw["languages"])
        .map((e) => e.toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final translations = _parseTranslations(id, raw["translations"], onWarning);

    final defaultExtract = switch (format) {
      StoreItemFormat.audioMdd ||
      StoreItemFormat.audioZip ||
      StoreItemFormat.audioZips ||
      StoreItemFormat.zim => false,
      StoreItemFormat.mdx ||
      StoreItemFormat.stardict ||
      StoreItemFormat.hunspell => false,
    };
    final extract = _asBool(raw["extract"]) ?? defaultExtract;

    return StoreItem(
      id: id,
      type: type,
      name: name,
      description: description,
      author: author,
      license: license,
      sourceUrl: sourceUrl,
      languages: languages,
      format: format,
      extract: extract,
      source: source,
      translations: translations,
    );
  }

  static Map<String, StoreTranslation> _parseTranslations(
    String itemId,
    dynamic raw,
    void Function(String message)? onWarning,
  ) {
    if (raw == null) return const {};
    if (raw is! Map) {
      onWarning?.call(
        "Item '$itemId': 'translations' must be a mapping; ignoring",
      );
      return const {};
    }

    final translations = <String, StoreTranslation>{};
    for (final entry in raw.entries) {
      final rawKey = _nonEmptyString(entry.key);
      if (rawKey == null) {
        onWarning?.call(
          "Item '$itemId': skipping translation with an empty locale key",
        );
        continue;
      }

      final key = normalizeStoreLocaleTag(rawKey);
      if (translations.containsKey(key)) {
        onWarning?.call(
          "Item '$itemId': duplicate translation locale '$key'; keeping first",
        );
        continue;
      }

      final value = entry.value;
      if (value is! Map) {
        onWarning?.call(
          "Item '$itemId': translation '$key' must be a mapping; skipping",
        );
        continue;
      }

      final name = _nonEmptyString(value["name"]);
      final description = _nonEmptyString(value["description"]);
      if (name == null && description == null) {
        onWarning?.call(
          "Item '$itemId': translation '$key' has no name or description; skipping",
        );
        continue;
      }

      translations[key] = StoreTranslation(
        name: name,
        description: description,
      );
    }

    return translations.isEmpty
        ? const {}
        : Map<String, StoreTranslation>.unmodifiable(translations);
  }

  static StoreSourceConfig? _parseSource(
    String itemId,
    Map<dynamic, dynamic> raw,
    void Function(String message)? onWarning,
  ) {
    final type = StoreSourceType.tryParse(_nonEmptyString(raw["type"]));
    if (type == null) {
      onWarning?.call("Skipping item '$itemId': unknown source.type");
      return null;
    }

    switch (type) {
      case StoreSourceType.githubRelease:
        final repo = _nonEmptyString(raw["repo"]);
        if (repo == null || !repo.contains("/")) {
          onWarning?.call(
            "Skipping item '$itemId': invalid github_release repo",
          );
          return null;
        }
        final tag = _nonEmptyString(raw["tag"]);
        final patterns = [
          ..._parseStringList(raw["assets"]),
          ..._parseStringList(raw["assetPatterns"]),
          if (_nonEmptyString(raw["assetPattern"]) != null)
            _nonEmptyString(raw["assetPattern"])!,
        ];
        if (patterns.isEmpty) {
          onWarning?.call(
            "Skipping item '$itemId': github_release requires assets/assetPattern",
          );
          return null;
        }
        return StoreSourceConfig(
          type: type,
          repo: repo,
          tag: tag,
          assetPatterns: patterns,
        );

      case StoreSourceType.githubRaw:
        final repo = _nonEmptyString(raw["repo"]);
        if (repo == null || !repo.contains("/")) {
          onWarning?.call("Skipping item '$itemId': invalid github_raw repo");
          return null;
        }
        final branch = _nonEmptyString(raw["branch"]) ?? "main";
        final files = _parseStringList(raw["files"]);
        if (files.isEmpty) {
          onWarning?.call("Skipping item '$itemId': github_raw requires files");
          return null;
        }
        return StoreSourceConfig(
          type: type,
          repo: repo,
          branch: branch,
          rawFiles: files,
        );

      case StoreSourceType.direct:
        final directFiles = <StoreDirectFile>[];
        final rawFiles = raw["files"];
        if (rawFiles is List) {
          for (final entry in rawFiles) {
            if (entry is String && entry.trim().isNotEmpty) {
              final uri = Uri.tryParse(entry.trim());
              if (uri != null &&
                  (uri.isScheme("http") || uri.isScheme("https"))) {
                final filename = uri.pathSegments.isNotEmpty
                    ? uri.pathSegments.last
                    : "download";
                directFiles.add(
                  StoreDirectFile(url: entry.trim(), filename: filename),
                );
              }
            } else if (entry is Map) {
              final url = _nonEmptyString(entry["url"]);
              final uri = url == null ? null : Uri.tryParse(url);
              if (url == null ||
                  uri == null ||
                  !(uri.isScheme("http") || uri.isScheme("https"))) {
                continue;
              }
              final filename =
                  _nonEmptyString(entry["filename"]) ??
                  (uri.pathSegments.isNotEmpty
                      ? uri.pathSegments.last
                      : "download");
              directFiles.add(StoreDirectFile(url: url, filename: filename));
            }
          }
        } else if (_nonEmptyString(raw["url"]) != null) {
          final url = _nonEmptyString(raw["url"])!;
          final uri = Uri.tryParse(url);
          if (uri != null && (uri.isScheme("http") || uri.isScheme("https"))) {
            final filename =
                _nonEmptyString(raw["filename"]) ??
                (uri.pathSegments.isNotEmpty
                    ? uri.pathSegments.last
                    : "download");
            directFiles.add(StoreDirectFile(url: url, filename: filename));
          }
        }

        if (directFiles.isEmpty) {
          onWarning?.call(
            "Skipping item '$itemId': direct source has no valid url/files",
          );
          return null;
        }
        return StoreSourceConfig(type: type, directFiles: directFiles);
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    return null;
  }

  static String? _nonEmptyString(dynamic value) {
    final str = _asString(value)?.trim();
    if (str == null || str.isEmpty) return null;
    return str;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == "true") return true;
      if (lower == "false") return false;
    }
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map(_nonEmptyString)
        .whereType<String>()
        .toList(growable: false);
  }
}
