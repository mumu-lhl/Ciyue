import "package:yaml/yaml.dart";

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
  });
}

class StoreCatalog {
  final int schemaVersion;
  final List<StoreItem> items;

  const StoreCatalog({required this.schemaVersion, required this.items});
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
    final rawItems = doc["items"];
    if (rawItems == null) {
      return StoreCatalog(schemaVersion: schemaVersion, items: const []);
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

    return StoreCatalog(schemaVersion: schemaVersion, items: items);
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
    );
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
