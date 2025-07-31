// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary.dart';

// ignore_for_file: type=lint
class $ResourceTable extends Resource
    with drift.TableInfo<$ResourceTable, ResourceData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResourceTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _blockOffsetMeta =
      const drift.VerificationMeta('blockOffset');
  @override
  late final drift.GeneratedColumn<int> blockOffset =
      drift.GeneratedColumn<int>('block_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _compressedSizeMeta =
      const drift.VerificationMeta('compressedSize');
  @override
  late final drift.GeneratedColumn<int> compressedSize =
      drift.GeneratedColumn<int>('compressed_size', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _endOffsetMeta =
      const drift.VerificationMeta('endOffset');
  @override
  late final drift.GeneratedColumn<int> endOffset = drift.GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _keyMeta =
      const drift.VerificationMeta('key');
  @override
  late final drift.GeneratedColumn<String> key = drift.GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _startOffsetMeta =
      const drift.VerificationMeta('startOffset');
  @override
  late final drift.GeneratedColumn<int> startOffset =
      drift.GeneratedColumn<int>('start_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _partMeta =
      const drift.VerificationMeta('part');
  @override
  late final drift.GeneratedColumn<int> part = drift.GeneratedColumn<int>(
      'part', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [blockOffset, compressedSize, endOffset, key, startOffset, part];
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
    if (data.containsKey('block_offset')) {
      context.handle(
          _blockOffsetMeta,
          blockOffset.isAcceptableOrUnknown(
              data['block_offset']!, _blockOffsetMeta));
    } else if (isInserting) {
      context.missing(_blockOffsetMeta);
    }
    if (data.containsKey('compressed_size')) {
      context.handle(
          _compressedSizeMeta,
          compressedSize.isAcceptableOrUnknown(
              data['compressed_size']!, _compressedSizeMeta));
    } else if (isInserting) {
      context.missing(_compressedSizeMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(_endOffsetMeta,
          endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta));
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
          _startOffsetMeta,
          startOffset.isAcceptableOrUnknown(
              data['start_offset']!, _startOffsetMeta));
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('part')) {
      context.handle(
          _partMeta, part.isAcceptableOrUnknown(data['part']!, _partMeta));
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  ResourceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResourceData(
      blockOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block_offset'])!,
      compressedSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}compressed_size'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
      part: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}part']),
    );
  }

  @override
  $ResourceTable createAlias(String alias) {
    return $ResourceTable(attachedDatabase, alias);
  }
}

