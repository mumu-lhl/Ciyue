import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:ciyue/services/mdd_reader_pool.dart";
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

Future<void> playSound(Uint8List audio, String mimeType) async {
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
  if (mddAudioList.isNotEmpty) {
    final player = AudioPlayer();

    for (final mddAudio in mddAudioList) {
      final audios = await mddAudioResourceDao.getByKeyAndMddAudioID(
        "$word.spx",
        mddAudio.id,
      );
      for (final audio in audios!) {
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

  if (Platform.isLinux) {
    return;
  }

  await flutterTts.speak(word);
}
