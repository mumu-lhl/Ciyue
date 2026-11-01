import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:ciyue/services/linux_tts_transport.dart";

/// Linux-native text-to-speech backends for Ciyue.
///
/// Two backends, in preference order:
///
/// 1. **speech-dispatcher via SSIP** — the persistent connection in
///    [LinuxTtsService] speaks through the user's configured
///    synthesizer (usually espeak-ng underneath, with the user's own
///    voice/rate defaults). No audio is rendered by Ciyue itself.
/// 2. **espeak-ng directly** — [LinuxTtsService.synthesizeWav] renders
///    WAV bytes that the caller plays like any other audio. Used when
///    speech-dispatcher is unavailable.
///
/// This file intentionally does not touch `flutter_tts` or any
/// settings/UI code: the caller (which owns settings and playback)
/// passes language/rate/pitch/voice on every call, in Ciyue's own
/// units, and this layer maps them onto each backend. All failures
/// are reported as failure results / `null` / empty lists, never
/// thrown, so the caller can silently fall through to the next
/// backend.
///
/// Rate/pitch mappings (Ciyue's settings units are shared with
/// `flutter_tts`, so these keep Linux speech consistent with other
/// platforms):
///
/// * Ciyue `ttsSpeechRate` 0.1–1.0 (0.5 = normal) →
///   SSIP `RATE` -100..100 via [ssipRateFromSpeechRate]
///   (`(rate - 0.5) * 200`, 0.5 → 0) and espeak `-s` words-per-minute
///   via [espeakWpmFromSpeechRate] (`rate * 350`, 0.5 → 175 wpm).
/// * Ciyue `ttsPitch` 0.5–2.0 (1.0 = normal) →
///   SSIP `PITCH` -100..100 via [ssipPitchFromSpeechPitch]
///   (`(pitch - 1.0) * 100`, 1.0 → 0) and espeak `-p` 0..99 via
///   [espeakPitchFromSpeechPitch] (`(pitch - 1.0) * 50 + 50`,
///   1.0 → 50).
///
/// Every mapping clamps to its backend range. SSIP volume is never
/// set: the daemon default stands.
///
/// SSIP wire rules this layer relies on (verified live against
/// speech-dispatcher 0.12.0-rc2): all commands and replies are
/// CRLF-terminated UTF-8; replies are `ccc-continuation` lines plus
/// a final `ddd text` line; only the first digit of a reply code
/// classifies it (2xx = success) for codes 100–599; event codes
/// 700–799 are exact. The client speaks first (no greeting banner).
/// SSIP parameters do not survive a reconnect, so they are re-applied
/// on every (re)connect. Completion must never depend on an END event
/// arriving: on hardware without audio output, synthesis may never
/// complete and no END event is ever delivered.

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

/// Which Linux TTS backends are usable right now.
///
/// [ssip] means a speech-dispatcher socket answered the SSIP
/// handshake; [espeak] means `espeak-ng --version` exited 0.
class LinuxTtsAvailability {
  const LinuxTtsAvailability({required this.ssip, required this.espeak});

  final bool ssip;
  final bool espeak;

  /// True when at least one backend is usable.
  bool get any => ssip || espeak;

  @override
  bool operator ==(Object other) =>
      other is LinuxTtsAvailability &&
      other.ssip == ssip &&
      other.espeak == espeak;

  @override
  int get hashCode => Object.hash(ssip, espeak);

  @override
  String toString() => "LinuxTtsAvailability(ssip: $ssip, espeak: $espeak)";
}

/// A speakable voice from either backend.
///
/// For SSIP, [id] is the synthesis voice name from
/// `LIST SYNTHESIS_VOICES` (e.g. `Afrikaans+Adam`), [language] its
/// language code, and [variant] its dialect string (`null` when the
/// daemon reports `none`). For espeak, [id] is the voice name from
/// `espeak-ng --voices` (e.g. `English_(America)`), [language] the
/// language column (e.g. `en-us`), and [variant] the age/gender
/// column (e.g. `--/M`). [displayName] is suitable for a voice
/// picker. Pass [id] back as the `voice` argument of
/// [LinuxTtsService.speak] / [LinuxTtsService.synthesizeWav].
class LinuxVoice {
  const LinuxVoice({
    required this.id,
    required this.language,
    required this.variant,
    required this.displayName,
  });

  final String id;
  final String language;
  final String? variant;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is LinuxVoice &&
      other.id == id &&
      other.language == language &&
      other.variant == variant &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, language, variant, displayName);

  @override
  String toString() =>
      "LinuxVoice(id: $id, language: $language, variant: $variant)";
}

