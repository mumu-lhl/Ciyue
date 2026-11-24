import "package:ciyue/repositories/settings.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

/// Reveals the less common options of this page.
///
/// It lives next to what it reveals: the card it unlocks is on the same page
/// and directly below it, so the effect of the switch is visible at once.
class AdvanceSwitch extends StatefulWidget {
  const AdvanceSwitch({super.key});

  @override
  State<AdvanceSwitch> createState() => _AdvanceSwitchState();
}

class _AdvanceSwitchState extends State<AdvanceSwitch> {
  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context);
    return SwitchListTile(
      title: Text(locale!.advance),
      subtitle: Text(locale.advanceSwitchDescription),
      value: settings.advance,
      onChanged: (value) async {
        await settings.setAdvance(value);
        if (mounted) setState(() {});
      },
      secondary: const Icon(Icons.settings),
    );
  }
}
