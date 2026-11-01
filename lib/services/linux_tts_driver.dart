import "package:ciyue/repositories/settings.dart";
import "package:ciyue/services/linux_tts.dart";
import "package:flutter/foundation.dart";

/// The utterance parameters for one Linux TTS call, resolved from
/// [settings] in Ciyue's own units (the same units `flutter_tts`
/// uses on other platforms).
///
/// Voice selection: when [settings.linuxTtsVoice] is set, its id is
/// passed as the voice; otherwise `null` is passed and the backend
/// picks its default for [language]. On the SSIP path the language
/// itself selects the voice (`SET SELF LANGUAGE`, and the daemon's
/// configured default voice for that language); on the espeak WAV
/// path an unset voice means espeak-ng's own default voice — the
/// language is not separately passed to `espeak-ng` (see
/// [LinuxTtsService.synthesizeWav], which takes no language), so an
/// explicit voice choice is the only way to get a non-default
/// language out of the WAV fallback.
///
/// One SSIP caveat: [LinuxTtsService] remembers the last parameters
/// it applied and a `null` voice leaves the connection's current
/// voice untouched, so switching back to the default voice after
/// speaking with an explicit voice may keep that voice on the SSIP
/// path until the process (or connection) restarts. The WAV path
/// has no such stickiness.
({String? language, double rate, double pitch, String? voice})
linuxTtsSpeakOptions() => (
  language: settings.ttsLanguage,
  rate: settings.ttsSpeechRate,
  pitch: settings.ttsPitch,
  voice: settings.linuxTtsVoice,
);

/// The Linux TTS backend surface the playback chain and [TtsHelper]
/// speak through. This mirrors [LinuxTtsService] one-to-one so the
/// real implementation is a trivial delegation (see
/// [_RealLinuxTtsDriver]); the indirection exists only so tests can
/// substitute a fake with zero processes, network, or audio (the
/// shared [LinuxTtsService.instance] has no replaceable instance).
abstract class LinuxTtsDriver {
  Future<LinuxTtsAvailability> detect({bool refresh = false});

  Future<List<LinuxVoice>> voices({String? language});

  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  });

  Future<void> stop();

  Future<Uint8List?> synthesizeWav(
    String text, {
    String? voice,
    double? rate,
    double? pitch,
  });
}

class _RealLinuxTtsDriver implements LinuxTtsDriver {
  const _RealLinuxTtsDriver();

  LinuxTtsService get _service => LinuxTtsService.instance;

  @override
  Future<LinuxTtsAvailability> detect({bool refresh = false}) =>
      _service.detect(refresh: refresh);

  @override
  Future<List<LinuxVoice>> voices({String? language}) =>
      _service.voices(language: language);

  @override
  Future<SsipSpeakResult> speak(
    String text, {
    String? language,
    double? rate,
    double? pitch,
    String? voice,
  }) => _service.speak(
    text,
    language: language,
    rate: rate,
    pitch: pitch,
    voice: voice,
  );

  @override
  Future<void> stop() => _service.stop();

  @override
  Future<Uint8List?> synthesizeWav(
    String text, {
    String? voice,
    double? rate,
    double? pitch,
  }) => _service.synthesizeWav(text, voice: voice, rate: rate, pitch: pitch);
}

const _realLinuxTtsDriver = _RealLinuxTtsDriver();

/// Test override for the Linux TTS driver used by the playback chain
/// and [TtsHelper]. Production code leaves this null so the real
/// [LinuxTtsService] is used; tests set a fake and clear it in
/// tearDown. Only ever consulted on Linux.
@visibleForTesting
LinuxTtsDriver? linuxTtsDriverOverride;

/// The driver the Linux playback paths speak through: the test
/// override when set, otherwise the real [LinuxTtsService].
LinuxTtsDriver get linuxTtsDriver =>
    linuxTtsDriverOverride ?? _realLinuxTtsDriver;
