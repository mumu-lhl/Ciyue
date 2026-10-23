import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/mdd_reader_pool.dart";
import "package:ciyue/viewModels/audio.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

Future<List<String>> findMddAudioFilesOnAndroid(String? directory) async {
  final documentsDir = Directory(
    directory ?? join((await getApplicationSupportDirectory()).path, "audios"),
  );
  final mddFiles = <String>[];
  await findAllFileByExtension(documentsDir, mddFiles, "mdd");
  return mddFiles;
}

Future<void> playSound(
  Uint8List audio,
  String mimeType, {
  String? label,
}) async {
  if (AudioModel.instance != null) {
    await AudioModel.instance!.playAudioBytes(audio, mimeType, label: label);
    return;
  }

  final player = AudioPlayer();
  await player.setSourceBytes(audio, mimeType: mimeType);
  await player.resume();
  player.onPlayerComplete.listen((event) {
    player.release();
  });
}

Future<void> playSoundOfWord(
  String word,
  List<MddAudioListData> mddAudioList,
) async {
  if (AudioModel.instance != null) {
    await AudioModel.instance!.playWord(word, mddList: mddAudioList);
    return;
  }

  if (settings.pronunciationMode != PronunciationMode.ttsOnly &&
      mddAudioList.isNotEmpty) {
    final player = AudioPlayer();

    // Query all audio packages concurrently; results stay in list order so
    // the first playable match (by package priority) still wins. Each
    // package tries the candidate keys (.spx, then .mp3/.wav) in order.
    final lookupResults = await Future.wait(
      mddAudioList.map((mddAudio) async {
        for (final key in pronunciationKeyCandidates(word)) {
          final results = await mddAudioResourceDao.getByKeyAndMddAudioID(
            key,
            mddAudio.id,
          );
          if (results != null && results.isNotEmpty) {
            return results;
          }
        }
        return null;
      }),
    );
    for (var i = 0; i < mddAudioList.length; i++) {
      final mddAudio = mddAudioList[i];
      final audios = lookupResults[i];
      for (final audio in audios ?? <MddAudioResourceData>[]) {
        if (setExtension(audio.key, "") != word) {
          continue;
        }

        final reader = await mddReaderFor(mddAudio.path);
        final info = await reader.locate(audio.key);
        if (info == null) {
          continue;
        }

        final Uint8List data = await reader.readOneMdd(info) as Uint8List;
        final mimeType = lookupMimeType(audio.key);
        await player.setSourceBytes(data, mimeType: mimeType);

        await player.resume();

        player.onPlayerComplete.listen((event) {
          player.release();
        });

        return;
      }
    }
  }

  if (settings.pronunciationMode == PronunciationMode.packOnly ||
      Platform.isLinux) {
    return;
  }

  await flutterTts.speak(word);
}
