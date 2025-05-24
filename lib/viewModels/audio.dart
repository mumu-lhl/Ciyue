import "dart:io";

import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:flutter/material.dart";

class AudioModel extends ChangeNotifier {
  List<MddAudioListData> mddAudioList = [];
  int mddAudioListState = 0;

  Future<void> init() async {
    mddAudioList = await mddAudioListDao.allOrdered();
    mddAudioListState++;

    notifyListeners();
  }

  Future<int> addMddAudio(String path, String title) async {
    final id = await mddAudioListDao.add(path, title);
    await init();

    return id;
  }

  Future<void> removeMddAudio(int id) async {
    if (Platform.isAndroid) {
      final mddAudio = mddAudioList.firstWhere((element) => element.id == id);
      File(mddAudio.path).delete();
    }

    mddAudioListDao.remove(id);
    mddAudioList.removeWhere((element) => element.id == id);

    mddAudioResourceDao.remove(id);

    mddAudioListState++;
    notifyListeners();
  }

  Future<void> updateMddAudioOrder() async {
    for (int i = 0; i < mddAudioList.length; i++) {
      if (mddAudioList[i].order != i) {
        await mddAudioListDao.updateOrder(mddAudioList[i].id, i);
      }
    }
  }

  void reorderMddAudio(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final MddAudioListData item = mddAudioList.removeAt(oldIndex);
    mddAudioList.insert(newIndex, item);
    mddAudioListState++;
    notifyListeners();
    updateMddAudioOrder();
  }
}
