import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:audioplayers/audioplayers.dart";
import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts_driver.dart";
import "package:flutter_tts/flutter_tts.dart";

/// Applies the user's TTS settings (engine, language, speech rate, pitch)
/// to a flutter_tts instance. Used at startup for the shared instance and
/// by [TtsHelper] so learning features speak with the same voice settings
/// as word pronunciation instead of their own hardcoded ones.
Future<void> applyTtsSettings(FlutterTts tts) async {
  if (Platform.isAndroid && settings.ttsEngine != null) {
    await tts.setEngine(settings.ttsEngine!);
  }
  if (settings.ttsLanguage != null) {
    await tts.setLanguage(settings.ttsLanguage!);
  }
  await tts.setSpeechRate(settings.ttsSpeechRate);
  await tts.setPitch(settings.ttsPitch);
}

/// Small wrapper around the shared flutter_tts instance for reading text
/// aloud in learning features (chat messages, quiz words). Strips markdown
/// formatting so the spoken text sounds natural.
class TtsHelper {
  TtsHelper._();

  static String? _speaking;

  /// Linux-only player for the espeak WAV fallback (SSIP speech
  /// needs no player). Stopped by [stop] and before a new utterance.
  static AudioPlayer? _linuxPlayer;
  static StreamSubscription<void>? _linuxPlayerSub;

  /// Linux-only estimate timer that clears [_speaking] after the
  /// speech has plausibly finished. SSIP END events are never
  /// awaited (they may never arrive without audio hardware), and
  /// this timer never stops speech — only [stop] and a second tap
  /// do that.
  static Timer? _linuxSpeechTimer;

  /// Prepares the shared TTS instance for a learning-feature utterance:
  /// applies the current settings and (re)registers this helper's
  /// completion handlers — the word-pronunciation path registers its own
  /// handlers on the same instance, so each speaker asserts its handlers
  /// right before speaking.
  static Future<void> _prepare() async {
    await applyTtsSettings(flutterTts);
    await flutterTts.setVolume(1.0);
    flutterTts.setCompletionHandler(() {
      _speaking = null;
    });
    flutterTts.setCancelHandler(() {
      _speaking = null;
    });
    flutterTts.setErrorHandler((dynamic _) {
      _speaking = null;
    });
  }

  /// Remove markdown syntax that would sound bad when spoken.
  static String stripMarkdown(String text) {
    var result = text;
    // Code blocks.
    result = result.replaceAll(RegExp(r"```[\s\S]*?```"), " ");
    // Inline code, images, links: keep the inner text.
    result = result.replaceAllMapped(
      RegExp(r"`([^`]*)`"),
      (m) => m.group(1) ?? "",
    );
    result = result.replaceAllMapped(
      RegExp(r"!\[([^\]]*)\]\([^)]*\)"),
      (m) => m.group(1) ?? "",
    );
    result = result.replaceAllMapped(
      RegExp(r"\[([^\]]*)\]\([^)]*\)"),
      (m) => m.group(1) ?? "",
    );
    // Headings, bold, italic, strikethrough.
    result = result.replaceAll(RegExp(r"^#{1,6}\s*", multiLine: true), "");
    for (final pattern in [
      RegExp(r"\*\*([^*]*)\*\*"),
      RegExp(r"__([^_]*)__"),
      RegExp(r"\*([^*]*)\*"),
      RegExp(r"_([^_]*)_"),
      RegExp(r"~~([^~]*)~~"),
    ]) {
      result = result.replaceAllMapped(pattern, (m) => m.group(1) ?? "");
    }
    // Lists and quotes and horizontal rules.
    result = result.replaceAll(RegExp(r"^[\s]*[-*+]\s+", multiLine: true), "");
    result = result.replaceAll(RegExp(r"^[\s]*\d+\.\s+", multiLine: true), "");
    result = result.replaceAll(RegExp(r"^>\s*", multiLine: true), "");
    result = result.replaceAll(RegExp(r"^[-*_]{3,}\s*$", multiLine: true), "");
    // Collapse whitespace.
    result = result.replaceAll(RegExp(r"[ \t]+"), " ");
    result = result.replaceAll(RegExp(r" ?\n ?"), "\n");
    result = result.replaceAll(RegExp(r"\n{3,}"), "\n\n");
    return result.trim();
  }

