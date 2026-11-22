import "dart:async";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/models/dictionary_lookup.dart";
import "package:ciyue/services/personal_dictionary_service.dart";
import "package:ciyue/services/storage_usage.dart";
import "package:flutter/foundation.dart";

/// Loads one content estimate per personal dictionary: the dictionary
/// list gives the ids and titles, [service] the entries to measure. A
/// dictionary with no entries still appears, with 0 bytes — its row
/// exists, it just holds nothing yet.
Future<List<PersonalDictionaryStorageEstimate>> loadPersonalDictionaryEstimates(
  PersonalDictionaryService service,
) async {
  final estimates = <PersonalDictionaryStorageEstimate>[];
  for (final dictionary in await dictionaryListDao.all()) {
    if (!DictionaryType.isPersonal(dictionary.type)) continue;
    final entries = await service.listEntries(dictionary.id);
    estimates.add(
      PersonalDictionaryStorageEstimate(
        dictionaryId: dictionary.id,
        title: dictionary.title?.isNotEmpty == true
            ? dictionary.title!
            : dictionary.path,
        entryCount: entries.length,
        estimatedBytes: estimatePersonalDictionaryBytes(entries),
      ),
    );
  }
  return estimates;
}

/// View model for the Telegram-style storage management page: measures how
/// much space each category uses and deletes the rebuildable caches.
class StorageUsageViewModel extends ChangeNotifier {
  StorageUsageViewModel({
    StorageUsageService? service,
    this.onClearFullTextIndex,
    Future<List<PersonalDictionaryStorageEstimate>> Function()?
    personalDictionaryEstimates,
  }) : _service =
           service ??
           StorageUsageService(
             personalDictionaryEstimates: personalDictionaryEstimates,
           ) {
    unawaited(refresh());
  }

  final StorageUsageService _service;
  final Future<void> Function()? onClearFullTextIndex;

  bool _isLoading = false;
  List<StorageUsage> _usages = [];
  List<PersonalDictionaryStorageEstimate> _personalDictionaryEstimates = [];
  String? _errorMessage;

  /// Set in [dispose]: a refresh still in flight when the page is popped
  /// must not notify listeners on the disposed notifier.
  bool _disposed = false;

  bool get isLoading => _isLoading;
  List<StorageUsage> get usages => _usages;

  /// Per-dictionary personal-dictionary content estimates, for the
  /// breakdown under the database category. Empty when there are no
  /// personal dictionaries or no loader was provided.
  List<PersonalDictionaryStorageEstimate> get personalDictionaryEstimates =>
      _personalDictionaryEstimates;

  /// Sum of the per-dictionary estimates, in bytes. A content estimate
  /// only — it is not added to [totalBytes], whose database category
  /// already counts the shared file these bytes live in.
  int get personalDictionaryEstimatedBytes => _personalDictionaryEstimates.fold(
    0,
    (sum, estimate) => sum + estimate.estimatedBytes,
  );

  String? get errorMessage => _errorMessage;

  /// Sum of every measurable category, in bytes.
  int get totalBytes =>
      _usages.fold(0, (sum, usage) => sum + (usage.bytes ?? 0));

  /// Kinds the user unchecked on the page: excluded from the clear even
  /// though they are clearable. Everything clearable starts selected, so
  /// this set is empty until the user taps a row's check.
  final Set<StorageCategoryKind> _deselected = {};

  /// Whether [kind] is included in the next clear: clearable, measurable,
  /// and not unchecked by the user. Size-only categories are never
  /// selected.
  bool isSelected(StorageCategoryKind kind) {
    final usage = _usageFor(kind);
    return usage != null &&
        usage.clearable &&
        (usage.bytes ?? 0) > 0 &&
        !_deselected.contains(kind);
  }

  /// Toggles [kind] in or out of the next clear. A no-op for categories
  /// that cannot be cleared or have nothing to clear.
  void toggleSelection(StorageCategoryKind kind) {
    final usage = _usageFor(kind);
    if (usage == null || !usage.clearable || (usage.bytes ?? 0) <= 0) return;
    if (_deselected.contains(kind)) {
      _deselected.remove(kind);
    } else {
      _deselected.add(kind);
    }
    _notify();
  }

  /// Sum of the selected clearable categories, in bytes: the number the
  /// bottom button shows and the clear confirms.
  int get selectedClearableBytes => _usages
      .where((usage) => isSelected(usage.kind))
      .fold(0, (sum, usage) => sum + (usage.bytes ?? 0));

  StorageUsage? _usageFor(StorageCategoryKind kind) {
    for (final usage in _usages) {
      if (usage.kind == kind) return usage;
    }
    return null;
  }

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
      _personalDictionaryEstimates = await _service
          .measurePersonalDictionaries();
      // Drop unchecked kinds that are gone or no longer clearable, so a
      // stale entry can never exclude a category that was re-measured
      // with bytes again.
      _deselected.removeWhere(
        (kind) =>
            _usageFor(kind) == null ||
            !_usageFor(kind)!.clearable ||
            (_usageFor(kind)!.bytes ?? 0) <= 0,
      );
    } catch (e) {
      _errorMessage = e.toString();
      _usages = [];
      _personalDictionaryEstimates = [];
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Deletes the selected clearable categories (see [isSelected]),
  /// continuing past individual failures. The full-text index goes first,
  /// then the file-backed caches. Returns the total bytes freed.
  Future<int> clearSelectedCache() async {
    var freed = 0;
    for (final kind in [
      StorageCategoryKind.fullTextIndex,
      StorageCategoryKind.dictionaryIndexCache,
      StorageCategoryKind.pronunciationCache,
      StorageCategoryKind.otherCache,
    ]) {
      if (!isSelected(kind)) continue;
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
