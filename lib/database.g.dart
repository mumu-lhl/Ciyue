// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $WordbookTable extends Wordbook
    with drift.TableInfo<$WordbookTable, WordbookData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordbookTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _wordMeta =
      const drift.VerificationMeta('word');
  @override
  late final drift.GeneratedColumn<String> word = drift.GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [word];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wordbook';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<WordbookData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word')) {
      context.handle(
          _wordMeta, word.isAcceptableOrUnknown(data['word']!, _wordMeta));
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  WordbookData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordbookData(
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
    );
  }

  @override
  $WordbookTable createAlias(String alias) {
    return $WordbookTable(attachedDatabase, alias);
  }
}

class WordbookData extends drift.DataClass
    implements drift.Insertable<WordbookData> {
  final String word;
  const WordbookData({required this.word});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['word'] = drift.Variable<String>(word);
    return map;
  }

  WordbookCompanion toCompanion(bool nullToAbsent) {
    return WordbookCompanion(
      word: drift.Value(word),
    );
  }

  factory WordbookData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return WordbookData(
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
    };
  }

  WordbookData copyWith({String? word}) => WordbookData(
        word: word ?? this.word,
      );
  WordbookData copyWithCompanion(WordbookCompanion data) {
    return WordbookData(
      word: data.word.present ? data.word.value : this.word,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordbookData(')
          ..write('word: $word')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => word.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordbookData && other.word == this.word);
}

class WordbookCompanion extends drift.UpdateCompanion<WordbookData> {
  final drift.Value<String> word;
  final drift.Value<int> rowid;
  const WordbookCompanion({
    this.word = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  WordbookCompanion.insert({
    required String word,
    this.rowid = const drift.Value.absent(),
  }) : word = drift.Value(word);
  static drift.Insertable<WordbookData> custom({
    drift.Expression<String>? word,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (word != null) 'word': word,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordbookCompanion copyWith(
      {drift.Value<String>? word, drift.Value<int>? rowid}) {
    return WordbookCompanion(
      word: word ?? this.word,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (word.present) {
      map['word'] = drift.Variable<String>(word.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordbookCompanion(')
          ..write('word: $word, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ResourceTable extends Resource
    with drift.TableInfo<$ResourceTable, ResourceData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _keyMeta =
      const drift.VerificationMeta('key');
  @override
  late final drift.GeneratedColumn<String> key = drift.GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _blockOffsetMeta =
      const drift.VerificationMeta('blockOffset');
  @override
  late final drift.GeneratedColumn<int> blockOffset =
      drift.GeneratedColumn<int>('block_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _startOffsetMeta =
      const drift.VerificationMeta('startOffset');
  @override
  late final drift.GeneratedColumn<int> startOffset =
      drift.GeneratedColumn<int>('start_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _endOffsetMeta =
      const drift.VerificationMeta('endOffset');
  @override
  late final drift.GeneratedColumn<int> endOffset = drift.GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _compressedSizeMeta =
      const drift.VerificationMeta('compressedSize');
  @override
  late final drift.GeneratedColumn<int> compressedSize =
      drift.GeneratedColumn<int>('compressed_size', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [key, blockOffset, startOffset, endOffset, compressedSize];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<ResourceData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('block_offset')) {
      context.handle(
          _blockOffsetMeta,
          blockOffset.isAcceptableOrUnknown(
              data['block_offset']!, _blockOffsetMeta));
    } else if (isInserting) {
      context.missing(_blockOffsetMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
          _startOffsetMeta,
          startOffset.isAcceptableOrUnknown(
              data['start_offset']!, _startOffsetMeta));
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(_endOffsetMeta,
          endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta));
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('compressed_size')) {
      context.handle(
          _compressedSizeMeta,
          compressedSize.isAcceptableOrUnknown(
              data['compressed_size']!, _compressedSizeMeta));
    } else if (isInserting) {
      context.missing(_compressedSizeMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  ResourceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      blockOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block_offset'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      compressedSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}compressed_size'])!,
    );
  }

  @override
  $ResourceTable createAlias(String alias) {
    return $ResourceTable(attachedDatabase, alias);
  }
}

class ResourceData extends drift.DataClass
    implements drift.Insertable<ResourceData> {
  final String key;
  final int blockOffset;
  final int startOffset;
  final int endOffset;
  final int compressedSize;
  const ResourceData(
      {required this.key,
      required this.blockOffset,
      required this.startOffset,
      required this.endOffset,
      required this.compressedSize});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['key'] = drift.Variable<String>(key);
    map['block_offset'] = drift.Variable<int>(blockOffset);
    map['start_offset'] = drift.Variable<int>(startOffset);
    map['end_offset'] = drift.Variable<int>(endOffset);
    map['compressed_size'] = drift.Variable<int>(compressedSize);
    return map;
  }

  ResourceCompanion toCompanion(bool nullToAbsent) {
    return ResourceCompanion(
      key: drift.Value(key),
      blockOffset: drift.Value(blockOffset),
      startOffset: drift.Value(startOffset),
      endOffset: drift.Value(endOffset),
      compressedSize: drift.Value(compressedSize),
    );
  }

  factory ResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return ResourceData(
      key: serializer.fromJson<String>(json['key']),
      blockOffset: serializer.fromJson<int>(json['blockOffset']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      compressedSize: serializer.fromJson<int>(json['compressedSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'blockOffset': serializer.toJson<int>(blockOffset),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'compressedSize': serializer.toJson<int>(compressedSize),
    };
  }

  ResourceData copyWith(
          {String? key,
          int? blockOffset,
          int? startOffset,
          int? endOffset,
          int? compressedSize}) =>
      ResourceData(
        key: key ?? this.key,
        blockOffset: blockOffset ?? this.blockOffset,
        startOffset: startOffset ?? this.startOffset,
        endOffset: endOffset ?? this.endOffset,
        compressedSize: compressedSize ?? this.compressedSize,
      );
  ResourceData copyWithCompanion(ResourceCompanion data) {
    return ResourceData(
      key: data.key.present ? data.key.value : this.key,
      blockOffset:
          data.blockOffset.present ? data.blockOffset.value : this.blockOffset,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      compressedSize: data.compressedSize.present
          ? data.compressedSize.value
          : this.compressedSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceData(')
          ..write('key: $key, ')
          ..write('blockOffset: $blockOffset, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('compressedSize: $compressedSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, blockOffset, startOffset, endOffset, compressedSize);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceData &&
          other.key == this.key &&
          other.blockOffset == this.blockOffset &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.compressedSize == this.compressedSize);
}

class ResourceCompanion extends drift.UpdateCompanion<ResourceData> {
  final drift.Value<String> key;
  final drift.Value<int> blockOffset;
  final drift.Value<int> startOffset;
  final drift.Value<int> endOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> rowid;
  const ResourceCompanion({
    this.key = const drift.Value.absent(),
    this.blockOffset = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  ResourceCompanion.insert({
    required String key,
    required int blockOffset,
    required int startOffset,
    required int endOffset,
    required int compressedSize,
    this.rowid = const drift.Value.absent(),
  })  : key = drift.Value(key),
        blockOffset = drift.Value(blockOffset),
        startOffset = drift.Value(startOffset),
        endOffset = drift.Value(endOffset),
        compressedSize = drift.Value(compressedSize);
  static drift.Insertable<ResourceData> custom({
    drift.Expression<String>? key,
    drift.Expression<int>? blockOffset,
    drift.Expression<int>? startOffset,
    drift.Expression<int>? endOffset,
    drift.Expression<int>? compressedSize,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (key != null) 'key': key,
      if (blockOffset != null) 'block_offset': blockOffset,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceCompanion copyWith(
      {drift.Value<String>? key,
      drift.Value<int>? blockOffset,
      drift.Value<int>? startOffset,
      drift.Value<int>? endOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? rowid}) {
    return ResourceCompanion(
      key: key ?? this.key,
      blockOffset: blockOffset ?? this.blockOffset,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      compressedSize: compressedSize ?? this.compressedSize,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (key.present) {
      map['key'] = drift.Variable<String>(key.value);
    }
    if (blockOffset.present) {
      map['block_offset'] = drift.Variable<int>(blockOffset.value);
    }
    if (startOffset.present) {
      map['start_offset'] = drift.Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = drift.Variable<int>(endOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = drift.Variable<int>(compressedSize.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceCompanion(')
          ..write('key: $key, ')
          ..write('blockOffset: $blockOffset, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DictionaryTable extends Dictionary
    with drift.TableInfo<$DictionaryTable, DictionaryData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _keyMeta =
      const drift.VerificationMeta('key');
  @override
  late final drift.GeneratedColumn<String> key = drift.GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _blockOffsetMeta =
      const drift.VerificationMeta('blockOffset');
  @override
  late final drift.GeneratedColumn<int> blockOffset =
      drift.GeneratedColumn<int>('block_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _startOffsetMeta =
      const drift.VerificationMeta('startOffset');
  @override
  late final drift.GeneratedColumn<int> startOffset =
      drift.GeneratedColumn<int>('start_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _endOffsetMeta =
      const drift.VerificationMeta('endOffset');
  @override
  late final drift.GeneratedColumn<int> endOffset = drift.GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _compressedSizeMeta =
      const drift.VerificationMeta('compressedSize');
  @override
  late final drift.GeneratedColumn<int> compressedSize =
      drift.GeneratedColumn<int>('compressed_size', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [key, blockOffset, startOffset, endOffset, compressedSize];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<DictionaryData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('block_offset')) {
      context.handle(
          _blockOffsetMeta,
          blockOffset.isAcceptableOrUnknown(
              data['block_offset']!, _blockOffsetMeta));
    } else if (isInserting) {
      context.missing(_blockOffsetMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
          _startOffsetMeta,
          startOffset.isAcceptableOrUnknown(
              data['start_offset']!, _startOffsetMeta));
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(_endOffsetMeta,
          endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta));
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('compressed_size')) {
      context.handle(
          _compressedSizeMeta,
          compressedSize.isAcceptableOrUnknown(
              data['compressed_size']!, _compressedSizeMeta));
    } else if (isInserting) {
      context.missing(_compressedSizeMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  DictionaryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      blockOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block_offset'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      compressedSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}compressed_size'])!,
    );
  }

  @override
  $DictionaryTable createAlias(String alias) {
    return $DictionaryTable(attachedDatabase, alias);
  }
}

class DictionaryData extends drift.DataClass
    implements drift.Insertable<DictionaryData> {
  final String key;
  final int blockOffset;
  final int startOffset;
  final int endOffset;
  final int compressedSize;
  const DictionaryData(
      {required this.key,
      required this.blockOffset,
      required this.startOffset,
      required this.endOffset,
      required this.compressedSize});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['key'] = drift.Variable<String>(key);
    map['block_offset'] = drift.Variable<int>(blockOffset);
    map['start_offset'] = drift.Variable<int>(startOffset);
    map['end_offset'] = drift.Variable<int>(endOffset);
    map['compressed_size'] = drift.Variable<int>(compressedSize);
    return map;
  }

  DictionaryCompanion toCompanion(bool nullToAbsent) {
    return DictionaryCompanion(
      key: drift.Value(key),
      blockOffset: drift.Value(blockOffset),
      startOffset: drift.Value(startOffset),
      endOffset: drift.Value(endOffset),
      compressedSize: drift.Value(compressedSize),
    );
  }

  factory DictionaryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryData(
      key: serializer.fromJson<String>(json['key']),
      blockOffset: serializer.fromJson<int>(json['blockOffset']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      compressedSize: serializer.fromJson<int>(json['compressedSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'blockOffset': serializer.toJson<int>(blockOffset),
      'startOffset': serializer.toJson<int>(startOffset),
      'endOffset': serializer.toJson<int>(endOffset),
      'compressedSize': serializer.toJson<int>(compressedSize),
    };
  }

  DictionaryData copyWith(
          {String? key,
          int? blockOffset,
          int? startOffset,
          int? endOffset,
          int? compressedSize}) =>
      DictionaryData(
        key: key ?? this.key,
        blockOffset: blockOffset ?? this.blockOffset,
        startOffset: startOffset ?? this.startOffset,
        endOffset: endOffset ?? this.endOffset,
        compressedSize: compressedSize ?? this.compressedSize,
      );
  DictionaryData copyWithCompanion(DictionaryCompanion data) {
    return DictionaryData(
      key: data.key.present ? data.key.value : this.key,
      blockOffset:
          data.blockOffset.present ? data.blockOffset.value : this.blockOffset,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      compressedSize: data.compressedSize.present
          ? data.compressedSize.value
          : this.compressedSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryData(')
          ..write('key: $key, ')
          ..write('blockOffset: $blockOffset, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('compressedSize: $compressedSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(key, blockOffset, startOffset, endOffset, compressedSize);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryData &&
          other.key == this.key &&
          other.blockOffset == this.blockOffset &&
          other.startOffset == this.startOffset &&
          other.endOffset == this.endOffset &&
          other.compressedSize == this.compressedSize);
}

class DictionaryCompanion extends drift.UpdateCompanion<DictionaryData> {
  final drift.Value<String> key;
  final drift.Value<int> blockOffset;
  final drift.Value<int> startOffset;
  final drift.Value<int> endOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> rowid;
  const DictionaryCompanion({
    this.key = const drift.Value.absent(),
    this.blockOffset = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  DictionaryCompanion.insert({
    required String key,
    required int blockOffset,
    required int startOffset,
    required int endOffset,
    required int compressedSize,
    this.rowid = const drift.Value.absent(),
  })  : key = drift.Value(key),
        blockOffset = drift.Value(blockOffset),
        startOffset = drift.Value(startOffset),
        endOffset = drift.Value(endOffset),
        compressedSize = drift.Value(compressedSize);
  static drift.Insertable<DictionaryData> custom({
    drift.Expression<String>? key,
    drift.Expression<int>? blockOffset,
    drift.Expression<int>? startOffset,
    drift.Expression<int>? endOffset,
    drift.Expression<int>? compressedSize,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (key != null) 'key': key,
      if (blockOffset != null) 'block_offset': blockOffset,
      if (startOffset != null) 'start_offset': startOffset,
      if (endOffset != null) 'end_offset': endOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryCompanion copyWith(
      {drift.Value<String>? key,
      drift.Value<int>? blockOffset,
      drift.Value<int>? startOffset,
      drift.Value<int>? endOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? rowid}) {
    return DictionaryCompanion(
      key: key ?? this.key,
      blockOffset: blockOffset ?? this.blockOffset,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      compressedSize: compressedSize ?? this.compressedSize,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (key.present) {
      map['key'] = drift.Variable<String>(key.value);
    }
    if (blockOffset.present) {
      map['block_offset'] = drift.Variable<int>(blockOffset.value);
    }
    if (startOffset.present) {
      map['start_offset'] = drift.Variable<int>(startOffset.value);
    }
    if (endOffset.present) {
      map['end_offset'] = drift.Variable<int>(endOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = drift.Variable<int>(compressedSize.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryCompanion(')
          ..write('key: $key, ')
          ..write('blockOffset: $blockOffset, ')
          ..write('startOffset: $startOffset, ')
          ..write('endOffset: $endOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DictionaryDatabase extends drift.GeneratedDatabase {
  _$DictionaryDatabase(QueryExecutor e) : super(e);
  $DictionaryDatabaseManager get managers => $DictionaryDatabaseManager(this);
  late final $WordbookTable wordbook = $WordbookTable(this);
  late final $ResourceTable resource = $ResourceTable(this);
  late final $DictionaryTable dictionary = $DictionaryTable(this);
  late final Index idxWordbook = drift.Index(
      'idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  late final Index idxData =
      drift.Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  late final Index idxWord =
      drift.Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities =>
      [wordbook, resource, dictionary, idxWordbook, idxData, idxWord];
}

typedef $$WordbookTableCreateCompanionBuilder = WordbookCompanion Function({
  required String word,
  drift.Value<int> rowid,
});
typedef $$WordbookTableUpdateCompanionBuilder = WordbookCompanion Function({
  drift.Value<String> word,
  drift.Value<int> rowid,
});

class $$WordbookTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $WordbookTable,
    WordbookData,
    $$WordbookTableFilterComposer,
    $$WordbookTableOrderingComposer,
    $$WordbookTableCreateCompanionBuilder,
    $$WordbookTableUpdateCompanionBuilder> {
  $$WordbookTableTableManager(_$DictionaryDatabase db, $WordbookTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$WordbookTableFilterComposer(drift.ComposerState(db, table)),
          orderingComposer:
              $$WordbookTableOrderingComposer(drift.ComposerState(db, table)),
          updateCompanionCallback: ({
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion(
            word: word,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String word,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion.insert(
            word: word,
            rowid: rowid,
          ),
        ));
}

class $$WordbookTableFilterComposer
    extends drift.FilterComposer<_$DictionaryDatabase, $WordbookTable> {
  $$WordbookTableFilterComposer(super.$state);
  drift.ColumnFilters<String> get word => $state.composableBuilder(
      column: $state.table.word,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$WordbookTableOrderingComposer
    extends drift.OrderingComposer<_$DictionaryDatabase, $WordbookTable> {
  $$WordbookTableOrderingComposer(super.$state);
  drift.ColumnOrderings<String> get word => $state.composableBuilder(
      column: $state.table.word,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ResourceTableCreateCompanionBuilder = ResourceCompanion Function({
  required String key,
  required int blockOffset,
  required int startOffset,
  required int endOffset,
  required int compressedSize,
  drift.Value<int> rowid,
});
typedef $$ResourceTableUpdateCompanionBuilder = ResourceCompanion Function({
  drift.Value<String> key,
  drift.Value<int> blockOffset,
  drift.Value<int> startOffset,
  drift.Value<int> endOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> rowid,
});

class $$ResourceTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $ResourceTable,
    ResourceData,
    $$ResourceTableFilterComposer,
    $$ResourceTableOrderingComposer,
    $$ResourceTableCreateCompanionBuilder,
    $$ResourceTableUpdateCompanionBuilder> {
  $$ResourceTableTableManager(_$DictionaryDatabase db, $ResourceTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ResourceTableFilterComposer(drift.ComposerState(db, table)),
          orderingComposer:
              $$ResourceTableOrderingComposer(drift.ComposerState(db, table)),
          updateCompanionCallback: ({
            drift.Value<String> key = const drift.Value.absent(),
            drift.Value<int> blockOffset = const drift.Value.absent(),
            drift.Value<int> startOffset = const drift.Value.absent(),
            drift.Value<int> endOffset = const drift.Value.absent(),
            drift.Value<int> compressedSize = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              ResourceCompanion(
            key: key,
            blockOffset: blockOffset,
            startOffset: startOffset,
            endOffset: endOffset,
            compressedSize: compressedSize,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required int blockOffset,
            required int startOffset,
            required int endOffset,
            required int compressedSize,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              ResourceCompanion.insert(
            key: key,
            blockOffset: blockOffset,
            startOffset: startOffset,
            endOffset: endOffset,
            compressedSize: compressedSize,
            rowid: rowid,
          ),
        ));
}

class $$ResourceTableFilterComposer
    extends drift.FilterComposer<_$DictionaryDatabase, $ResourceTable> {
  $$ResourceTableFilterComposer(super.$state);
  drift.ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get blockOffset => $state.composableBuilder(
      column: $state.table.blockOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get startOffset => $state.composableBuilder(
      column: $state.table.startOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get endOffset => $state.composableBuilder(
      column: $state.table.endOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get compressedSize => $state.composableBuilder(
      column: $state.table.compressedSize,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ResourceTableOrderingComposer
    extends drift.OrderingComposer<_$DictionaryDatabase, $ResourceTable> {
  $$ResourceTableOrderingComposer(super.$state);
  drift.ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get blockOffset => $state.composableBuilder(
      column: $state.table.blockOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get startOffset => $state.composableBuilder(
      column: $state.table.startOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get endOffset => $state.composableBuilder(
      column: $state.table.endOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get compressedSize => $state.composableBuilder(
      column: $state.table.compressedSize,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$DictionaryTableCreateCompanionBuilder = DictionaryCompanion Function({
  required String key,
  required int blockOffset,
  required int startOffset,
  required int endOffset,
  required int compressedSize,
  drift.Value<int> rowid,
});
typedef $$DictionaryTableUpdateCompanionBuilder = DictionaryCompanion Function({
  drift.Value<String> key,
  drift.Value<int> blockOffset,
  drift.Value<int> startOffset,
  drift.Value<int> endOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> rowid,
});

class $$DictionaryTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $DictionaryTable,
    DictionaryData,
    $$DictionaryTableFilterComposer,
    $$DictionaryTableOrderingComposer,
    $$DictionaryTableCreateCompanionBuilder,
    $$DictionaryTableUpdateCompanionBuilder> {
  $$DictionaryTableTableManager(_$DictionaryDatabase db, $DictionaryTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$DictionaryTableFilterComposer(drift.ComposerState(db, table)),
          orderingComposer:
              $$DictionaryTableOrderingComposer(drift.ComposerState(db, table)),
          updateCompanionCallback: ({
            drift.Value<String> key = const drift.Value.absent(),
            drift.Value<int> blockOffset = const drift.Value.absent(),
            drift.Value<int> startOffset = const drift.Value.absent(),
            drift.Value<int> endOffset = const drift.Value.absent(),
            drift.Value<int> compressedSize = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              DictionaryCompanion(
            key: key,
            blockOffset: blockOffset,
            startOffset: startOffset,
            endOffset: endOffset,
            compressedSize: compressedSize,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required int blockOffset,
            required int startOffset,
            required int endOffset,
            required int compressedSize,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              DictionaryCompanion.insert(
            key: key,
            blockOffset: blockOffset,
            startOffset: startOffset,
            endOffset: endOffset,
            compressedSize: compressedSize,
            rowid: rowid,
          ),
        ));
}

class $$DictionaryTableFilterComposer
    extends drift.FilterComposer<_$DictionaryDatabase, $DictionaryTable> {
  $$DictionaryTableFilterComposer(super.$state);
  drift.ColumnFilters<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get blockOffset => $state.composableBuilder(
      column: $state.table.blockOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get startOffset => $state.composableBuilder(
      column: $state.table.startOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get endOffset => $state.composableBuilder(
      column: $state.table.endOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<int> get compressedSize => $state.composableBuilder(
      column: $state.table.compressedSize,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$DictionaryTableOrderingComposer
    extends drift.OrderingComposer<_$DictionaryDatabase, $DictionaryTable> {
  $$DictionaryTableOrderingComposer(super.$state);
  drift.ColumnOrderings<String> get key => $state.composableBuilder(
      column: $state.table.key,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get blockOffset => $state.composableBuilder(
      column: $state.table.blockOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get startOffset => $state.composableBuilder(
      column: $state.table.startOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get endOffset => $state.composableBuilder(
      column: $state.table.endOffset,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<int> get compressedSize => $state.composableBuilder(
      column: $state.table.compressedSize,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $DictionaryDatabaseManager {
  final _$DictionaryDatabase _db;
  $DictionaryDatabaseManager(this._db);
  $$WordbookTableTableManager get wordbook =>
      $$WordbookTableTableManager(_db, _db.wordbook);
  $$ResourceTableTableManager get resource =>
      $$ResourceTableTableManager(_db, _db.resource);
  $$DictionaryTableTableManager get dictionary =>
      $$DictionaryTableTableManager(_db, _db.dictionary);
}

class $DictionaryListTable extends DictionaryList
    with drift.TableInfo<$DictionaryListTable, DictionaryListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryListTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _idMeta =
      const drift.VerificationMeta('id');
  @override
  late final drift.GeneratedColumn<int> id = drift.GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const drift.VerificationMeta _pathMeta =
      const drift.VerificationMeta('path');
  @override
  late final drift.GeneratedColumn<String> path = drift.GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [id, path];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_list';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<DictionaryListData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
  @override
  DictionaryListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryListData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
    );
  }

  @override
  $DictionaryListTable createAlias(String alias) {
    return $DictionaryListTable(attachedDatabase, alias);
  }
}

class DictionaryListData extends drift.DataClass
    implements drift.Insertable<DictionaryListData> {
  final int id;
  final String path;
  const DictionaryListData({required this.id, required this.path});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['path'] = drift.Variable<String>(path);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      id: drift.Value(id),
      path: drift.Value(path),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  DictionaryListData copyWith({int? id, String? path}) => DictionaryListData(
        id: id ?? this.id,
        path: path ?? this.path,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.id == this.id &&
          other.path == this.path);
}

class DictionaryListCompanion
    extends drift.UpdateCompanion<DictionaryListData> {
  final drift.Value<int> id;
  final drift.Value<String> path;
  const DictionaryListCompanion({
    this.id = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.id = const drift.Value.absent(),
    required String path,
  }) : path = drift.Value(path);
  static drift.Insertable<DictionaryListData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? path,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  DictionaryListCompanion copyWith(
      {drift.Value<int>? id, drift.Value<String>? path}) {
    return DictionaryListCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = drift.Variable<String>(path.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends drift.GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DictionaryListTable dictionaryList = $DictionaryListTable(this);
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities => [dictionaryList];
}

typedef $$DictionaryListTableCreateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<int> id,
  required String path,
});
typedef $$DictionaryListTableUpdateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<int> id,
  drift.Value<String> path,
});

class $$DictionaryListTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $DictionaryListTable,
    DictionaryListData,
    $$DictionaryListTableFilterComposer,
    $$DictionaryListTableOrderingComposer,
    $$DictionaryListTableCreateCompanionBuilder,
    $$DictionaryListTableUpdateCompanionBuilder> {
  $$DictionaryListTableTableManager(
      _$AppDatabase db, $DictionaryListTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          filteringComposer: $$DictionaryListTableFilterComposer(
              drift.ComposerState(db, table)),
          orderingComposer: $$DictionaryListTableOrderingComposer(
              drift.ComposerState(db, table)),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion(
            id: id,
            path: path,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String path,
          }) =>
              DictionaryListCompanion.insert(
            id: id,
            path: path,
          ),
        ));
}

class $$DictionaryListTableFilterComposer
    extends drift.FilterComposer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableFilterComposer(super.$state);
  drift.ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$DictionaryListTableOrderingComposer
    extends drift.OrderingComposer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableOrderingComposer(super.$state);
  drift.ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DictionaryListTableTableManager get dictionaryList =>
      $$DictionaryListTableTableManager(_db, _db.dictionaryList);
}
