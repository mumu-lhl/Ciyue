import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:flutter/material.dart";

class DictManagerModel extends ChangeNotifier {
  int groupId = dictManager.groupId;
  bool isEmpty = dictManager.isEmpty;

  int state = 0;

  bool checkIsEmpty() {
    if (dictManager.isEmpty != isEmpty) {
      isEmpty = dictManager.isEmpty;
      notifyListeners();

      return true;
    } else {
      return false;
    }
  }

  Future<void> add(String path) async {
    await dictManager.add(path);

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
    await dictManager.setCurrentGroup(id);
    groupId = id;

    state += 1;

    if (!checkIsEmpty()) {
      notifyListeners();
    }
  }

  Future<void> updateDictIds() async {
    dictManager.dictIds = await dictGroupDao.getDictIds(dictManager.groupId);

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
