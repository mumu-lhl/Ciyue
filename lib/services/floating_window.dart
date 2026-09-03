import "package:ciyue/core/app_globals.dart";
import "package:flutter/services.dart";

const _platform = MethodChannel("org.eu.mumulhl.ciyue");

Future<void> dismissFloatingWindow() async {
  if (!runningInFloatingWindow) {
    return;
  }

  try {
    await _platform.invokeMethod("dismissFloatingWindow");
  } catch (error, stackTrace) {
    talker.error("Failed to dismiss floating window", error, stackTrace);
  }
}