class ResourceData extends drift.DataClass
    implements drift.Insertable<ResourceData> {
  final int blockOffset;
  final int compressedSize;
  final int endOffset;
  final String key;
  final int startOffset;
  final int? part;
  const ResourceData(
      {required this.blockOffset,
      required this.compressedSize,
      required this.endOffset,
      required this.key,
      required this.startOffset,
      this.part});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['block_offset'] = drift.Variable<int>(blockOffset);
    map['compressed_size'] = drift.Variable<int>(compressedSize);
    map['end_offset'] = drift.Variable<int>(endOffset);
    map['key'] = drift.Variable<String>(key);
    map['start_offset'] = drift.Variable<int>(startOffset);
    if (!nullToAbsent || part != null) {
      map['part'] = drift.Variable<int>(part);
    }
    return map;
  }

  ResourceCompanion toCompanion(bool nullToAbsent) {
    return ResourceCompanion(
      blockOffset: drift.Value(blockOffset),
      compressedSize: drift.Value(compressedSize),
      endOffset: drift.Value(endOffset),
      key: drift.Value(key),
      startOffset: drift.Value(startOffset),
      part: part == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(part),
    );
  }

  factory ResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return ResourceData(
      blockOffset: serializer.fromJson<int>(json['blockOffset']),
      compressedSize: serializer.fromJson<int>(json['compressedSize']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      key: serializer.fromJson<String>(json['key']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
      part: serializer.fromJson<int?>(json['part']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blockOffset': serializer.toJson<int>(blockOffset),
      'compressedSize': serializer.toJson<int>(compressedSize),
      'endOffset': serializer.toJson<int>(endOffset),
      'key': serializer.toJson<String>(key),
      'startOffset': serializer.toJson<int>(startOffset),
      'part': serializer.toJson<int?>(part),
    };
  }

  ResourceData copyWith(
          {int? blockOffset,
          int? compressedSize,
          int? endOffset,
          String? key,
          int? startOffset,
          drift.Value<int?> part = const drift.Value.absent()}) =>
      ResourceData(
        blockOffset: blockOffset ?? this.blockOffset,
        compressedSize: compressedSize ?? this.compressedSize,
        endOffset: endOffset ?? this.endOffset,
        key: key ?? this.key,
        startOffset: startOffset ?? this.startOffset,
        part: part.present ? part.value : this.part,
      );
  ResourceData copyWithCompanion(ResourceCompanion data) {
    return ResourceData(
      blockOffset:
          data.blockOffset.present ? data.blockOffset.value : this.blockOffset,
      compressedSize: data.compressedSize.present
          ? data.compressedSize.value
          : this.compressedSize,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      key: data.key.present ? data.key.value : this.key,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
      part: data.part.present ? data.part.value : this.part,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceData(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('startOffset: $startOffset, ')
          ..write('part: $part')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      blockOffset, compressedSize, endOffset, key, startOffset, part);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResourceData &&
          other.blockOffset == this.blockOffset &&
          other.compressedSize == this.compressedSize &&
          other.endOffset == this.endOffset &&
          other.key == this.key &&
          other.startOffset == this.startOffset &&
          other.part == this.part);
}

class ResourceCompanion extends drift.UpdateCompanion<ResourceData> {
  final drift.Value<int> blockOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> endOffset;
  final drift.Value<String> key;
  final drift.Value<int> startOffset;
  final drift.Value<int?> part;
  final drift.Value<int> rowid;
  const ResourceCompanion({
    this.blockOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.key = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.part = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  ResourceCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int startOffset,
    this.part = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  })  : blockOffset = drift.Value(blockOffset),
        compressedSize = drift.Value(compressedSize),
        endOffset = drift.Value(endOffset),
        key = drift.Value(key),
        startOffset = drift.Value(startOffset);
  static drift.Insertable<ResourceData> custom({
    drift.Expression<int>? blockOffset,
    drift.Expression<int>? compressedSize,
    drift.Expression<int>? endOffset,
    drift.Expression<String>? key,
    drift.Expression<int>? startOffset,
    drift.Expression<int>? part,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (blockOffset != null) 'block_offset': blockOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (endOffset != null) 'end_offset': endOffset,
      if (key != null) 'key': key,
      if (startOffset != null) 'start_offset': startOffset,
      if (part != null) 'part': part,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResourceCompanion copyWith(
      {drift.Value<int>? blockOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? endOffset,
      drift.Value<String>? key,
      drift.Value<int>? startOffset,
      drift.Value<int?>? part,
      drift.Value<int>? rowid}) {
    return ResourceCompanion(
      blockOffset: blockOffset ?? this.blockOffset,
      compressedSize: compressedSize ?? this.compressedSize,
      endOffset: endOffset ?? this.endOffset,
      key: key ?? this.key,
      startOffset: startOffset ?? this.startOffset,
      part: part ?? this.part,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (blockOffset.present) {
      map['block_offset'] = drift.Variable<int>(blockOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = drift.Variable<int>(compressedSize.value);
    }
    if (endOffset.present) {
      map['end_offset'] = drift.Variable<int>(endOffset.value);
    }
    if (key.present) {
      map['key'] = drift.Variable<String>(key.value);
    }
    if (startOffset.present) {
      map['start_offset'] = drift.Variable<int>(startOffset.value);
    }
    if (part.present) {
      map['part'] = drift.Variable<int>(part.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResourceCompanion(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('startOffset: $startOffset, ')
          ..write('part: $part, ')
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
  static const drift.VerificationMeta _blockOffsetMeta =
      const drift.VerificationMeta('blockOffset');
  @override
  late final drift.GeneratedColumn<int> blockOffset =
      drift.GeneratedColumn<int>('block_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _compressedSizeMeta =
      const drift.VerificationMeta('compressedSize');
  @override
  late final drift.GeneratedColumn<int> compressedSize =
      drift.GeneratedColumn<int>('compressed_size', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _endOffsetMeta =
      const drift.VerificationMeta('endOffset');
  @override
  late final drift.GeneratedColumn<int> endOffset = drift.GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _keyMeta =
      const drift.VerificationMeta('key');
  @override
  late final drift.GeneratedColumn<String> key = drift.GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _startOffsetMeta =
      const drift.VerificationMeta('startOffset');
  @override
  late final drift.GeneratedColumn<int> startOffset =
      drift.GeneratedColumn<int>('start_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [blockOffset, compressedSize, endOffset, key, startOffset];
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
    if (data.containsKey('block_offset')) {
      context.handle(
          _blockOffsetMeta,
          blockOffset.isAcceptableOrUnknown(
              data['block_offset']!, _blockOffsetMeta));
    } else if (isInserting) {
      context.missing(_blockOffsetMeta);
    }
    if (data.containsKey('compressed_size')) {
      context.handle(
          _compressedSizeMeta,
          compressedSize.isAcceptableOrUnknown(
              data['compressed_size']!, _compressedSizeMeta));
    } else if (isInserting) {
      context.missing(_compressedSizeMeta);
    }
    if (data.containsKey('end_offset')) {
      context.handle(_endOffsetMeta,
          endOffset.isAcceptableOrUnknown(data['end_offset']!, _endOffsetMeta));
    } else if (isInserting) {
      context.missing(_endOffsetMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
          _startOffsetMeta,
          startOffset.isAcceptableOrUnknown(
              data['start_offset']!, _startOffsetMeta));
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  DictionaryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryData(
      blockOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block_offset'])!,
      compressedSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}compressed_size'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
    );
  }

  @override
  $DictionaryTable createAlias(String alias) {
    return $DictionaryTable(attachedDatabase, alias);
  }
}

class DictionaryData extends drift.DataClass
    implements drift.Insertable<DictionaryData> {
  final int blockOffset;
  final int compressedSize;
  final int endOffset;
  final String key;
  final int startOffset;
  const DictionaryData(
      {required this.blockOffset,
      required this.compressedSize,
      required this.endOffset,
      required this.key,
      required this.startOffset});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['block_offset'] = drift.Variable<int>(blockOffset);
    map['compressed_size'] = drift.Variable<int>(compressedSize);
    map['end_offset'] = drift.Variable<int>(endOffset);
    map['key'] = drift.Variable<String>(key);
    map['start_offset'] = drift.Variable<int>(startOffset);
    return map;
  }

  DictionaryCompanion toCompanion(bool nullToAbsent) {
    return DictionaryCompanion(
      blockOffset: drift.Value(blockOffset),
      compressedSize: drift.Value(compressedSize),
      endOffset: drift.Value(endOffset),
      key: drift.Value(key),
      startOffset: drift.Value(startOffset),
    );
  }

  factory DictionaryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryData(
      blockOffset: serializer.fromJson<int>(json['blockOffset']),
      compressedSize: serializer.fromJson<int>(json['compressedSize']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      key: serializer.fromJson<String>(json['key']),
      startOffset: serializer.fromJson<int>(json['startOffset']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'blockOffset': serializer.toJson<int>(blockOffset),
      'compressedSize': serializer.toJson<int>(compressedSize),
      'endOffset': serializer.toJson<int>(endOffset),
      'key': serializer.toJson<String>(key),
      'startOffset': serializer.toJson<int>(startOffset),
    };
  }

  DictionaryData copyWith(
          {int? blockOffset,
          int? compressedSize,
          int? endOffset,
          String? key,
          int? startOffset}) =>
      DictionaryData(
        blockOffset: blockOffset ?? this.blockOffset,
        compressedSize: compressedSize ?? this.compressedSize,
        endOffset: endOffset ?? this.endOffset,
        key: key ?? this.key,
        startOffset: startOffset ?? this.startOffset,
      );
  DictionaryData copyWithCompanion(DictionaryCompanion data) {
    return DictionaryData(
      blockOffset:
          data.blockOffset.present ? data.blockOffset.value : this.blockOffset,
      compressedSize: data.compressedSize.present
          ? data.compressedSize.value
          : this.compressedSize,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      key: data.key.present ? data.key.value : this.key,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryData(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('startOffset: $startOffset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(blockOffset, compressedSize, endOffset, key, startOffset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryData &&
          other.blockOffset == this.blockOffset &&
          other.compressedSize == this.compressedSize &&
          other.endOffset == this.endOffset &&
          other.key == this.key &&
          other.startOffset == this.startOffset);
}

class DictionaryCompanion extends drift.UpdateCompanion<DictionaryData> {
  final drift.Value<int> blockOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> endOffset;
  final drift.Value<String> key;
  final drift.Value<int> startOffset;
  final drift.Value<int> rowid;
  const DictionaryCompanion({
    this.blockOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.key = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  DictionaryCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int startOffset,
    this.rowid = const drift.Value.absent(),
  })  : blockOffset = drift.Value(blockOffset),
        compressedSize = drift.Value(compressedSize),
        endOffset = drift.Value(endOffset),
        key = drift.Value(key),
        startOffset = drift.Value(startOffset);
  static drift.Insertable<DictionaryData> custom({
    drift.Expression<int>? blockOffset,
    drift.Expression<int>? compressedSize,
    drift.Expression<int>? endOffset,
    drift.Expression<String>? key,
    drift.Expression<int>? startOffset,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (blockOffset != null) 'block_offset': blockOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (endOffset != null) 'end_offset': endOffset,
      if (key != null) 'key': key,
      if (startOffset != null) 'start_offset': startOffset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryCompanion copyWith(
      {drift.Value<int>? blockOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? endOffset,
      drift.Value<String>? key,
      drift.Value<int>? startOffset,
      drift.Value<int>? rowid}) {
    return DictionaryCompanion(
      blockOffset: blockOffset ?? this.blockOffset,
      compressedSize: compressedSize ?? this.compressedSize,
      endOffset: endOffset ?? this.endOffset,
      key: key ?? this.key,
      startOffset: startOffset ?? this.startOffset,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (blockOffset.present) {
      map['block_offset'] = drift.Variable<int>(blockOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = drift.Variable<int>(compressedSize.value);
    }
    if (endOffset.present) {
      map['end_offset'] = drift.Variable<int>(endOffset.value);
    }
    if (key.present) {
      map['key'] = drift.Variable<String>(key.value);
    }
    if (startOffset.present) {
      map['start_offset'] = drift.Variable<int>(startOffset.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryCompanion(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('startOffset: $startOffset, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DictionaryDatabase extends drift.GeneratedDatabase {
  _$DictionaryDatabase(QueryExecutor e) : super(e);
  $DictionaryDatabaseManager get managers => $DictionaryDatabaseManager(this);
  late final $ResourceTable resource = $ResourceTable(this);
  late final $DictionaryTable dictionary = $DictionaryTable(this);
  late final drift.Index idxData =
      drift.Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  late final drift.Index idxWord =
      drift.Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities =>
      [resource, dictionary, idxData, idxWord];
}

typedef $$ResourceTableCreateCompanionBuilder = ResourceCompanion Function({
  required int blockOffset,
  required int compressedSize,
  required int endOffset,
  required String key,
  required int startOffset,
  drift.Value<int?> part,
  drift.Value<int> rowid,
});
typedef $$ResourceTableUpdateCompanionBuilder = ResourceCompanion Function({
  drift.Value<int> blockOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> endOffset,
  drift.Value<String> key,
  drift.Value<int> startOffset,
  drift.Value<int?> part,
  drift.Value<int> rowid,
});

class $$ResourceTableFilterComposer
    extends drift.Composer<_$DictionaryDatabase, $ResourceTable> {
  $$ResourceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get endOffset => $composableBuilder(
      column: $table.endOffset,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get part => $composableBuilder(
      column: $table.part, builder: (column) => drift.ColumnFilters(column));
}

class $$ResourceTableOrderingComposer
    extends drift.Composer<_$DictionaryDatabase, $ResourceTable> {
  $$ResourceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get endOffset => $composableBuilder(
      column: $table.endOffset,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get part => $composableBuilder(
      column: $table.part, builder: (column) => drift.ColumnOrderings(column));
}

class $$ResourceTableAnnotationComposer
    extends drift.Composer<_$DictionaryDatabase, $ResourceTable> {
  $$ResourceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset, builder: (column) => column);

  drift.GeneratedColumn<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize, builder: (column) => column);

  drift.GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  drift.GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  drift.GeneratedColumn<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => column);

  drift.GeneratedColumn<int> get part =>
      $composableBuilder(column: $table.part, builder: (column) => column);
}

class $$ResourceTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $ResourceTable,
    ResourceData,
    $$ResourceTableFilterComposer,
    $$ResourceTableOrderingComposer,
    $$ResourceTableAnnotationComposer,
    $$ResourceTableCreateCompanionBuilder,
    $$ResourceTableUpdateCompanionBuilder,
    (
      ResourceData,
      drift.BaseReferences<_$DictionaryDatabase, $ResourceTable, ResourceData>
    ),
    ResourceData,
    drift.PrefetchHooks Function()> {
  $$ResourceTableTableManager(_$DictionaryDatabase db, $ResourceTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResourceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResourceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResourceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> blockOffset = const drift.Value.absent(),
            drift.Value<int> compressedSize = const drift.Value.absent(),
            drift.Value<int> endOffset = const drift.Value.absent(),
            drift.Value<String> key = const drift.Value.absent(),
            drift.Value<int> startOffset = const drift.Value.absent(),
            drift.Value<int?> part = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              ResourceCompanion(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            startOffset: startOffset,
            part: part,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int blockOffset,
            required int compressedSize,
            required int endOffset,
            required String key,
            required int startOffset,
            drift.Value<int?> part = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              ResourceCompanion.insert(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            startOffset: startOffset,
            part: part,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ResourceTableProcessedTableManager = drift.ProcessedTableManager<
    _$DictionaryDatabase,
    $ResourceTable,
    ResourceData,
    $$ResourceTableFilterComposer,
    $$ResourceTableOrderingComposer,
    $$ResourceTableAnnotationComposer,
    $$ResourceTableCreateCompanionBuilder,
    $$ResourceTableUpdateCompanionBuilder,
    (
      ResourceData,
      drift.BaseReferences<_$DictionaryDatabase, $ResourceTable, ResourceData>
    ),
    ResourceData,
    drift.PrefetchHooks Function()>;
typedef $$DictionaryTableCreateCompanionBuilder = DictionaryCompanion Function({
  required int blockOffset,
  required int compressedSize,
  required int endOffset,
  required String key,
  required int startOffset,
  drift.Value<int> rowid,
});
typedef $$DictionaryTableUpdateCompanionBuilder = DictionaryCompanion Function({
  drift.Value<int> blockOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> endOffset,
  drift.Value<String> key,
  drift.Value<int> startOffset,
  drift.Value<int> rowid,
});

class $$DictionaryTableFilterComposer
    extends drift.Composer<_$DictionaryDatabase, $DictionaryTable> {
  $$DictionaryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get endOffset => $composableBuilder(
      column: $table.endOffset,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnFilters(column));
}

class $$DictionaryTableOrderingComposer
    extends drift.Composer<_$DictionaryDatabase, $DictionaryTable> {
  $$DictionaryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get endOffset => $composableBuilder(
      column: $table.endOffset,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$DictionaryTableAnnotationComposer
    extends drift.Composer<_$DictionaryDatabase, $DictionaryTable> {
  $$DictionaryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get blockOffset => $composableBuilder(
      column: $table.blockOffset, builder: (column) => column);

  drift.GeneratedColumn<int> get compressedSize => $composableBuilder(
      column: $table.compressedSize, builder: (column) => column);

  drift.GeneratedColumn<int> get endOffset =>
      $composableBuilder(column: $table.endOffset, builder: (column) => column);

  drift.GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  drift.GeneratedColumn<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => column);
}

class $$DictionaryTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $DictionaryTable,
    DictionaryData,
    $$DictionaryTableFilterComposer,
    $$DictionaryTableOrderingComposer,
    $$DictionaryTableAnnotationComposer,
    $$DictionaryTableCreateCompanionBuilder,
    $$DictionaryTableUpdateCompanionBuilder,
    (
      DictionaryData,
      drift
      .BaseReferences<_$DictionaryDatabase, $DictionaryTable, DictionaryData>
    ),
    DictionaryData,
    drift.PrefetchHooks Function()> {
  $$DictionaryTableTableManager(_$DictionaryDatabase db, $DictionaryTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> blockOffset = const drift.Value.absent(),
            drift.Value<int> compressedSize = const drift.Value.absent(),
            drift.Value<int> endOffset = const drift.Value.absent(),
            drift.Value<String> key = const drift.Value.absent(),
            drift.Value<int> startOffset = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              DictionaryCompanion(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            startOffset: startOffset,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int blockOffset,
            required int compressedSize,
            required int endOffset,
            required String key,
            required int startOffset,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              DictionaryCompanion.insert(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            startOffset: startOffset,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DictionaryTableProcessedTableManager = drift.ProcessedTableManager<
    _$DictionaryDatabase,
    $DictionaryTable,
    DictionaryData,
    $$DictionaryTableFilterComposer,
    $$DictionaryTableOrderingComposer,
    $$DictionaryTableAnnotationComposer,
    $$DictionaryTableCreateCompanionBuilder,
    $$DictionaryTableUpdateCompanionBuilder,
    (
      DictionaryData,
      drift
      .BaseReferences<_$DictionaryDatabase, $DictionaryTable, DictionaryData>
    ),
    DictionaryData,
    drift.PrefetchHooks Function()>;

class $DictionaryDatabaseManager {
  final _$DictionaryDatabase _db;
  $DictionaryDatabaseManager(this._db);
  $$ResourceTableTableManager get resource =>
      $$ResourceTableTableManager(_db, _db.resource);
  $$DictionaryTableTableManager get dictionary =>
      $$DictionaryTableTableManager(_db, _db.dictionary);
}
