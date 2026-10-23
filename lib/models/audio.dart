/// How word pronunciation is produced when the speaker button is used.
enum PronunciationMode {
  /// Pronunciation packs first; TTS speaks when no pack has the word.
  packFirst,

  /// Only pronunciation packs; nothing is spoken when no pack matches.
  packOnly,

  /// Only TTS; pronunciation packs are not consulted.
  ttsOnly,
}

/// What actually produced (or failed to produce) a pronunciation.
enum PronunciationResult {
  /// A pronunciation pack entry was played.
  pack,

  /// TTS spoke the word.
  tts,

  /// Nothing could be played (no pack match, and TTS unavailable or
  /// disabled by the pronunciation mode).
  unavailable,
}
