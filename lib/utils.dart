import "dart:io";

import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:material_ui/material_ui.dart";
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

/// The wide-landscape layout: the home split view.
///
/// Portrait tablets and phones keep the compact layout even when they are
/// wide enough to count as large screens.
bool useDesktopLayout(BuildContext context) {
  return isLargeScreen(context) &&
      MediaQuery.of(context).size.aspectRatio > 1.0;
}

/// Whether the top navigation row replaces the vertical rail.
///
/// Four labels plus the global chat button need a genuinely wide window.
/// Narrower windows keep the rail, which also leaves landscape phones (wide
/// enough for the split view, but well under this threshold) on the layout
/// they already had.
bool useTopNavBar(BuildContext context) {
  return useDesktopLayout(context) && MediaQuery.of(context).size.width >= 900;
}

Future<bool> requestManageExternalStorage(BuildContext context) async {
  final deviceInfo = DeviceInfoPlugin();
  final androidInfo = await deviceInfo.androidInfo;

  final PermissionStatus status;
  if (androidInfo.version.sdkInt >= 30) {
    final isGranted = await Permission.manageExternalStorage.isGranted;
    if (isGranted) return true;

    status = await Permission.manageExternalStorage.request();
  } else {
    final isGranted = await Permission.storage.isGranted;
    if (isGranted) return true;

    status = await Permission.storage.request();
  }

  if (status.isGranted) {
    return true;
  }

  if (context.mounted) {
    ToastService.show(
      AppLocalizations.of(context)!.permissionDenied,
      context,
      type: ToastType.error,
    );
  }
  return false;
}

bool isFullFlavor() {
  return ["full", "full-dev"].contains(appFlavor);
}

bool isDesktop() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

bool isMobile() {
  return Platform.isAndroid || Platform.isIOS;
}

/// Whether this Linux session runs on Wayland rather than X11.
///
/// `XDG_SESSION_TYPE` is the authoritative signal; `WAYLAND_DISPLAY` is a
/// fallback for sessions that do not set the former. A non-Linux platform is
/// never Wayland.
bool isWaylandSession() {
  if (!Platform.isLinux) return false;

  final sessionType = Platform.environment["XDG_SESSION_TYPE"];
  if (sessionType != null && sessionType.isNotEmpty) {
    return sessionType.toLowerCase() == "wayland";
  }

  final waylandDisplay = Platform.environment["WAYLAND_DISPLAY"];
  return waylandDisplay != null && waylandDisplay.isNotEmpty;
}
