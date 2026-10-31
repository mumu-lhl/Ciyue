import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:material_ui/material_ui.dart";

class DictManagerModel extends ChangeNotifier {
  /// Called when the set of dictionaries to look up in changed, so that the
  /// words on screen can be looked up again with the new group.
  final VoidCallback? onDictionariesChanged;

  DictManagerModel({this.onDictionariesChanged});

  int get groupId => dictManager.groupId;
  bool get isEmpty => dictManager.isEmpty;
  bool get isLoading => dictManager.isLoading;
  bool isSwitchingGroup = false;
  int? pendingGroupId;

  int state = 0;
  bool _lastKnownIsEmpty = dictManager.isEmpty;

  bool checkIsEmpty() {
    if (dictManager.isEmpty != _lastKnownIsEmpty) {
      _lastKnownIsEmpty = dictManager.isEmpty;
      Future.microtask(() => notifyListeners());
      return true;
    } else {
      return false;
    }
  }

  Future<void> add(int id, String path) async {
    // A group that is still loading ends by assigning its stored list to
    // dictManager.dictIds, which would forget this dictionary. Wait it out so
    // the enable sticks.
    await dictManager.waitForGroupSwitch();

    await dictManager.add(id, path);
    _lastKnownIsEmpty = dictManager.isEmpty;

    update();
  }

  Future<void> close(int id) async {
    // Same reason as add(): a running switch would reload the dictionary from
    // the group's stored list before this removal is written back.
    await dictManager.waitForGroupSwitch();

    await dictManager.close(id);
    _lastKnownIsEmpty = dictManager.isEmpty;

    state += 1;

    notifyListeners();
  }

  Future<void> setCurrentGroup(int id) async {
    if (id == groupId || isSwitchingGroup) return;

    isSwitchingGroup = true;
    pendingGroupId = id;
    notifyListeners();

    try {
      await dictManager.setCurrentGroup(id);
      // Remember the selection so initGroup() restores this group on the next
      // launch instead of falling back to the one stored at first run.
      await prefs.setInt("currentDictionaryGroupId", id);
      // The group decides which dictionaries a word is looked up in, so the
      // words on screen have to be looked up again.
      onDictionariesChanged?.call();
    } finally {
      pendingGroupId = null;
      isSwitchingGroup = false;
      _lastKnownIsEmpty = dictManager.isEmpty;
      state += 1;
      notifyListeners();
    }
  }

  /// Switches to the group at [position] (1-based) in the group list.
  ///
  /// The position follows the order the groups are shown in, which is the
  /// order they were created in, so the first one is the default group.
  /// Returns false when there is no such group.
  Future<bool> switchToGroupAt(int position) async {
    final groups = dictManager.groups;
    if (position < 1 || position > groups.length) return false;
    final target = groups[position - 1];
    if (target.id == groupId) return true;
    await setCurrentGroup(target.id);
    return true;
  }

  Future<void> updateDictIds() async {
    // Deriving the group's list from dictManager.dicts is only meaningful
    // once the group has finished loading; before that the map is either
    // still being cleared or only partly filled, and the resulting list would
    // be written back to the database.
    await dictManager.waitForGroupSwitch();

    final allDicts = await dictionaryListDao.all();
    final activeDictIds = allDicts
        .where((d) => dictManager.contain(d.id))
        .map((d) => d.id)
        .toList();

    dictManager.dictIds = activeDictIds;
    await dictGroupDao.updateDictIds(dictManager.groupId, activeDictIds);

    state += 1;

    if (!checkIsEmpty()) {
      notifyListeners();
    }
  }

  Future<void> updateGroupList() async {
    dictManager.groups = await dictGroupDao.getAllGroups();

    state += 1;
    notifyListeners();
  }

  void update() {
    state += 1;
    notifyListeners();
  }
}
