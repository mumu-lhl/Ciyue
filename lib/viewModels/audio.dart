import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:flutter/material.dart";

class AudioSettingsPageModel extends ChangeNotifier {
  List<MddAudioListData> mddAudioList = [];
  int mddAudioListState = 0;

  Future<void> init() async {
    mddAudioList = await mddAudioListDao.all();
    mddAudioListState++;

    notifyListeners();
  }

  Future<int> addMddAudio(String path, String title) async {
    final id = await mddAudioListDao.add(path, title);
    mddAudioList.add(MddAudioListData(id: id, path: path, title: title));

    mddAudioListState++;
    notifyListeners();

    return id;
  }

  Future<void> removeMddAudio(int id) async {
    await mddAudioListDao.remove(id);
    mddAudioList.removeWhere((element) => element.id == id);

    await mddAudioResourceDao.remove(id);

    mddAudioListState++;
    notifyListeners();
  }
}

class AudioModel extends ChangeNotifier {}
