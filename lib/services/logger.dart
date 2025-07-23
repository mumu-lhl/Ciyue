import "package:flutter/foundation.dart";
import "package:logger/logger.dart";

class CustomLogPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final message =
        "[${event.time.toIso8601String()}] (${event.level}) ${event.message}";
    if (kDebugMode) {
      print(message);
    }

    return [message];
  }
}
