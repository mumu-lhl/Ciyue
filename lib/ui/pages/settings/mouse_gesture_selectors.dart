import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Assigns an action to each desktop mouse gesture. The action is resolved at
/// run time, so switching to the expansion layout can fall back from
/// dictionary tabs (which do not exist there) to word tabs.
class MouseGestureSelectors extends ConsumerWidget {
  const MouseGestureSelectors({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.mouse),
          title: Text(locale.rockerGesture),
          trailing: _actionDropdown(
            locale,
            settings.rockerGestureAction,
            settings.setRockerGestureAction,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.mouse),
          title: Text(locale.wheelGesture),
          trailing: _actionDropdown(
            locale,
            settings.wheelGestureAction,
            settings.setWheelGestureAction,
          ),
        ),
      ],
    );
  }

  DropdownButton<MouseGestureAction> _actionDropdown(
    AppLocalizations locale,
    MouseGestureAction value,
    Future<void> Function(MouseGestureAction) onChanged,
  ) {
    return DropdownButton<MouseGestureAction>(
      value: value,
      isDense: true,
      items: [
        DropdownMenuItem(
          value: MouseGestureAction.off,
          child: Text(locale.gestureActionOff),
        ),
        DropdownMenuItem(
          value: MouseGestureAction.dictionaryTabs,
          child: Text(locale.gestureActionDictionaryTabs),
        ),
        DropdownMenuItem(
          value: MouseGestureAction.wordTabs,
          child: Text(locale.gestureActionWordTabs),
        ),
      ],
      onChanged: (selected) async {
        if (selected != null && selected != value) {
          await onChanged(selected);
        }
      },
    );
  }
}
