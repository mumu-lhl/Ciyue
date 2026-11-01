import "dart:convert";
import "dart:math" as math;
import "dart:typed_data";

import "package:ciyue/services/linux_tts.dart";
import "package:ciyue/services/linux_tts_transport.dart";
import "package:flutter_test/flutter_test.dart";

List<int> _bytes(String text) => utf8.encode(text);

String _sentText(_FakeTransport transport) =>
    utf8.decode(transport.sent, allowMalformed: true);

int _countOccurrences(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;

/// A scripted fake SSIP transport: [read] serves [script] in small
/// chunks (to exercise partial-line buffering), [tryRead] serves
/// [eventBytes], and every sent byte is recorded for exact assertions.
/// Zero network, zero sockets.
class _FakeTransport implements SsipTransport {
  _FakeTransport({
    required this._script,
    this.connectDelay,
    this.connectFails = false,
    List<int>? eventBytes,
    // `eventBytes` is the fake's construction-time parameter name.
  }) : _eventBytes = eventBytes; // ignore: prefer_initializing_formals

  // Small chunks exercise partial-line buffering in the line reader.
  static const int _chunkSize = 7;

  final List<int> _script;
  final List<int>? _eventBytes;
  final Duration? connectDelay;
  final bool connectFails;

  final List<int> sent = [];
  int connectCalls = 0;
  int closeCalls = 0;
  bool _open = false;
  bool _closed = false;
  int _readPos = 0;
  int _eventPos = 0;

  @override
  bool get isOpen => _open;

  @override
  Future<void> connect(Duration timeout) async {
    connectCalls++;
    if (connectFails) throw StateError("fake connect refused");
    if (connectDelay != null) await Future<void>.delayed(connectDelay!);
    // Complete normally even if closed while waiting, so no
    // unhandled async error escapes a timed-out connect.
    if (!_closed) _open = true;
  }

  @override
  Future<void> send(List<int> bytes) async {
    if (!_open) throw StateError("fake transport is not open");
    sent.addAll(bytes);
  }

  @override
  Future<List<int>?> read(Duration timeout) async {
    if (!_open) return null;
    if (_readPos >= _script.length) return null;
    final end = math.min(_readPos + _chunkSize, _script.length);
    final chunk = _script.sublist(_readPos, end);
    _readPos = end;
    return chunk;
  }

  @override
  Future<List<int>?> tryRead() async {
    final eventBytes = _eventBytes;
    if (eventBytes == null || _eventPos >= eventBytes.length) return null;
    final end = math.min(_eventPos + _chunkSize, eventBytes.length);
    final chunk = eventBytes.sublist(_eventPos, end);
    _eventPos = end;
    return chunk;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _closed = true;
    _open = false;
  }
}

/// Hands out [_FakeTransport]s from a queue of scripts (one per
/// connection, in order; the last script repeats for extra
/// connections, e.g. reconnect retries).
class _FakeTransportFactory {
  _FakeTransportFactory({
    required this.scripts,
    this.connectDelay,
    this.connectFails = false,
    this.eventBytes,
  });

  final List<List<int>> scripts;
  final Duration? connectDelay;
  final bool connectFails;
  final List<int>? eventBytes;
  final List<_FakeTransport> created = [];
  int _next = 0;

  SsipTransport call() {
    final script = scripts[_next < scripts.length ? _next : scripts.length - 1];
    _next++;
    final transport = _FakeTransport(
      script: List<int>.of(script),
      connectDelay: connectDelay,
      connectFails: connectFails,
      eventBytes: eventBytes,
    );
    created.add(transport);
    return transport;
  }
}

/// A fake `espeak-ng` runner returning canned output.
class _FakeEspeak {
  _FakeEspeak({required this.result, this.throwError = false});

  EspeakResult result;
  bool throwError;
  int calls = 0;
  final List<List<String>> argvs = [];

  Future<EspeakResult> call(List<String> argv) async {
    calls++;
    argvs.add(List<String>.of(argv));
    if (throwError) throw StateError("fake espeak spawn failed");
    return result;
  }
}

const _handshake =
    "208 OK CLIENT NAME SET\r\n"
    "220 OK NOTIFICATION SET\r\n";
const _setsEn =
    "201 OK LANGUAGE SET\r\n203 OK RATE SET\r\n204 OK PITCH SET\r\n";

void main() {
  final services = <LinuxTtsService>[];

  LinuxTtsService makeService({
    _FakeTransportFactory? factory,
    _FakeEspeak? espeak,
    Duration pumpInterval = const Duration(milliseconds: 50),
  }) {
    final service = LinuxTtsService(
      transportFactory: factory?.call,
      espeakRunner: espeak?.call,
      pumpInterval: pumpInterval,
    );
    services.add(service);
    return service;
  }

  tearDown(() async {
    for (final service in services) {
      await service.dispose();
    }
    services.clear();
  });

  group("SSIP speak framing", () {
    test("pins exact bytes incl. dot-stuffing and multi-line 225", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225-1\r\n225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "hello\n.dot line\n.\n..double\nplain",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result.success, isTrue);
      expect(result.messageId, "1");
      expect(result.error, isNull);
      expect(
        _sentText(factory.created.single),
        "SET SELF CLIENT_NAME ciyue:ciyue:main\r\n"
        "SET SELF NOTIFICATION ALL on\r\n"
        "SET SELF LANGUAGE en\r\n"
        "SET SELF RATE 0\r\n"
        "SET SELF PITCH 0\r\n"
        "SPEAK\r\n"
        "hello\r\n"
        "..dot line\r\n"
        "..\r\n"
        "...double\r\n"
        "plain\r\n"
        ".\r\n",
      );
    });

    test("single-line 225 succeeds with no message id", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "hi",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result.success, isTrue);
      expect(result.messageId, isNull);
    });

    test("voice is set after language, rate, and pitch", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake"
            "201 OK LANGUAGE SET\r\n"
            "203 OK RATE SET\r\n"
            "204 OK PITCH SET\r\n"
            "209 OK VOICE SET\r\n"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "bonjour",
        language: "fr",
        rate: 0.5,
        pitch: 1.0,
        voice: "French (France)",
      );

      expect(result.success, isTrue);
      final sent = _sentText(factory.created.single);
      expect(
        sent.indexOf("SET SELF LANGUAGE fr\r\n") <
            sent.indexOf("SET SELF RATE 0\r\n"),
        isTrue,
      );
      expect(
        sent.indexOf("SET SELF RATE 0\r\n") <
            sent.indexOf("SET SELF PITCH 0\r\n"),
        isTrue,
      );
      expect(
        sent.indexOf("SET SELF PITCH 0\r\n") <
            sent.indexOf("SET SELF SYNTHESIS_VOICE French (France)\r\n"),
        isTrue,
      );
      expect(
        sent.indexOf("SET SELF SYNTHESIS_VOICE French (France)\r\n") <
            sent.indexOf("SPEAK\r\n"),
        isTrue,
      );
    });

    test("rate and pitch map to SSIP ints in SET bytes", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake"
            "203 OK RATE SET\r\n"
            "204 OK PITCH SET\r\n"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak("hi", rate: 0.1, pitch: 2.0);

      expect(result.success, isTrue);
      final sent = _sentText(factory.created.single);
      expect(sent, contains("SET SELF RATE -80\r\n"));
      expect(sent, contains("SET SELF PITCH 100\r\n"));
      expect(sent, isNot(contains("SET SELF LANGUAGE")));
    });

    test("299 is success, 499 is failure (first-digit reply rule)", () async {
      final okFactory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "299 OK WEIRD\r\n"
            "220 OK NOTIFICATION SET\r\n"
            "201 OK LANGUAGE SET\r\n"
            "203 OK RATE SET\r\n"
            "204 OK PITCH SET\r\n"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final okService = makeService(factory: okFactory);
      final okResult = await okService.speak(
        "hi",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );
      expect(okResult.success, isTrue);

      final badFactory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake"
            "499 NOPE\r\n",
          ),
          _bytes(
            "$_handshake"
            "499 NOPE\r\n",
          ),
        ],
      );
      final badService = makeService(factory: badFactory);
      final badResult = await badService.speak(
        "hi",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );
      expect(badResult.success, isFalse);
      expect(badResult.error, isNotNull);
      expect(_sentText(badFactory.created.first), isNot(contains("SPEAK")));
    });

    test("events interleaved with replies are stashed, not lost", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "208 OK CLIENT NAME SET\r\n"
            "701-7\r\n701-9\r\n701 BEGIN\r\n"
            "220 OK NOTIFICATION SET\r\n"
            "$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "hi",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result.success, isTrue);
      final event = service.lastEventFor("7");
      expect(event, isNotNull);
      expect(event!.kind, SsipEventKind.begin);
    });

    test("reconnect re-applies params after EOF mid-speak", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          // First connection: handshake + SETs + SPEAK accepted,
          // then the transport ends before the queued reply.
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n",
          ),
          // Second connection: full success.
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225-9\r\n225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "hello",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result.success, isTrue);
      expect(result.messageId, "9");
      expect(factory.created, hasLength(2));
      final second = _sentText(factory.created[1]);
      expect(second, contains("SET SELF CLIENT_NAME ciyue:ciyue:main\r\n"));
      expect(second, contains("SET SELF LANGUAGE en\r\n"));
      expect(second, contains("SET SELF RATE 0\r\n"));
      expect(second, contains("SET SELF PITCH 0\r\n"));
      expect(second, contains("SPEAK\r\nhello\r\n.\r\n"));
    });

    test("stop sends CANCEL and keeps the connection open", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225-1\r\n225 OK MESSAGE QUEUED\r\n"
            "213 OK CANCELED\r\n"
            "230 OK RECEIVING DATA\r\n"
            "225-2\r\n225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      await service.speak("one", language: "en", rate: 0.5, pitch: 1.0);
      await service.stop();
      final second = await service.speak(
        "two",
        language: "en",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(second.success, isTrue);
      expect(second.messageId, "2");
      expect(factory.created, hasLength(1));
      final sent = _sentText(factory.created.single);
      expect(_countOccurrences(sent, "SET SELF CLIENT_NAME"), 1);
      expect(_countOccurrences(sent, "CANCEL self\r\n"), 1);
      expect(_countOccurrences(sent, "SPEAK\r\n"), 2);
    });

    test("dispose sends QUIT and closes", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n"
            "231 HAPPY HACKING\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);
      await service.speak("hi", language: "en", rate: 0.5, pitch: 1.0);

      await service.dispose();
      services.remove(service);

      expect(_sentText(factory.created.single), endsWith("QUIT\r\n"));
      expect(factory.created.single.closeCalls, 1);
      final after = await service.speak("hi");
      expect(after.success, isFalse);
    });

    test("empty text fails without any I/O", () async {
      final factory = _FakeTransportFactory(scripts: [_bytes("")]);
      final service = makeService(factory: factory);

      final result = await service.speak("  \n ");

      expect(result.success, isFalse);
      expect(factory.created, isEmpty);
    });

    test("connect refusal fails without throwing", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectFails: true,
      );
      final service = makeService(factory: factory);

      final result = await service.speak("hi", language: "en");

      expect(result.success, isFalse);
      // One reconnect attempt.
      expect(factory.created, hasLength(2));
    });

    test(
      "slow connect times out and fails without throwing",
      timeout: const Timeout(Duration(seconds: 15)),
      () async {
        final factory = _FakeTransportFactory(
          scripts: [_bytes("")],
          connectDelay: const Duration(seconds: 5),
        );
        final service = makeService(factory: factory);

        final result = await service.speak("hi", language: "en");

        expect(result.success, isFalse);
        expect(factory.created, hasLength(2));
      },
    );

    test("unsafe language value is skipped, not sent", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake"
            "203 OK RATE SET\r\n"
            "204 OK PITCH SET\r\n"
            "230 OK RECEIVING DATA\r\n"
            "225 OK MESSAGE QUEUED\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final result = await service.speak(
        "hi",
        language: "en\r\nQUIT\r\n",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result.success, isTrue);
      expect(
        _sentText(factory.created.single),
        isNot(contains("SET SELF LANGUAGE")),
      );
    });
  });

  group("SSIP events via the background pump", () {
    test("idle 702/703/700 events land in the last-event map", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes(
            "$_handshake$_setsEn"
            "230 OK RECEIVING DATA\r\n"
            "225-3\r\n225 OK MESSAGE QUEUED\r\n",
          ),
        ],
        eventBytes: _bytes(
          "702-3\r\n702-9\r\n702 END\r\n"
          "703-4\r\n703-9\r\n703 CANCELED\r\n"
          "700-5\r\n700-9\r\n700-my-mark\r\n700 END\r\n",
        ),
      );
      final service = makeService(factory: factory);
      await service.speak("hi", language: "en", rate: 0.5, pitch: 1.0);

      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(service.lastEventFor("3")?.kind, SsipEventKind.end);
      expect(service.lastEventFor("4")?.kind, SsipEventKind.canceled);
      final mark = service.lastEventFor("5");
      expect(mark?.kind, SsipEventKind.indexMark);
      expect(mark?.indexMark, "my-mark");
    });
  });

  group("voices", () {
    test("SSIP voices are language-filtered and parsed", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes("208 OK CLIENT NAME SET\r\n231 HAPPY HACKING\r\n"),
          _bytes(
            "$_handshake"
            "249-Afrikaans+Adam\taf\tAdam\r\n"
            "249-Afrikaans\taf\tnone\r\n"
            "249 OK VOICE LIST SENT\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      final voices = await service.voices(language: "af");

      expect(
        _sentText(factory.created.last),
        contains("LIST SYNTHESIS_VOICES af\r\n"),
      );
      expect(voices, hasLength(2));
      expect(
        voices[0],
        const LinuxVoice(
          id: "Afrikaans+Adam",
          language: "af",
          variant: "Adam",
          displayName: "Afrikaans+Adam",
        ),
      );
      expect(voices[1].variant, isNull);
      expect(voices[1].id, "Afrikaans");
    });

    test("SSIP 304 returns an empty list", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes("208 OK CLIENT NAME SET\r\n231 HAPPY HACKING\r\n"),
          _bytes(
            "$_handshake"
            "304 CANT LIST VOICES\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      expect(await service.voices(language: "xx"), isEmpty);
    });

    test("null language always sends an SSIP language filter", () async {
      final factory = _FakeTransportFactory(
        scripts: [
          _bytes("208 OK CLIENT NAME SET\r\n231 HAPPY HACKING\r\n"),
          _bytes(
            "$_handshake"
            "249 OK VOICE LIST SENT\r\n",
          ),
        ],
      );
      final service = makeService(factory: factory);

      await service.voices();

      expect(
        _sentText(factory.created.last),
        contains("LIST SYNTHESIS_VOICES en\r\n"),
      );
    });

    test("espeak fallback parses --voices output", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectFails: true,
      );
      final espeak = _FakeEspeak(
        result: EspeakResult(
          exitCode: 0,
          stdout: _bytes(
            "Pty Language       Age/Gender VoiceName          File                 Other Languages\n"
            " 5  af              --/M      Afrikaans          gmw/af               \n"
            " 2  en-gb           --/M      English_(Great_Britain) gmw/en               (en 2)\n"
            " 2  en-us           --/M      English_(America)  gmw/en-US            (en 3)\n"
            " 5  de              --/M      German             gmw/de               \n",
          ),
          stderr: const [],
        ),
      );
      final service = makeService(factory: factory, espeak: espeak);

      final voices = await service.voices(language: "en");

      expect(espeak.argvs, [
        ["espeak-ng", "--version"],
        ["espeak-ng", "--voices"],
      ]);
      expect(voices.map((v) => v.id), [
        "English_(Great_Britain)",
        "English_(America)",
      ]);
      expect(voices[0].language, "en-gb");
      expect(voices[0].variant, "--/M");
      expect(voices[0].displayName, "English_(Great_Britain) (en-gb)");

      final all = await service.voices();
      expect(all, hasLength(4));
    });

    test("neither backend returns an empty list", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectFails: true,
      );
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 1, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      expect(await service.voices(language: "en"), isEmpty);
    });
  });

  group("rate and pitch mappings", () {
    test("SSIP rate boundaries", () {
      expect(ssipRateFromSpeechRate(0.0), -100);
      expect(ssipRateFromSpeechRate(0.1), -80);
      expect(ssipRateFromSpeechRate(0.25), -50);
      expect(ssipRateFromSpeechRate(0.5), 0);
      expect(ssipRateFromSpeechRate(0.75), 50);
      expect(ssipRateFromSpeechRate(1.0), 100);
      expect(ssipRateFromSpeechRate(1.5), 100);
      expect(ssipRateFromSpeechRate(-1.0), -100);
      expect(ssipRateFromSpeechRate(double.nan), 0);
      expect(ssipRateFromSpeechRate(double.infinity), 0);
    });

    test("SSIP pitch boundaries", () {
      expect(ssipPitchFromSpeechPitch(0.0), -100);
      expect(ssipPitchFromSpeechPitch(0.5), -50);
      expect(ssipPitchFromSpeechPitch(0.75), -25);
      expect(ssipPitchFromSpeechPitch(1.0), 0);
      expect(ssipPitchFromSpeechPitch(1.5), 50);
      expect(ssipPitchFromSpeechPitch(2.0), 100);
      expect(ssipPitchFromSpeechPitch(2.5), 100);
      expect(ssipPitchFromSpeechPitch(3.0), 100);
      expect(ssipPitchFromSpeechPitch(double.nan), 0);
    });

    test("espeak wpm boundaries", () {
      expect(espeakWpmFromSpeechRate(0.0), 80);
      expect(espeakWpmFromSpeechRate(0.1), 80);
      expect(espeakWpmFromSpeechRate(0.25), 88);
      expect(espeakWpmFromSpeechRate(0.5), 175);
      expect(espeakWpmFromSpeechRate(0.75), 263);
      expect(espeakWpmFromSpeechRate(1.0), 350);
      expect(espeakWpmFromSpeechRate(1.5), 450);
      expect(espeakWpmFromSpeechRate(2.0), 450);
      expect(espeakWpmFromSpeechRate(double.nan), 175);
    });

    test("espeak pitch boundaries", () {
      expect(espeakPitchFromSpeechPitch(0.0), 0);
      expect(espeakPitchFromSpeechPitch(0.5), 25);
      expect(espeakPitchFromSpeechPitch(0.75), 38);
      expect(espeakPitchFromSpeechPitch(1.0), 50);
      expect(espeakPitchFromSpeechPitch(1.5), 75);
      expect(espeakPitchFromSpeechPitch(2.0), 99);
      expect(espeakPitchFromSpeechPitch(2.5), 99);
      expect(espeakPitchFromSpeechPitch(double.nan), 50);
    });
  });

  group("espeak argv and synthesis", () {
    test("argv building with voice, rate, and pitch", () {
      expect(buildEspeakArgv("hello", voice: "en-US", rate: 0.5, pitch: 1.0), [
        "espeak-ng",
        "--stdout",
        "-v",
        "en-US",
        "-s",
        "175",
        "-p",
        "50",
        "--",
        "hello",
      ]);
    });

    test("argv building omits -v without a voice, uses defaults", () {
      expect(buildEspeakArgv("hello"), [
        "espeak-ng",
        "--stdout",
        "-s",
        "175",
        "-p",
        "50",
        "--",
        "hello",
      ]);
    });

    test("argv building clamps extremes and keeps text whole", () {
      final argv = buildEspeakArgv("a -- b\nc", rate: 0.0, pitch: 2.0);
      expect(argv, containsAllInOrder(["-s", "80", "-p", "99"]));
      expect(argv[argv.length - 2], "--");
      expect(argv.last, "a -- b\nc");
    });

    test("synthesizeWav returns valid RIFF bytes", () async {
      final wav = Uint8List.fromList([
        ..._bytes("RIFF"),
        0,
        0,
        0,
        0,
        ..._bytes("WAVE"),
        1,
        2,
        3,
      ]);
      final espeak = _FakeEspeak(
        result: EspeakResult(exitCode: 0, stdout: wav, stderr: const []),
      );
      final service = makeService(espeak: espeak);

      final result = await service.synthesizeWav(
        "hello",
        voice: "en-US",
        rate: 0.5,
        pitch: 1.0,
      );

      expect(result, wav);
      expect(espeak.argvs.single, [
        "espeak-ng",
        "--stdout",
        "-v",
        "en-US",
        "-s",
        "175",
        "-p",
        "50",
        "--",
        "hello",
      ]);
    });

    test("synthesizeWav rejects empty, non-RIFF, and failed runs", () async {
      final service = makeService(
        espeak: _FakeEspeak(
          result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
        ),
      );
      expect(await service.synthesizeWav("hello"), isNull);

      final nonRiff = makeService(
        espeak: _FakeEspeak(
          result: EspeakResult(
            exitCode: 0,
            stdout: _bytes("NOPE...."),
            stderr: const [],
          ),
        ),
      );
      expect(await nonRiff.synthesizeWav("hello"), isNull);

      final failed = makeService(
        espeak: _FakeEspeak(
          result: EspeakResult(
            exitCode: 1,
            stdout: _bytes("RIFF...."),
            stderr: const [],
          ),
        ),
      );
      expect(await failed.synthesizeWav("hello"), isNull);

      final throwing = makeService(
        espeak: _FakeEspeak(
          result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
          throwError: true,
        ),
      );
      expect(await throwing.synthesizeWav("hello"), isNull);
    });

    test("synthesizeWav with empty text does no I/O", () async {
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
      );
      final service = makeService(espeak: espeak);

      expect(await service.synthesizeWav(" "), isNull);
      expect(espeak.calls, 0);
    });
  });

  group("detection", () {
    Future<_FakeTransportFactory> probeFactory() async => _FakeTransportFactory(
      scripts: [_bytes("208 OK CLIENT NAME SET\r\n231 HAPPY HACKING\r\n")],
    );

    test("both present", () async {
      final factory = await probeFactory();
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      final availability = await service.detect();

      expect(availability.ssip, isTrue);
      expect(availability.espeak, isTrue);
      expect(availability.any, isTrue);
      expect(
        _sentText(factory.created.single),
        contains("SET SELF CLIENT_NAME ciyue:ciyue:main\r\n"),
      );
      expect(_sentText(factory.created.single), contains("QUIT\r\n"));
    });

    test("SSIP only", () async {
      final factory = await probeFactory();
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 1, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      final availability = await service.detect();

      expect(
        availability,
        const LinuxTtsAvailability(ssip: true, espeak: false),
      );
    });

    test("espeak only", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectFails: true,
      );
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      final availability = await service.detect();

      expect(
        availability,
        const LinuxTtsAvailability(ssip: false, espeak: true),
      );
    });

    test("neither", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectFails: true,
      );
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 1, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      expect(
        await service.detect(),
        const LinuxTtsAvailability(ssip: false, espeak: false),
      );
    });

    test("detection is cached; refresh probes again", () async {
      final factory = await probeFactory();
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      await service.detect();
      await service.detect();

      expect(factory.created, hasLength(1));
      expect(espeak.calls, 1);

      await service.detect(refresh: true);

      expect(factory.created, hasLength(2));
      expect(espeak.calls, 2);
    });

    test("slow SSIP probe times out instead of hanging", () async {
      final factory = _FakeTransportFactory(
        scripts: [_bytes("")],
        connectDelay: const Duration(seconds: 5),
      );
      final espeak = _FakeEspeak(
        result: const EspeakResult(exitCode: 0, stdout: [], stderr: []),
      );
      final service = makeService(factory: factory, espeak: espeak);

      final availability = await service.detect();

      expect(availability.ssip, isFalse);
      expect(availability.espeak, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
