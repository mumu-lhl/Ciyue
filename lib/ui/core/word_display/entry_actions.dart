import "package:material_ui/material_ui.dart";

/// Whether the entry on screen offers the AI refresh/edit actions.
///
/// The mobile bottom bar is built by the browser shell, outside the entry
/// widget, so it cannot read the entry's selected tab directly. The entry
/// publishes the flag here and the bar offers the actions in its overflow menu.
final ValueNotifier<bool> entryAIActionsVisible = ValueNotifier<bool>(false);

/// Publishes [visible] after the current frame.
///
/// The bottom bar is a descendant of the same Scaffold as the entry, so
/// notifying it while the entry builds would rebuild a widget that is already
/// building.
void publishEntryAIActions(bool visible) {
  if (entryAIActionsVisible.value == visible) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    entryAIActionsVisible.value = visible;
  });
}