/// The outcome of one SSIP `SPEAK`.
///
/// [success] means the daemon queued the message; [messageId] is the
/// daemon-assigned id when the daemon returned it (multi-line `225`
/// form), `null` when it used the single-line form. [error] explains
/// a failure for diagnostics; callers should treat any failure as
/// "try the next backend" and not surface it.
class SsipSpeakResult {
  const SsipSpeakResult._({
    required this.success,
    required this.messageId,
    required this.error,
  });

  factory SsipSpeakResult.success(String? messageId) =>
      SsipSpeakResult._(success: true, messageId: messageId, error: null);

  factory SsipSpeakResult.failure(String error) =>
      SsipSpeakResult._(success: false, messageId: null, error: error);

  final bool success;
  final String? messageId;
  final String? error;

  @override
  String toString() =>
      "SsipSpeakResult(success: $success, messageId: $messageId, "
      "error: $error)";
}

/// Kinds of SSIP message events (codes 700–705).
enum SsipEventKind { indexMark, begin, end, canceled, paused, resumed }

/// One parsed SSIP event notification.
///
/// [messageId] is the id of the message the event belongs to (from
/// the first line of the event group). [indexMark] is set only for
/// [SsipEventKind.indexMark] events.
class SsipEvent {
  const SsipEvent({
    required this.messageId,
    required this.kind,
    required this.indexMark,
  });

  final String messageId;
  final SsipEventKind kind;
  final String? indexMark;

  @override
  String toString() =>
      "SsipEvent(messageId: $messageId, kind: $kind, indexMark: $indexMark)";
}

/// Speech parameters for one utterance, in Ciyue's settings units.
///
/// All fields are optional: a `null` field leaves the backend's
/// current value untouched. [rate] is Ciyue `ttsSpeechRate`
/// (0.1–1.0, 0.5 normal); [pitch] is Ciyue `ttsPitch` (0.5–2.0, 1.0
/// normal); [language] is an RFC 1766 language code (e.g. `en`,
/// `en-US`); [voice] is a [LinuxVoice.id].
class LinuxTtsParams {
  const LinuxTtsParams({this.language, this.rate, this.pitch, this.voice});

  final String? language;
  final double? rate;
  final double? pitch;
  final String? voice;

  /// Returns a copy with non-null fields from [other] taking
  /// precedence. Used to remember the last effective parameters so a
  /// reconnect can re-apply them (SSIP parameters do not persist
  /// across connections).
  LinuxTtsParams merge(LinuxTtsParams other) => LinuxTtsParams(
    language: other.language ?? language,
    rate: other.rate ?? rate,
    pitch: other.pitch ?? pitch,
    voice: other.voice ?? voice,
  );

  @override
  bool operator ==(Object other) =>
      other is LinuxTtsParams &&
      other.language == language &&
      other.rate == rate &&
      other.pitch == pitch &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(language, rate, pitch, voice);

  @override
  String toString() =>
      "LinuxTtsParams(language: $language, rate: $rate, "
      "pitch: $pitch, voice: $voice)";
}

// ---------------------------------------------------------------------------
// Rate / pitch mappings (pure, boundary-tested)
// ---------------------------------------------------------------------------

/// Ciyue speech rate (0.1–1.0, 0.5 normal) → SSIP `RATE` (-100..100).
int ssipRateFromSpeechRate(double rate) {
  if (!rate.isFinite) rate = 0.5;
  return ((rate - 0.5) * 200).clamp(-100, 100).round();
}

/// Ciyue pitch (0.5–2.0, 1.0 normal) → SSIP `PITCH` (-100..100).
int ssipPitchFromSpeechPitch(double pitch) {
  if (!pitch.isFinite) pitch = 1.0;
  return ((pitch - 1.0) * 100).clamp(-100, 100).round();
}

/// Ciyue speech rate (0.1–1.0, 0.5 normal) → espeak `-s` wpm (80..450).
int espeakWpmFromSpeechRate(double rate) {
  if (!rate.isFinite) rate = 0.5;
  return (rate * 350).clamp(80, 450).round();
}

/// Ciyue pitch (0.5–2.0, 1.0 normal) → espeak `-p` (0..99).
int espeakPitchFromSpeechPitch(double pitch) {
  if (!pitch.isFinite) pitch = 1.0;
  return ((pitch - 1.0) * 50 + 50).clamp(0, 99).round();
}

// ---------------------------------------------------------------------------
// espeak-ng process runner
// ---------------------------------------------------------------------------

/// The result of one `espeak-ng` invocation.
class EspeakResult {
  const EspeakResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final List<int> stdout;
  final List<int> stderr;
}

/// Runs `espeak-ng` with [argv] (no shell; `argv.first` is the
/// executable). Injected so tests can substitute canned output.
typedef EspeakRunner = Future<EspeakResult> Function(List<String> argv);

