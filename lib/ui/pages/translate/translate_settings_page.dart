import "package:ciyue/services/translation_sources.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/pages/settings/ai_settings/ai_settings_page.dart";
import "package:ciyue/viewModels/translate_settings_view_model.dart";
import "package:material_ui/material_ui.dart";

class AiTranslateSettingsPage extends StatefulWidget {
  const AiTranslateSettingsPage({super.key});

  @override
  State<AiTranslateSettingsPage> createState() =>
      _AiTranslateSettingsPageState();
}

class _AiTranslateSettingsPageState extends State<AiTranslateSettingsPage> {
  late final AiTranslateSettingsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AiTranslateSettingsViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        final viewModel = _viewModel;
        return Scaffold(
          appBar: AppBar(title: Text(locale.settings)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  // Output options
                  _SettingsCard(
                    child: DropdownButtonFormField<bool>(
                      decoration: InputDecoration(
                        labelText: locale.outputType,
                        prefixIcon: const Icon(Icons.tune_rounded),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      initialValue: viewModel.isRichOutput,
                      items: [
                        DropdownMenuItem(
                          value: true,
                          child: Text(locale.richOutput),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(locale.simpleOutput),
                        ),
                      ],
                      onChanged: (bool? newValue) {
                        if (newValue != null) {
                          viewModel.setRichOutput(newValue);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Sources section header
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      locale.translationSources,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      locale.translationSourcesHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Reorderable source list
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: viewModel.sourceOrder.length,
                    onReorderItem: viewModel.reorderSources,
                    itemBuilder: (context, index) {
                      final id = viewModel.sourceOrder[index];
                      final source = translationSourceById(id)!;
                      return _SourceSettingsTile(
                        key: ValueKey(id),
                        viewModel: viewModel,
                        source: source,
                        index: index,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // History toggle
                  _SettingsCard(
                    padding: EdgeInsets.zero,
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      secondary: const Icon(Icons.history_rounded),
                      title: Text(locale.enableTranslationHistory),
                      value: viewModel.enableTranslationHistory,
                      onChanged: viewModel.setEnableTranslationHistory,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant
              .withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}

/// One source row: drag handle, badge+name, config state, enable switch.
/// Expands to show config fields for key-based sources when enabled.
class _SourceSettingsTile extends StatelessWidget {
  const _SourceSettingsTile({
    super.key,
    required this.viewModel,
    required this.source,
    required this.index,
  });

  final AiTranslateSettingsViewModel viewModel;
  final TranslationSource source;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = AppLocalizations.of(context)!;
    final enabled = viewModel.enabledSources.contains(source.id);
    final configured = source.isConfigured;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Text(
              source.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: source.requiresConfig
                ? Text(
                    configured ? locale.configured : locale.notConfigured,
                    style: TextStyle(
                      color: configured
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                    ),
                  )
                : Text(locale.freeSource),
            trailing: Switch(
              value: enabled,
              onChanged: (v) => viewModel.setSourceEnabled(source.id, v),
            ),
          ),
          if (enabled && source.requiresConfig)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _SourceConfigFields(viewModel: viewModel, source: source),
            ),
        ],
      ),
    );
  }
}

/// Config text fields per source id.
class _SourceConfigFields extends StatelessWidget {
  const _SourceConfigFields({required this.viewModel, required this.source});

  final AiTranslateSettingsViewModel viewModel;
  final TranslationSource source;

  @override
  Widget build(BuildContext context) {
    if (source.isAi) {
      final locale = AppLocalizations.of(context)!;
      return Row(
        children: [
          Expanded(
            child: Text(
              locale.configureInAiSettings,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(locale.openAiSettings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsPage()),
              );
            },
          ),
        ],
      );
    }
    switch (source.id) {
      case "deeplx":
        return TextFormField(
          controller: viewModel.deeplxUrlController,
          decoration: const InputDecoration(
            labelText: "DeepLX URL",
            prefixIcon: Icon(Icons.link_rounded),
          ),
          onChanged: viewModel.setDeeplxUrl,
        );
      case "deepl":
        return _keyField(
          controller: viewModel.deeplApiKeyController,
          label: "DeepL API Key",
          onChanged: viewModel.setDeeplApiKey,
        );
      case "googleCloud":
        return _keyField(
          controller: viewModel.googleCloudApiKeyController,
          label: "Google Cloud API Key",
          onChanged: viewModel.setGoogleCloudApiKey,
        );
      case "azure":
        return Column(
          children: [
            _keyField(
              controller: viewModel.azureApiKeyController,
              label: "Azure API Key",
              onChanged: viewModel.setAzureApiKey,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: viewModel.azureRegionController,
              decoration: const InputDecoration(
                labelText: "Azure Region",
                prefixIcon: Icon(Icons.public_rounded),
              ),
              onChanged: viewModel.setAzureRegion,
            ),
          ],
        );
      case "yandex":
        return Column(
          children: [
            _keyField(
              controller: viewModel.yandexApiKeyController,
              label: "Yandex API Key",
              onChanged: viewModel.setYandexApiKey,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: viewModel.yandexFolderIdController,
              decoration: const InputDecoration(
                labelText: "Yandex Folder ID",
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              onChanged: viewModel.setYandexFolderId,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _keyField({
    required TextEditingController controller,
    required String label,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.key_rounded),
      ),
      onChanged: onChanged,
    );
  }
}
