import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/models/audio.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/mdd_reader_pool.dart";
import "package:ciyue/services/zip_archive_reader.dart";
import "package:material_ui/material_ui.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";
import "package:path_provider/path_provider.dart";

/// Resource keys tried for a word's pronunciation, in order: the
/// long-standing .spx convention first, then the common audio formats,
/// so packs whose entries are keyed as .mp3/.wav also match.
///
/// MDict stores resource keys with a leading backslash (`\apple.mp3`), while
/// some packs written by other tools omit it, so both spellings are tried.
List<String> pronunciationKeyCandidates(String word) => [
  "\\$word.spx",
  "\\$word.mp3",
  "\\$word.wav",
  "$word.spx",
  "$word.mp3",
  "$word.wav",
];

/// The headword an mdd resource key stands for: `\Apple.mp3` -> `apple`.
/// Resource keys carry a leading separator and their own capitalisation, so
/// neither can be compared to a query directly.
///
/// Unicode normalisation is deliberately not applied here. A pack built on
/// macOS may store `café.mp3` in NFD (the `e` plus a combining accent) while
/// the query arrives in NFC, and those never compare equal. Storing a
/// normalised key is not an option either: [locate] needs the original bytes
/// to find the record. Matching both forms means asking for NFD keys as well,
/// which needs a direct `unorm_dart` dependency and a wider candidate list;
/// no pack in circulation has needed it yet, so it stays out until one does.
String resourceKeyStem(String key) {
  var stem = key;
  while (stem.startsWith("\\") || stem.startsWith("/")) {
    stem = stem.substring(1);
  }
  return setExtension(stem, "").toLowerCase();
}

/// Whether [path] is a zip-based pronunciation pack.
///
/// `.zips` is the extension GoldenDict gives its pronunciation archives; the
/// file itself is a plain zip, so both spellings are read the same way.
bool isZipAudioPack(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith(".zip") || lower.endsWith(".zips");
}

final Map<String, ZipArchiveReader> _zipAudioReaders = {};

/// The reader for a zip pronunciation pack, or null when the file is gone.
///
/// Unlike `.mdd`, an archive needs no index table: the reader parses the
/// central directory on first lookup and keeps a name map in memory, which is
/// why these packs write nothing to the database at import time.
ZipArchiveReader? zipAudioReaderFor(String path) {
  final cached = _zipAudioReaders[path];
  if (cached != null) return cached;
  final file = File(path);
  if (!file.existsSync()) return null;
  final reader = ZipArchiveReader(file);
  _zipAudioReaders[path] = reader;
  return reader;
}

/// One audio entry found in a zip pack.
typedef ZipAudioHit = ({Uint8List data, String key});

/// Reads the first candidate spelling of [word] that [path] contains.
Future<ZipAudioHit?> readZipAudioEntry(String path, String word) async {
  final reader = zipAudioReaderFor(path);
  if (reader == null) return null;
  for (final key in pronunciationKeyCandidates(word)) {
    final data = await reader.readEntry(key);
    if (data != null) return (data: data, key: key);
  }
  return null;
}

/// Drops the cached reader for [path], if any.
void closeZipAudioReader(String path) {
  _zipAudioReaders.remove(path)?.close();
}

class AudioModel extends ChangeNotifier {
  static AudioModel? _instance;
  static AudioModel? get instance => _instance;

  AudioModel() {
    _instance = this;
  }

  List<MddAudioListData> mddAudioList = [];

  /// Number of indexed resources per pronunciation pack, for display in
  /// the audio settings (lets users see a pack was indexed correctly).
  Map<int, int> mddAudioCounts = {};
  int mddAudioListState = 0;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  String? _playingWord;
  String? get playingWord => _playingWord;

  AudioPlayer? _activePlayer;
  Timer? _safetyTimer;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerStateSub;

  bool isWordPlaying(String word) {
    if (!_isPlaying || _playingWord == null) return false;
    return _playingWord!.toLowerCase() == word.toLowerCase();
  }

  @visibleForTesting
  void setPlaybackStateForTesting({required bool isPlaying, String? word}) {
    _isPlaying = isPlaying;
    _playingWord = word;
    notifyListeners();
  }

  Future<void> init() async {
    mddAudioList = await mddAudioListDao.allOrdered();
    mddAudioCounts = {
      // Zip packs keep no resource rows: their entries live in the archive's
      // own index, and the settings card shows nothing rather than a
      // misleading "0 pronunciations".
      for (final pack in mddAudioList)
        if (!isZipAudioPack(pack.path))
          pack.id: await mddAudioResourceDao.countByMddAudioID(pack.id),
    };
    mddAudioListState++;

    _setupTtsHandlers();

    notifyListeners();
  }

  void _setupTtsHandlers() {
    if (Platform.isLinux) return;
    try {
      flutterTts.setStartHandler(() {
        if (!_isPlaying) {
          _isPlaying = true;
          notifyListeners();
        }
      });
      flutterTts.setCompletionHandler(() {
        _onPlaybackComplete();
      });
      flutterTts.setCancelHandler(() {
        _onPlaybackComplete();
      });
      flutterTts.setErrorHandler((dynamic msg) {
        _onPlaybackComplete();
      });
    } catch (e) {
      talker.error("Failed to setup TTS handlers", e);
    }
  }

