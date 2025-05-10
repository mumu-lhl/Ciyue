import "dart:io";

import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";

Future<Directory> databaseDirectory() {
  return Platform.isAndroid
      ? getApplicationDocumentsDirectory()
      : getApplicationSupportDirectory();
}

bool isLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width >= 600.0;
}
