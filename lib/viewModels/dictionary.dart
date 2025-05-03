import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:flutter/material.dart";

class DictManagerModel extends ChangeNotifier {
  int groupId = dictManager.groupId;
  bool isEmpty = dictManager.isEmpty;

  void checkIsEmpty() {
    isEmpty = dictManager.isEmpty;
  }

  Future<void> close(int id) async {
    await dictManager.close(id);
    checkIsEmpty();
    notifyListeners();
  }

  Future<void> setCurrentGroup(int id) async {
    await dictManager.setCurrentGroup(id);
    groupId = id;
    checkIsEmpty();
    notifyListeners();
  }

  Future<void> updateDictIds() async {
    dictManager.dictIds = await dictGroupDao.getDictIds(dictManager.groupId);
    checkIsEmpty();
    notifyListeners();
  }

  Future<void> updateGroupList() async {
    dictManager.groups = await dictGroupDao.getAllGroups();
    notifyListeners();
  }
}
