import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/services/command_line.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/utils.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:path_provider/path_provider.dart";
import "package:window_manager/window_manager.dart";

/// Size used when `--reset-window-state` runs and when the window first
/// opens (see `initApp`).
const _initialWindowSize = Size(800, 600);

StreamSubscription<dynamic>? _logSubscription;

/// Appends the global talker stream to `ciyue.log` in the application support
/// directory.
///
/// Safe to call before `initApp` so startup logs are captured as well.
Future<void> enableFileLogging() async {
  if (_logSubscription != null) {
    return;
  }

  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  final file = File("${directory.path}/ciyue.log");
  final sink = file.openWrite(mode: FileMode.append);
  _logSubscription = talker.stream.listen((data) {
    // `TalkerData.toString()` is the default object string; use the formatted
    // message and strip the ANSI colours meant for the console.
    final line = data.generateTextMessage().replaceAll(
      RegExp(r"\x1B\[[0-9;]*m"),
      "",
    );
    sink.writeln(line);
  });
  talker.info("Logging to file: ${file.path}");
}

/// Builds the help text shown for `--help` and for parse errors.
String buildCommandLineUsage(CommandLineParser parser) {
  return """
Usage: ciyue [options] [--] <word>

A dictionary lookup program for desktop.

Options:
${parser.usage}

Arguments:
  <word>  Word or phrase to look up. Positional arguments are joined with
          spaces, so "ciyue break the ice" queries the phrase. Quote the
          phrase to keep it as one argument. Put -- before a word that
          starts with a dash.

Examples:
  ciyue hello
  ciyue "break the ice"
  ciyue --group-name Default hello
  ciyue --reset-window-state
  ciyue ciyue://query?word=hello&group=Default
""";
}

/// Builds the text shown for `--version`.
Future<String> buildVersionText() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return "Ciyue ${info.version} (${info.buildNumber}) on "
        "${Platform.operatingSystem}";
  } catch (_) {
    // Version lookup should never prevent `--version` from answering.
    return "Ciyue on ${Platform.operatingSystem}";
  }
}

/// Applies [options] to the running UI.
///
/// [container] must belong to the mounted `ProviderScope`.
Future<void> applyCommandLineOptions(
  ProviderContainer container,
  CommandLineOptions options,
) async {
  talker.info("Applying command line options: $options");

  if (options.noTts) {
    ttsDisabledByCommandLine = true;
  }

  if (options.resetWindowState && isDesktop()) {
    await _resetWindowState();
  }

  final groupName = options.effectiveGroupName;
  if (groupName != null) {
    await _switchToGroup(container, groupName);
  }

  final wantsWindow =
      options.word != null || options.togglePopup || options.window != null;
  if (wantsWindow && isDesktop()) {
    await _bringToFront();
  }

  final word = options.word;
  if (word != null) {
    navigateToProcessText(word);
  }
}

Future<void> _switchToGroup(ProviderContainer container, String name) async {
  final groups = await dictGroupDao.getAllGroups();
  final matches = groups.where((group) => group.name == name);
  if (matches.isEmpty) {
    talker.warning("Dictionary group not found: $name");
    return;
  }
  await container
      .read(dictManagerModelProvider)
      .setCurrentGroup(matches.first.id);
}

Future<void> _resetWindowState() async {
  try {
    await windowManager.setSize(_initialWindowSize);
    await windowManager.center();
  } catch (error, stackTrace) {
    talker.error("Failed to reset the window state", error, stackTrace);
  }
}

Future<void> _bringToFront() async {
  try {
    await windowManager.show();
    await windowManager.focus();
  } catch (error, stackTrace) {
    talker.error("Failed to bring the window to the front", error, stackTrace);
  }
}
