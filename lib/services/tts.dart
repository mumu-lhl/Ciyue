import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/repositories/settings.dart";
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
  /// TTS engine (e.g. Linux desktop) flutter_tts throws, which must not
  /// surface as an unhandled async error from a button tap.
  static Future<void> toggleSpeak(String text) async {
    try {
      final clean = stripMarkdown(text);
      if (clean.isEmpty) return;
      if (_speaking == clean) {
        await stop();
        return;
      }
      await _prepare();
      _speaking = clean;
      await flutterTts.speak(clean);
    } catch (_) {
      _speaking = null;
    }
  }

  static Future<void> stop() async {
    _speaking = null;
    try {
      await flutterTts.stop();
    } catch (_) {}
  }

  static bool get isSpeaking => _speaking != null;
}
