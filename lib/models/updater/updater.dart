import "package:freezed_annotation/freezed_annotation.dart";

part "updater.freezed.dart";

@freezed
abstract class Update with _$Update {
  const factory Update(
      {required bool success,
      required bool isUpdateAvailable,
      required String version}) = _Update;
}
