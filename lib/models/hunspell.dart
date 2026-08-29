enum HunspellLookupMode {
  /// Only use stems when the original word is absent from a dictionary.
  fallback,

  /// Add stems even when the original word exists.
  supplement,
}

class HunspellSourceInfo {
  final int id;
  final String name;
  final String affPath;
  final String dicPath;
  final String? language;
  final bool enabled;
  final int order;

  const HunspellSourceInfo({
    required this.id,
    required this.name,
    required this.affPath,
    required this.dicPath,
    required this.language,
    required this.enabled,
    required this.order,
  });
}
