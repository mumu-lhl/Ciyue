// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class Resource extends Table with TableInfo<Resource, ResourceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Resource(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> blockOffset = GeneratedColumn<int>(
      'block_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> compressedSize = GeneratedColumn<int>(
      'compressed_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
      'start_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> part = GeneratedColumn<int>(
      'part', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [blockOffset, compressedSize, endOffset, key, startOffset, part];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resource';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
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
  Resource createAlias(String alias) {
    return Resource(attachedDatabase, alias);
  }
}

class ResourceData extends DataClass implements Insertable<ResourceData> {
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['block_offset'] = Variable<int>(blockOffset);
    map['compressed_size'] = Variable<int>(compressedSize);
    map['end_offset'] = Variable<int>(endOffset);
    map['key'] = Variable<String>(key);
    map['start_offset'] = Variable<int>(startOffset);
    if (!nullToAbsent || part != null) {
      map['part'] = Variable<int>(part);
    }
    return map;
  }

  ResourceCompanion toCompanion(bool nullToAbsent) {
    return ResourceCompanion(
      blockOffset: Value(blockOffset),
      compressedSize: Value(compressedSize),
      endOffset: Value(endOffset),
      key: Value(key),
      startOffset: Value(startOffset),
      part: part == null && nullToAbsent ? const Value.absent() : Value(part),
    );
  }

  factory ResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
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
    serializer ??= driftRuntimeOptions.defaultSerializer;
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
          Value<int?> part = const Value.absent()}) =>
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

class ResourceCompanion extends UpdateCompanion<ResourceData> {
  final Value<int> blockOffset;
  final Value<int> compressedSize;
  final Value<int> endOffset;
  final Value<String> key;
  final Value<int> startOffset;
  final Value<int?> part;
  final Value<int> rowid;
  const ResourceCompanion({
    this.blockOffset = const Value.absent(),
    this.compressedSize = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.key = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.part = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResourceCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int startOffset,
    this.part = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : blockOffset = Value(blockOffset),
        compressedSize = Value(compressedSize),
        endOffset = Value(endOffset),
        key = Value(key),
        startOffset = Value(startOffset);
  static Insertable<ResourceData> custom({
    Expression<int>? blockOffset,
    Expression<int>? compressedSize,
    Expression<int>? endOffset,
    Expression<String>? key,
    Expression<int>? startOffset,
    Expression<int>? part,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
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
      {Value<int>? blockOffset,
      Value<int>? compressedSize,
      Value<int>? endOffset,
      Value<String>? key,
      Value<int>? startOffset,
      Value<int?>? part,
      Value<int>? rowid}) {
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blockOffset.present) {
      map['block_offset'] = Variable<int>(blockOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = Variable<int>(compressedSize.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (part.present) {
      map['part'] = Variable<int>(part.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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

class Dictionary extends Table with TableInfo<Dictionary, DictionaryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Dictionary(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> blockOffset = GeneratedColumn<int>(
      'block_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> compressedSize = GeneratedColumn<int>(
      'compressed_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> endOffset = GeneratedColumn<int>(
      'end_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
      'start_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [blockOffset, compressedSize, endOffset, key, startOffset];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
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
  Dictionary createAlias(String alias) {
    return Dictionary(attachedDatabase, alias);
  }
}

class DictionaryData extends DataClass implements Insertable<DictionaryData> {
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['block_offset'] = Variable<int>(blockOffset);
    map['compressed_size'] = Variable<int>(compressedSize);
    map['end_offset'] = Variable<int>(endOffset);
    map['key'] = Variable<String>(key);
    map['start_offset'] = Variable<int>(startOffset);
    return map;
  }

  DictionaryCompanion toCompanion(bool nullToAbsent) {
    return DictionaryCompanion(
      blockOffset: Value(blockOffset),
      compressedSize: Value(compressedSize),
      endOffset: Value(endOffset),
      key: Value(key),
      startOffset: Value(startOffset),
    );
  }

  factory DictionaryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
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
    serializer ??= driftRuntimeOptions.defaultSerializer;
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

class DictionaryCompanion extends UpdateCompanion<DictionaryData> {
  final Value<int> blockOffset;
  final Value<int> compressedSize;
  final Value<int> endOffset;
  final Value<String> key;
  final Value<int> startOffset;
  final Value<int> rowid;
  const DictionaryCompanion({
    this.blockOffset = const Value.absent(),
    this.compressedSize = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.key = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DictionaryCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int startOffset,
    this.rowid = const Value.absent(),
  })  : blockOffset = Value(blockOffset),
        compressedSize = Value(compressedSize),
        endOffset = Value(endOffset),
        key = Value(key),
        startOffset = Value(startOffset);
  static Insertable<DictionaryData> custom({
    Expression<int>? blockOffset,
    Expression<int>? compressedSize,
    Expression<int>? endOffset,
    Expression<String>? key,
    Expression<int>? startOffset,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blockOffset != null) 'block_offset': blockOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (endOffset != null) 'end_offset': endOffset,
      if (key != null) 'key': key,
      if (startOffset != null) 'start_offset': startOffset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DictionaryCompanion copyWith(
      {Value<int>? blockOffset,
      Value<int>? compressedSize,
      Value<int>? endOffset,
      Value<String>? key,
      Value<int>? startOffset,
      Value<int>? rowid}) {
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
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (blockOffset.present) {
      map['block_offset'] = Variable<int>(blockOffset.value);
    }
    if (compressedSize.present) {
      map['compressed_size'] = Variable<int>(compressedSize.value);
    }
    if (endOffset.present) {
      map['end_offset'] = Variable<int>(endOffset.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<int>(startOffset.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
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

class DatabaseAtV5 extends GeneratedDatabase {
  DatabaseAtV5(QueryExecutor e) : super(e);
  late final Resource resource = Resource(this);
  late final Dictionary dictionary = Dictionary(this);
  late final Index idxData =
      Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  late final Index idxWord =
      Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [resource, dictionary, idxData, idxWord];
  @override
  int get schemaVersion => 5;
}
