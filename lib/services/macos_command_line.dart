import "dart:io";

import "package:flutter/services.dart";

const _channel = MethodChannel("org.eu.mumulhl.ciyue/command_line");

/// Returns the command line arguments macOS delivered through the native
/// runner: the process arguments at launch plus any `ciyue://` links opened
/// while starting.
///
/// The native side attaches its channel while the window is created, which can
/// happen slightly after Dart starts; retry briefly so an early launch does
/// not lose its arguments.
Future<List<String>> consumeMacOSCommandLine() async {
  if (!Platform.isMacOS) {
    return const [];
  }

  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      final result = await _channel.invokeMethod<Object?>(
        "consumePendingCommandLine",
      );
      if (result is List) {
        return result.whereType<String>().toList(growable: false);
      }
      return const [];
    } on MissingPluginException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    } on PlatformException {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  return const [];
}

/// Registers the handler for `ciyue://` links opened while the app runs.
void initMacOSCommandLineHandler(
  void Function(List<String> arguments) onArguments,
) {
  if (!Platform.isMacOS) {
    return;
  }

  _channel.setMethodCallHandler((call) async {
    if (call.method != "commandLine") {
      return;
    }
    final arguments = (call.arguments as List?)?.whereType<String>().toList(
      growable: false,
    );
    if (arguments != null && arguments.isNotEmpty) {
      onArguments(arguments);
    }
  });
}
