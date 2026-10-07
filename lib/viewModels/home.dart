import "package:ciyue/core/app_globals.dart";
import "package:ciyue/core/app_router.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/viewModels/history_view_model.dart";
import "package:ciyue/viewModels/wordbook.dart";
import "package:material_ui/material_ui.dart";
import "package:provider/provider.dart";

class HistoryModel extends HistoryViewModel<HistoryData> {
  bool get enableHistory => settings.enableHistory;

  void addHistory(String word) async {
    if (!settings.enableHistory) {
      return;
    }
    await historyDao.addHistory(word);
    await loadHistory();
  }

  void clearHistory() async {
    await historyDao.clearHistory();
    await loadHistory();
  }

  @override
  Future<void> deleteHistory(int id) async {
    final word = history.firstWhere((element) => element.id == id).word;
    await historyDao.removeHistory(word);
    await loadHistory();
  }

  @override
  Future<void> deleteSelected() async {
    await historyDao.removeHistories(selectedIds);
    clearSelection();
    await loadHistory();
  }

  Future<void> addSelectedToWordbook() async {
    final words = history
        .where((element) => selectedIds.contains(element.id))
        .map((e) => e.word);
    final existWords = await wordbookDao.wordsExist(words);
    for (final word in words) {
      if (existWords.contains(word)) {
        await Provider.of<WordbookModel>(
          navigatorKey.currentContext!,
          listen: false,
        ).delete(word);
      } else {
        await Provider.of<WordbookModel>(
          navigatorKey.currentContext!,
          listen: false,
        ).add(word);
      }
    }
    clearSelection();
  }

  @override
  Iterable<int> get historyIds => history.map((e) => e.id);

  @override
  Future<void> loadHistory() async {
    final history = await historyDao.getAllHistory();
    setHistory(history);
  }

  void setEnableHistory(bool value) {
    settings.setEnableHistory(value);
    notifyListeners();
  }
}

class HomeModel extends ChangeNotifier {
  int state = 0;
  String _searchWord = "";
  String? _selectedWord;
  final List<String> _tabs = [];
  int _activeTabIndex = -1;

  final searchController = SearchController();
  final searchBarFocusNode = FocusNode();

  List<String> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;

  String get searchWord => _searchWord;

  set searchWord(String word) {
    _searchWord = word;
    notifyListeners();
  }

  String? get selectedWord {
    if (_activeTabIndex >= 0 && _activeTabIndex < _tabs.length) {
      final tabWord = _tabs[_activeTabIndex];
      if (tabWord.isNotEmpty) {
        return tabWord;
      }
    }
    return _selectedWord;
  }

  set selectedWord(String? word) {
    if (word == null) {
      _selectedWord = null;
      notifyListeners();
      return;
    }

    final trimmed = word.trim();
    if (trimmed.isEmpty) return;

    final existingIndex = _tabs.indexOf(trimmed);
    if (existingIndex != -1) {
      _activeTabIndex = existingIndex;
      _selectedWord = trimmed;
      notifyListeners();
      return;
    }

    if (_tabs.isEmpty) {
      _tabs.add(trimmed);
      _activeTabIndex = 0;
    } else if (_activeTabIndex >= 0 && _activeTabIndex < _tabs.length) {
      _tabs[_activeTabIndex] = trimmed;
    } else {
      _tabs.add(trimmed);
      _activeTabIndex = _tabs.length - 1;
    }
    _selectedWord = trimmed;
    notifyListeners();
  }

  void openWordInNewTab(String word, {bool switchTo = true}) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;

    final existingIndex = _tabs.indexOf(trimmed);
    if (existingIndex != -1) {
      if (switchTo) {
        _activeTabIndex = existingIndex;
        _selectedWord = trimmed;
        notifyListeners();
      }
      return;
    }

    if (_activeTabIndex >= 0 &&
        _activeTabIndex < _tabs.length &&
        _tabs[_activeTabIndex].isEmpty) {
      _tabs[_activeTabIndex] = trimmed;
      _selectedWord = trimmed;
      notifyListeners();
      return;
    }

    _tabs.add(trimmed);
    if (switchTo) {
      _activeTabIndex = _tabs.length - 1;
      _selectedWord = trimmed;
    }
    notifyListeners();
  }

  void newTab() {
    final emptyIndex = _tabs.indexOf("");
    if (emptyIndex != -1) {
      _activeTabIndex = emptyIndex;
      _selectedWord = "";
    } else {
      _tabs.add("");
      _activeTabIndex = _tabs.length - 1;
      _selectedWord = "";
    }
    focusSearchBar();
    notifyListeners();
  }

  void switchToTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      _activeTabIndex = index;
      _selectedWord = _tabs[index];
      notifyListeners();
    }
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _activeTabIndex = -1;
      _selectedWord = null;
    } else {
      if (_activeTabIndex == index) {
        _activeTabIndex = index.clamp(0, _tabs.length - 1);
        _selectedWord = _tabs[_activeTabIndex];
      } else if (_activeTabIndex > index) {
        _activeTabIndex--;
        _selectedWord = _tabs[_activeTabIndex];
      }
    }
    notifyListeners();
  }

  void closeOtherTabs(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final keep = _tabs[index];
    _tabs.clear();
    _tabs.add(keep);
    _activeTabIndex = 0;
    _selectedWord = keep;
    notifyListeners();
  }

  void closeAllTabs() {
    _tabs.clear();
    _activeTabIndex = -1;
    _selectedWord = null;
    notifyListeners();
  }

  void nextTab() {
    if (_tabs.length > 1) {
      _activeTabIndex = (_activeTabIndex + 1) % _tabs.length;
      _selectedWord = _tabs[_activeTabIndex];
      notifyListeners();
    }
  }

  void previousTab() {
    if (_tabs.length > 1) {
      _activeTabIndex = (_activeTabIndex - 1 + _tabs.length) % _tabs.length;
      _selectedWord = _tabs[_activeTabIndex];
      notifyListeners();
    }
  }

  void reorderTabs(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _tabs.length) return;
    if (newIndex < 0 || newIndex >= _tabs.length) return;

    final activeWord = selectedWord;
    final item = _tabs.removeAt(oldIndex);
    _tabs.insert(newIndex, item);
    if (activeWord != null) {
      _activeTabIndex = _tabs.indexOf(activeWord);
    }
    notifyListeners();
  }

  void ensureInitialWord(String word) {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return;
    if (_tabs.isEmpty) {
      _tabs.add(trimmed);
      _activeTabIndex = 0;
      _selectedWord = trimmed;
      notifyListeners();
    }
  }

  void focusSearchBar() {
    searchBarFocusNode.requestFocus();
    notifyListeners();
  }

  void update() {
    state++;
    notifyListeners();
  }
}
