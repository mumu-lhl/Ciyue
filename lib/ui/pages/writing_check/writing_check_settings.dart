import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/writing_check_settings_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";

class WritingCheckSettingsPage extends StatelessWidget {
  const WritingCheckSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WritingCheckSettingsViewModel(),
      child: const _WritingCheckSettingsPage(),
    );
  }
}

class _WritingCheckSettingsPage extends StatelessWidget {
  const _WritingCheckSettingsPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Consumer<WritingCheckSettingsViewModel>(
            builder: (context, viewModel, child) {
              return ListView(
                children: [
                  SwitchListTile(
                    title: Text(l10n.enableWritingCheckHistory),
                    value: viewModel.enableHistory,
                    onChanged: (value) {
                      viewModel.setEnableHistory(value);
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
