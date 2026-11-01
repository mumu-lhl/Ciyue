import "dart:io";

import "package:ciyue/services/platform.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel("org.eu.mumulhl.ciyue");
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // The next native reply for "pickDictionaryDirectoryPath": a path string,
  // null for a cancelled pick, or a thrown error for a failed resolution.
  Object? nextReply;
  Object? nextError;

  setUp(() {
    nextReply = null;
    nextError = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == "pickDictionaryDirectoryPath") {
        if (nextError != null) {
          throw nextError!;
        }
        return nextReply;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test("resolved path is returned when the directory exists", () async {
    final directory = await Directory.systemTemp.createTemp("ciyue_pick_");
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete();
      }
    });
    nextReply = directory.path;

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isFalse);
    expect(pick.unresolvable, isFalse);
    expect(pick.path, directory.path);
  });

  test("null reply means the user cancelled", () async {
    nextReply = null;

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isTrue);
    expect(pick.unresolvable, isFalse);
    expect(pick.path, isNull);
  });

  test("native error means unresolvable, not cancelled", () async {
    nextError = PlatformException(
      code: "UNRESOLVABLE_DIRECTORY",
      message: "Selected directory cannot be resolved",
    );

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isFalse);
    expect(pick.unresolvable, isTrue);
    expect(pick.path, isNull);
  });

  test("empty reply means unresolvable, not cancelled", () async {
    nextReply = "";

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isFalse);
    expect(pick.unresolvable, isTrue);
    expect(pick.path, isNull);
  });

  test("returned path that does not exist means unresolvable", () async {
    final missing = Directory(
      "${Directory.systemTemp.path}/ciyue_pick_missing_${DateTime.now().microsecondsSinceEpoch}",
    );
    expect(await missing.exists(), isFalse);
    nextReply = missing.path;

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isFalse);
    expect(pick.unresolvable, isTrue);
    expect(pick.path, isNull);
  });

  test("missing native method means unresolvable, not cancelled", () async {
    nextError = MissingPluginException(
      "No implementation found for method pickDictionaryDirectoryPath",
    );

    final pick = await PlatformMethod.pickDictionaryDirectoryPath();

    expect(pick.cancelled, isFalse);
    expect(pick.unresolvable, isTrue);
    expect(pick.path, isNull);
  });
}
