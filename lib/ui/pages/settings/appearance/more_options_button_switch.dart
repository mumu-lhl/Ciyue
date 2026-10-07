import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class MoreOptionsButtonSwitch extends ConsumerStatefulWidget {
  const MoreOptionsButtonSwitch({super.key});

  @override
  ConsumerState<MoreOptionsButtonSwitch> createState() =>
      _MoreOptionsButtonSwitchState();
}

class _MoreOptionsButtonSwitchState
    extends ConsumerState<MoreOptionsButtonSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.moreOptionsButton),
      value: settings.showMoreOptionsButton,
      onChanged: (value) async {
        await prefs.setBool("showMoreOptionsButton", value);
        ref.read(homeModelProvider).update();
        setState(() {
          settings.showMoreOptionsButton = value;
        });
      },
      secondary: const Icon(Icons.more_vert),
    );
  }
}
