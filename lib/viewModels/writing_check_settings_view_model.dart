import "package:ciyue/repositories/settings.dart";
import "package:material_ui/material_ui.dart";

class WritingCheckSettingsViewModel extends ChangeNotifier {
  bool get enableHistory => settings.enableWritingCheckHistory;

  Future<void> setEnableHistory(bool value) async {
    await settings.setEnableWritingCheckHistory(value);
    notifyListeners();
  }
}
