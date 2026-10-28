import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/platform.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/settings_group.dart";
import "package:ciyue/utils.dart";
import "package:file_selector/file_selector.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

class HunspellSettingsPage extends ConsumerStatefulWidget {
  const HunspellSettingsPage({super.key});

  @override
  ConsumerState<HunspellSettingsPage> createState() =>
      _HunspellSettingsPageState();
}

class _HunspellSettingsPageState extends ConsumerState<HunspellSettingsPage> {
  late Future<List<HunspellSourceData>> _sources;

  /// Why a word list could not be loaded, keyed by its id.
  var _errors = const <int, String>{};
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _sources = hunspellSourceDao.all();
    _errors = Map.of(hunspellManager.errors);
    PlatformMethod.onHunspellDirectoryImported = _onHunspellDirectoryImported;
  }

  @override
  void dispose() {
    PlatformMethod.onHunspellDirectoryImported = null;
    super.dispose();
  }

  /// The loader runs in an isolate and reports the reason it knows how to
  /// spell; everything it recognises is translated here, where the locale is.
  /// Anything else is passed through as it came — a Hunspell message is already
  /// in English and there is no translation to reach for.
  String? _errorTextFor(int id, AppLocalizations l10n) {
    final error = _errors[id];
    if (error == null) return null;
    if (error == hunspellFilesMissingMarker) return l10n.hunspellFilesMissing;
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text("Hunspell")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              // The window is edge-to-edge, so the list would otherwise run
              // under the system navigation bar and hide the last row's lower
              // half. The inset belongs in the scroll extent, so the last item
              // can still be scrolled fully into view.
              bottom: 12 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              SettingsGroupCard(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.spellcheck),
                    title: Text(l10n.enableWordFormLookup),
                    subtitle: Text(l10n.enableWordFormLookupDescription),
                    value: settings.enableHunspellMorphology,
                    onChanged: _setMorphologyEnabled,
                  ),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.hunspellLookupMode),
                    subtitle: Text(l10n.hunspellLookupModeDescription),
                    trailing: DropdownButton<HunspellLookupMode>(
                      value: settings.hunspellLookupMode,
                      items: [
                        DropdownMenuItem(
                          value: HunspellLookupMode.fallback,
                          child: Text(l10n.hunspellFallback),
                        ),
                        DropdownMenuItem(
                          value: HunspellLookupMode.supplement,
                          child: Text(l10n.hunspellSupplement),
                        ),
                      ],
                      onChanged: _setLookupMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SettingsGroupCard(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: Text(l10n.importHunspellDictionaries),
                    subtitle: Text(l10n.importHunspellDictionariesDescription),
                    trailing: _isImporting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isImporting ? null : _importDirectory,
                  ),
                  FutureBuilder<List<HunspellSourceData>>(
                    future: _sources,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return ListTile(
                          title: Text(
                            l10n.hunspellSourcesLoadFailed(
                              snapshot.error.toString(),
                            ),
                          ),
                        );
                      }
                      if (snapshot.data!.isEmpty) {
                        return ListTile(
                          title: Text(l10n.noHunspellDictionaries),
                        );
                      }

                      final sources = snapshot.data!;
                      final failed = sources
                          .where((source) => _errors.containsKey(source.id))
                          .length;
                      return Column(
                        children: [
                          if (failed > 0)
                            ListTile(
                              iconColor: Theme.of(context).colorScheme.error,
                              textColor: Theme.of(context).colorScheme.error,
                              leading: const Icon(Icons.error_outline),
                              title: Text(
                                l10n.hunspellSourcesFailedCount(failed),
                              ),
                            ),
                          for (int i = 0; i < sources.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                indent: 52,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.25),
                              ),
                            _HunspellSourceTile(
                              source: sources[i],
                              l10n: l10n,
                              errorText: _errorTextFor(sources[i].id, l10n),
                              onShowSettings: () =>
                                  _showSourceSettings(sources[i]),
                              onSetEnabled: (value) =>
                                  _setSourceEnabled(sources[i].id, value),
                              onRemove: () => _removeSource(sources[i].id),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setMorphologyEnabled(bool value) async {
    await settings.setEnableHunspellMorphology(value);
    if (value) {
      await reloadHunspellFromDatabase();
    } else {
      await hunspellManager.close();
    }
    _invalidateLookup();
    if (mounted) setState(() {});
  }

  Future<void> _setLookupMode(HunspellLookupMode? mode) async {
    if (mode == null || mode == settings.hunspellLookupMode) {
      return;
    }
    await settings.setHunspellLookupMode(mode);
    _invalidateLookup();
    if (mounted) setState(() {});
  }

  Future<void> _setSourceEnabled(int id, bool value) async {
    await hunspellSourceDao.setEnabled(id, value);
    if (settings.enableHunspellMorphology) {
      await reloadHunspellFromDatabase();
    }
    _invalidateLookup();
    _refreshSources();
  }

  Future<void> _setSourceTwoPassLookup(int id, bool value) async {
    await hunspellSourceDao.setTwoPassLookup(id, value);
    if (settings.enableHunspellMorphology) {
      await reloadHunspellFromDatabase();
    }
    _invalidateLookup();
    _refreshSources();
  }

  Future<void> _showSourceSettings(HunspellSourceData source) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var twoPass = source.twoPassLookup;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(source.name),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.twoPassLookup),
                    subtitle: Text(l10n.twoPassLookupDescription),
                    value: twoPass,
                    onChanged: (value) async {
                      setDialogState(() => twoPass = value);
                      await _setSourceTwoPassLookup(source.id, value);
                    },
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeSource(int id) async {
    await hunspellSourceDao.remove(id);
    if (settings.enableHunspellMorphology) {
      await reloadHunspellFromDatabase();
    }
    _invalidateLookup();
    _refreshSources();
  }

  Future<void> _importDirectory() async {
    if (Platform.isAndroid && !isFullFlavor()) {
      await PlatformMethod.openHunspellDirectory();
      return;
    }

    final path = await getDirectoryPath();
    if (path == null) {
      return;
    }

    setState(() => _isImporting = true);
    try {
      final pairs = await findHunspellPairs(Directory(path));
      await addHunspellPairs(pairs);
      _refreshSources();
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _onHunspellDirectoryImported() {
    _refreshSources();
  }

  void _refreshSources() {
    if (!mounted) return;
    setState(() {
      _sources = hunspellSourceDao.all();
      // Read this only after the reload that preceded the call: the manager
      // holds the failures of the last reload, not of the current one.
      _errors = Map.of(hunspellManager.errors);
    });
  }

  void _invalidateLookup() {
    ref.invalidate(dictionaryLookupProvider);
    ref.invalidate(validDictIdsProvider);
    ref.invalidate(wordContentProvider);
  }
}

class _HunspellSourceTile extends StatelessWidget {
  const _HunspellSourceTile({
    required this.source,
    required this.l10n,
    required this.onShowSettings,
    required this.onSetEnabled,
    required this.onRemove,
    this.errorText,
  });

  final HunspellSourceData source;
  final AppLocalizations l10n;
  final VoidCallback onShowSettings;
  final ValueChanged<bool> onSetEnabled;
  final VoidCallback onRemove;

  /// Set when this word list failed to load; the text is the loader's reason.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = source.twoPassLookup
        ? "${source.language ?? source.affPath} • ${l10n.twoPassLookup}"
        : (source.language ?? source.affPath);

    return ListTile(
      leading: const Icon(Icons.book),
      title: Text(source.name),
      isThreeLine: errorText != null,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(description),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 14,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      errorText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      onTap: onShowSettings,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.hunspellDictionarySettings,
            icon: const Icon(Icons.tune),
            onPressed: onShowSettings,
          ),
          Switch(value: source.enabled, onChanged: onSetEnabled),
          IconButton(
            tooltip: l10n.remove,
            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
