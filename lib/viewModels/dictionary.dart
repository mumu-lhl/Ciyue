import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:material_ui/material_ui.dart";

class DictManagerModel extends ChangeNotifier {
  int get groupId => dictManager.groupId;
  bool isEmpty = dictManager.isEmpty;
  bool isSwitchingGroup = false;
  int? pendingGroupId;

  int state = 0;

  bool checkIsEmpty() {
    if (dictManager.isEmpty != isEmpty) {
      isEmpty = dictManager.isEmpty;
      Future.microtask(() => notifyListeners());
      return true;
    } else {
      return false;
    }
  }

  Future<void> add(int id, String path) async {
    await dictManager.add(id, path);

    update();
  }

  Future<void> close(int id) async {
    await dictManager.close(id);

    state += 1;

    if (!checkIsEmpty()) {
      notifyListeners();
    }
  }

  Future<void> setCurrentGroup(int id) async {
    if (id == groupId || isSwitchingGroup) return;

    isSwitchingGroup = true;
    pendingGroupId = id;
    notifyListeners();

    try {
      await dictManager.setCurrentGroup(id);
    } finally {
      pendingGroupId = null;
      isSwitchingGroup = false;
      isEmpty = dictManager.isEmpty;
      state += 1;
      notifyListeners();
    }
  }

  Future<void> updateDictIds() async {
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
