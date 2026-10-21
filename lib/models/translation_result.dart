import "package:freezed_annotation/freezed_annotation.dart";

part "translation_result.freezed.dart";

@freezed
abstract class TranslationResult with _$TranslationResult {
  const factory TranslationResult({
    required String text,
    @Default(<String>[]) List<String> alternatives,

    /// Source language the provider detected (app language code),
    /// when the provider reports one and the request was auto-detect.
    String? detectedLanguage,
  }) = _TranslationResult;
}
