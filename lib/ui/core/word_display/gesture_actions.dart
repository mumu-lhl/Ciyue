import "dart:convert";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/ui/core/word_display/utils.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum GestureKind { rocker, wheel }

class GestureMessage {
  final GestureKind kind;
  final int direction;

  const GestureMessage(this.kind, this.direction);
}

/// Reads a gesture payload, or returns null when it is malformed.
GestureMessage? parseGesture(String payload) {
  Object? data;
  try {
    data = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  if (data is! Map) return null;
  final GestureKind kind;
  switch (data["kind"]) {
    case "rocker":
      kind = GestureKind.rocker;
    case "wheel":
      kind = GestureKind.wheel;
    default:
      return null;
  }
  final direction = data["direction"];
  if (direction is! int || (direction != 1 && direction != -1)) return null;
  return GestureMessage(kind, direction);
}

/// The expansion style has no dictionary tabs, so that action falls back to
/// word tabs instead of leaving the gesture silently dead.
MouseGestureAction resolveGestureAction(
  MouseGestureAction configured,
  bool hasDictionaryTabs,
) {
  if (configured == MouseGestureAction.off) return MouseGestureAction.off;
  if (configured == MouseGestureAction.dictionaryTabs && !hasDictionaryTabs) {
    return MouseGestureAction.wordTabs;
  }
  return configured;
}

/// Runs the action the reader assigned to a gesture in the appearance settings.
void handleGesture(WidgetRef ref, String payload) {
  final gesture = parseGesture(payload);
  if (gesture == null) return;
  final settings = ref.read(settingsProvider);
  final configured = gesture.kind == GestureKind.rocker
      ? settings.rockerGestureAction
      : settings.wheelGestureAction;
  final action = resolveGestureAction(configured, dictTabController != null);
  if (action == MouseGestureAction.off) return;
  if (action == MouseGestureAction.dictionaryTabs) {
    _stepDictionaryTab(gesture.direction);
    return;
  }
  final homeModel = ref.read(homeModelProvider);
  if (gesture.direction > 0) {
    homeModel.nextTab();
  } else {
    homeModel.previousTab();
  }
}

/// Steps through the dictionary tab bar, wrapping at either end. The
/// controller only exists in the tab layout, which [resolveGestureAction]
/// already accounts for.
bool _stepDictionaryTab(int direction) {
  final controller = dictTabController;
  if (controller == null) return false;
  final index = adjacentDictTabIndex(
    current: controller.index,
    length: controller.length,
    step: direction,
  );
  if (index == null) return false;
  try {
    controller.animateTo(index);
  } catch (_) {
    // The tab bar was torn down between the check and the call.
    return false;
  }
  return true;
}
