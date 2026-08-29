import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/hunspell.dart";
import "package:ciyue/repositories/hunspell.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/hunspell.dart";
import "package:ciyue/services/platform.dart";
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
    return Scaffold(
      appBar: AppBar(title: const Text("Hunspell")),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ListView(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.spellcheck),
                title: const Text("Enable word-form lookup"),
                subtitle: const Text(
                  "Disabled by default. Use Hunspell to find word forms.",
                ),
                value: settings.enableHunspellMorphology,
                onChanged: _setMorphologyEnabled,
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text("Lookup mode"),
                subtitle: const Text(
                  "Choose whether stems supplement existing entries.",
                ),
                trailing: DropdownButton<HunspellLookupMode>(
                  value: settings.hunspellLookupMode,
                  items: const [
                    DropdownMenuItem(
                      value: HunspellLookupMode.fallback,
                      child: Text("Fallback"),
                    ),
                    DropdownMenuItem(
                      value: HunspellLookupMode.supplement,
                      child: Text("Supplement"),
                    ),
                  ],
                  onChanged: _setLookupMode,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text("Import Hunspell dictionaries"),
                subtitle: const Text(
                  "Select a folder containing .aff and .dic files.",
                ),
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
                      title: Text("Failed to load sources: ${snapshot.error}"),
                    );
                  }
                  if (snapshot.data!.isEmpty) {
                    return const ListTile(
                      title: Text("No Hunspell dictionaries imported"),
                    );
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
                                tooltip: "Remove",
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
