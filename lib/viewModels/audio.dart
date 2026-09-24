import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/services/mdd_reader_pool.dart";
import "package:material_ui/material_ui.dart";
import "package:mime/mime.dart";
import "package:path/path.dart";

class AudioModel extends ChangeNotifier {
  static AudioModel? _instance;
  static AudioModel? get instance => _instance;

  AudioModel() {
    _instance = this;
  }

  List<MddAudioListData> mddAudioList = [];
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

  Future<void> playWord(String word, {List<MddAudioListData>? mddList}) async {
    await stopAudio();

    final targetList = mddList ?? mddAudioList;
    if (targetList.isNotEmpty) {
      for (final mddAudio in targetList) {
        final audios = await mddAudioResourceDao.getByKeyAndMddAudioID(
          "$word.spx",
          mddAudio.id,
        );
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
          final mimeType = lookupMimeType(audio.key) ?? "audio/spx";

          await playAudioBytes(data, mimeType, label: word);
          return;
        }
      }
    }

    if (Platform.isLinux) {
      _onPlaybackComplete();
      return;
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
    } catch (e) {
      talker.error("Failed to speak via TTS", e);
      _onPlaybackComplete();
    }
  }

  Future<void> playAudioBytes(
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
    } catch (e) {
      talker.error("Failed to play audio bytes", e);
      _onPlaybackComplete();
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
    await closeMddReader(mddAudio.path);

    if (Platform.isAndroid) {
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
