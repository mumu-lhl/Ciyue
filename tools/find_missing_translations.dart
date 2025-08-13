// ignore_for_file: avoid_print

import "dart:convert";
import "dart:io";

Future<void> main() async {
  final l10nDir = Directory("lib/l10n");
  final files = l10nDir.listSync().where((item) => item.path.endsWith(".arb"));

  final enFile = File("lib/l10n/app_en.arb");
  if (!await enFile.exists()) {
    print("Error: lib/l10n/app_en.arb not found!");
    return;
  }
  final enContent = await enFile.readAsString();
  final enJson = jsonDecode(enContent) as Map<String, dynamic>;
  final enKeys = enJson.keys.where((key) => !key.startsWith("@")).toSet();

  print("Found ${enKeys.length} keys in app_en.arb");

  for (final fileSystemEntity in files) {
    final file = File(fileSystemEntity.path);
    if (file.path == enFile.path) {
      continue;
    }

    final content = await file.readAsString();
    final jsonMap = jsonDecode(content) as Map<String, dynamic>;
    final locale = jsonMap["@@locale"];
    final keys = jsonMap.keys.where((key) => !key.startsWith("@")).toSet();

    final missingKeys = enKeys.difference(keys);

    if (missingKeys.isNotEmpty) {
      print(
          "\n--- Missing translations for ${file.path} (locale: $locale) ---");
      for (final key in missingKeys) {
        final value = enJson[key];
        final meta = enJson["@$key"];
        print('"$key": "$value",');
        if (meta != null) {
          print('"@$key": ${jsonEncode(meta)},');
        }
      }
    } else {
      print(
          "\n--- No missing translations for ${file.path} (locale: $locale) ---");
    }
  }
}
