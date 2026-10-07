import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/writing_check_settings_view_model.dart";
import "package:material_ui/material_ui.dart";

class WritingCheckSettingsPage extends StatefulWidget {
  const WritingCheckSettingsPage({super.key});

  @override
  State<WritingCheckSettingsPage> createState() =>
      _WritingCheckSettingsPageState();
}

class _WritingCheckSettingsPageState extends State<WritingCheckSettingsPage> {
  late final WritingCheckSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WritingCheckSettingsViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListenableBuilder(
            listenable: _viewModel,
            builder: (context, child) {
              return ListView(
                children: [
                  SwitchListTile(
                    title: Text(l10n.enableWritingCheckHistory),
                    value: _viewModel.enableHistory,
                    onChanged: (value) {
                      _viewModel.setEnableHistory(value);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