Future<EspeakResult> _defaultEspeakRunner(List<String> argv) async {
  final result = await Process.run(
    argv.first,
    argv.sublist(1),
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  List<int> asBytes(Object? value) {
    if (value is List<int>) return value;
    return utf8.encode(value.toString());
  }

  return EspeakResult(
    exitCode: result.exitCode,
    stdout: asBytes(result.stdout),
    stderr: asBytes(result.stderr),
  );
}

/// Builds the `espeak-ng` argv for rendering [text] to WAV on stdout.
///
/// `espeak-ng --stdout [-v <voice>] -s <wpm> -p <pitch> -- <text>`.
/// The text is a single argv element after `--` (never a shell
/// string), so arbitrary text is safe. `-v` is omitted when [voice]
/// is `null`/empty; `-s`/`-p` always use the mapped Ciyue defaults
/// (175 wpm / 50) when [rate]/[pitch] are `null`.
List<String> buildEspeakArgv(
  String text, {
  String? voice,
  double? rate,
  double? pitch,
}) {
  final argv = <String>["espeak-ng", "--stdout"];
  if (voice != null && voice.isNotEmpty) {
    argv.addAll(["-v", voice]);
  }
  argv.addAll([
    "-s",
    "${espeakWpmFromSpeechRate(rate ?? 0.5)}",
    "-p",
    "${espeakPitchFromSpeechPitch(pitch ?? 1.0)}",
    "--",
    text,
  ]);
  return argv;
}

// ---------------------------------------------------------------------------
// SSIP reply / event parsing
// ---------------------------------------------------------------------------

/// One parsed SSIP reply: [code] plus the payload text of every line
/// (continuation payloads first, final line text last).
class _SsipReply {
  const _SsipReply({required this.code, required this.lines});

  final int code;
  final List<String> lines;

  /// Only the first digit classifies codes 100–599: 2xx is success.
  bool get isSuccess => code >= 200 && code < 300;
}

final _replyLinePattern = RegExp(r"^(\d{3})([ -])(.*)$");

/// Splits a byte stream into CRLF/LF lines, buffering partial lines
/// across arbitrarily split chunks. Lines are decoded as UTF-8 with
/// malformed sequences replaced, never throwing.
class _LineReader {
  _LineReader(this._transport);

  final SsipTransport _transport;
  final List<int> _buffer = [];
  bool _eof = false;

  /// Reads the next complete line (without its terminator), waiting
  /// up to [timeout] per transport read. Returns `null` on
  /// end-of-stream (after flushing any trailing unterminated bytes
  /// as a final line).
  Future<String?> readLine(Duration timeout) async {
    while (true) {
      final line = _takeLine();
      if (line != null) return line;
      if (_eof) return null;
      final chunk = await _transport.read(timeout);
      if (chunk == null) {
        _eof = true;
        if (_buffer.isNotEmpty) {
          final rest = utf8.decode(_buffer, allowMalformed: true);
          _buffer.clear();
          return rest;
        }
        return null;
      }
      _buffer.addAll(chunk);
    }
  }

  /// Returns the next complete line already buffered (or readable
  /// without waiting), or `null` when no complete line is available.
  /// Used by the best-effort event pump; never waits.
  Future<String?> tryReadLine() async {
    final line = _takeLine();
    if (line != null) return line;
    if (_eof) return null;
    List<int>? chunk;
    try {
      chunk = await _transport.tryRead();
    } catch (_) {
      return null;
    }
    if (chunk == null || chunk.isEmpty) return null;
    _buffer.addAll(chunk);
    return _takeLine();
  }

  String? _takeLine() {
    final newline = _buffer.indexOf(10); // \n
    if (newline < 0) return null;
    var end = newline;
    if (end > 0 && _buffer[end - 1] == 13) end--; // strip \r
    final line = utf8.decode(_buffer.sublist(0, end), allowMalformed: true);
    _buffer.removeRange(0, newline + 1);
    return line;
  }
}

class _EventLine {
  const _EventLine(this.code, this.text);

  final int code;
  final String text;
}

/// Accumulates the lines of one SSIP event group (codes 700–799)
/// until its final (space-form) line arrives, then yields the event.
/// Non-event lines reset the accumulator and yield `null`.
class _EventAccumulator {
  final List<_EventLine> _lines = [];

  SsipEvent? feed(String line) {
    final match = _replyLinePattern.firstMatch(line);
    if (match == null) {
      _lines.clear();
      return null;
    }
    final code = int.parse(match.group(1)!);
    final separator = match.group(2)!;
    final text = match.group(3)!;
    if (code < 700 || code >= 800) {
      _lines.clear();
      return null;
    }
    _lines.add(_EventLine(code, text));
    if (separator != " ") return null;
    final lines = List<_EventLine>.of(_lines);
    _lines.clear();
    final kind = switch (lines.first.code) {
      700 => SsipEventKind.indexMark,
      701 => SsipEventKind.begin,
      702 => SsipEventKind.end,
      703 => SsipEventKind.canceled,
      704 => SsipEventKind.paused,
      705 => SsipEventKind.resumed,
      _ => null,
    };
    if (kind == null) return null;
    return SsipEvent(
      messageId: lines.first.text,
      kind: kind,
      indexMark: kind == SsipEventKind.indexMark && lines.length >= 3
          ? lines[2].text
          : null,
    );
  }
}

/// Marker for "the transport ended mid-command": the caller drops the
/// connection and retries once on a fresh one.
class _SsipTransportFailure implements Exception {
  const _SsipTransportFailure(this.message);

  final String message;

  @override
  String toString() => "SsipTransportFailure: $message";
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

const Duration _connectTimeout = Duration(seconds: 2);
const Duration _detectConnectTimeout = Duration(seconds: 1);
const Duration _detectReplyTimeout = Duration(seconds: 2);
const Duration _replyTimeout = Duration(seconds: 10);
const Duration _detectEspeakTimeout = Duration(seconds: 3);
const Duration _espeakVoicesTimeout = Duration(seconds: 5);
const Duration _espeakSynthesizeTimeout = Duration(seconds: 30);
const String _clientName = "ciyue:ciyue:main";

/// Owns the single persistent SSIP connection to speech-dispatcher
/// and the espeak-ng fallback.
///
/// Use [LinuxTtsService.instance] in the app. Constructing a service
/// directly (with injected [transportFactory]/[espeakRunner]) is for
/// tests; each instance owns its own connection state.
///
/// Threading model: all SSIP commands on the persistent connection
/// are serialized through one queue, so concurrent [speak]/[stop]/
/// [voices] calls cannot interleave commands and corrupt replies.
/// SSIP event notifications are harvested best-effort by a periodic
/// pump into [lastEvents]; speech completion must never depend on
/// them (no END event arrives on hardware without audio output).
class LinuxTtsService {
  LinuxTtsService({
    SsipTransportFactory? transportFactory,
    EspeakRunner? espeakRunner,
    Duration pumpInterval = const Duration(milliseconds: 250),
  }) : _transportFactory = transportFactory ?? createDefaultSsipTransport,
       _espeakRunner = espeakRunner ?? _defaultEspeakRunner,
       // The parameter must stay publicly named `pumpInterval`; an
       // initializing formal would rename it to `_pumpInterval`.
       _pumpInterval = pumpInterval; // ignore: prefer_initializing_formals

  /// The shared instance used by the app.
  static final LinuxTtsService instance = LinuxTtsService();

  final SsipTransportFactory _transportFactory;
  final EspeakRunner _espeakRunner;
  final Duration _pumpInterval;

  SsipTransport? _transport;
  _LineReader? _reader;
  LinuxTtsAvailability? _cachedAvailability;
  LinuxTtsParams _lastParams = const LinuxTtsParams();
  LinuxTtsParams _appliedParams = const LinuxTtsParams();
  final Map<String, SsipEvent> _lastEvents = {};
  final _EventAccumulator _pumpAccumulator = _EventAccumulator();
  Timer? _pumpTimer;
  bool _busy = false;
  bool _disposed = false;
  Future<void> _tail = Future.value();

  /// The most recent event per message id, best-effort only. Updated
  /// by the event pump and by event groups seen while awaiting a
  /// reply. Never await these to decide that speech finished.
  Map<String, SsipEvent> get lastEvents => Map.unmodifiable(_lastEvents);

  /// The most recent event for [messageId], if one was seen.
  SsipEvent? lastEventFor(String messageId) => _lastEvents[messageId];

  // -- serialization -------------------------------------------------------

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<T> _withBusy<T>(Future<T> Function() operation) async {
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  // -- detection -----------------------------------------------------------

  /// Reports which backends are usable. The result is cached for the
  /// lifetime of this service (pass [refresh] to probe again, e.g.
  /// after the user starts speech-dispatcher). Timeouts are short
  /// (~1s SSIP connect, ~3s `espeak-ng --version`) so a missing
  /// daemon never hangs the speaker button.
  ///
  /// The SSIP probe uses a throwaway transport and never disturbs
  /// the persistent connection; when the persistent connection is
  /// already open, SSIP is reported available without new I/O.
  Future<LinuxTtsAvailability> detect({bool refresh = false}) async {
    final cached = _cachedAvailability;
    if (cached != null && !refresh) return cached;
    if (_disposed) {
      return cached ?? const LinuxTtsAvailability(ssip: false, espeak: false);
    }
    final result = await _detectOnce();
    _cachedAvailability = result;
    return result;
  }

  Future<LinuxTtsAvailability> _detectOnce() async {
    final bool ssip;
    if (_transport != null && _transport!.isOpen) {
      ssip = true;
    } else {
      ssip = await _probeSsip();
    }
    return LinuxTtsAvailability(ssip: ssip, espeak: await _probeEspeak());
  }

  /// Probes SSIP on a throwaway connection: connect + `SET SELF
  /// CLIENT_NAME` answered 2xx means reachable.
  Future<bool> _probeSsip() async {
    final transport = _transportFactory();
    try {
      await transport
          .connect(_detectConnectTimeout)
          .timeout(_detectConnectTimeout);
      final reader = _LineReader(transport);
      await transport.send(
        utf8.encode("SET SELF CLIENT_NAME $_clientName\r\n"),
      );
      final reply = await _readReply(reader, _detectReplyTimeout);
      final reachable = reply != null && reply.isSuccess;
      // Politely close a connection we opened; ignore any failure.
      try {
        await transport.send(utf8.encode("QUIT\r\n"));
        await reader.readLine(const Duration(milliseconds: 500));
      } catch (_) {}
      return reachable;
    } catch (_) {
      return false;
    } finally {
      try {
        await transport.close();
      } catch (_) {}
    }
  }

  Future<bool> _probeEspeak() async {
    try {
      final result = await _espeakRunner(["espeak-ng", "--version"])
          .timeout(_detectEspeakTimeout);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  // -- voices --------------------------------------------------------------

  /// Voices from the active backend: SSIP first (language-filtered
  /// `LIST SYNTHESIS_VOICES`), espeak-ng when SSIP is unavailable or
  /// its listing fails at the transport level. Returns `[]` when
  /// neither backend can list voices.
  ///
  /// The unfiltered SSIP voice list is 13k+ lines, so a language
  /// filter is always sent: [language] when given, else the language
  /// of the last spoken parameters, else `en`. For espeak, a `null`
  /// [language] returns every voice; otherwise voices whose language
  /// matches [language] exactly or as a prefix (`en` matches
  /// `en-gb`) are returned.
  Future<List<LinuxVoice>> voices({String? language}) {
    return _serialize(() async {
      if (_disposed) return <LinuxVoice>[];
      try {
        final ssipAvailable = await _ssipAvailable();
        if (ssipAvailable) {
          final ssipVoices = await _ssipVoices(language);
          if (ssipVoices != null) return ssipVoices;
        }
        return await _espeakVoices(language);
      } catch (_) {
        return <LinuxVoice>[];
      }
    });
  }

  Future<bool> _ssipAvailable() async {
    if (_transport != null && _transport!.isOpen) return true;
    return (await detect()).ssip;
  }

  /// Returns the SSIP voice list, `[]` when the daemon determinately
  /// cannot list them (e.g. 304 for an unknown language), or `null`
  /// on transport failure (caller falls back to espeak).
  Future<List<LinuxVoice>?> _ssipVoices(String? language) async {
    return _withBusy(() async {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          if (!await _ensureConnected(_lastParams)) return null;
          final filter = language ?? _lastParams.language ?? "en";
          final transport = _transport!;
          final reader = _reader!;
          await transport.send(
            utf8.encode("LIST SYNTHESIS_VOICES $filter\r\n"),
          );
          final reply = await _readReply(reader, _replyTimeout);
          if (reply == null) throw const _SsipTransportFailure("EOF");
          if (!reply.isSuccess) return <LinuxVoice>[];
          final voices = <LinuxVoice>[];
          for (final line in reply.lines) {
            // The final line is the "OK VOICE LIST SENT" text; the
            // voice lines carry tab-separated name/language/variant.
            final parts = line.split("\t");
            if (parts.length < 2) continue;
            final name = parts[0];
            if (name.isEmpty) continue;
            final variant = parts.length >= 3 && parts[2] != "none"
                ? parts[2]
                : null;
            voices.add(
              LinuxVoice(
                id: name,
                language: parts[1],
                variant: variant,
                displayName: name,
              ),
            );
          }
          return voices;
        } catch (_) {
          await _closeTransport();
          if (attempt == 1) return null;
        }
      }
      return null;
    });
  }

  Future<List<LinuxVoice>> _espeakVoices(String? language) async {
    try {
      final result = await _espeakRunner(["espeak-ng", "--voices"])
          .timeout(_espeakVoicesTimeout);
      if (result.exitCode != 0) return <LinuxVoice>[];
      final text = utf8.decode(result.stdout, allowMalformed: true);
      final voices = <LinuxVoice>[];
      // Columns: Pty, Language, Age/Gender, VoiceName, File, ...
      // The header line ("Pty Language ...") has no leading number
      // and is skipped by the pattern. Voice names contain no
      // whitespace, so whitespace splitting is safe.
      final pattern = RegExp(r"^\s*(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)");
      for (final line in text.split("\n")) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;
        final voiceLanguage = match.group(2)!;
        if (language != null) {
          final wanted = language.toLowerCase();
          final actual = voiceLanguage.toLowerCase();
          if (actual != wanted && !actual.startsWith("$wanted-")) continue;
        }
        final name = match.group(4)!;
        voices.add(
          LinuxVoice(
            id: name,
            language: voiceLanguage,
            variant: match.group(3),
            displayName: "$name ($voiceLanguage)",
          ),
        );
      }
      return voices;
    } catch (_) {
      return <LinuxVoice>[];
    }
  }

  // -- speaking (SSIP) -----------------------------------------------------

  /// Queues [text] for speech through speech-dispatcher.
  ///
  /// [language]/[rate]/[pitch]/[voice] are Ciyue settings values
  /// (see [LinuxTtsParams]); they are applied with `SET SELF ...`
  /// before the `SPEAK` block, in the order language, rate, pitch,
  /// then voice — voice last, because `SET LANGUAGE` may override a
  /// previous voice. Fields left `null` keep the connection's current
  /// values. SSIP volume is never set.
  ///
  /// Never throws: any failure (daemon unreachable, rejected
  /// parameter, transport error after one reconnect) returns a
  /// failure result so the caller can silently try the next backend.
  /// An empty [text] is a failure without any I/O.
  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  }) {
    return _serialize(() async {
      if (_disposed) {
        return SsipSpeakResult.failure("Linux TTS service is disposed.");
      }
      if (text.trim().isEmpty) {
        return SsipSpeakResult.failure("Empty text.");
      }
      final params = _lastParams.merge(
        LinuxTtsParams(
          language: language,
          rate: rate,
          pitch: pitch,
          voice: voice,
        ),
      );
      try {
        return await _withBusy(() => _speakOnce(text, params));
      } catch (_) {
        return SsipSpeakResult.failure("SSIP communication failed.");
      }
    });
  }

  Future<SsipSpeakResult> _speakOnce(String text, LinuxTtsParams params) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (!await _ensureConnected(params)) {
          await _closeTransport();
          if (attempt == 1) {
            return SsipSpeakResult.failure("Could not connect to SSIP.");
          }
          continue;
        }
        if (!_paramsApplied(params)) {
          if (!await _applyParams(params)) {
            return SsipSpeakResult.failure(
              "Speech-dispatcher rejected a speech parameter.",
            );
          }
          _appliedParams = params;
        }
        _lastParams = params;
        final transport = _transport!;
        final reader = _reader!;
        final receiving = await _command("SPEAK", reader, transport);
        if (receiving == null) {
          throw const _SsipTransportFailure("EOF awaiting SPEAK reply.");
        }
        if (!receiving.isSuccess) {
          return SsipSpeakResult.failure(
            "Speech-dispatcher refused SPEAK (${receiving.code}).",
          );
        }
        await transport.send(utf8.encode(_speakBlock(text)));
        final queued = await _readReply(reader, _replyTimeout);
        if (queued == null) {
          throw const _SsipTransportFailure("EOF awaiting SPEAK result.");
        }
        if (!queued.isSuccess) {
          return SsipSpeakResult.failure(
            "Speech-dispatcher refused the message (${queued.code}).",
          );
        }
        // Multi-line form: first payload is the message id ("225-1"
        // + "225 OK MESSAGE QUEUED"). Single-line form: the only
        // payload is the OK text, and there is no id.
        String? messageId;
        if (queued.lines.length > 1 &&
            int.tryParse(queued.lines.first) != null) {
          messageId = queued.lines.first;
        }
        return SsipSpeakResult.success(messageId);
      } on _SsipTransportFailure {
        await _closeTransport();
        if (attempt == 1) {
          return SsipSpeakResult.failure("SSIP communication failed.");
        }
        // Reconnect once; _ensureConnected re-applies the parameters
        // (they do not persist across connections).
      } catch (_) {
        await _closeTransport();
        if (attempt == 1) {
          return SsipSpeakResult.failure("SSIP communication failed.");
        }
      }
    }
    return SsipSpeakResult.failure("SSIP communication failed.");
  }

  /// Stops any speech from this connection (`CANCEL self`).
  /// Best-effort: never throws, and keeps the connection open so the
  /// next [speak] does not pay to reconnect. A no-op when not
  /// connected.
  Future<void> stop() {
    return _serialize(() async {
      if (_disposed) return;
      await _withBusy(() async {
        final transport = _transport;
        final reader = _reader;
        if (transport == null || reader == null || !transport.isOpen) {
          return;
        }
        try {
          final reply = await _command("CANCEL self", reader, transport);
          if (reply == null) await _closeTransport();
          // Any non-2xx reply is ignored: stopping is best-effort.
        } catch (_) {
          await _closeTransport();
        }
      });
    });
  }

  /// Closes the SSIP connection (`QUIT`, then close). Idempotent.
  /// After [dispose], [speak] fails and [voices] returns `[]`.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stopPump();
    await _serialize(() async {
      final transport = _transport;
      final reader = _reader;
      if (transport != null && reader != null && transport.isOpen) {
        try {
          await transport.send(utf8.encode("QUIT\r\n"));
          await reader.readLine(const Duration(seconds: 1));
        } catch (_) {}
      }
      await _closeTransport();
    });
  }

  // -- connection management ----------------------------------------------

  /// Connects (if needed) and, on a fresh connection, sets the client
  /// name, enables event notifications, and applies [params].
  /// Returns `false` when the connection could not be established.
  Future<bool> _ensureConnected(LinuxTtsParams params) async {
    if (_transport != null && _reader != null && _transport!.isOpen) {
      return true;
    }
    await _closeTransport();
    final transport = _transportFactory();
    try {
      await transport.connect(_connectTimeout).timeout(_connectTimeout);
      _transport = transport;
      _reader = _LineReader(transport);
      final reader = _reader!;
      if (!await _commandOk(
        "SET SELF CLIENT_NAME $_clientName",
        reader,
        transport,
      )) {
        await _closeTransport();
        return false;
      }
      if (!await _commandOk(
        "SET SELF NOTIFICATION ALL on",
        reader,
        transport,
      )) {
        await _closeTransport();
        return false;
      }
      if (!await _applyParams(params)) {
        await _closeTransport();
        return false;
      }
      _appliedParams = params;
      _startPump();
      return true;
    } catch (_) {
      await _closeTransport();
      return false;
    }
  }

  bool _paramsApplied(LinuxTtsParams params) => _appliedParams == params;

  /// Applies the non-null fields of [params] in the order language,
  /// rate, pitch, voice (voice last: `SET LANGUAGE` may override a
  /// previous voice). Returns `false` when the daemon determinately
  /// rejects a parameter; throws [_SsipTransportFailure] when the
  /// transport ends mid-command. Values that cannot be sent safely
  /// on the wire (language with whitespace/control characters, voice
  /// with CR/LF/control characters) are skipped rather than sent.
  Future<bool> _applyParams(LinuxTtsParams params) async {
    final transport = _transport;
    final reader = _reader;
    if (transport == null || reader == null) {
      throw const _SsipTransportFailure("Not connected.");
    }
    final language = params.language;
    if (language != null &&
        language.isNotEmpty &&
        !_containsWhitespaceOrControl(language)) {
      final reply = await _command(
        "SET SELF LANGUAGE $language",
        reader,
        transport,
      );
      if (reply == null) {
        throw const _SsipTransportFailure("EOF setting language.");
      }
      if (!reply.isSuccess) return false;
    }
    if (params.rate != null) {
      final reply = await _command(
        "SET SELF RATE ${ssipRateFromSpeechRate(params.rate!)}",
        reader,
        transport,
      );
      if (reply == null) {
        throw const _SsipTransportFailure("EOF setting rate.");
      }
      if (!reply.isSuccess) return false;
    }
    if (params.pitch != null) {
      final reply = await _command(
        "SET SELF PITCH ${ssipPitchFromSpeechPitch(params.pitch!)}",
        reader,
        transport,
      );
      if (reply == null) {
        throw const _SsipTransportFailure("EOF setting pitch.");
      }
      if (!reply.isSuccess) return false;
    }
    final voice = params.voice;
    if (voice != null && voice.isNotEmpty && !_containsControl(voice)) {
      final reply = await _command(
        "SET SELF SYNTHESIS_VOICE $voice",
        reader,
        transport,
      );
      if (reply == null) {
        throw const _SsipTransportFailure("EOF setting voice.");
      }
      if (!reply.isSuccess) return false;
    }
    return true;
  }

  Future<_SsipReply?> _command(
    String command,
    _LineReader reader,
    SsipTransport transport,
  ) async {
    await transport.send(utf8.encode("$command\r\n"));
    return _readReply(reader, _replyTimeout);
  }

  Future<bool> _commandOk(
    String command,
    _LineReader reader,
    SsipTransport transport,
  ) async {
    final reply = await _command(command, reader, transport);
    return reply != null && reply.isSuccess;
  }

  /// Reads one reply group, stashing any 7xx event groups seen on the
  /// way into [_lastEvents]. Returns `null` on end-of-stream.
  Future<_SsipReply?> _readReply(_LineReader reader, Duration timeout) async {
    final accumulator = _EventAccumulator();
    final payloads = <String>[];
    int? code;
    while (true) {
      final line = await reader.readLine(timeout);
      if (line == null) return null;
      final match = _replyLinePattern.firstMatch(line);
      if (match == null) continue;
      final lineCode = int.parse(match.group(1)!);
      if (lineCode >= 700 && lineCode < 800) {
        final event = accumulator.feed(line);
        if (event != null) _recordEvent(event);
        continue;
      }
      code ??= lineCode;
      payloads.add(match.group(3)!);
      if (match.group(2) == " ") {
        return _SsipReply(code: code, lines: payloads);
      }
    }
  }

  /// The `SPEAK` data block: the text lines, dot-stuffed (any line
  /// starting with `.` gets an extra `.` prepended), terminated by a
  /// line containing only `.`. Always CRLF-terminated.
  String _speakBlock(String text) {
    final buffer = StringBuffer();
    for (final line in text.split(RegExp(r"\r\n|\r|\n"))) {
      if (line.startsWith(".")) buffer.write(".");
      buffer.write(line);
      buffer.write("\r\n");
    }
    buffer.write(".\r\n");
    return buffer.toString();
  }

  Future<void> _closeTransport() async {
    _stopPump();
    final transport = _transport;
    _transport = null;
    _reader = null;
    _appliedParams = const LinuxTtsParams();
    if (transport != null) {
      try {
        await transport.close();
      } catch (_) {}
    }
  }

  // -- event pump ----------------------------------------------------------

  void _startPump() {
    _stopPump();
    _pumpTimer = Timer.periodic(_pumpInterval, (_) {
      unawaited(_pumpOnce());
    });
  }

  void _stopPump() {
    _pumpTimer?.cancel();
    _pumpTimer = null;
  }

  /// Best-effort harvest of event notifications that arrive while the
  /// connection is idle. Skipped while a command is in flight (the
  /// reply reader stashes events itself in that window), and never
  /// throws: a dead connection is dropped so the next command
  /// reconnects.
  Future<void> _pumpOnce() async {
    if (_busy || _disposed) return;
    final transport = _transport;
    final reader = _reader;
    if (transport == null || reader == null || !transport.isOpen) return;
    try {
      while (true) {
        final line = await reader.tryReadLine();
        if (line == null) break;
        final event = _pumpAccumulator.feed(line);
        if (event != null) _recordEvent(event);
      }
      if (!transport.isOpen) await _closeTransport();
    } catch (_) {
      // Best-effort only; leave the connection for the next command.
    }
  }

  void _recordEvent(SsipEvent event) {
    _lastEvents[event.messageId] = event;
    // Bound memory: keep only the most recent events.
    while (_lastEvents.length > 64) {
      _lastEvents.remove(_lastEvents.keys.first);
    }
  }

  // -- espeak synthesis ----------------------------------------------------

  /// Renders [text] to WAV bytes with `espeak-ng --stdout`, or `null`
  /// on any failure (missing binary, nonzero exit, empty/non-WAV
  /// output, timeout). Never throws. [voice]/[rate]/[pitch] are
  /// Ciyue settings values; see [buildEspeakArgv] for the argv.
  Future<Uint8List?> synthesizeWav(
    String text, {
    String? voice,
    double? rate,
    double? pitch,
  }) async {
    if (text.trim().isEmpty) return null;
    try {
      final result = await _espeakRunner(
        buildEspeakArgv(text, voice: voice, rate: rate, pitch: pitch),
      ).timeout(_espeakSynthesizeTimeout);
      if (result.exitCode != 0) return null;
      final bytes = Uint8List.fromList(result.stdout);
      if (!_isWav(bytes)) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Light WAV validation: non-empty bytes starting with the `RIFF`
  /// magic. (espeak-ng `--stdout` output starts with `RIFF`.)
  bool _isWav(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46; // F
  }
}

bool _containsWhitespaceOrControl(String value) {
  for (final unit in value.codeUnits) {
    if (unit <= 0x20 || unit == 0x7f) return true;
  }
  return false;
}

bool _containsControl(String value) {
  for (final unit in value.codeUnits) {
    if (unit < 0x20 || unit == 0x7f) return true;
  }
  return false;
}
