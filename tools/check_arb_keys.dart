// ignore_for_file: avoid_print

import "dart:convert";
import "dart:io";

/// Structural checks for the ARB files in `lib/l10n`.
///
///   dart tools/check_arb_keys.dart
///       Reports duplicated keys, keys that exist in a locale but were
///       removed from the template, `@@locale` values that disagree with
///       the file name, unparsable files, and a generated `supportedLocales`
///       list that no longer matches the files on disk. Exits with code 1
///       when any of those is found.
///
///   dart tools/check_arb_keys.dart --strict
///       Also fails when a locale is missing keys that exist in the template.
///       Untranslated strings are a normal, transient state, so the default
///       is to report them without failing.
///
/// Coverage per locale (missing / identical to English / placeholder errors)
/// is the job of `tools/find_missing_translations.dart`; this script only
/// guards the structure that `flutter gen-l10n` and Weblate rely on.
const _usage =
    "Usage: dart tools/check_arb_keys.dart [--strict] "
    "[--arb-dir <dir>] [--generated <file>]";

const _templateName = "app_en.arb";

/// Every top-level key in [source], in order and including duplicates.
///
/// `jsonDecode` silently keeps the last occurrence of a duplicated key, so
/// duplicates can only be spotted by looking at the raw text. Keys are
/// compared in their decoded form for the escapes handled below; ARB keys
/// are plain identifiers in practice.
List<String> topLevelKeys(String source) {
  final keys = <String>[];
  var depth = 0;
  var expectKey = false;
  var index = 0;
  while (index < source.length) {
    final char = source[index];
    if (char == '"') {
      final buffer = StringBuffer();
      var cursor = index + 1;
      var escaped = false;
      while (cursor < source.length) {
        final current = source[cursor];
        if (escaped) {
          buffer.write(current);
          escaped = false;
        } else if (current == "\\") {
          escaped = true;
        } else if (current == '"') {
          break;
        } else {
          buffer.write(current);
        }
        cursor++;
      }
      if (expectKey && depth == 1) keys.add(buffer.toString());
      expectKey = false;
      index = cursor + 1;
      continue;
    }
    switch (char) {
      case "{":
        depth++;
        expectKey = depth == 1;
      case "[":
        depth++;
        expectKey = false;
      case "}":
      case "]":
        depth--;
        expectKey = false;
      case ",":
        expectKey = depth == 1;
      case ":":
        expectKey = false;
    }
    index++;
  }
  return keys;
}

/// Reads the locale tags listed in the generated `supportedLocales` list.
///
/// The declaration is looked up by its full signature: the file header also
/// mentions `AppLocalizations.supportedLocales` inside a doc comment.
Set<String> generatedLocales(String source) {
  final start = source.indexOf("static const List<Locale> supportedLocales");
  if (start < 0) return {};
  final end = source.indexOf("];", start);
  if (end < 0) return {};
  final pattern = RegExp(r"Locale\('([A-Za-z_]+)'(?:, '([A-Za-z]+)')?\)");
  return {
    for (final match in pattern.allMatches(source.substring(start, end)))
      match.group(2) == null
          ? match.group(1)!
          : "${match.group(1)}_${match.group(2)}",
  };
}

String _localeFromPath(String path) =>
    path.split("/").last.replaceFirst("app_", "").replaceFirst(".arb", "");

Future<void> main(List<String> args) async {
  var strict = false;
  var arbDir = "lib/l10n";
  var generatedPath = "lib/src/generated/i18n/app_localizations.dart";
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--strict":
        strict = true;
      case "--arb-dir":
        if (i + 1 >= args.length) {
          stderr.writeln("--arb-dir needs a value");
          exit(2);
        }
        arbDir = args[++i];
      case "--generated":
        if (i + 1 >= args.length) {
          stderr.writeln("--generated needs a value");
          exit(2);
        }
        generatedPath = args[++i];
      case "--help" || "-h":
        print(_usage);
        return;
      default:
        stderr.writeln("Unknown argument: ${args[i]}");
        stderr.writeln(_usage);
        exit(2);
    }
  }

  final directory = Directory(arbDir);
  if (!directory.existsSync()) {
    stderr.writeln("Error: $arbDir not found");
    exit(2);
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith(".arb"))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final template = files
      .where((f) => f.path.endsWith(_templateName))
      .firstOrNull;
  if (template == null) {
    stderr.writeln("Error: $arbDir/$_templateName not found");
    exit(2);
  }

  final errors = <String>[];
  final missing = <String, int>{};
  final declaredLocales = <String>{};

  final templateJson =
      jsonDecode(await template.readAsString()) as Map<String, dynamic>;
  final templateKeys = {
    for (final key in templateJson.keys)
      if (!key.startsWith("@")) key,
  };

  for (final file in files) {
    final name = file.path.split("/").last;
    final expectedLocale = _localeFromPath(file.path);
    final source = await file.readAsString();

    final seen = <String, int>{};
    for (final key in topLevelKeys(source)) {
      if (key == "@@locale") continue;
      seen[key] = (seen[key] ?? 0) + 1;
    }
    for (final entry in seen.entries) {
      if (entry.value > 1) {
        errors.add("$name: duplicated key \"${entry.key}\" (${entry.value}x)");
      }
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(source) as Map<String, dynamic>;
    } on FormatException catch (error) {
      errors.add("$name: invalid JSON (${error.message})");
      continue;
    }

    final declared = json["@@locale"];
    if (declared is! String || declared.isEmpty) {
      errors.add("$name: missing \"@@locale\"");
    } else {
      declaredLocales.add(declared);
      if (declared != expectedLocale) {
        errors.add(
          "$name: \"@@locale\" is \"$declared\", expected \"$expectedLocale\"",
        );
      }
    }

    final keys = {
      for (final key in json.keys)
        if (!key.startsWith("@")) key,
    };
    for (final key in keys) {
      if (!templateKeys.contains(key)) {
        errors.add("$name: stale key \"$key\" (not in $_templateName)");
      }
    }
    missing[name] =
        templateKeys.length - keys.intersection(templateKeys).length;
  }

  final generatedFile = File(generatedPath);
  if (generatedFile.existsSync()) {
    final generated = generatedLocales(await generatedFile.readAsString());
    final missingGenerated = declaredLocales.difference(generated);
    final orphanGenerated = generated.difference(declaredLocales);
    for (final locale in missingGenerated) {
      errors.add(
        "$generatedPath: locale \"$locale\" has an ARB file but is not in "
        "supportedLocales (run flutter gen-l10n)",
      );
    }
    for (final locale in orphanGenerated) {
      errors.add(
        "$generatedPath: locale \"$locale\" is in supportedLocales but has no "
        "ARB file (run flutter gen-l10n)",
      );
    }
  } else {
    stderr.writeln("Warning: $generatedPath not found, skipped locale check");
  }

  final incomplete = missing.entries.where((entry) => entry.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (incomplete.isNotEmpty) {
    final total = incomplete.fold(0, (sum, entry) => sum + entry.value);
    final detail = incomplete
        .map((entry) => "${entry.key} ${entry.value}")
        .join(", ");
    final summary =
        "untranslated: $total key(s) across ${incomplete.length} locale(s) "
        "($detail)";
    if (strict) {
      errors.add(summary);
    } else {
      print("note: $summary");
    }
  }

  if (errors.isEmpty) {
    print(
      "ARB check passed: ${files.length} file(s), "
      "${templateKeys.length} template key(s)",
    );
    return;
  }

  for (final error in errors) {
    print(error);
  }
  print("\nARB check failed: ${errors.length} problem(s)");
  exit(1);
}
