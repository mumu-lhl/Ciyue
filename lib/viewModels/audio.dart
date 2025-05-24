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

  Future<int> addMddAudio(String path) async {
    final id = await mddAudioListDao.add(path);
    mddAudioList.add(MddAudioListData(id: id, path: path));

    mddAudioListState++;
    notifyListeners();

    return id;
  }
}
