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
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _sources = hunspellSourceDao.all();
    PlatformMethod.onHunspellDirectoryImported = _onHunspellDirectoryImported;
  }

  @override
  void dispose() {
    PlatformMethod.onHunspellDirectoryImported = null;
    super.dispose();
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
              const Divider(),
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
                    return ListTile(title: Text(l10n.noHunspellDictionaries));
                  }

                  return Column(
                    children: [
                      for (final source in snapshot.data!)
                        ListTile(
                          leading: const Icon(Icons.book),
                          title: Text(source.name),
                          subtitle: Text(source.language ?? source.affPath),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: source.enabled,
                                onChanged: (value) =>
                                    _setSourceEnabled(source.id, value),
                              ),
                              IconButton(
                                tooltip: l10n.remove,
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _removeSource(source.id),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
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
    if (mounted) {
      setState(() {
        _sources = hunspellSourceDao.all();
      });
    }
  }

  void _invalidateLookup() {
    ref.invalidate(dictionaryLookupProvider);
    ref.invalidate(validDictIdsProvider);
    ref.invalidate(wordContentProvider);
  }
}
