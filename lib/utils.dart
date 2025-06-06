import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";

void addToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(AppLocalizations.of(context)!.copied),
    duration: const Duration(seconds: 1),
  ));
}

Future<Directory> databaseDirectory() {
  return Platform.isAndroid
      ? getApplicationDocumentsDirectory()
      : getApplicationSupportDirectory();
}

bool isLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= 600.0;
}