  /// Speak [text]. Tapping again while the same text is speaking stops it.
  /// All platform errors are swallowed: on platforms without a working
  /// TTS engine flutter_tts throws, which must not surface as an
  /// unhandled async error from a button tap. On Linux the native
  /// backends are used instead (see [_speakViaLinuxTts]); flutter_tts
  /// is never touched there.
  static Future<void> toggleSpeak(String text) async {
    if (ttsDisabledByCommandLine) return;
    try {
      final clean = stripMarkdown(text);
      if (clean.isEmpty) return;
      if (_speaking == clean) {
        await stop();
        return;
      }
      if (Platform.isLinux) {
        // Stop any in-flight Linux speech/WAV first, so speaking a
        // different text interrupts the previous utterance instead
        // of queueing behind it.
        await stop();
        await _speakViaLinuxTts(clean);
        return;
      }
      await _prepare();
      _speaking = clean;
      await flutterTts.speak(clean);
    } catch (_) {
      _speaking = null;
    }
  }

  /// Linux speech: SSIP first, then an espeak-ng WAV played through
  /// a throwaway player. Mirrors the word-pronunciation chain's
  /// backend order; the markdown-stripped text is spoken with the
  /// same rate/pitch/language/voice settings as word pronunciation.
  static Future<void> _speakViaLinuxTts(String clean) async {
    _speaking = clean;
    _linuxSpeechTimer?.cancel();
    final seconds = (clean.length ~/ 8).clamp(3, 30);
    _linuxSpeechTimer = Timer(Duration(seconds: seconds), () {
      if (_speaking == clean) _speaking = null;
    });

    final options = linuxTtsSpeakOptions();
    try {
      final spoken = await linuxTtsDriver.speak(
        clean,
        language: options.language,
        rate: options.rate,
        pitch: options.pitch,
        voice: options.voice,
      );
      if (spoken.success) return;
    } catch (_) {
      // Fall through to the WAV fallback below.
    }

    Uint8List? wav;
    try {
      wav = await linuxTtsDriver.synthesizeWav(
        clean,
        voice: options.voice,
        rate: options.rate,
        pitch: options.pitch,
      );
    } catch (_) {
      wav = null;
    }
    if (wav == null || wav.isEmpty) {
      _linuxSpeechTimer?.cancel();
      _linuxSpeechTimer = null;
      _speaking = null;
      return;
    }
    await _playLinuxWav(clean, wav);
  }

  static Future<void> _playLinuxWav(String clean, Uint8List wav) async {
    await _stopLinuxPlayer();
    try {
      final player = AudioPlayer();
      _linuxPlayer = player;
      _linuxPlayerSub = player.onPlayerComplete.listen((_) {
        if (_speaking == clean) _speaking = null;
        unawaited(_stopLinuxPlayer());
      });
      await player.setSourceBytes(wav, mimeType: "audio/wav");
      await player.resume();
    } catch (_) {
      _speaking = null;
      await _stopLinuxPlayer();
    }
  }

  static Future<void> _stopLinuxPlayer() async {
    await _linuxPlayerSub?.cancel();
    _linuxPlayerSub = null;
    final player = _linuxPlayer;
    _linuxPlayer = null;
    if (player != null) {
      try {
        await player.stop();
        await player.release();
      } catch (_) {}
    }
  }

  static Future<void> stop() async {
    _speaking = null;
    _linuxSpeechTimer?.cancel();
    _linuxSpeechTimer = null;
    if (Platform.isLinux) {
      // Stop both: the WAV player (if the espeak fallback is
      // playing) and the SSIP speech (if speech-dispatcher is
      // speaking), so tap-again-to-stop works on either backend.
      await _stopLinuxPlayer();
      try {
        await linuxTtsDriver.stop();
      } catch (_) {}
      return;
    }
    try {
      await flutterTts.stop();
    } catch (_) {}
  }

  static bool get isSpeaking => _speaking != null;
}
