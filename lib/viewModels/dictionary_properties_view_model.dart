import "package:ciyue/repositories/dictionary.dart";
import "package:flutter/material.dart";

class DictionaryPropertiesViewModel extends ChangeNotifier {
  bool _isLoading = true;
  String _title = "";
  int _entriesTotal = 0;

  bool _disposed = false;

  bool get isLoading => _isLoading;
  String get title => _title;
  int get entriesTotal => _entriesTotal;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  Future<void> fetchProperties(String path, int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      final dict = Mdict(path: path);
      await dict.initOnlyMetadata(id);
      _title = dict.title;
      _entriesTotal = dict.entriesTotal;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
