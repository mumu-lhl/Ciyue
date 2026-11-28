import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/providers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/store.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/store.dart";
import "package:ciyue/services/toast.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/app_dropdown.dart";
import "package:dio/dio.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:url_launcher/url_launcher.dart";

class _DownloadProgress {
  final int received;
  final int total;
  final CancelToken cancelToken;

  const _DownloadProgress({
    required this.received,
    required this.total,
    required this.cancelToken,
  });

  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;
}

class StorePage extends ConsumerStatefulWidget {
  final StoreItemType? initialType;

  const StorePage({super.key, this.initialType});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  StoreItemType? _selectedType;
  String _searchQuery = "";
  String? _selectedLanguage;
  bool _isLoading = true;
  String? _loadError;

  List<StoreItemEntry> _entries = const [];
  List<StoreCatalogFailure> _sourceFailures = const [];
  int _enabledSourceCount = 0;
  Map<String, StoreInstalledItem> _installedById = const {};
  final Map<String, bool> _updatesAvailable = {};
  final Map<String, _DownloadProgress> _activeDownloads = {};

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    unawaited(_loadStore(forceRefresh: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final dl in _activeDownloads.values) {
      dl.cancelToken.cancel("Page disposed");
    }
    super.dispose();
  }

  Future<void> _loadStore({required bool forceRefresh}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final resultFuture = StoreService.instance.fetchCatalogs(
        forceRefresh: forceRefresh,
      );
      final installedFuture = storeInstalledItemDao.all();

      final result = await resultFuture;
      final installed = await installedFuture;

      final installedMap = <String, StoreInstalledItem>{
        for (final row in installed) row.itemId: row,
      };

      if (!mounted) return;
      setState(() {
        _entries = result.entries;
        _sourceFailures = result.failures;
        _enabledSourceCount = result.enabledSourceCount;
        _installedById = installedMap;
        _loadError = result.allFailed
            ? result.failures
                  .map((f) => "${f.source.url}: ${f.error}")
                  .join("\n")
            : null;
        _isLoading = false;
      });

      unawaited(
        _checkUpdatesForInstalled(result.entries, installedMap, forceRefresh),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _checkUpdatesForInstalled(
    List<StoreItemEntry> entries,
    Map<String, StoreInstalledItem> installedMap,
    bool forceRefresh,
  ) async {
    final checks = <Future<void>>[];
    for (final entry in entries) {
      final key = entry.storageKey;
      final installed = installedMap[key];
      if (installed == null) continue;
      if (entry.item.source.type == StoreSourceType.direct) continue;

      checks.add(() async {
        final hasUpdate = await StoreService.instance.hasUpdate(
          entry.item,
          installed,
          forceRefresh: forceRefresh,
        );
        if (mounted) {
          setState(() {
            _updatesAvailable[key] = hasUpdate;
          });
        }
      }());
    }
    await Future.wait(checks);
  }

  Future<void> _downloadItem(StoreItemEntry entry) async {
    final key = entry.storageKey;
    final item = entry.item;
    if (_activeDownloads.containsKey(key)) return;
    final l10n = AppLocalizations.of(context)!;
    final displayItem = item.localized(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final cancelToken = CancelToken();

    setState(() {
      _activeDownloads[key] = _DownloadProgress(
        received: 0,
        total: 0,
        cancelToken: cancelToken,
      );
    });

    try {
      final installed = await StoreService.instance.downloadAndInstall(
        displayItem,
        storageKey: key,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _activeDownloads[key] = _DownloadProgress(
              received: received,
              total: total,
              cancelToken: cancelToken,
            );
          });
        },
      );

      if (item.type == StoreItemType.dictionary) {
        ref.read(dictManagerModelProvider).update();
      }

      if (!mounted) return;
      setState(() {
        _activeDownloads.remove(key);
        _installedById = {..._installedById, key: installed};
        _updatesAvailable[key] = false;
      });
      await ToastService.show(
        l10n.storeInstallSuccess(displayItem.name),
        context,
        type: ToastType.success,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _activeDownloads.remove(key);
      });
      if (CancelToken.isCancel(e)) {
        await ToastService.show(
          l10n.storeDownloadCancelled,
          context,
          type: ToastType.info,
        );
      } else {
        await ToastService.show(
          l10n.storeInstallFailed(e.message ?? e.toString()),
          context,
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeDownloads.remove(key);
      });
      await ToastService.show(
        l10n.storeInstallFailed(e.toString()),
        context,
        type: ToastType.error,
      );
    }
  }

  void _cancelDownload(String storageKey) {
    _activeDownloads[storageKey]?.cancelToken.cancel("Cancelled by user");
  }

  Future<void> _uninstallItem(
    StoreItemEntry entry,
    StoreInstalledItem installed,
  ) async {
    final key = entry.storageKey;
    final item = entry.item;
    final l10n = AppLocalizations.of(context)!;
    final displayName = item.localizedName(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.storeUninstall),
        content: Text(l10n.storeUninstallConfirm(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.storeUninstall),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await StoreService.instance.uninstall(installed);
      if (item.type == StoreItemType.dictionary) {
        ref.read(dictManagerModelProvider).update();
      }
      if (!mounted) return;
      setState(() {
        final next = Map<String, StoreInstalledItem>.of(_installedById);
        next.remove(key);
        _installedById = next;
        _updatesAvailable.remove(key);
      });
      await ToastService.show(
        l10n.storeUninstallSuccess(displayName),
        context,
        type: ToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      await ToastService.show(
        l10n.storeInstallFailed(e.toString()),
        context,
        type: ToastType.error,
      );
    }
  }

  Future<void> _openStoreSettings() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const StoreSettingsDialog(),
    );
    if (changed == true && mounted) {
      await _loadStore(forceRefresh: true);
    }
  }

  List<String> get _availableLanguages {
    final langs = <String>{};
    for (final entry in _entries) {
      langs.addAll(entry.item.languages);
    }
    final sorted = langs.toList()..sort();
    return sorted;
  }

  List<StoreItemEntry> _filteredEntries(String localeTag) {
    final query = _searchQuery.trim().toLowerCase();
    return _entries
        .where((entry) {
          final item = entry.item;
          if (_selectedType != null && item.type != _selectedType) return false;
          if (_selectedLanguage != null &&
              !item.languages.contains(_selectedLanguage)) {
            return false;
          }
          if (query.isNotEmpty) {
            final localizedName = item.localizedName(localeTag);
            final localizedDescription = item.localizedDescription(localeTag);
            final haystack =
                "$localizedName ${item.name} "
                        "$localizedDescription ${item.description} "
                        "${item.author} ${item.license}"
                    .toLowerCase();
            if (!haystack.contains(query)) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final filtered = _filteredEntries(localeTag);
    final languages = _availableLanguages;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storeTitle),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : () => _loadStore(forceRefresh: true),
          ),
          IconButton(
            tooltip: l10n.storeSettings,
            icon: const Icon(Icons.tune_rounded),
            onPressed: _openStoreSettings,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: l10n.storeSearchHint,
                              isDense: true,
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = "");
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                          ),
                        ),
                        if (languages.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: AppDropdown<String?>(
                              value: _selectedLanguage,
                              dense: true,
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(l10n.storeAllLanguages),
                                ),
                                for (final lang in languages)
                                  DropdownMenuItem<String?>(
                                    value: lang,
                                    child: Text(lang.toUpperCase()),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedLanguage = value);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(l10n.storeFilterAll),
                            selected: _selectedType == null,
                            onSelected: (_) {
                              setState(() => _selectedType = null);
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(l10n.storeFilterDictionaries),
                            selected: _selectedType == StoreItemType.dictionary,
                            onSelected: (_) {
                              setState(
                                () => _selectedType = StoreItemType.dictionary,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(l10n.storeFilterHunspell),
                            selected: _selectedType == StoreItemType.hunspell,
                            onSelected: (_) {
                              setState(
                                () => _selectedType = StoreItemType.hunspell,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(l10n.storeFilterAudio),
                            selected: _selectedType == StoreItemType.audio,
                            onSelected: (_) {
                              setState(
                                () => _selectedType = StoreItemType.audio,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(context, l10n, filtered, localeTag)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    List<StoreItemEntry> filtered,
    String localeTag,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_enabledSourceCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.source_rounded, size: 48),
              const SizedBox(height: 12),
              Text(l10n.storeNoEnabledSources, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openStoreSettings,
                icon: const Icon(Icons.tune_rounded),
                label: Text(l10n.storeSettings),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(
                l10n.storeLoadFailed(_loadError!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadStore(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.refresh),
              ),
            ],
          ),
        ),
      );
    }

    final warningBanner = _sourceFailures.isEmpty
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.storePartialLoadFailed(
                          _sourceFailures
                              .map(
                                (f) => f.source.displayName(
                                  l10n.storeOfficialSource,
                                ),
                              )
                              .join(", "),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    if (filtered.isEmpty) {
      return Column(
        children: [
          ?warningBanner,
          Expanded(child: Center(child: Text(l10n.storeEmpty))),
        ],
      );
    }

    final showSourceBadge = _enabledSourceCount > 1;
    final list = ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final entry = filtered[index];
        final key = entry.storageKey;
        return _StoreItemCard(
          item: entry.item,
          sourceBadge: showSourceBadge
              ? entry.displaySourceName(l10n.storeOfficialSource)
              : null,
          localeTag: localeTag,
          installed: _installedById[key],
          hasUpdate: _updatesAvailable[key] ?? false,
          downloadProgress: _activeDownloads[key],
          onDownload: () => _downloadItem(entry),
          onCancel: () => _cancelDownload(key),
          onUninstall: _installedById[key] == null
              ? null
              : () => _uninstallItem(entry, _installedById[key]!),
        );
      },
    );

    if (warningBanner == null) return list;
    return Column(
      children: [
        warningBanner,
        Expanded(child: list),
      ],
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  final StoreItem item;
  final String? sourceBadge;
  final String localeTag;
  final StoreInstalledItem? installed;
  final bool hasUpdate;
  final _DownloadProgress? downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback? onUninstall;

  const _StoreItemCard({
    required this.item,
    this.sourceBadge,
    required this.localeTag,
    required this.installed,
    required this.hasUpdate,
    required this.downloadProgress,
    required this.onDownload,
    required this.onCancel,
    required this.onUninstall,
  });

  String _typeLabel(AppLocalizations l10n) {
    return switch (item.type) {
      StoreItemType.dictionary => l10n.storeFilterDictionaries,
      StoreItemType.hunspell => l10n.storeFilterHunspell,
      StoreItemType.audio => l10n.storeFilterAudio,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final localizedName = item.localizedName(localeTag);
    final localizedDescription = item.localizedDescription(localeTag);
    final isDownloading = downloadProgress != null;
    final isInstalled = installed != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${l10n.storeAuthor(item.author)} · ${item.license}",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    if (sourceBadge != null)
                      Chip(
                        label: Text(sourceBadge!),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    Chip(
                      label: Text(_typeLabel(l10n)),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    if (isInstalled && hasUpdate)
                      Chip(
                        label: Text(l10n.storeUpdateAvailable),
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      )
                    else if (isInstalled)
                      Chip(
                        label: Text(l10n.storeInstalled),
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
            if (localizedDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(localizedDescription, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (item.languages.isNotEmpty)
                  Text(
                    item.languages.map((e) => e.toUpperCase()).join(", "),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                InkWell(
                  onTap: () => launchUrl(
                    Uri.parse(item.sourceUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.storeHomepage,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: downloadProgress!.fraction),
              const SizedBox(height: 4),
              Text(
                downloadProgress!.total > 0
                    ? "${_formatBytes(downloadProgress!.received)} / ${_formatBytes(downloadProgress!.total)}"
                    : _formatBytes(downloadProgress!.received),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isDownloading)
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: Text(l10n.storeCancelDownload),
                  )
                else if (!isInstalled)
                  FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(l10n.storeDownload),
                  )
                else ...[
                  if (onUninstall != null)
                    TextButton.icon(
                      onPressed: onUninstall,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(l10n.storeUninstall),
                    ),
                  const SizedBox(width: 8),
                  if (hasUpdate) ...[
                    OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.storeRedownload),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 18,
                      ),
                      label: Text(l10n.storeUpdate),
                    ),
                  ] else
                    OutlinedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(l10n.storeRedownload),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StoreSettingsDialog extends StatefulWidget {
  const StoreSettingsDialog({super.key});

  @override
  State<StoreSettingsDialog> createState() => _StoreSettingsDialogState();
}

class _StoreSettingsDialogState extends State<StoreSettingsDialog> {
  late StoreMirrorMode _mirrorMode;
  late final TextEditingController _customPrefixController;
  late bool _officialEnabled;
  late List<StoreCatalogSource> _customSources;

  bool _isAddingSource = false;
  String? _addSourceError;
  final TextEditingController _newSourceNameController =
      TextEditingController();
  final TextEditingController _newSourceUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mirrorMode = settings.storeMirrorMode;
    _customPrefixController = TextEditingController(
      text: settings.storeCustomMirrorPrefix,
    );
    _officialEnabled = settings.storeOfficialCatalogEnabled;
    _customSources = List<StoreCatalogSource>.of(
      settings.storeCustomCatalogSources,
    );
  }

  @override
  void dispose() {
    _customPrefixController.dispose();
    _newSourceNameController.dispose();
    _newSourceUrlController.dispose();
    super.dispose();
  }

  void _addCustomSource(AppLocalizations l10n) {
    final url = _newSourceUrlController.text.trim();
    if (url.isEmpty) {
      setState(() => _addSourceError = l10n.storeSourceUrlRequired);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme("http") || uri.isScheme("https")) ||
        uri.host.isEmpty) {
      setState(() => _addSourceError = l10n.storeSourceUrlInvalid);
      return;
    }

    if (url == defaultStoreCatalogUrl ||
        _customSources.any((source) => source.url == url)) {
      setState(() => _addSourceError = l10n.storeSourceUrlDuplicate);
      return;
    }

    final id = "custom_${DateTime.now().microsecondsSinceEpoch}_${_customSources.length}";
    setState(() {
      _customSources = [
        ..._customSources,
        StoreCatalogSource(
          id: id,
          name: _newSourceNameController.text.trim(),
          url: url,
          enabled: true,
        ),
      ];
      _newSourceNameController.clear();
      _newSourceUrlController.clear();
      _addSourceError = null;
      _isAddingSource = false;
    });
  }

  Future<void> _save() async {
    await settings.setStoreMirrorMode(_mirrorMode);
    await settings.setStoreCustomMirrorPrefix(_customPrefixController.text);
    await settings.setStoreOfficialCatalogEnabled(_officialEnabled);
    await settings.setStoreCustomCatalogSources(_customSources);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.storeSettings),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.storeMirrorMode,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              AppDropdown<StoreMirrorMode>(
                value: _mirrorMode,
                dense: true,
                items: [
                  DropdownMenuItem(
                    value: StoreMirrorMode.none,
                    child: Text(l10n.storeMirrorNone),
                  ),
                  const DropdownMenuItem(
                    value: StoreMirrorMode.jsdelivr,
                    child: Text("jsDelivr (GitHub Raw)"),
                  ),
                  DropdownMenuItem(
                    value: StoreMirrorMode.custom,
                    child: Text(l10n.storeMirrorCustom),
                  ),
                ],
                onChanged: (mode) {
                  if (mode != null) {
                    setState(() => _mirrorMode = mode);
                  }
                },
              ),
              if (_mirrorMode == StoreMirrorMode.custom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customPrefixController,
                  decoration: InputDecoration(
                    labelText: l10n.storeCustomMirrorPrefix,
                    hintText: "https://gh-proxy.com/",
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.storeCatalogSources,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (!_isAddingSource)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isAddingSource = true;
                          _addSourceError = null;
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(l10n.storeAddSource),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _CatalogSourceTile(
                title: l10n.storeOfficialSource,
                subtitle: defaultStoreCatalogUrl,
                enabled: _officialEnabled,
                onToggle: (value) {
                  setState(() => _officialEnabled = value);
                },
              ),
              for (var i = 0; i < _customSources.length; i++) ...[
                const SizedBox(height: 8),
                _CatalogSourceTile(
                  title: _customSources[i].displayName(
                    l10n.storeOfficialSource,
                  ),
                  subtitle: _customSources[i].url,
                  enabled: _customSources[i].enabled,
                  onToggle: (value) {
                    setState(() {
                      _customSources[i] = _customSources[i].copyWith(
                        enabled: value,
                      );
                    });
                  },
                  onDelete: () {
                    setState(() {
                      _customSources.removeAt(i);
                    });
                  },
                  deleteTooltip: l10n.delete,
                ),
              ],
              if (_isAddingSource) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _newSourceNameController,
                        decoration: InputDecoration(
                          labelText: l10n.storeSourceNameOptional,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _newSourceUrlController,
                        decoration: InputDecoration(
                          labelText: l10n.storeSourceUrl,
                          hintText: "https://example.com/catalog.yaml",
                          isDense: true,
                          errorText: _addSourceError,
                          border: const OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addCustomSource(l10n),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isAddingSource = false;
                                _addSourceError = null;
                                _newSourceNameController.clear();
                                _newSourceUrlController.clear();
                              });
                            },
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _addCustomSource(l10n),
                            child: Text(l10n.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.close),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
      ],
    );
  }
}

class _CatalogSourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  const _CatalogSourceTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onToggle,
    this.onDelete,
    this.deleteTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              tooltip: deleteTooltip,
              onPressed: onDelete,
            ),
          Switch(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}