  Future<PronunciationResult> playWord(
    String word, {
    List<MddAudioListData>? mddList,
  }) async {
    await stopAudio();

    final mode = settings.pronunciationMode;
    final targetList = mddList ?? mddAudioList;
    if (mode != PronunciationMode.ttsOnly && targetList.isNotEmpty) {
      for (final mddAudio in targetList) {
        if (isZipAudioPack(mddAudio.path)) {
          // Zip packs are read straight out of the archive; there is no
          // resource table to consult.
          final hit = await readZipAudioEntry(mddAudio.path, word);
          if (hit != null) {
            await playAudioBytes(
              hit.data,
              lookupMimeType(hit.key) ?? "audio/mpeg",
              label: word,
            );
            return PronunciationResult.pack;
          }
          continue;
        }

        for (final key in pronunciationKeyCandidates(word)) {
          final audios = await mddAudioResourceDao.getByKeyAndMddAudioID(
            key,
            mddAudio.id,
          );
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
            final mimeType = lookupMimeType(audio.key) ?? "audio/spx";

            await playAudioBytes(data, mimeType, label: word);
            return PronunciationResult.pack;
          }
        }
      }
    }

    if (mode == PronunciationMode.packOnly ||
        Platform.isLinux ||
        ttsDisabledByCommandLine) {
      _onPlaybackComplete();
      return PronunciationResult.unavailable;
    }

    _isPlaying = true;
    _playingWord = word;
    notifyListeners();

    _safetyTimer?.cancel();
    final seconds = (word.length ~/ 2).clamp(3, 10);
    _safetyTimer = Timer(Duration(seconds: seconds), _onPlaybackComplete);

    try {
      _setupTtsHandlers();
      await flutterTts.speak(word);
      return PronunciationResult.tts;
    } catch (e) {
      talker.error("Failed to speak via TTS", e);
      _onPlaybackComplete();
      return PronunciationResult.unavailable;
    }
  }

  Future<bool> playAudioBytes(
    Uint8List audio,
    String mimeType, {
    String? label,
  }) async {
    await stopAudio();

    _isPlaying = true;
    _playingWord = label;
    notifyListeners();

    try {
      final player = AudioPlayer();
      _activePlayer = player;

      _playerCompleteSub = player.onPlayerComplete.listen((_) {
        _onPlaybackComplete();
      });

      _playerStateSub = player.onPlayerStateChanged.listen((state) {
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _onPlaybackComplete();
        }
      });

      _safetyTimer?.cancel();
      _safetyTimer = Timer(const Duration(seconds: 15), _onPlaybackComplete);

      await player.setSourceBytes(audio, mimeType: mimeType);
      await player.resume();
      return true;
    } catch (e) {
      talker.error("Failed to play audio bytes", e);
      _onPlaybackComplete();
      return false;
    }
  }

  Future<void> stopAudio() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;

    await _playerCompleteSub?.cancel();
    _playerCompleteSub = null;
    await _playerStateSub?.cancel();
    _playerStateSub = null;

    if (_activePlayer != null) {
      try {
        await _activePlayer!.stop();
        await _activePlayer!.release();
      } catch (e) {
        talker.error("Error releasing audio player", e);
      }
      _activePlayer = null;
    }

    if (!Platform.isLinux) {
      try {
        await flutterTts.stop();
      } catch (_) {}
    }

    if (_isPlaying || _playingWord != null) {
      _isPlaying = false;
      _playingWord = null;
      notifyListeners();
    }
  }

  void _onPlaybackComplete() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _playerCompleteSub?.cancel();
    _playerCompleteSub = null;
    _playerStateSub?.cancel();
    _playerStateSub = null;

    _activePlayer?.release();
    _activePlayer = null;

    if (_isPlaying || _playingWord != null) {
      _isPlaying = false;
      _playingWord = null;
      notifyListeners();
    }
  }

  Future<int> addMddAudio(String path, String title) async {
    final id = await mddAudioListDao.add(path, title);
    await init();

    return id;
  }

  Future<void> removeMddAudio(int id) async {
    final mddAudio = mddAudioList.firstWhere((element) => element.id == id);
    closeZipAudioReader(mddAudio.path);
    await closeMddReader(mddAudio.path);

    if (Platform.isAndroid) {
      // Only files inside the app's own storage are app-owned copies
      // (imported by the common flavor) and are deleted with the entry.
      // Full-flavor packs point at the user's own files in the folder
      // they picked; removing the entry must not delete those.
      final supportDir = (await getApplicationSupportDirectory()).path;
      if (isWithin(supportDir, mddAudio.path)) {
        try {
          await File(mddAudio.path).delete();
        } catch (_) {}
      }
    }

    mddAudioListDao.remove(id);
    mddAudioList.removeWhere((element) => element.id == id);
    mddAudioCounts.remove(id);

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
    final MddAudioListData item = mddAudioList.removeAt(oldIndex);
    mddAudioList.insert(newIndex, item);
    mddAudioListState++;
    notifyListeners();
    updateMddAudioOrder();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _activePlayer?.dispose();
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }
}
