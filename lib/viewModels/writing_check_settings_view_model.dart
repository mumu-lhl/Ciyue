import "package:ciyue/repositories/settings.dart";
import "package:flutter/material.dart";

class WritingCheckSettingsViewModel extends ChangeNotifier {
  bool get enableHistory => settings.enableWritingCheckHistory;

  Future<void> setEnableHistory(bool value) async {
    await settings.setEnableWritingCheckHistory(value);
    notifyListeners();
  }
}
