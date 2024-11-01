// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary.dart';

// ignore_for_file: type=lint
class $WordbookTable extends Wordbook
    with drift.TableInfo<$WordbookTable, WordbookData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordbookTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _tagMeta =
      const drift.VerificationMeta('tag');
  @override
  late final drift.GeneratedColumn<int> tag = drift.GeneratedColumn<int>(
      'tag', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const drift.VerificationMeta _wordMeta =
      const drift.VerificationMeta('word');
  @override
  late final drift.GeneratedColumn<String> word = drift.GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [tag, word];
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
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    }
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
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag']),
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
  final int? tag;
  final String word;
  const WordbookData({this.tag, required this.word});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (!nullToAbsent || tag != null) {
      map['tag'] = drift.Variable<int>(tag);
    }
    map['word'] = drift.Variable<String>(word);
    return map;
  }

  WordbookCompanion toCompanion(bool nullToAbsent) {
    return WordbookCompanion(
      tag: tag == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(tag),
      word: drift.Value(word),
    );
  }

  factory WordbookData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return WordbookData(
      tag: serializer.fromJson<int?>(json['tag']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<int?>(tag),
      'word': serializer.toJson<String>(word),
    };
  }

  WordbookData copyWith(
          {drift.Value<int?> tag = const drift.Value.absent(), String? word}) =>
      WordbookData(
        tag: tag.present ? tag.value : this.tag,
        word: word ?? this.word,
      );
  WordbookData copyWithCompanion(WordbookCompanion data) {
    return WordbookData(
      tag: data.tag.present ? data.tag.value : this.tag,
      word: data.word.present ? data.word.value : this.word,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordbookData(')
          ..write('tag: $tag, ')
          ..write('word: $word')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tag, word);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordbookData &&
          other.tag == this.tag &&
          other.word == this.word);
}

