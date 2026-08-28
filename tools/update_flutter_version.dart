import "dart:io";

final _versionPattern = RegExp(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$");
final _workflowVersionPattern = RegExp(
  r"^(\s*(?:flutter-version|flutter_version):\s*)(.+?)\s*$",
  multiLine: true,
);

int updateFlutterVersion(Directory root, String version) {
  if (!_versionPattern.hasMatch(version)) {
    throw FormatException("Invalid Flutter version: $version");
  }

  final workflows = Directory("${root.path}/.github/workflows");
  if (!workflows.existsSync()) {
    throw FileSystemException("Workflow directory not found", workflows.path);
  }

  var replacements = 0;
  final files = workflows.listSync().whereType<File>().where(
    (file) => file.path.endsWith(".yml") || file.path.endsWith(".yaml"),
  );

  for (final file in files) {
    final original = file.readAsStringSync();
    final updated = original.replaceAllMapped(_workflowVersionPattern, (match) {
      final current = match.group(2)!;
      if (current.contains("inputs.flutter_version")) return match.group(0)!;
      if (current == version) return match.group(0)!;
      if (current != r"${{ vars.FLUTTER_VERSION }}" &&
          !_versionPattern.hasMatch(current)) {
        return match.group(0)!;
      }
      replacements++;
      return "${match.group(1)}$version";
    });
    if (updated != original) file.writeAsStringSync(updated);
  }

  return replacements;
}

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      "Usage: dart run tools/update_flutter_version.dart <version>",
    );
    exitCode = 64;
    return;
  }

  try {
    final count = updateFlutterVersion(Directory.current, arguments.single);
    stdout.writeln(
      "Updated $count Flutter version references to ${arguments.single}.",
    );
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
