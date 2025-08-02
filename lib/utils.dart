import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";
import "package:permission_handler/permission_handler.dart";
import "services/toast.dart";

void addToClipboard(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ToastService.show(AppLocalizations.of(context)!.copied, context);
}

Future<Directory> databaseDirectory() {
  return Platform.isAndroid
      ? getApplicationDocumentsDirectory()
      : getApplicationSupportDirectory();
}

bool isLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= 600.0;
}

Future<bool> requestManageExternalStorage(BuildContext context) async {
  final isGranted = await Permission.manageExternalStorage.isGranted;
  if (isGranted) return true;

  final status = await Permission.manageExternalStorage.request();
  if (status.isGranted) {
    return true;
  } else {
    if (context.mounted) {
      ToastService.show(
        AppLocalizations.of(context)!.permissionDenied,
        context,
        type: ToastType.error,
      );
    }
    return false;
  }
}
