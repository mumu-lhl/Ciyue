import "package:flutter_tts/flutter_tts.dart";

/// Small wrapper around flutter_tts for reading text aloud in learning
/// features (chat messages, quiz words). Strips markdown formatting so the
/// spoken text sounds natural.
class TtsHelper {
  TtsHelper._();

  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;
  static String? _speaking;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.9);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {
      _speaking = null;
    });
    _tts.setCancelHandler(() {
      _speaking = null;
    });
    _initialized = true;
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
      await _ensureInitialized();
      final clean = stripMarkdown(text);
      if (clean.isEmpty) return;
      if (_speaking == clean) {
        await stop();
        return;
      }
      _speaking = clean;
      await _tts.speak(clean);
    } catch (_) {
      _speaking = null;
    }
  }

  static Future<void> stop() async {
    _speaking = null;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static bool get isSpeaking => _speaking != null;
}
