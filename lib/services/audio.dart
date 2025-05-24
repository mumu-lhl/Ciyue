import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/main.dart";
import "package:ciyue/services/dictionary.dart";
import "package:dict_reader/dict_reader.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

Future<List<String>> findMddAudioFilesOnAndroid() async {
  final documentsDir =
      Directory(join((await getApplicationSupportDirectory()).path, "audios"));
  final mddFiles = <String>[];
  await findAllFileByExtension(documentsDir, mddFiles, "mdd");
  return mddFiles;
}

Future<void> playSoundOfWord(
    String word, List<MddAudioListData> mddAudioList) async {
  if (mddAudioList.isNotEmpty) {
    final player = AudioPlayer();

    for (final mddAudio in mddAudioList) {
      final audio = await mddAudioResourceDao.getByKeyAndMddAudioID(
          "$word.spx", mddAudio.id);
      if (audio != null) {
        final reader = DictReader(mddAudio.path);
        await reader.init(false);

        final Uint8List data = await reader.readOne(audio.blockOffset,
            audio.startOffset, audio.endOffset, audio.compressedSize);
        await player.setSourceBytes(data, mimeType: "audio/x-speex");

        await player.resume();

        await player.release();

        return;
      }
    }
  }

  if (Platform.isLinux) {
    return;
  }

  await flutterTts.speak(word);
}
