import "package:freezed_annotation/freezed_annotation.dart";

part "ai.freezed.dart";

@freezed
abstract class ModelInfo with _$ModelInfo {
  const factory ModelInfo(
    String originName,
    String shownName,
  ) = _ModelInfo;
}

@freezed
abstract class ModelProvider with _$ModelProvider {
  const factory ModelProvider({
    required String name,
    required String displayedName,
    required String apiUrl,
    required List<ModelInfo> models,
    @Default(false) bool allowCustomModel,
    @Default(false) bool allowCustomAPIUrl,
  }) = _ModelProvider;
}
