// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ModelInfo {
  String get originName;
  String get shownName;

  /// Create a copy of ModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ModelInfoCopyWith<ModelInfo> get copyWith =>
      _$ModelInfoCopyWithImpl<ModelInfo>(this as ModelInfo, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ModelInfo &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.shownName, shownName) ||
                other.shownName == shownName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, originName, shownName);

  @override
  String toString() {
    return 'ModelInfo(originName: $originName, shownName: $shownName)';
  }
}

/// @nodoc
abstract mixin class $ModelInfoCopyWith<$Res> {
  factory $ModelInfoCopyWith(ModelInfo value, $Res Function(ModelInfo) _then) =
      _$ModelInfoCopyWithImpl;
  @useResult
  $Res call({String originName, String shownName});
}

/// @nodoc
class _$ModelInfoCopyWithImpl<$Res> implements $ModelInfoCopyWith<$Res> {
  _$ModelInfoCopyWithImpl(this._self, this._then);

  final ModelInfo _self;
  final $Res Function(ModelInfo) _then;

  /// Create a copy of ModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? originName = null,
    Object? shownName = null,
  }) {
    return _then(_self.copyWith(
      originName: null == originName
          ? _self.originName
          : originName // ignore: cast_nullable_to_non_nullable
              as String,
      shownName: null == shownName
          ? _self.shownName
          : shownName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [ModelInfo].
extension ModelInfoPatterns on ModelInfo {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ModelInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ModelInfo() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ModelInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelInfo():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ModelInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelInfo() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(String originName, String shownName)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ModelInfo() when $default != null:
        return $default(_that.originName, _that.shownName);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(String originName, String shownName) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelInfo():
        return $default(_that.originName, _that.shownName);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(String originName, String shownName)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelInfo() when $default != null:
        return $default(_that.originName, _that.shownName);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ModelInfo implements ModelInfo {
  const _ModelInfo(this.originName, this.shownName);

  @override
  final String originName;
  @override
  final String shownName;

  /// Create a copy of ModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ModelInfoCopyWith<_ModelInfo> get copyWith =>
      __$ModelInfoCopyWithImpl<_ModelInfo>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ModelInfo &&
            (identical(other.originName, originName) ||
                other.originName == originName) &&
            (identical(other.shownName, shownName) ||
                other.shownName == shownName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, originName, shownName);

  @override
  String toString() {
    return 'ModelInfo(originName: $originName, shownName: $shownName)';
  }
}

/// @nodoc
abstract mixin class _$ModelInfoCopyWith<$Res>
    implements $ModelInfoCopyWith<$Res> {
  factory _$ModelInfoCopyWith(
          _ModelInfo value, $Res Function(_ModelInfo) _then) =
      __$ModelInfoCopyWithImpl;
  @override
  @useResult
  $Res call({String originName, String shownName});
}

/// @nodoc
class __$ModelInfoCopyWithImpl<$Res> implements _$ModelInfoCopyWith<$Res> {
  __$ModelInfoCopyWithImpl(this._self, this._then);

  final _ModelInfo _self;
  final $Res Function(_ModelInfo) _then;

  /// Create a copy of ModelInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? originName = null,
    Object? shownName = null,
  }) {
    return _then(_ModelInfo(
      null == originName
          ? _self.originName
          : originName // ignore: cast_nullable_to_non_nullable
              as String,
      null == shownName
          ? _self.shownName
          : shownName // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$ModelProvider {
  String get name;
  String get displayedName;
  String get apiUrl;
  List<ModelInfo> get models;
  bool get allowCustomModel;
  bool get allowCustomAPIUrl;

  /// Create a copy of ModelProvider
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ModelProviderCopyWith<ModelProvider> get copyWith =>
      _$ModelProviderCopyWithImpl<ModelProvider>(
          this as ModelProvider, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ModelProvider &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayedName, displayedName) ||
                other.displayedName == displayedName) &&
            (identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl) &&
            const DeepCollectionEquality().equals(other.models, models) &&
            (identical(other.allowCustomModel, allowCustomModel) ||
                other.allowCustomModel == allowCustomModel) &&
            (identical(other.allowCustomAPIUrl, allowCustomAPIUrl) ||
                other.allowCustomAPIUrl == allowCustomAPIUrl));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      displayedName,
      apiUrl,
      const DeepCollectionEquality().hash(models),
      allowCustomModel,
      allowCustomAPIUrl);

  @override
  String toString() {
    return 'ModelProvider(name: $name, displayedName: $displayedName, apiUrl: $apiUrl, models: $models, allowCustomModel: $allowCustomModel, allowCustomAPIUrl: $allowCustomAPIUrl)';
  }
}

/// @nodoc
abstract mixin class $ModelProviderCopyWith<$Res> {
  factory $ModelProviderCopyWith(
          ModelProvider value, $Res Function(ModelProvider) _then) =
      _$ModelProviderCopyWithImpl;
  @useResult
  $Res call(
      {String name,
      String displayedName,
      String apiUrl,
      List<ModelInfo> models,
      bool allowCustomModel,
      bool allowCustomAPIUrl});
}

/// @nodoc
class _$ModelProviderCopyWithImpl<$Res>
    implements $ModelProviderCopyWith<$Res> {
  _$ModelProviderCopyWithImpl(this._self, this._then);

  final ModelProvider _self;
  final $Res Function(ModelProvider) _then;

  /// Create a copy of ModelProvider
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? displayedName = null,
    Object? apiUrl = null,
    Object? models = null,
    Object? allowCustomModel = null,
    Object? allowCustomAPIUrl = null,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayedName: null == displayedName
          ? _self.displayedName
          : displayedName // ignore: cast_nullable_to_non_nullable
              as String,
      apiUrl: null == apiUrl
          ? _self.apiUrl
          : apiUrl // ignore: cast_nullable_to_non_nullable
              as String,
      models: null == models
          ? _self.models
          : models // ignore: cast_nullable_to_non_nullable
              as List<ModelInfo>,
      allowCustomModel: null == allowCustomModel
          ? _self.allowCustomModel
          : allowCustomModel // ignore: cast_nullable_to_non_nullable
              as bool,
      allowCustomAPIUrl: null == allowCustomAPIUrl
          ? _self.allowCustomAPIUrl
          : allowCustomAPIUrl // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [ModelProvider].
extension ModelProviderPatterns on ModelProvider {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ModelProvider value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ModelProvider() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ModelProvider value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelProvider():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ModelProvider value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelProvider() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String name,
            String displayedName,
            String apiUrl,
            List<ModelInfo> models,
            bool allowCustomModel,
            bool allowCustomAPIUrl)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ModelProvider() when $default != null:
        return $default(_that.name, _that.displayedName, _that.apiUrl,
            _that.models, _that.allowCustomModel, _that.allowCustomAPIUrl);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String name,
            String displayedName,
            String apiUrl,
            List<ModelInfo> models,
            bool allowCustomModel,
            bool allowCustomAPIUrl)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelProvider():
        return $default(_that.name, _that.displayedName, _that.apiUrl,
            _that.models, _that.allowCustomModel, _that.allowCustomAPIUrl);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String name,
            String displayedName,
            String apiUrl,
            List<ModelInfo> models,
            bool allowCustomModel,
            bool allowCustomAPIUrl)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ModelProvider() when $default != null:
        return $default(_that.name, _that.displayedName, _that.apiUrl,
            _that.models, _that.allowCustomModel, _that.allowCustomAPIUrl);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ModelProvider implements ModelProvider {
  const _ModelProvider(
      {required this.name,
      required this.displayedName,
      required this.apiUrl,
      required final List<ModelInfo> models,
      this.allowCustomModel = false,
      this.allowCustomAPIUrl = false})
      : _models = models;

  @override
  final String name;
  @override
  final String displayedName;
  @override
  final String apiUrl;
  final List<ModelInfo> _models;
  @override
  List<ModelInfo> get models {
    if (_models is EqualUnmodifiableListView) return _models;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_models);
  }

  @override
  @JsonKey()
  final bool allowCustomModel;
  @override
  @JsonKey()
  final bool allowCustomAPIUrl;

  /// Create a copy of ModelProvider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ModelProviderCopyWith<_ModelProvider> get copyWith =>
      __$ModelProviderCopyWithImpl<_ModelProvider>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ModelProvider &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.displayedName, displayedName) ||
                other.displayedName == displayedName) &&
            (identical(other.apiUrl, apiUrl) || other.apiUrl == apiUrl) &&
            const DeepCollectionEquality().equals(other._models, _models) &&
            (identical(other.allowCustomModel, allowCustomModel) ||
                other.allowCustomModel == allowCustomModel) &&
            (identical(other.allowCustomAPIUrl, allowCustomAPIUrl) ||
                other.allowCustomAPIUrl == allowCustomAPIUrl));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      displayedName,
      apiUrl,
      const DeepCollectionEquality().hash(_models),
      allowCustomModel,
      allowCustomAPIUrl);

  @override
  String toString() {
    return 'ModelProvider(name: $name, displayedName: $displayedName, apiUrl: $apiUrl, models: $models, allowCustomModel: $allowCustomModel, allowCustomAPIUrl: $allowCustomAPIUrl)';
  }
}

