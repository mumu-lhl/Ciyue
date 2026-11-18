import "package:ciyue/services/storage_usage.dart";
import "package:flutter/foundation.dart";

/// View model for the Telegram-style storage management page: measures how
/// much space each category uses and deletes the rebuildable caches.
class StorageUsageViewModel extends ChangeNotifier {
  StorageUsageViewModel({
    StorageUsageService? service,
    this.onClearFullTextIndex,
  }) : _service = service ?? StorageUsageService() {
    refresh();
  }

  final StorageUsageService _service;
  final Future<void> Function()? onClearFullTextIndex;

  bool _isLoading = false;
  List<StorageUsage> _usages = [];
  String? _errorMessage;

  /// Set in [dispose]: a refresh still in flight when the page is popped
  /// must not notify listeners on the disposed notifier.
  bool _disposed = false;

  bool get isLoading => _isLoading;
  List<StorageUsage> get usages => _usages;
  String? get errorMessage => _errorMessage;

  /// Sum of every measurable category, in bytes.
  int get totalBytes =>
      _usages.fold(0, (sum, usage) => sum + (usage.bytes ?? 0));

  /// Sum of the measurable clearable categories, in bytes.
  int get clearableBytes => _usages
      .where((usage) => usage.clearable)
      .fold(0, (sum, usage) => sum + (usage.bytes ?? 0));

  /// True when at least one category could not be measured (for example
  /// the dictionaries behind a `content://` URI): the total then covers
  /// only the measurable categories, and the page says so.
  bool get hasUnknownSizes => _usages.any((usage) => usage.bytes == null);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    _notify();
    try {
      _usages = await _service.measure();
    } catch (e) {
      _errorMessage = e.toString();
      _usages = [];
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Deletes one clearable category and refreshes. Returns the bytes freed;
  /// 0 for kinds that cannot be cleared or when the clear fails.
  Future<int> clearCategory(StorageCategoryKind kind) async {
    var freed = 0;
    try {
      freed = await _clearOne(kind);
    } catch (_) {
      freed = 0;
    }
    await refresh();
    return freed;
  }

  /// Deletes every clearable category, continuing past individual failures.
  /// The full-text index goes first, then the file-backed caches. Returns
  /// the total bytes freed.
  Future<int> clearAllCache() async {
    var freed = 0;
    for (final kind in [
      StorageCategoryKind.fullTextIndex,
      StorageCategoryKind.dictionaryIndexCache,
      StorageCategoryKind.pronunciationCache,
      StorageCategoryKind.otherCache,
    ]) {
      try {
        freed += await _clearOne(kind);
      } catch (_) {
        // Keep going with the remaining categories.
      }
    }
    await refresh();
    return freed;
  }

  Future<int> _clearOne(StorageCategoryKind kind) async {
    return switch (kind) {
      StorageCategoryKind.fullTextIndex => await _clearFullTextIndex(),
      StorageCategoryKind.dictionaryIndexCache =>
        await _service.clearDictionaryIndexCache(),
      StorageCategoryKind.pronunciationCache =>
        await _service.clearPronunciationCache(),
      StorageCategoryKind.otherCache => await _service.clearOtherCache(),
      _ => 0,
    };
  }

  /// The full-text index is cleared through the search service, which does
  /// not report the bytes freed; the size measured before the clear is the
  /// best estimate.
  Future<int> _clearFullTextIndex() async {
    final clear = onClearFullTextIndex;
    if (clear == null) return 0;
    final before = _knownBytes(StorageCategoryKind.fullTextIndex);
    await clear();
    return before;
  }

  int _knownBytes(StorageCategoryKind kind) {
    for (final usage in _usages) {
      if (usage.kind == kind) return usage.bytes ?? 0;
    }
    return 0;
  }
}
