import "package:flutter_riverpod/flutter_riverpod.dart";

class ExportOptions {
  final bool wordbook;
  final bool searchHistory;
  final bool writingCheckHistory;
  final bool translateHistory;

  ExportOptions({
    this.wordbook = true,
    this.searchHistory = true,
    this.writingCheckHistory = true,
    this.translateHistory = true,
  });

  ExportOptions copyWith({
    bool? wordbook,
    bool? searchHistory,
    bool? writingCheckHistory,
    bool? translateHistory,
  }) {
    return ExportOptions(
      wordbook: wordbook ?? this.wordbook,
      searchHistory: searchHistory ?? this.searchHistory,
      writingCheckHistory: writingCheckHistory ?? this.writingCheckHistory,
      translateHistory: translateHistory ?? this.translateHistory,
    );
  }
}

class ExportOptionsNotifier extends Notifier<ExportOptions> {
  @override
  ExportOptions build() {
    return ExportOptions();
  }

  void toggleWordbook(bool value) => state = state.copyWith(wordbook: value);
  void toggleSearchHistory(bool value) =>
      state = state.copyWith(searchHistory: value);
  void toggleWritingCheckHistory(bool value) =>
      state = state.copyWith(writingCheckHistory: value);
  void toggleTranslateHistory(bool value) =>
      state = state.copyWith(translateHistory: value);
}

final exportOptionsProvider =
    NotifierProvider<ExportOptionsNotifier, ExportOptions>(() {
  return ExportOptionsNotifier();
});
