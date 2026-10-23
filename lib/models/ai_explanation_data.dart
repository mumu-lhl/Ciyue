import "dart:convert";

/// One example sentence from a structured AI explanation, with its
/// translation when the model provided one.
class AiExample {
  const AiExample({required this.sentence, this.translation});

  final String sentence;
  final String? translation;
}

/// A word explanation as structured data, produced by the AI with the
/// structured explain prompt and rendered natively instead of as
/// markdown text. Every field is optional: models do not always fill
/// the whole schema, and partial data still renders.
class AiExplanationData {
  const AiExplanationData({
    this.phonetic,
    this.partOfSpeech,
    this.meanings = const [],
    this.examples = const [],
    this.synonyms = const [],
    this.antonyms = const [],
  });

  final String? phonetic;
  final String? partOfSpeech;
  final List<String> meanings;
  final List<AiExample> examples;
  final List<String> synonyms;
  final List<String> antonyms;

  bool get isEmpty =>
      (phonetic == null || phonetic!.isEmpty) &&
      (partOfSpeech == null || partOfSpeech!.isEmpty) &&
      meanings.isEmpty &&
      examples.isEmpty &&
      synonyms.isEmpty &&
      antonyms.isEmpty;

  /// Parses [text] as a structured explanation, tolerating the ways
  /// models actually answer: markdown code fences around the JSON,
  /// prose before or after it, meanings given as objects with a
  /// "definition" field, examples given as plain strings. Returns
  /// null when no usable JSON object is present, so callers can fall
  /// back to rendering the raw text.
  static AiExplanationData? tryParse(String text) {
    final jsonText = _extractJsonObject(text);
    if (jsonText == null) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonText);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) {
      return null;
    }
    final data = AiExplanationData(
      phonetic: _asString(decoded["phonetic"]),
      partOfSpeech: _asString(
        decoded["partOfSpeech"] ?? decoded["part_of_speech"],
      ),
      meanings: _asStringList(
        decoded["meanings"],
        objectKeys: const ["definition", "meaning", "text"],
      ),
      examples: _asExamples(decoded["examples"]),
      synonyms: _asStringList(decoded["synonyms"]),
      antonyms: _asStringList(decoded["antonyms"]),
    );
    return data.isEmpty ? null : data;
  }

  /// Finds the outermost JSON object in [text]: strips a markdown
  /// fence if present, then takes the span from the first "{" to the
  /// last "}".
  static String? _extractJsonObject(String text) {
    var candidate = text.trim();
    final fence = RegExp(r"```(?:json)?\s*([\s\S]*?)```").firstMatch(candidate);
    if (fence != null) {
      candidate = fence.group(1)!.trim();
    }
    final start = candidate.indexOf("{");
    final end = candidate.lastIndexOf("}");
    if (start < 0 || end <= start) {
      return null;
    }
    return candidate.substring(start, end + 1);
  }

  static String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static List<String> _asStringList(
    Object? value, {
    List<String> objectKeys = const [],
  }) {
    if (value is! List) {
      return const [];
    }
    final result = <String>[];
    for (final entry in value) {
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty) {
          result.add(trimmed);
        }
      } else if (entry is Map) {
        for (final key in objectKeys) {
          final inner = _asString(entry[key]);
          if (inner != null) {
            result.add(inner);
            break;
          }
        }
      }
    }
    return result;
  }

  static List<AiExample> _asExamples(Object? value) {
    if (value is! List) {
      return const [];
    }
    final result = <AiExample>[];
    for (final entry in value) {
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty) {
          result.add(AiExample(sentence: trimmed));
        }
      } else if (entry is Map) {
        final sentence = _asString(entry["sentence"] ?? entry["example"]);
        if (sentence != null) {
          result.add(
            AiExample(
              sentence: sentence,
              translation: _asString(entry["translation"]),
            ),
          );
        }
      }
    }
    return result;
  }
}
