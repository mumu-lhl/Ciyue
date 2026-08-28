import "dart:io";

import "package:flutter_test/flutter_test.dart";

import "../../tools/update_flutter_version.dart" as updater;

void main() {
  test("updates workflow literals and repository variables only", () async {
    final root = await Directory.systemTemp.createTemp(
      "ciyue_flutter_version_",
    );
    addTearDown(() => root.delete(recursive: true));
    final workflows = Directory("${root.path}/.github/workflows")
      ..createSync(recursive: true);
    final workflow = File("${workflows.path}/build.yml")
      ..writeAsStringSync("""
jobs:
  check:
    steps:
      - with:
          flutter-version: \${{ vars.FLUTTER_VERSION }}
  reusable:
    with:
      flutter_version: 3.41.6
  delegated:
    with:
      flutter_version: \${{ inputs.flutter_version }}
""");

    final replacements = updater.updateFlutterVersion(root, "3.44.6");

    expect(replacements, 2);
    expect(workflow.readAsStringSync(), contains("flutter-version: 3.44.6"));
    expect(workflow.readAsStringSync(), contains("flutter_version: 3.44.6"));
    expect(
      workflow.readAsStringSync(),
      contains("flutter_version: \${{ inputs.flutter_version }}"),
    );
    expect(updater.updateFlutterVersion(root, "3.44.6"), 0);
  });

  test("rejects non-semantic Flutter versions", () async {
    final root = await Directory.systemTemp.createTemp(
      "ciyue_flutter_version_",
    );
    addTearDown(() => root.delete(recursive: true));

    expect(
      () => updater.updateFlutterVersion(root, "stable"),
      throwsA(isA<FormatException>()),
    );
  });
}
