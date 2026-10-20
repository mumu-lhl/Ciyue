// ignore_for_file: avoid_print

import "dart:convert";
import "dart:io";

/// Reports translation coverage of every locale against app_en.arb.
///
/// Designed to be read by both humans and agents:
///
///   dart tools/find_missing_translations.dart
///       Human report: a coverage summary first (per locale: translated
///       count, coverage %, missing / identical-to-English / stale /
///       placeholder-error counts), then keys missing in the most
///       locales, then per-locale details. Missing entries are printed
///       as valid ARB lines (JSON-escaped) that can be pasted into the
///       locale file and translated in place.
///
///   dart tools/find_missing_translations.dart --json
///       The same data as one JSON document on stdout.
///
/// Options:
///   --summary        Only print the summary table (human mode).
///   --locale <code>  Only report this locale (may be repeated, or
///                    comma-separated). Matches @@locale or file name.
///   --strict         Exit with code 1 when any key is missing or any
///                    placeholder mismatch exists (for CI/scripts).
///
/// Per locale the report distinguishes:
///   missing             key exists in English, absent in the locale
///   identicalToEnglish  key present but value equals the English text
///                       (usually an untranslated placeholder copy;
///                       a few strings legitimately match, e.g. "OK")
///   stale               key present in the locale but removed from
///                       English — dead weight, safe to delete
///   placeholderErrors   translated value whose {placeholder} set
///                       differs from English — these break intl at
///                       runtime and should be fixed first

class LocaleReport {
  LocaleReport(this.locale, this.file);

  final String locale;
  final String file;
  final List<Map<String, String>> missing = [];
  final List<String> identicalToEnglish = [];
  final List<String> stale = [];
  final List<Map<String, Object>> placeholderErrors = [];
  String? parseError;
  int translated = 0;
}

final _placeholderRegex = RegExp(r"\{\s*([A-Za-z_][A-Za-z0-9_]*)");

Set<String> _placeholders(Object? value) {
  if (value is! String) return {};
  return _placeholderRegex.allMatches(value).map((m) => m.group(1)!).toSet();
}

String _localeFromFileName(String path) {
  final name = path.split("/").last;
  return name.replaceFirst("app_", "").replaceFirst(".arb", "");
}

Future<void> main(List<String> args) async {
  var jsonMode = false;
  var summaryOnly = false;
  var strict = false;
  final localeFilter = <String>{};
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--json":
        jsonMode = true;
      case "--summary":
        summaryOnly = true;
      case "--strict":
        strict = true;
      case "--locale":
        if (i + 1 < args.length) {
          localeFilter.addAll(args[++i].split(","));
        }
      default:
        if (args[i].startsWith("--locale=")) {
          localeFilter.addAll(args[i].substring("--locale=".length).split(","));
        } else {
          stderr.writeln("Unknown argument: ${args[i]}");
          exitCode = 2;
          return;
        }
    }
  }

  final enFile = File("lib/l10n/app_en.arb");
  if (!await enFile.exists()) {
    stderr.writeln("Error: lib/l10n/app_en.arb not found!");
    exitCode = 2;
    return;
  }
  final enJson =
      jsonDecode(await enFile.readAsString()) as Map<String, dynamic>;
  final enValues = <String, Object?>{
    for (final e in enJson.entries)
      if (!e.key.startsWith("@")) e.key: e.value,
  };
  final enKeys = enValues.keys.toSet();

  final arbFiles =
      Directory("lib/l10n")
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(".arb") && f.path != enFile.path)
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final reports = <LocaleReport>[];
  final missingInCount = <String, List<String>>{};

  for (final file in arbFiles) {
    var report = LocaleReport(_localeFromFileName(file.path), file.path);
    try {
      final jsonMap =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final declared = jsonMap["@@locale"];
      if (declared is String && declared.isNotEmpty) {
        // Prefer the declared locale for display/filtering.
        report = LocaleReport(declared, file.path);
      }
      final values = <String, Object?>{
        for (final e in jsonMap.entries)
          if (!e.key.startsWith("@")) e.key: e.value,
      };

      for (final key in enKeys) {
        if (!values.containsKey(key)) {
          report.missing.add({"key": key, "english": "${enValues[key]}"});
          missingInCount.putIfAbsent(key, () => []).add(report.locale);
        } else {
          report.translated++;
          if (values[key] == enValues[key] && "${enValues[key]}".isNotEmpty) {
            report.identicalToEnglish.add(key);
          }
          final expected = _placeholders(enValues[key]);
          final actual = _placeholders(values[key]);
          if (expected.length != actual.length ||
              !expected.containsAll(actual)) {
            report.placeholderErrors.add({
              "key": key,
              "expected": expected.toList()..sort(),
              "actual": actual.toList()..sort(),
            });
          }
        }
      }
      report.stale.addAll(values.keys.where((k) => !enKeys.contains(k)));
      report.missing.sort((a, b) => a["key"]!.compareTo(b["key"]!));
      report.identicalToEnglish.sort();
      report.stale.sort();
    } catch (e) {
      report.parseError = "$e";
    }
    if (localeFilter.isEmpty || localeFilter.contains(report.locale)) {
      reports.add(report);
    }
  }

  final missingRanked = missingInCount.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.length.compareTo(a.value.length);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  final totalMissing = reports.fold(0, (sum, r) => sum + r.missing.length);
  final totalErrors = reports.fold(
    0,
    (sum, r) => sum + r.placeholderErrors.length,
  );

  if (jsonMode) {
    print(
      jsonEncode({
        "source": {"file": enFile.path, "keys": enKeys.length},
        "locales": {
          for (final r in reports)
            r.locale: {
              "file": r.file,
              "translated": r.translated,
              "total": enKeys.length,
              "coverage": enKeys.isEmpty
                  ? 0
                  : double.parse(
                      (r.translated / enKeys.length).toStringAsFixed(4),
                    ),
              "missing": r.missing,
              "identicalToEnglish": r.identicalToEnglish,
              "stale": r.stale,
              "placeholderErrors": r.placeholderErrors,
              if (r.parseError != null) "parseError": r.parseError,
            },
        },
        "missingInMostLocales": [
          for (final e in missingRanked)
            {"key": e.key, "count": e.value.length, "locales": e.value},
        ],
      }),
    );
  } else {
    _printHuman(
      enKeys.length,
      reports,
      missingRanked,
      summaryOnly: summaryOnly,
      enJson: enJson,
    );
  }

  if (strict && (totalMissing > 0 || totalErrors > 0)) {
    exitCode = 1;
  }
}

