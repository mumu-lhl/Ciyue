import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/session_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

class CloudSyncSettingsPage extends StatefulWidget {
  final CloudSyncSessionService? sessionService;

  const CloudSyncSettingsPage({super.key, this.sessionService});

  @override
  State<CloudSyncSettingsPage> createState() => _CloudSyncSettingsPageState();
}

class _CloudSyncSettingsPageState extends State<CloudSyncSettingsPage> {
  late final CloudSyncSessionService _session;
  final _endpointController = TextEditingController();
  final _remoteRootController = TextEditingController(text: "Ciyue");
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  CloudSyncConfiguration? _configuration;
  CloudSyncPreview? _preview;
  String? _savedPassword;
  String? _statusMessage;
  final Set<String> _selectedDictionaryPackageIds = {};
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _session =
        widget.sessionService ??
        CloudSyncSessionService(
          database: mainDatabase,
          configurationStore: CloudSyncConfigurationStore(
            preferences: prefs,
            secretStorage: const SimpleSecureCloudSecretStorage(),
          ),
        );
    _loadConfiguration();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _remoteRootController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    final configuration = await _session.loadConfiguration();
    if (!mounted) return;
    setState(() {
      _configuration = configuration;
      _savedPassword = configuration.password;
      _endpointController.text = configuration.endpoint;
      _remoteRootController.text = configuration.remoteRoot;
      _usernameController.text = configuration.username;
      _passwordController.clear();
    });
  }

  void _invalidatePreview() {
    if (_preview == null && _statusMessage == null) return;
    setState(() {
      _preview = null;
      _selectedDictionaryPackageIds.clear();
      _statusMessage = null;
    });
  }

  Future<void> _previewConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final endpoint = _endpointController.text.trim();
    final root = _remoteRootController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.isNotEmpty
        ? _passwordController.text
        : _savedPassword;
    if (username.isNotEmpty != (password != null && password.isNotEmpty)) {
      setState(() => _statusMessage = l10n.cloudSyncCredentialsPair);
      return;
    }

    setState(() {
      _busy = true;
      _preview = null;
      _statusMessage = null;
    });
    try {
      final preview = await _session.preview(
        endpoint: endpoint,
        remoteRoot: root,
        username: username,
        password: password,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selectedDictionaryPackageIds.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = l10n.cloudSyncSyncFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndSync() async {
    final preview = _preview;
    if (preview == null) return;
    final l10n = AppLocalizations.of(context)!;
    final endpoint = _endpointController.text.trim();
    final remoteRoot = _remoteRootController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.isNotEmpty
        ? _passwordController.text
        : _savedPassword;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final outcome = await _session.connectAndSync(
        endpoint: endpoint,
        remoteRoot: remoteRoot,
        username: username,
        password: password,
        previewedSpaceId: preview.spaceId,
        selectedDictionaryPackageIds: Set.unmodifiable(
          _selectedDictionaryPackageIds,
        ),
        dictionaryPreview: preview.dictionaryPreview,
      );
      final configuration = await _session.loadConfiguration();
      if (!mounted) return;
      setState(() {
        _configuration = configuration;
        _savedPassword = configuration.password;
        _passwordController.clear();
        _preview = null;
        _selectedDictionaryPackageIds.clear();
        _statusMessage = outcome.conflicts.isEmpty
            ? l10n.cloudSyncSyncComplete
            : l10n.cloudSyncConflicts(outcome.conflicts.length);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = l10n.cloudSyncSyncFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _preview = null;
      _selectedDictionaryPackageIds.clear();
      _statusMessage = null;
    });
    try {
      await _session.disconnect();
      await _loadConfiguration();
      if (!mounted) return;
      setState(() {
        _savedPassword = null;
        _passwordController.clear();
        _statusMessage = l10n.cloudSyncDisconnected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = l10n.cloudSyncSyncFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final configuration = _configuration;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudSync)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.cloudSyncDescription),
              const SizedBox(height: 16),
              TextField(
                enabled: !_busy,
                controller: _endpointController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.cloudSyncWebDavUrl,
                  hintText: "https://example.com/remote.php/dav/files/user/",
                ),
                onChanged: (_) => _invalidatePreview(),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                controller: _remoteRootController,
                decoration: InputDecoration(
                  labelText: l10n.cloudSyncRemoteFolder,
                  hintText: "Ciyue",
                ),
                onChanged: (_) => _invalidatePreview(),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                controller: _usernameController,
                autocorrect: false,
                decoration: InputDecoration(labelText: l10n.cloudSyncUsername),
                onChanged: (_) => _invalidatePreview(),
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                controller: _passwordController,
                obscureText: _obscurePassword,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.cloudSyncPassword,
                  helperText: _savedPassword == null
                      ? null
                      : l10n.cloudSyncPasswordHint,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                onChanged: (_) => _invalidatePreview(),
              ),
              if (configuration?.isConfigured == true) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_done),
                  title: Text(l10n.cloudSyncSavedProfile),
                  trailing: TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: Text(l10n.cloudSyncDisconnect),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _previewConnection,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.preview),
                label: Text(l10n.cloudSyncPreviewButton),
              ),
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (_preview case final preview?) ...[
                const SizedBox(height: 20),
                _PreviewCard(
                  preview: preview,
                  remoteFolder: _remoteRootController.text.trim(),
                  selectedDictionaryPackageIds: _selectedDictionaryPackageIds,
                  onDictionarySelectionChanged: (packageId, selected) {
                    setState(() {
                      if (selected) {
                        _selectedDictionaryPackageIds.add(packageId);
                      } else {
                        _selectedDictionaryPackageIds.remove(packageId);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _confirmAndSync,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    configuration?.isConfigured == true
                        ? l10n.cloudSyncNow
                        : l10n.cloudSyncConfirmButton,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final CloudSyncPreview preview;
  final String remoteFolder;
  final Set<String> selectedDictionaryPackageIds;
  final void Function(String packageId, bool selected)
  onDictionarySelectionChanged;

  const _PreviewCard({
    required this.preview,
    required this.remoteFolder,
    required this.selectedDictionaryPackageIds,
    required this.onDictionarySelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    String summary(CloudSyncDataSummary data) => l10n.cloudSyncLocalSummary(
      data.wordbookEntries,
      data.wordbookTags,
      data.flashcards,
      data.reviewLogs,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cloudSyncPreviewHeading,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.cloudSyncPreviewIntro(remoteFolder)),
            if (!preview.remoteFolderExists) ...[
              const SizedBox(height: 8),
              Text(l10n.cloudSyncFolderMissing),
            ],
            const SizedBox(height: 12),
            Text(summary(preview.local)),
            Text(
              l10n.cloudSyncRemoteSummary(
                preview.remote.wordbookEntries,
                preview.remote.wordbookTags,
                preview.remote.flashcards,
                preview.remote.reviewLogs,
              ),
            ),
            Text(
              l10n.cloudSyncMergedSummary(
                preview.merged.wordbookEntries,
                preview.merged.wordbookTags,
                preview.merged.flashcards,
                preview.merged.reviewLogs,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.cloudSyncRemoteDevices(preview.remoteDeviceCount)),
            const SizedBox(height: 8),
            Text(
              preview.conflicts.isEmpty
                  ? l10n.cloudSyncNoConflicts
                  : l10n.cloudSyncConflicts(preview.conflicts.length),
              style: preview.conflicts.isEmpty
                  ? null
                  : theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
            ),
            if (preview.dictionaryPreview case final dictionaryPreview?) ...[
              const SizedBox(height: 16),
              Text(
                l10n.cloudSyncDictionaries,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.cloudSyncDictionaryHint),
              if (dictionaryPreview.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(l10n.cloudSyncDictionaryEmpty),
                )
              else
                for (final item in dictionaryPreview.items)
                  CheckboxListTile(
                    key: ValueKey("dictionary-sync-${item.packageId}"),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selectedDictionaryPackageIds.contains(
                      item.packageId,
                    ),
                    onChanged: item.availableLocally == item.availableRemotely
                        ? null
                        : (selected) => onDictionarySelectionChanged(
                            item.packageId,
                            selected ?? false,
                          ),
                    title: Text(item.title),
                    subtitle: Text(
                      "${item.fileName} · "
                      "${_dictionarySyncDirection(item, l10n)} · "
                      "${l10n.cloudSyncDictionaryDetails(item.fileCount, _formatBytes(item.totalSizeBytes))}",
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

String _dictionarySyncDirection(
  DictionarySyncItem item,
  AppLocalizations l10n,
) {
  if (item.availableLocally && item.availableRemotely) {
    return l10n.cloudSyncDictionarySynced;
  }
  return item.availableLocally
      ? l10n.cloudSyncDictionaryUpload
      : l10n.cloudSyncDictionaryDownload;
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return "$bytes B";
  final kibibytes = bytes / 1024;
  if (kibibytes < 1024) return "${kibibytes.toStringAsFixed(1)} KB";
  final mebibytes = kibibytes / 1024;
  if (mebibytes < 1024) return "${mebibytes.toStringAsFixed(1)} MB";
  return "${(mebibytes / 1024).toStringAsFixed(1)} GB";
}