/// @nodoc
abstract mixin class _$ModelProviderCopyWith<$Res>
    implements $ModelProviderCopyWith<$Res> {
  factory _$ModelProviderCopyWith(
          _ModelProvider value, $Res Function(_ModelProvider) _then) =
      __$ModelProviderCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String name,
      String displayedName,
      String apiUrl,
      List<ModelInfo> models,
      bool allowCustomModel,
      bool allowCustomAPIUrl});
}

/// @nodoc
class __$ModelProviderCopyWithImpl<$Res>
    implements _$ModelProviderCopyWith<$Res> {
  __$ModelProviderCopyWithImpl(this._self, this._then);

  final _ModelProvider _self;
  final $Res Function(_ModelProvider) _then;

  /// Create a copy of ModelProvider
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? name = null,
    Object? displayedName = null,
    Object? apiUrl = null,
    Object? models = null,
    Object? allowCustomModel = null,
    Object? allowCustomAPIUrl = null,
  }) {
    return _then(_ModelProvider(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      displayedName: null == displayedName
          ? _self.displayedName
          : displayedName // ignore: cast_nullable_to_non_nullable
              as String,
      apiUrl: null == apiUrl
          ? _self.apiUrl
          : apiUrl // ignore: cast_nullable_to_non_nullable
              as String,
      models: null == models
          ? _self._models
          : models // ignore: cast_nullable_to_non_nullable
              as List<ModelInfo>,
      allowCustomModel: null == allowCustomModel
          ? _self.allowCustomModel
          : allowCustomModel // ignore: cast_nullable_to_non_nullable
              as bool,
      allowCustomAPIUrl: null == allowCustomAPIUrl
          ? _self.allowCustomAPIUrl
          : allowCustomAPIUrl // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
