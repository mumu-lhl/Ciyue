import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";

class SelectionTextViewModel extends ChangeNotifier {
  String _selectedText = "";

  String get selectedText => _selectedText;

  void setSelectedText(SelectedContent? selectedContent) {
    if (selectedContent == null) return;

    final next = selectedContent.plainText.trim();
    if (next == _selectedText) return;
    _selectedText = next;
    notifyListeners();
  }

  void clear() {
    if (_selectedText.isEmpty) return;
    _selectedText = "";
    notifyListeners();
  }
}
