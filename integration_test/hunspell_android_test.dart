import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:hunspell_ffi/hunspell_ffi.dart";
import "package:integration_test/integration_test.dart";
import "package:path_provider/path_provider.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("loads Hunspell on Android", (_) async {
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory(
      "${supportDirectory.path}/hunspell_integration_test",
    )..createSync(recursive: true);
    final affFile = File("${directory.path}/simple.aff")
      ..writeAsStringSync("""SET UTF-8

SFX S Y 1
SFX S 0 s .
""");
    final dicFile = File("${directory.path}/simple.dic")
      ..writeAsStringSync("""1
rim/S
""");

    try {
      final dictionary = HunspellDictionary.open(
        affPath: affFile.path,
        dicPath: dicFile.path,
      );
      try {
        expect(dictionary.stem("rims"), contains("rim"));
      } finally {
        dictionary.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
