import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/viewModels/chat_view_model.dart";
import "package:flutter/foundation.dart";

/// Manages custom chat scenarios stored in prefs.
class ChatScenarioManager with ChangeNotifier {
  static const String _prefsKey = "customChatScenarios";
  static const String _disabledKey = "disabledPresetScenarios";

  List<ChatScenario> _customScenarios = [];
  Set<String> _disabledPresets = {};

  ChatScenarioManager() {
    _load();
  }

  void _load() {
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr != null) {
      try {
        final list = json.decode(jsonStr) as List;
        // Parse per entry: one malformed scenario must not wipe the
        // user's whole custom list.
        _customScenarios = [
          for (final e in list)
            if (e is Map<String, dynamic>)
              for (final s in _tryParse(e)) s,
        ];
      } catch (_) {
        _customScenarios = [];
      }
    }
    final disabledJson = prefs.getString(_disabledKey);
    if (disabledJson != null) {
      try {
        _disabledPresets = (json.decode(disabledJson) as List)
            .whereType<String>()
            .toSet();
      } catch (_) {
        _disabledPresets = {};
      }
    }
  }

  Iterable<ChatScenario> _tryParse(Map<String, dynamic> json) sync* {
    try {
      yield _scenarioFromJson(json);
    } catch (_) {}
  }

  List<ChatScenario> get customScenarios => List.unmodifiable(_customScenarios);

  /// All enabled scenarios: presets (not disabled) + custom.
  List<ChatScenario> get allScenarios => [
    for (final s in ChatScenario.presets)
      if (!_disabledPresets.contains(s.id)) s,
    ..._customScenarios,
  ];

  bool isPresetDisabled(String id) => _disabledPresets.contains(id);

  Future<void> setPresetDisabled(String id, bool disabled) async {
    if (disabled) {
      _disabledPresets.add(id);
    } else {
      _disabledPresets.remove(id);
    }
    await prefs.setString(_disabledKey, json.encode(_disabledPresets.toList()));
    notifyListeners();
  }

  Future<void> addScenario(String title, String description) async {
    final scenario = ChatScenario(
      id: "custom_${DateTime.now().millisecondsSinceEpoch}",
      titleKey: title, // For custom, titleKey holds the actual title
      systemPrompt: description,
    );
    _customScenarios.add(scenario);
    await _save();
    notifyListeners();
  }

  Future<void> updateScenario(
    String id,
    String title,
    String description,
  ) async {
    final index = _customScenarios.indexWhere((s) => s.id == id);
    if (index != -1) {
      _customScenarios[index] = ChatScenario(
        id: id,
        titleKey: title,
        systemPrompt: description,
      );
      await _save();
      notifyListeners();
    }
  }

  Future<void> deleteScenario(String id) async {
    _customScenarios.removeWhere((s) => s.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final list = _customScenarios.map(_scenarioToJson).toList();
    await prefs.setString(_prefsKey, json.encode(list));
  }

  Map<String, dynamic> _scenarioToJson(ChatScenario s) => {
    "id": s.id,
    "title": s.titleKey,
    "description": s.systemPrompt,
  };

  ChatScenario _scenarioFromJson(Map<String, dynamic> json) => ChatScenario(
    id: json["id"] as String,
    titleKey: json["title"] as String,
    systemPrompt: json["description"] as String,
  );
}
