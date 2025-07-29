import "package:flutter/material.dart";
import "package:logger/logger.dart";
import "dart:collection";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/utils.dart";

class LogsViewModel extends ChangeNotifier {
  bool _isMultiSelectMode = false;
  final List<int> _selectedIndices = [];

  bool get isMultiSelectMode => _isMultiSelectMode;
  List<int> get selectedIndices => _selectedIndices;
  ListQueue<OutputEvent> get logs => loggerOutput.buffer;

  void toggleSelection(int index) {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
    } else {
      _selectedIndices.add(index);
    }

    if (!_isMultiSelectMode && _selectedIndices.isNotEmpty) {
      _isMultiSelectMode = true;
    } else if (_isMultiSelectMode && _selectedIndices.isEmpty) {
      _isMultiSelectMode = false;
    }

    notifyListeners();
  }

  void clearSelection() {
    _selectedIndices.clear();
    _isMultiSelectMode = false;
    notifyListeners();
  }

  void copySelectedLogs(BuildContext context) {
    final selectedLogs = _selectedIndices
        .map((index) => logs.elementAt(index).lines.join("\n"))
        .join("\n\n");
    addToClipboard(context, selectedLogs);
    clearSelection();
  }

  void copyAllLogs(BuildContext context) {
    final allLogs = logs.map((log) => log.lines.join("\n")).join("\n\n");
    addToClipboard(context, allLogs);
  }

  void copyLog(BuildContext context, String logText) {
    addToClipboard(context, logText);
  }
}
