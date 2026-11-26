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

  List<StoreItem> _items = const [];
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
      final catalogFuture = StoreService.instance.fetchCatalog(
        forceRefresh: forceRefresh,
      );
      final installedFuture = storeInstalledItemDao.all();

      final catalog = await catalogFuture;
      final installed = await installedFuture;

      final installedMap = <String, StoreInstalledItem>{
        for (final row in installed) row.itemId: row,
      };

      if (!mounted) return;
      setState(() {
        _items = catalog.items;
        _installedById = installedMap;
        _isLoading = false;
      });

      unawaited(
        _checkUpdatesForInstalled(catalog.items, installedMap, forceRefresh),
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
    List<StoreItem> items,
    Map<String, StoreInstalledItem> installedMap,
    bool forceRefresh,
  ) async {
    final checks = <Future<void>>[];
    for (final item in items) {
      final installed = installedMap[item.id];
      if (installed == null) continue;
      if (item.source.type == StoreSourceType.direct) continue;

      checks.add(() async {
        final hasUpdate = await StoreService.instance.hasUpdate(
          item,
          installed,
          forceRefresh: forceRefresh,
        );
        if (mounted) {
          setState(() {
            _updatesAvailable[item.id] = hasUpdate;
          });
        }
      }());
    }
    await Future.wait(checks);
  }

  Future<void> _downloadItem(StoreItem item) async {
    if (_activeDownloads.containsKey(item.id)) return;
    final l10n = AppLocalizations.of(context)!;
    final cancelToken = CancelToken();

    setState(() {
      _activeDownloads[item.id] = _DownloadProgress(
        received: 0,
        total: 0,
        cancelToken: cancelToken,
      );
    });

    try {
      final installed = await StoreService.instance.downloadAndInstall(
        item,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _activeDownloads[item.id] = _DownloadProgress(
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
        _activeDownloads.remove(item.id);
        _installedById = {..._installedById, item.id: installed};
        _updatesAvailable[item.id] = false;
      });
      await ToastService.show(
        l10n.storeInstallSuccess(item.name),
        context,
        type: ToastType.success,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _activeDownloads.remove(item.id);
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
        _activeDownloads.remove(item.id);
      });
      await ToastService.show(
        l10n.storeInstallFailed(e.toString()),
        context,
        type: ToastType.error,
      );
    }
  }

  void _cancelDownload(String itemId) {
    _activeDownloads[itemId]?.cancelToken.cancel("Cancelled by user");
  }

  Future<void> _uninstallItem(
    StoreItem item,
    StoreInstalledItem installed,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.storeUninstall),
        content: Text(l10n.storeUninstallConfirm(item.name)),
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
        next.remove(item.id);
        _installedById = next;
        _updatesAvailable.remove(item.id);
      });
      await ToastService.show(
        l10n.storeUninstallSuccess(item.name),
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
      builder: (_) => const _StoreSettingsDialog(),
    );
    if (changed == true && mounted) {
      await _loadStore(forceRefresh: true);
    }
  }

  List<String> get _availableLanguages {
    final langs = <String>{};
    for (final item in _items) {
      langs.addAll(item.languages);
    }
    final sorted = langs.toList()..sort();
    return sorted;
  }

  List<StoreItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    return _items
        .where((item) {
          if (_selectedType != null && item.type != _selectedType) return false;
          if (_selectedLanguage != null &&
              !item.languages.contains(_selectedLanguage)) {
            return false;
          }
          if (query.isNotEmpty) {
            final haystack =
                "${item.name} ${item.author} ${item.description} ${item.license}"
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
    final filtered = _filteredItems;
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
              Expanded(child: _buildBody(context, l10n, filtered)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    List<StoreItem> filtered,
  ) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    if (filtered.isEmpty) {
      return Center(child: Text(l10n.storeEmpty));
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        4,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        return _StoreItemCard(
          item: item,
          installed: _installedById[item.id],
          hasUpdate: _updatesAvailable[item.id] ?? false,
          downloadProgress: _activeDownloads[item.id],
          onDownload: () => _downloadItem(item),
          onCancel: () => _cancelDownload(item.id),
          onUninstall: _installedById[item.id] == null
              ? null
              : () => _uninstallItem(item, _installedById[item.id]!),
        );
      },
    );
  }
}

class _StoreItemCard extends StatelessWidget {
  final StoreItem item;
  final StoreInstalledItem? installed;
  final bool hasUpdate;
  final _DownloadProgress? downloadProgress;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback? onUninstall;

  const _StoreItemCard({
    required this.item,
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
                        item.name,
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
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, style: theme.textTheme.bodyMedium),
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

class _StoreSettingsDialog extends StatefulWidget {
  const _StoreSettingsDialog();

  @override
  State<_StoreSettingsDialog> createState() => _StoreSettingsDialogState();
}

class _StoreSettingsDialogState extends State<_StoreSettingsDialog> {
  late StoreMirrorMode _mirrorMode;
  late final TextEditingController _customPrefixController;
  late final TextEditingController _catalogUrlController;

  @override
  void initState() {
    super.initState();
    _mirrorMode = settings.storeMirrorMode;
    _customPrefixController = TextEditingController(
      text: settings.storeCustomMirrorPrefix,
    );
    _catalogUrlController = TextEditingController(
      text: settings.storeCatalogUrl,
    );
  }

  @override
  void dispose() {
    _customPrefixController.dispose();
    _catalogUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await settings.setStoreMirrorMode(_mirrorMode);
    await settings.setStoreCustomMirrorPrefix(_customPrefixController.text);
    await settings.setStoreCatalogUrl(_catalogUrlController.text);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.storeSettings),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.storeMirrorMode,
                style: Theme.of(context).textTheme.labelLarge,
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
              TextField(
                controller: _catalogUrlController,
                decoration: InputDecoration(
                  labelText: l10n.storeCatalogUrl,
                  hintText: defaultStoreCatalogUrl,
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _catalogUrlController.clear();
                  },
                  child: Text(l10n.storeResetCatalogUrl),
                ),
              ),
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
