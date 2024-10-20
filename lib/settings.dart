import 'package:ciyue/main.dart';

class _Settings {
  late bool autoExport;

  _Settings() {
    autoExport = prefs.getBool("autoExport") ?? false;
  }
}

final settings = _Settings();
