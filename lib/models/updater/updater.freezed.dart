// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'updater.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Update {
  bool get success;
  bool get isUpdateAvailable;
  String get version;

  /// Create a copy of Update
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UpdateCopyWith<Update> get copyWith =>
      _$UpdateCopyWithImpl<Update>(this as Update, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Update &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.isUpdateAvailable, isUpdateAvailable) ||
                other.isUpdateAvailable == isUpdateAvailable) &&
            (identical(other.version, version) || other.version == version));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, success, isUpdateAvailable, version);

  @override
  String toString() {
    return 'Update(success: $success, isUpdateAvailable: $isUpdateAvailable, version: $version)';
  }
}

/// @nodoc
abstract mixin class $UpdateCopyWith<$Res> {
  factory $UpdateCopyWith(Update value, $Res Function(Update) _then) =
      _$UpdateCopyWithImpl;
  @useResult
  $Res call({bool success, bool isUpdateAvailable, String version});
}

/// @nodoc
class _$UpdateCopyWithImpl<$Res> implements $UpdateCopyWith<$Res> {
  _$UpdateCopyWithImpl(this._self, this._then);

  final Update _self;
  final $Res Function(Update) _then;

  /// Create a copy of Update
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? success = null,
    Object? isUpdateAvailable = null,
    Object? version = null,
  }) {
    return _then(_self.copyWith(
      success: null == success
          ? _self.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      isUpdateAvailable: null == isUpdateAvailable
          ? _self.isUpdateAvailable
          : isUpdateAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _Update implements Update {
  const _Update(
      {required this.success,
      required this.isUpdateAvailable,
      required this.version});

  @override
  final bool success;
  @override
  final bool isUpdateAvailable;
  @override
  final String version;

  /// Create a copy of Update
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UpdateCopyWith<_Update> get copyWith =>
      __$UpdateCopyWithImpl<_Update>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Update &&
            (identical(other.success, success) || other.success == success) &&
            (identical(other.isUpdateAvailable, isUpdateAvailable) ||
                other.isUpdateAvailable == isUpdateAvailable) &&
            (identical(other.version, version) || other.version == version));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, success, isUpdateAvailable, version);

  @override
  String toString() {
    return 'Update(success: $success, isUpdateAvailable: $isUpdateAvailable, version: $version)';
  }
}

/// @nodoc
abstract mixin class _$UpdateCopyWith<$Res> implements $UpdateCopyWith<$Res> {
  factory _$UpdateCopyWith(_Update value, $Res Function(_Update) _then) =
      __$UpdateCopyWithImpl;
  @override
  @useResult
  $Res call({bool success, bool isUpdateAvailable, String version});
}

/// @nodoc
class __$UpdateCopyWithImpl<$Res> implements _$UpdateCopyWith<$Res> {
  __$UpdateCopyWithImpl(this._self, this._then);

  final _Update _self;
  final $Res Function(_Update) _then;

  /// Create a copy of Update
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? success = null,
    Object? isUpdateAvailable = null,
    Object? version = null,
  }) {
    return _then(_Update(
      success: null == success
          ? _self.success
          : success // ignore: cast_nullable_to_non_nullable
              as bool,
      isUpdateAvailable: null == isUpdateAvailable
          ? _self.isUpdateAvailable
          : isUpdateAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      version: null == version
          ? _self.version
          : version // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
