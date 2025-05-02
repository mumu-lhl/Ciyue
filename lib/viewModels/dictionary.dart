import "package:ciyue/database/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:flutter/material.dart";

class DictManagerModel extends ChangeNotifier {
  final Map<int, Mdict> dicts = dictManager.dicts;
  List<DictGroupData> groups = dictManager.groups;
  List<int> dictIds = dictManager.dictIds;
  int groupId = dictManager.groupId;

  Future<void> setCurrentGroup(int id) async {
    await dictManager.setCurrentGroup(id);
    groupId = id;
    notifyListeners();
  }

  Future<void> close(int id) async {
    await dictManager.close(id);
    notifyListeners();
  }

  Future<void> updateDictIds() async {
    dictManager.dictIds = await dictGroupDao.getDictIds(dictManager.groupId);
    notifyListeners();
  }

  Future<void> updateGroupList() async {
    dictManager.groups = await dictGroupDao.getAllGroups();
    notifyListeners();
  }
}
