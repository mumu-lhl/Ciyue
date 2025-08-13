// ignore_for_file: avoid_print

import "dart:convert";
import "dart:io";

Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    print("Usage: dart run tools/rename_l10n_key.dart <oldKey> <newKey>");
    exit(1);
  }

  final oldKey = arguments[0];
  final newKey = arguments[1];

  final l10nDir = Directory("lib/l10n");
  if (!await l10nDir.exists()) {
    print("Error: Directory lib/l10n not found!");
    exit(1);
  }

  final files = l10nDir.listSync().where((item) => item.path.endsWith(".arb"));

  print("Renaming key '$oldKey' to '$newKey' in *.arb files under lib/l10n/");

  var filesProcessed = 0;
  for (final fileSystemEntity in files) {
    final file = File(fileSystemEntity.path);
    final content = await file.readAsString();
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;

    if (jsonMap.containsKey(oldKey) || jsonMap.containsKey("@$oldKey")) {
      print("Processing ${file.path}");
      filesProcessed++;

      final newMap = <String, dynamic>{};
      for (final entry in jsonMap.entries) {
        var key = entry.key;
        if (key == oldKey) {
          key = newKey;
        } else if (key == "@$oldKey") {
          key = "@$newKey";
        }
        newMap[key] = entry.value;
      }

      final encoder = JsonEncoder.withIndent("  ");
      // add a newline at the end of the file
      final newContent = "${encoder.convert(newMap)}\n";
      await file.writeAsString(newContent);
    }
  }

  if (filesProcessed > 0) {
    print("Done. Renamed key in $filesProcessed files.");
    print("Please run 'flutter gen-l10n' to regenerate localization files.");
  } else {
    print("Key '$oldKey' not found in any .arb files.");
  }
}
