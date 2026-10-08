import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/cloud_sync/apply_service.dart";
import "package:ciyue/services/cloud_sync/configuration.dart";
import "package:ciyue/services/cloud_sync/coordinator.dart";
import "package:ciyue/services/cloud_sync/dictionary_sync.dart";
import "package:ciyue/services/cloud_sync/preview_service.dart";
import "package:ciyue/services/cloud_sync/session_service.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:dio/dio.dart";
import "package:file_selector/file_selector.dart" show openFile;
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
  final _sftpFingerprintController = TextEditingController();
  final _sftpKeyPassphraseController = TextEditingController();
  final _s3BucketController = TextEditingController();
  final _s3RegionController = TextEditingController(text: "us-east-1");
  final _s3AccessKeyController = TextEditingController();
  final _s3SecretKeyController = TextEditingController();

  CloudSyncConfiguration? _configuration;
  CloudSyncPreview? _preview;
  CloudSyncProvider _provider = CloudSyncProvider.webDav;
  String? _sftpPrivateKey;
  String? _sftpPrivateKeyName;
  bool _removeSftpPrivateKey = false;
  bool _s3UsePathStyle = true;
  String? _statusMessage;
  String? _mismatchedCloudSpaceId;
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
    _sftpFingerprintController.dispose();
    _sftpKeyPassphraseController.dispose();
    _s3BucketController.dispose();
    _s3RegionController.dispose();
    _s3AccessKeyController.dispose();
    _s3SecretKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadConfiguration() async {
    final configuration = await _session.loadConfiguration();
    if (!mounted) return;
    setState(() {
      _configuration = configuration;
      _provider = configuration.provider;
      _endpointController.text = configuration.endpoint;
      _remoteRootController.text = configuration.remoteRoot;
      _usernameController.text = configuration.username;
      _passwordController.clear();
      _sftpFingerprintController.text =
          configuration.sftpHostKeyFingerprint ?? "";
      _sftpKeyPassphraseController.clear();
      _s3BucketController.text = configuration.s3Bucket ?? "";
      _s3RegionController.text = configuration.s3Region ?? "us-east-1";
      _s3AccessKeyController.text = configuration.s3AccessKeyId ?? "";
      _s3SecretKeyController.clear();
      _s3UsePathStyle = configuration.s3UsePathStyle;
      _sftpPrivateKey = null;
      _sftpPrivateKeyName = null;
      _removeSftpPrivateKey = false;
    });
  }

  void _invalidatePreview() {
    if (_preview == null &&
        _statusMessage == null &&
        _mismatchedCloudSpaceId == null) {
      return;
    }
    setState(() {
      _preview = null;
      _selectedDictionaryPackageIds.clear();
      _statusMessage = null;
      _mismatchedCloudSpaceId = null;
    });
  }

  CloudSyncConnectionSettings _connectionSettings() {
    final saved = _configuration?.provider == _provider ? _configuration : null;
    final selectedPrivateKey = _removeSftpPrivateKey
        ? null
        : _sftpPrivateKey ?? saved?.sftpPrivateKey;
    return CloudSyncConnectionSettings(
      provider: _provider,
      endpoint: _endpointController.text.trim(),
      remoteRoot: _remoteRootController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : saved?.password,
      sftpHostKeyFingerprint: _sftpFingerprintController.text.trim(),
      sftpPrivateKey: selectedPrivateKey,
      sftpKeyPassphrase: _sftpKeyPassphraseController.text.isNotEmpty
          ? _sftpKeyPassphraseController.text
          : saved?.sftpKeyPassphrase,
      s3Bucket: _s3BucketController.text.trim(),
      s3Region: _s3RegionController.text.trim(),
      s3AccessKeyId: _s3AccessKeyController.text.trim(),
      s3SecretAccessKey: _s3SecretKeyController.text.isNotEmpty
          ? _s3SecretKeyController.text
          : saved?.s3SecretAccessKey,
      s3UsePathStyle: _s3UsePathStyle,
    );
  }

  void _onProviderChanged(CloudSyncProvider? provider) {
    if (provider == null || provider == _provider) return;
    setState(() {
      _provider = provider;
      if (provider == CloudSyncProvider.s3) _usernameController.clear();
      _passwordController.clear();
      _sftpKeyPassphraseController.clear();
      _s3SecretKeyController.clear();
      _sftpPrivateKey = null;
      _sftpPrivateKeyName = null;
      _removeSftpPrivateKey = false;
      if (_configuration?.provider != provider) {
        _sftpFingerprintController.clear();
      }
      _statusMessage = null;
    });
    _invalidatePreview();
  }

  Future<void> _chooseSftpPrivateKey() async {
    final file = await openFile();
    if (file == null) return;
    try {
      final contents = await file.readAsString();
      if (contents.length > 128 * 1024) {
        if (mounted) {
          setState(
            () => _statusMessage =
                "${AppLocalizations.of(context)!.cloudSyncSyncFailed}: Private key file is too large (>128KB).",
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _sftpPrivateKey = contents;
        _sftpPrivateKeyName = file.name;
        _removeSftpPrivateKey = false;
      });
      _invalidatePreview();
    } catch (e) {
      if (mounted) {
        setState(
          () => _statusMessage = _formatSyncError(
            e,
            AppLocalizations.of(context)!,
          ),
        );
      }
    }
  }

  void _clearSftpPrivateKey() {
    setState(() {
      _sftpPrivateKey = null;
      _sftpPrivateKeyName = null;
      _removeSftpPrivateKey = true;
    });
    _invalidatePreview();
  }

  bool _isSavedProfile() {
    final configuration = _configuration;
    if (configuration == null || !configuration.isConfigured) return false;
    final settings = _connectionSettings();
    return settings.provider == configuration.provider &&
        settings.endpoint == configuration.endpoint &&
        settings.remoteRoot == configuration.remoteRoot &&
        settings.username == configuration.username &&
        switch (settings.provider) {
          CloudSyncProvider.webDav => true,
          CloudSyncProvider.sftp =>
            settings.sftpHostKeyFingerprint ==
                configuration.sftpHostKeyFingerprint,
          CloudSyncProvider.s3 =>
            settings.s3Bucket == configuration.s3Bucket &&
                settings.s3Region == configuration.s3Region &&
                settings.s3AccessKeyId == configuration.s3AccessKeyId &&
                settings.s3UsePathStyle == configuration.s3UsePathStyle,
        };
  }

  String _providerLabel(AppLocalizations l10n, CloudSyncProvider provider) =>
      switch (provider) {
        CloudSyncProvider.webDav => l10n.cloudSyncProviderWebDav,
        CloudSyncProvider.sftp => l10n.cloudSyncProviderSftp,
        CloudSyncProvider.s3 => l10n.cloudSyncProviderS3,
      };

  Future<void> _previewConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = _connectionSettings();
    if (_provider == CloudSyncProvider.webDav &&
        settings.username.isNotEmpty !=
            (settings.password != null && settings.password!.isNotEmpty)) {
      setState(() => _statusMessage = l10n.cloudSyncCredentialsPair);
      return;
    }
    if (_provider == CloudSyncProvider.sftp &&
        (settings.username.isEmpty ||
            (settings.password?.isNotEmpty != true &&
                settings.sftpPrivateKey?.isNotEmpty != true) ||
            settings.sftpHostKeyFingerprint?.isNotEmpty != true)) {
      setState(() => _statusMessage = l10n.cloudSyncSftpCredentialsHint);
      return;
    }
    if (_provider == CloudSyncProvider.s3 &&
        (settings.s3Bucket?.isNotEmpty != true ||
            settings.s3Region?.isNotEmpty != true ||
            settings.s3AccessKeyId?.isNotEmpty != true ||
            settings.s3SecretAccessKey?.isNotEmpty != true)) {
      setState(() => _statusMessage = l10n.cloudSyncSyncFailed);
      return;
    }

    setState(() {
      _busy = true;
      _preview = null;
      _statusMessage = null;
    });
    try {
      final preview = await _session.preview(settings: settings);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _selectedDictionaryPackageIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is CloudSyncSpaceMismatchException) {
          _mismatchedCloudSpaceId = e.cloudSpaceId;
        }
        _statusMessage = _formatSyncError(e, l10n);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndSync() async {
    final preview = _preview;
    if (preview == null) return;
    final l10n = AppLocalizations.of(context)!;
    final settings = _connectionSettings();

    setState(() {
      _busy = true;
      _statusMessage = null;
      _mismatchedCloudSpaceId = null;
    });
    try {
      final outcome = await _session.connectAndSync(
        settings: settings,
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
        _passwordController.clear();
        _sftpKeyPassphraseController.clear();
        _s3SecretKeyController.clear();
        _sftpPrivateKey = null;
        _sftpPrivateKeyName = null;
        _removeSftpPrivateKey = false;
        _preview = null;
        _selectedDictionaryPackageIds.clear();
        _statusMessage = outcome.conflicts.isEmpty
            ? l10n.cloudSyncSyncComplete
            : l10n.cloudSyncConflicts(outcome.conflicts.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is CloudSyncSpaceMismatchException) {
          _mismatchedCloudSpaceId = e.cloudSpaceId;
        }
        _statusMessage = _formatSyncError(e, l10n);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _mismatchedCloudSpaceId = null;
    });
    try {
      final outcome = await _session.syncConfigured();
      final configuration = await _session.loadConfiguration();
      if (!mounted) return;
      setState(() {
        _configuration = configuration;
        _preview = null;
        _selectedDictionaryPackageIds.clear();
        _statusMessage = outcome.conflicts.isEmpty
            ? l10n.cloudSyncSyncComplete
            : l10n.cloudSyncConflicts(outcome.conflicts.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is CloudSyncSpaceMismatchException) {
          _mismatchedCloudSpaceId = e.cloudSpaceId;
        }
        _statusMessage = _formatSyncError(e, l10n);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rebindSpaceAndSync(String newSpaceId) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _statusMessage = null;
      _mismatchedCloudSpaceId = null;
    });
    try {
      await _session.rebindSpace(newSpaceId);
      final outcome = await _session.syncConfigured();
      final configuration = await _session.loadConfiguration();
      if (!mounted) return;
      setState(() {
        _configuration = configuration;
        _preview = null;
        _selectedDictionaryPackageIds.clear();
        _statusMessage = outcome.conflicts.isEmpty
            ? l10n.cloudSyncSyncComplete
            : l10n.cloudSyncConflicts(outcome.conflicts.length);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is CloudSyncSpaceMismatchException) {
          _mismatchedCloudSpaceId = e.cloudSpaceId;
        }
        _statusMessage = _formatSyncError(e, l10n);
      });
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
      _mismatchedCloudSpaceId = null;
    });
    try {
      await _session.disconnect();
      await _loadConfiguration();
      if (!mounted) return;
      setState(() {
        _passwordController.clear();
        _sftpKeyPassphraseController.clear();
        _s3SecretKeyController.clear();
        _sftpPrivateKey = null;
        _sftpPrivateKeyName = null;
        _removeSftpPrivateKey = false;
        _statusMessage = l10n.cloudSyncDisconnected;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = _formatSyncError(e, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatSyncError(Object error, AppLocalizations l10n) {
    if (error is CloudSyncSpaceMismatchException) {
      return "${l10n.cloudSyncSyncFailed}: Local sync space (${error.localSpaceId}) does not match cloud folder (${error.cloudSpaceId}).";
    }
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        return "${l10n.cloudSyncSyncFailed}: Authentication failed (HTTP $statusCode). Please verify your credentials.";
      }
      if (statusCode == 404) {
        return "${l10n.cloudSyncSyncFailed}: Remote folder or URL not found (HTTP 404).";
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return "${l10n.cloudSyncSyncFailed}: Connection timed out. Please check network connectivity.";
      }
      if (error.type == DioExceptionType.connectionError) {
        return "${l10n.cloudSyncSyncFailed}: Failed to connect to server: ${error.message ?? 'connection refused'}.";
      }
      return "${l10n.cloudSyncSyncFailed}: ${error.response?.statusMessage ?? error.message ?? error.toString()}";
    }
    if (error is SocketException) {
      return "${l10n.cloudSyncSyncFailed}: Network error (${error.message}).";
    }
    if (error is HandshakeException) {
      return "${l10n.cloudSyncSyncFailed}: SSL/TLS handshake failed (${error.message}).";
    }
    if (error is CloudSyncLocalChangedException) {
      return "${l10n.cloudSyncSyncFailed}: Local data changed while syncing. Please try again.";
    }
    if (error is StateError) {
      return "${l10n.cloudSyncSyncFailed}: ${error.message}";
    }
    if (error is FormatException) {
      return "${l10n.cloudSyncSyncFailed}: ${error.message}";
    }
    return "${l10n.cloudSyncSyncFailed}: $error";
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
              DropdownButtonFormField<CloudSyncProvider>(
                initialValue: _provider,
                decoration: InputDecoration(
                  labelText: l10n.cloudSyncProviderType,
                ),
                items: [
                  for (final provider in CloudSyncProvider.values)
                    DropdownMenuItem(
                      value: provider,
                      child: Text(_providerLabel(l10n, provider)),
                    ),
                ],
                onChanged: _busy ? null : _onProviderChanged,
              ),
              const SizedBox(height: 12),
              TextField(
                enabled: !_busy,
                controller: _endpointController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: switch (_provider) {
                    CloudSyncProvider.webDav => l10n.cloudSyncWebDavUrl,
                    CloudSyncProvider.sftp => l10n.cloudSyncSftpUrl,
                    CloudSyncProvider.s3 => l10n.cloudSyncS3Endpoint,
                  },
                  hintText: switch (_provider) {
                    CloudSyncProvider.webDav =>
                      "https://example.com/remote.php/dav/files/user/",
                    CloudSyncProvider.sftp =>
                      "sftp://nas.example.com:22/backup",
                    CloudSyncProvider.s3 => "https://s3.example.com",
                  },
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
              if (_provider != CloudSyncProvider.s3) ...[
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _usernameController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _provider == CloudSyncProvider.sftp
                        ? l10n.cloudSyncSftpUsername
                        : l10n.cloudSyncUsername,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
              ],
              if (_provider == CloudSyncProvider.s3) ...[
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _s3BucketController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncS3Bucket,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _s3RegionController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncS3Region,
                    hintText: "us-east-1",
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _s3AccessKeyController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncS3AccessKey,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _s3SecretKeyController,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncS3SecretKey,
                    helperText:
                        configuration?.provider == _provider &&
                            configuration?.s3SecretAccessKey != null
                        ? l10n.cloudSyncS3SecretHint
                        : null,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _s3UsePathStyle,
                  onChanged: _busy
                      ? null
                      : (value) {
                          setState(() => _s3UsePathStyle = value ?? false);
                          _invalidatePreview();
                        },
                  title: Text(l10n.cloudSyncS3PathStyle),
                ),
                Text(l10n.cloudSyncS3Hint),
              ],
              if (_provider == CloudSyncProvider.sftp) ...[
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _sftpFingerprintController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncSftpFingerprint,
                    helperText: l10n.cloudSyncSftpFingerprintHint,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
                const SizedBox(height: 8),
                Text(l10n.cloudSyncSftpCredentialsHint),
              ],
              if (_provider != CloudSyncProvider.s3) ...[
                const SizedBox(height: 12),
                TextField(
                  enabled: !_busy,
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _provider == CloudSyncProvider.sftp
                        ? l10n.cloudSyncSftpPassword
                        : l10n.cloudSyncPassword,
                    helperText:
                        configuration?.provider == _provider &&
                            configuration?.password != null
                        ? l10n.cloudSyncPasswordHint
                        : null,
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
              ],
              if (_provider == CloudSyncProvider.sftp) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseSftpPrivateKey,
                  icon: const Icon(Icons.key),
                  label: Text(l10n.cloudSyncSftpPrivateKey),
                ),
                if (_sftpPrivateKeyName case final name?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.cloudSyncSftpPrivateKeySelected(name)),
                    trailing: IconButton(
                      tooltip: l10n.cloudSyncSftpRemovePrivateKey,
                      onPressed: _busy ? null : _clearSftpPrivateKey,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  )
                else if (configuration?.provider == _provider &&
                    configuration?.sftpPrivateKey != null &&
                    !_removeSftpPrivateKey)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.cloudSyncSftpSavedPrivateKey),
                    trailing: IconButton(
                      tooltip: l10n.cloudSyncSftpRemovePrivateKey,
                      onPressed: _busy ? null : _clearSftpPrivateKey,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  enabled: !_busy,
                  controller: _sftpKeyPassphraseController,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.cloudSyncSftpKeyPassphrase,
                  ),
                  onChanged: (_) => _invalidatePreview(),
                ),
              ],
              if (configuration?.isConfigured == true) ...[
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_done),
                  title: Text(
                    l10n.cloudSyncSavedProfile(
                      _providerLabel(l10n, configuration!.provider),
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: Text(l10n.cloudSyncDisconnect),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              if (configuration?.isConfigured == true) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _syncNow,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                        label: Text(l10n.cloudSyncNow),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _previewConnection,
                        icon: const Icon(Icons.preview),
                        label: Text(l10n.cloudSyncPreviewButton),
                      ),
                    ),
                  ],
                ),
              ] else ...[
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
              ],
              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _statusMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _statusMessage == l10n.cloudSyncSyncComplete
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                ),
              ],
              if (_mismatchedCloudSpaceId != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _rebindSpaceAndSync(_mismatchedCloudSpaceId!),
                  icon: const Icon(Icons.sync_problem),
                  label: const Text("Rebind to cloud space and sync"),
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
                    _isSavedProfile()
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
