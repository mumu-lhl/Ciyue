/// Font families that cover phonetic/IPA characters (U+0250–U+02AF, combining
/// marks) which the default CJK font picked up on Linux does not contain.
///
/// The same list is used for Flutter text and for the dictionary WebViews so a
/// transcription such as `ɡədɪ́çt` does not turn into tofu boxes in either place.
const List<String> ipaFontFallbacks = [
  "DejaVu Sans",
  "Noto Sans",
  "FreeSans",
  "Liberation Sans",
  "Arial Unicode MS",
  "Segoe UI Symbol",
  "Apple Symbols",
];

/// The same chain as a CSS `font-family` value, with a generic last resort.
String get ipaFontFallbackCss =>
    "${ipaFontFallbacks.map((family) => '"$family"').join(", ")}, sans-serif";
