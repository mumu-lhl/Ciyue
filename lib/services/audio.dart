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

/// Extensions recognised as pronunciation packs.
///
/// `.mdd` is the MDict resource container. `.zip` and `.zips` are plain
/// archives — the latter being GoldenDict's pronunciation pack extension —
/// read through the archive's own index instead of a database table.
const audioPackExtensions = ["mdd", "zip", "zips"];

Future<List<String>> findAudioPackFilesOnAndroid(String? directory) async {
  final documentsDir = Directory(
    directory ?? join((await getApplicationSupportDirectory()).path, "audios"),
  );
  final files = <String>[];
  for (final extension in audioPackExtensions) {
    await findAllFileByExtension(documentsDir, files, extension);
  }
  return files;
}

/// Plays raw audio bytes and reports whether the platform accepted them.
///
/// A `false` return means the device has no decoder for this stream, which is
/// how pack audio in an unsupported format (Ogg Speex, for instance) behaves:
/// the bytes are there, the tap lands, and nothing is ever heard.
Future<bool> playSound(
  Uint8List audio,
  String mimeType, {
  String? label,
}) async {
  if (AudioModel.instance != null) {
    return AudioModel.instance!.playAudioBytes(audio, mimeType, label: label);
  }

  final player = AudioPlayer();
  try {
    await player.setSourceBytes(audio, mimeType: mimeType);
    await player.resume();
    player.onPlayerComplete.listen((event) {
      player.release();
    });
    return true;
  } catch (e) {
    talker.error("Failed to play audio bytes ($mimeType)", e);
    try {
      await player.release();
    } catch (_) {}
    return false;
  }
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
        if (resourceKeyStem(audio.key) != word.toLowerCase()) {
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

  // Zip packs are answered straight from the archive. They come after the
  // `.mdd` packs above so the user's package order still decides who wins.
  for (final mddAudio in mddAudioList) {
    if (!isZipAudioPack(mddAudio.path)) continue;
    final hit = await readZipAudioEntry(mddAudio.path, word);
    if (hit == null) continue;

    final player = AudioPlayer();
    await player.setSourceBytes(hit.data, mimeType: lookupMimeType(hit.key));
    await player.resume();
    player.onPlayerComplete.listen((event) {
      player.release();
    });
    return;
  }

  if (settings.pronunciationMode == PronunciationMode.packOnly ||
      Platform.isLinux ||
      ttsDisabledByCommandLine) {
    return;
  }

  await flutterTts.speak(word);
}