class WordbookCompanion extends drift.UpdateCompanion<WordbookData> {
  final drift.Value<int?> tag;
  final drift.Value<String> word;
  final drift.Value<int> rowid;
  const WordbookCompanion({
    this.tag = const drift.Value.absent(),
    this.word = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  WordbookCompanion.insert({
    this.tag = const drift.Value.absent(),
    required String word,
    this.rowid = const drift.Value.absent(),
  }) : word = drift.Value(word);
  static drift.Insertable<WordbookData> custom({
    drift.Expression<int>? tag,
    drift.Expression<String>? word,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (word != null) 'word': word,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordbookCompanion copyWith(
      {drift.Value<int?>? tag,
      drift.Value<String>? word,
      drift.Value<int>? rowid}) {
    return WordbookCompanion(
      tag: tag ?? this.tag,
      word: word ?? this.word,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (tag.present) {
      map['tag'] = drift.Variable<int>(tag.value);
    }
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
          ..write('tag: $tag, ')
          ..write('word: $word, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordbookTagsTable extends WordbookTags
    with drift.TableInfo<$WordbookTagsTable, WordbookTag> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordbookTagsTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _tagMeta =
      const drift.VerificationMeta('tag');
  @override
  late final drift.GeneratedColumn<String> tag = drift.GeneratedColumn<String>(
      'tag', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<drift.GeneratedColumn> get $columns => [id, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wordbook_tags';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<WordbookTag> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
  @override
  WordbookTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordbookTag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag'])!,
    );
  }

  @override
  $WordbookTagsTable createAlias(String alias) {
    return $WordbookTagsTable(attachedDatabase, alias);
  }
}

class WordbookTag extends drift.DataClass
    implements drift.Insertable<WordbookTag> {
  final int id;
  final String tag;
  const WordbookTag({required this.id, required this.tag});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['tag'] = drift.Variable<String>(tag);
    return map;
  }

  WordbookTagsCompanion toCompanion(bool nullToAbsent) {
    return WordbookTagsCompanion(
      id: drift.Value(id),
      tag: drift.Value(tag),
    );
  }

  factory WordbookTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return WordbookTag(
      id: serializer.fromJson<int>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tag': serializer.toJson<String>(tag),
    };
  }

  WordbookTag copyWith({int? id, String? tag}) => WordbookTag(
        id: id ?? this.id,
        tag: tag ?? this.tag,
      );
  WordbookTag copyWithCompanion(WordbookTagsCompanion data) {
    return WordbookTag(
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordbookTag(')
          ..write('id: $id, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordbookTag && other.id == this.id && other.tag == this.tag);
}

class WordbookTagsCompanion extends drift.UpdateCompanion<WordbookTag> {
  final drift.Value<int> id;
  final drift.Value<String> tag;
  const WordbookTagsCompanion({
    this.id = const drift.Value.absent(),
    this.tag = const drift.Value.absent(),
  });
  WordbookTagsCompanion.insert({
    this.id = const drift.Value.absent(),
    required String tag,
  }) : tag = drift.Value(tag);
  static drift.Insertable<WordbookTag> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? tag,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
    });
  }

  WordbookTagsCompanion copyWith(
      {drift.Value<int>? id, drift.Value<String>? tag}) {
    return WordbookTagsCompanion(
      id: id ?? this.id,
      tag: tag ?? this.tag,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (tag.present) {
      map['tag'] = drift.Variable<String>(tag.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordbookTagsCompanion(')
          ..write('id: $id, ')
          ..write('tag: $tag')
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
  const ResourceData(
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

  ResourceCompanion toCompanion(bool nullToAbsent) {
    return ResourceCompanion(
      blockOffset: drift.Value(blockOffset),
      compressedSize: drift.Value(compressedSize),
      endOffset: drift.Value(endOffset),
      key: drift.Value(key),
      startOffset: drift.Value(startOffset),
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

  ResourceData copyWith(
          {int? blockOffset,
          int? compressedSize,
          int? endOffset,
          String? key,
          int? startOffset}) =>
      ResourceData(
        blockOffset: blockOffset ?? this.blockOffset,
        compressedSize: compressedSize ?? this.compressedSize,
        endOffset: endOffset ?? this.endOffset,
        key: key ?? this.key,
        startOffset: startOffset ?? this.startOffset,
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
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResourceData(')
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
      (other is ResourceData &&
          other.blockOffset == this.blockOffset &&
          other.compressedSize == this.compressedSize &&
          other.endOffset == this.endOffset &&
          other.key == this.key &&
          other.startOffset == this.startOffset);
}

class ResourceCompanion extends drift.UpdateCompanion<ResourceData> {
  final drift.Value<int> blockOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> endOffset;
  final drift.Value<String> key;
  final drift.Value<int> startOffset;
  final drift.Value<int> rowid;
  const ResourceCompanion({
    this.blockOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.key = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  ResourceCompanion.insert({
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
  static drift.Insertable<ResourceData> custom({
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

  ResourceCompanion copyWith(
      {drift.Value<int>? blockOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? endOffset,
      drift.Value<String>? key,
      drift.Value<int>? startOffset,
      drift.Value<int>? rowid}) {
    return ResourceCompanion(
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
    return (StringBuffer('ResourceCompanion(')
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
  late final $WordbookTable wordbook = $WordbookTable(this);
  late final $WordbookTagsTable wordbookTags = $WordbookTagsTable(this);
  late final $ResourceTable resource = $ResourceTable(this);
  late final $DictionaryTable dictionary = $DictionaryTable(this);
  late final Index idxWordbook = drift.Index(
      'idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  late final Index idxWordbookTags = drift.Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  late final Index idxData =
      drift.Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  late final Index idxWord =
      drift.Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities => [
        wordbook,
        wordbookTags,
        resource,
        dictionary,
        idxWordbook,
        idxWordbookTags,
        idxData,
        idxWord
      ];
}

typedef $$WordbookTableCreateCompanionBuilder = WordbookCompanion Function({
  drift.Value<int?> tag,
  required String word,
  drift.Value<int> rowid,
});
typedef $$WordbookTableUpdateCompanionBuilder = WordbookCompanion Function({
  drift.Value<int?> tag,
  drift.Value<String> word,
  drift.Value<int> rowid,
});

class $$WordbookTableFilterComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTable> {
  $$WordbookTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnFilters(column));
}

class $$WordbookTableOrderingComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTable> {
  $$WordbookTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnOrderings(column));
}

class $$WordbookTableAnnotationComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTable> {
  $$WordbookTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  drift.GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);
}

class $$WordbookTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $WordbookTable,
    WordbookData,
    $$WordbookTableFilterComposer,
    $$WordbookTableOrderingComposer,
    $$WordbookTableAnnotationComposer,
    $$WordbookTableCreateCompanionBuilder,
    $$WordbookTableUpdateCompanionBuilder,
    (
      WordbookData,
      drift.BaseReferences<_$DictionaryDatabase, $WordbookTable, WordbookData>
    ),
    WordbookData,
    drift.PrefetchHooks Function()> {
  $$WordbookTableTableManager(_$DictionaryDatabase db, $WordbookTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordbookTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordbookTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordbookTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int?> tag = const drift.Value.absent(),
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion(
            tag: tag,
            word: word,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            drift.Value<int?> tag = const drift.Value.absent(),
            required String word,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion.insert(
            tag: tag,
            word: word,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WordbookTableProcessedTableManager = drift.ProcessedTableManager<
    _$DictionaryDatabase,
    $WordbookTable,
    WordbookData,
    $$WordbookTableFilterComposer,
    $$WordbookTableOrderingComposer,
    $$WordbookTableAnnotationComposer,
    $$WordbookTableCreateCompanionBuilder,
    $$WordbookTableUpdateCompanionBuilder,
    (
      WordbookData,
      drift.BaseReferences<_$DictionaryDatabase, $WordbookTable, WordbookData>
    ),
    WordbookData,
    drift.PrefetchHooks Function()>;
typedef $$WordbookTagsTableCreateCompanionBuilder = WordbookTagsCompanion
    Function({
  drift.Value<int> id,
  required String tag,
});
typedef $$WordbookTagsTableUpdateCompanionBuilder = WordbookTagsCompanion
    Function({
  drift.Value<int> id,
  drift.Value<String> tag,
});

class $$WordbookTagsTableFilterComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTagsTable> {
  $$WordbookTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => drift.ColumnFilters(column));
}

class $$WordbookTagsTableOrderingComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTagsTable> {
  $$WordbookTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => drift.ColumnOrderings(column));
}

class $$WordbookTagsTableAnnotationComposer
    extends drift.Composer<_$DictionaryDatabase, $WordbookTagsTable> {
  $$WordbookTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$WordbookTagsTableTableManager extends drift.RootTableManager<
    _$DictionaryDatabase,
    $WordbookTagsTable,
    WordbookTag,
    $$WordbookTagsTableFilterComposer,
    $$WordbookTagsTableOrderingComposer,
    $$WordbookTagsTableAnnotationComposer,
    $$WordbookTagsTableCreateCompanionBuilder,
    $$WordbookTagsTableUpdateCompanionBuilder,
    (
      WordbookTag,
      drift
      .BaseReferences<_$DictionaryDatabase, $WordbookTagsTable, WordbookTag>
    ),
    WordbookTag,
    drift.PrefetchHooks Function()> {
  $$WordbookTagsTableTableManager(
      _$DictionaryDatabase db, $WordbookTagsTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordbookTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordbookTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordbookTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> tag = const drift.Value.absent(),
          }) =>
              WordbookTagsCompanion(
            id: id,
            tag: tag,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String tag,
          }) =>
              WordbookTagsCompanion.insert(
            id: id,
            tag: tag,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WordbookTagsTableProcessedTableManager = drift.ProcessedTableManager<
    _$DictionaryDatabase,
    $WordbookTagsTable,
    WordbookTag,
    $$WordbookTagsTableFilterComposer,
    $$WordbookTagsTableOrderingComposer,
    $$WordbookTagsTableAnnotationComposer,
    $$WordbookTagsTableCreateCompanionBuilder,
    $$WordbookTagsTableUpdateCompanionBuilder,
    (
      WordbookTag,
      drift
      .BaseReferences<_$DictionaryDatabase, $WordbookTagsTable, WordbookTag>
    ),
    WordbookTag,
    drift.PrefetchHooks Function()>;
typedef $$ResourceTableCreateCompanionBuilder = ResourceCompanion Function({
  required int blockOffset,
  required int compressedSize,
  required int endOffset,
  required String key,
  required int startOffset,
  drift.Value<int> rowid,
});
typedef $$ResourceTableUpdateCompanionBuilder = ResourceCompanion Function({
  drift.Value<int> blockOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> endOffset,
  drift.Value<String> key,
  drift.Value<int> startOffset,
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
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              ResourceCompanion(
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
              ResourceCompanion.insert(
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
  $$WordbookTableTableManager get wordbook =>
      $$WordbookTableTableManager(_db, _db.wordbook);
  $$WordbookTagsTableTableManager get wordbookTags =>
      $$WordbookTagsTableTableManager(_db, _db.wordbookTags);
  $$ResourceTableTableManager get resource =>
      $$ResourceTableTableManager(_db, _db.resource);
  $$DictionaryTableTableManager get dictionary =>
      $$DictionaryTableTableManager(_db, _db.dictionary);
}