void _printHuman(
  int totalKeys,
  List<LocaleReport> reports,
  List<MapEntry<String, List<String>>> missingRanked, {
  required bool summaryOnly,
  required Map<String, dynamic> enJson,
}) {
  print("Translation coverage (source: app_en.arb, $totalKeys keys)\n");
  print(
    "${"locale".padRight(10)}${"translated".padRight(12)}"
    "${"coverage".padRight(10)}${"missing".padRight(9)}"
    "${"identical".padRight(11)}${"stale".padRight(7)}errors",
  );
  for (final r in reports) {
    if (r.parseError != null) {
      print("${r.locale.padRight(10)}PARSE ERROR: ${r.parseError}");
      continue;
    }
    final coverage = totalKeys == 0
        ? "0%"
        : "${(r.translated / totalKeys * 100).toStringAsFixed(1)}%";
    print(
      "${r.locale.padRight(10)}${"${r.translated}/$totalKeys".padRight(12)}"
      "${coverage.padRight(10)}${"${r.missing.length}".padRight(9)}"
      "${"${r.identicalToEnglish.length}".padRight(11)}"
      "${"${r.stale.length}".padRight(7)}${r.placeholderErrors.length}",
    );
  }

  if (missingRanked.isNotEmpty) {
    print("\nKeys missing in the most locales (top 20):");
    for (final e in missingRanked.take(20)) {
      print("  ${e.key} — missing in ${e.value.length}: ${e.value.join(", ")}");
    }
  }

  if (summaryOnly) return;

  for (final r in reports) {
    if (r.parseError != null) continue;
    if (r.missing.isNotEmpty) {
      print("\n--- ${r.locale} (${r.file}): ${r.missing.length} missing ---");
      for (final m in r.missing) {
        print("${jsonEncode(m["key"])}: ${jsonEncode(m["english"])},");
        final meta = enJson["@${m["key"]}"];
        if (meta != null) {
          print("${jsonEncode("@${m["key"]}")}: ${jsonEncode(meta)},");
        }
      }
    }
    if (r.placeholderErrors.isNotEmpty) {
      print(
        "\n--- ${r.locale}: ${r.placeholderErrors.length} placeholder errors ---",
      );
      for (final e in r.placeholderErrors) {
        print(
          "  ${e["key"]}: expected ${(e["expected"] as List).join(", ")}, "
          "found ${(e["actual"] as List).join(", ")}",
        );
      }
    }
    if (r.identicalToEnglish.isNotEmpty) {
      print(
        "\n--- ${r.locale}: ${r.identicalToEnglish.length} identical to English "
        "(possibly untranslated) ---",
      );
      print("  ${r.identicalToEnglish.join(", ")}");
    }
    if (r.stale.isNotEmpty) {
      print(
        "\n--- ${r.locale}: ${r.stale.length} stale keys (not in English) ---",
      );
      print("  ${r.stale.join(", ")}");
    }
    if (r.missing.isEmpty &&
        r.placeholderErrors.isEmpty &&
        r.identicalToEnglish.isEmpty &&
        r.stale.isEmpty) {
      print("\n--- ${r.locale}: complete ---");
    }
  }
}
