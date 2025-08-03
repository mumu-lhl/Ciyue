// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';

class DictionaryList extends Table
    with TableInfo<DictionaryList, DictionaryListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DictionaryList(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<String> fontPath = GeneratedColumn<String>(
      'font_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const CustomExpression('0'));
  @override
  List<GeneratedColumn> get $columns => [alias, fontPath, id, path, type];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dictionary_list';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictionaryListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryListData(
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias']),
      fontPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_path']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
    );
  }

  @override
  DictionaryList createAlias(String alias) {
    return DictionaryList(attachedDatabase, alias);
  }
}

class DictionaryListData extends DataClass
    implements Insertable<DictionaryListData> {
  final String? alias;
  final String? fontPath;
  final int id;
  final String path;
  final int type;
  const DictionaryListData(
      {this.alias,
      this.fontPath,
      required this.id,
      required this.path,
      required this.type});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || alias != null) {
      map['alias'] = Variable<String>(alias);
    }
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = Variable<String>(fontPath);
    }
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['type'] = Variable<int>(type);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      alias:
          alias == null && nullToAbsent ? const Value.absent() : Value(alias),
      fontPath: fontPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fontPath),
      id: Value(id),
      path: Value(path),
      type: Value(type),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      alias: serializer.fromJson<String?>(json['alias']),
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      type: serializer.fromJson<int>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'alias': serializer.toJson<String?>(alias),
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'type': serializer.toJson<int>(type),
    };
  }

  DictionaryListData copyWith(
          {Value<String?> alias = const Value.absent(),
          Value<String?> fontPath = const Value.absent(),
          int? id,
          String? path,
          int? type}) =>
      DictionaryListData(
        alias: alias.present ? alias.value : this.alias,
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
        id: id ?? this.id,
        path: path ?? this.path,
        type: type ?? this.type,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      alias: data.alias.present ? data.alias.value : this.alias,
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('alias: $alias, ')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(alias, fontPath, id, path, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.alias == this.alias &&
          other.fontPath == this.fontPath &&
          other.id == this.id &&
          other.path == this.path &&
          other.type == this.type);
}

class DictionaryListCompanion extends UpdateCompanion<DictionaryListData> {
  final Value<String?> alias;
  final Value<String?> fontPath;
  final Value<int> id;
  final Value<String> path;
  final Value<int> type;
  const DictionaryListCompanion({
    this.alias = const Value.absent(),
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.type = const Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.alias = const Value.absent(),
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    required String path,
    this.type = const Value.absent(),
  }) : path = Value(path);
  static Insertable<DictionaryListData> custom({
    Expression<String>? alias,
    Expression<String>? fontPath,
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? type,
  }) {
    return RawValuesInsertable({
      if (alias != null) 'alias': alias,
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (type != null) 'type': type,
    });
  }

  DictionaryListCompanion copyWith(
      {Value<String?>? alias,
      Value<String?>? fontPath,
      Value<int>? id,
      Value<String>? path,
      Value<int>? type}) {
    return DictionaryListCompanion(
      alias: alias ?? this.alias,
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (fontPath.present) {
      map['font_path'] = Variable<String>(fontPath.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('alias: $alias, ')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }
}

class Wordbook extends Table with TableInfo<Wordbook, WordbookData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Wordbook(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  late final GeneratedColumn<int> tag = GeneratedColumn<int>(
      'tag', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [createdAt, tag, word];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wordbook';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  WordbookData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordbookData(
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag']),
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
    );
  }

  @override
  Wordbook createAlias(String alias) {
    return Wordbook(attachedDatabase, alias);
  }
}

class WordbookData extends DataClass implements Insertable<WordbookData> {
  final DateTime createdAt;
  final int? tag;
  final String word;
  const WordbookData({required this.createdAt, this.tag, required this.word});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<int>(tag);
    }
    map['word'] = Variable<String>(word);
    return map;
  }

  WordbookCompanion toCompanion(bool nullToAbsent) {
    return WordbookCompanion(
      createdAt: Value(createdAt),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      word: Value(word),
    );
  }

  factory WordbookData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordbookData(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      tag: serializer.fromJson<int?>(json['tag']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'tag': serializer.toJson<int?>(tag),
      'word': serializer.toJson<String>(word),
    };
  }

  WordbookData copyWith(
          {DateTime? createdAt,
          Value<int?> tag = const Value.absent(),
          String? word}) =>
      WordbookData(
        createdAt: createdAt ?? this.createdAt,
        tag: tag.present ? tag.value : this.tag,
        word: word ?? this.word,
      );
  WordbookData copyWithCompanion(WordbookCompanion data) {
    return WordbookData(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      tag: data.tag.present ? data.tag.value : this.tag,
      word: data.word.present ? data.word.value : this.word,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordbookData(')
          ..write('createdAt: $createdAt, ')
          ..write('tag: $tag, ')
          ..write('word: $word')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(createdAt, tag, word);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordbookData &&
          other.createdAt == this.createdAt &&
          other.tag == this.tag &&
          other.word == this.word);
}

class WordbookCompanion extends UpdateCompanion<WordbookData> {
  final Value<DateTime> createdAt;
  final Value<int?> tag;
  final Value<String> word;
  final Value<int> rowid;
  const WordbookCompanion({
    this.createdAt = const Value.absent(),
    this.tag = const Value.absent(),
    this.word = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordbookCompanion.insert({
    required DateTime createdAt,
    this.tag = const Value.absent(),
    required String word,
    this.rowid = const Value.absent(),
  })  : createdAt = Value(createdAt),
        word = Value(word);
  static Insertable<WordbookData> custom({
    Expression<DateTime>? createdAt,
    Expression<int>? tag,
    Expression<String>? word,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (tag != null) 'tag': tag,
      if (word != null) 'word': word,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordbookCompanion copyWith(
      {Value<DateTime>? createdAt,
      Value<int?>? tag,
      Value<String>? word,
      Value<int>? rowid}) {
    return WordbookCompanion(
      createdAt: createdAt ?? this.createdAt,
      tag: tag ?? this.tag,
      word: word ?? this.word,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (tag.present) {
      map['tag'] = Variable<int>(tag.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordbookCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('tag: $tag, ')
          ..write('word: $word, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WordbookTags extends Table
    with TableInfo<WordbookTags, WordbookTagsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WordbookTags(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
      'tag', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<GeneratedColumn> get $columns => [id, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wordbook_tags';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WordbookTagsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordbookTagsData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag'])!,
    );
  }

  @override
  WordbookTags createAlias(String alias) {
    return WordbookTags(attachedDatabase, alias);
  }
}

class WordbookTagsData extends DataClass
    implements Insertable<WordbookTagsData> {
  final int id;
  final String tag;
  const WordbookTagsData({required this.id, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  WordbookTagsCompanion toCompanion(bool nullToAbsent) {
    return WordbookTagsCompanion(
      id: Value(id),
      tag: Value(tag),
    );
  }

  factory WordbookTagsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordbookTagsData(
      id: serializer.fromJson<int>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tag': serializer.toJson<String>(tag),
    };
  }

  WordbookTagsData copyWith({int? id, String? tag}) => WordbookTagsData(
        id: id ?? this.id,
        tag: tag ?? this.tag,
      );
  WordbookTagsData copyWithCompanion(WordbookTagsCompanion data) {
    return WordbookTagsData(
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordbookTagsData(')
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
      (other is WordbookTagsData &&
          other.id == this.id &&
          other.tag == this.tag);
}

class WordbookTagsCompanion extends UpdateCompanion<WordbookTagsData> {
  final Value<int> id;
  final Value<String> tag;
  const WordbookTagsCompanion({
    this.id = const Value.absent(),
    this.tag = const Value.absent(),
  });
  WordbookTagsCompanion.insert({
    this.id = const Value.absent(),
    required String tag,
  }) : tag = Value(tag);
  static Insertable<WordbookTagsData> custom({
    Expression<int>? id,
    Expression<String>? tag,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
    });
  }

  WordbookTagsCompanion copyWith({Value<int>? id, Value<String>? tag}) {
    return WordbookTagsCompanion(
      id: id ?? this.id,
      tag: tag ?? this.tag,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
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

class History extends Table with TableInfo<History, HistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  History(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, word];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
    );
  }

  @override
  History createAlias(String alias) {
    return History(attachedDatabase, alias);
  }
}

class HistoryData extends DataClass implements Insertable<HistoryData> {
  final int id;
  final String word;
  const HistoryData({required this.id, required this.word});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['word'] = Variable<String>(word);
    return map;
  }

  HistoryCompanion toCompanion(bool nullToAbsent) {
    return HistoryCompanion(
      id: Value(id),
      word: Value(word),
    );
  }

  factory HistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryData(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
    };
  }

  HistoryData copyWith({int? id, String? word}) => HistoryData(
        id: id ?? this.id,
        word: word ?? this.word,
      );
  HistoryData copyWithCompanion(HistoryCompanion data) {
    return HistoryData(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryData(')
          ..write('id: $id, ')
          ..write('word: $word')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryData && other.id == this.id && other.word == this.word);
}

class HistoryCompanion extends UpdateCompanion<HistoryData> {
  final Value<int> id;
  final Value<String> word;
  const HistoryCompanion({
    this.id = const Value.absent(),
    this.word = const Value.absent(),
  });
  HistoryCompanion.insert({
    this.id = const Value.absent(),
    required String word,
  }) : word = Value(word);
  static Insertable<HistoryData> custom({
    Expression<int>? id,
    Expression<String>? word,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
    });
  }

  HistoryCompanion copyWith({Value<int>? id, Value<String>? word}) {
    return HistoryCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryCompanion(')
          ..write('id: $id, ')
          ..write('word: $word')
          ..write(')'))
        .toString();
  }
}

class DictGroup extends Table with TableInfo<DictGroup, DictGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DictGroup(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> dictIds = GeneratedColumn<String>(
      'dict_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<GeneratedColumn> get $columns => [dictIds, id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dict_group';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DictGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictGroupData(
      dictIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dict_ids'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
    );
  }

  @override
  DictGroup createAlias(String alias) {
    return DictGroup(attachedDatabase, alias);
  }
}

class DictGroupData extends DataClass implements Insertable<DictGroupData> {
  final String dictIds;
  final int id;
  final String name;
  const DictGroupData(
      {required this.dictIds, required this.id, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dict_ids'] = Variable<String>(dictIds);
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  DictGroupCompanion toCompanion(bool nullToAbsent) {
    return DictGroupCompanion(
      dictIds: Value(dictIds),
      id: Value(id),
      name: Value(name),
    );
  }

  factory DictGroupData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictGroupData(
      dictIds: serializer.fromJson<String>(json['dictIds']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dictIds': serializer.toJson<String>(dictIds),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  DictGroupData copyWith({String? dictIds, int? id, String? name}) =>
      DictGroupData(
        dictIds: dictIds ?? this.dictIds,
        id: id ?? this.id,
        name: name ?? this.name,
      );
  DictGroupData copyWithCompanion(DictGroupCompanion data) {
    return DictGroupData(
      dictIds: data.dictIds.present ? data.dictIds.value : this.dictIds,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictGroupData(')
          ..write('dictIds: $dictIds, ')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dictIds, id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictGroupData &&
          other.dictIds == this.dictIds &&
          other.id == this.id &&
          other.name == this.name);
}

class DictGroupCompanion extends UpdateCompanion<DictGroupData> {
  final Value<String> dictIds;
  final Value<int> id;
  final Value<String> name;
  const DictGroupCompanion({
    this.dictIds = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  DictGroupCompanion.insert({
    required String dictIds,
    this.id = const Value.absent(),
    required String name,
  })  : dictIds = Value(dictIds),
        name = Value(name);
  static Insertable<DictGroupData> custom({
    Expression<String>? dictIds,
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (dictIds != null) 'dict_ids': dictIds,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  DictGroupCompanion copyWith(
      {Value<String>? dictIds, Value<int>? id, Value<String>? name}) {
    return DictGroupCompanion(
      dictIds: dictIds ?? this.dictIds,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dictIds.present) {
      map['dict_ids'] = Variable<String>(dictIds.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictGroupCompanion(')
          ..write('dictIds: $dictIds, ')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class MddAudioList extends Table
    with TableInfo<MddAudioList, MddAudioListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MddAudioList(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, path, title, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mdd_audio_list';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MddAudioListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MddAudioListData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  MddAudioList createAlias(String alias) {
    return MddAudioList(attachedDatabase, alias);
  }
}

class MddAudioListData extends DataClass
    implements Insertable<MddAudioListData> {
  final int id;
  final String path;
  final String title;
  final int order;
  const MddAudioListData(
      {required this.id,
      required this.path,
      required this.title,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['title'] = Variable<String>(title);
    map['order'] = Variable<int>(order);
    return map;
  }

  MddAudioListCompanion toCompanion(bool nullToAbsent) {
    return MddAudioListCompanion(
      id: Value(id),
      path: Value(path),
      title: Value(title),
      order: Value(order),
    );
  }

  factory MddAudioListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MddAudioListData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'title': serializer.toJson<String>(title),
      'order': serializer.toJson<int>(order),
    };
  }

  MddAudioListData copyWith(
          {int? id, String? path, String? title, int? order}) =>
      MddAudioListData(
        id: id ?? this.id,
        path: path ?? this.path,
        title: title ?? this.title,
        order: order ?? this.order,
      );
  MddAudioListData copyWithCompanion(MddAudioListCompanion data) {
    return MddAudioListData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      title: data.title.present ? data.title.value : this.title,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MddAudioListData(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, title, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MddAudioListData &&
          other.id == this.id &&
          other.path == this.path &&
          other.title == this.title &&
          other.order == this.order);
}

class MddAudioListCompanion extends UpdateCompanion<MddAudioListData> {
  final Value<int> id;
  final Value<String> path;
  final Value<String> title;
  final Value<int> order;
  const MddAudioListCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.title = const Value.absent(),
    this.order = const Value.absent(),
  });
  MddAudioListCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required String title,
    required int order,
  })  : path = Value(path),
        title = Value(title),
        order = Value(order);
  static Insertable<MddAudioListData> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? title,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (order != null) 'order': order,
    });
  }

  MddAudioListCompanion copyWith(
      {Value<int>? id,
      Value<String>? path,
      Value<String>? title,
      Value<int>? order}) {
    return MddAudioListCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MddAudioListCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('title: $title, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class MddAudioResource extends Table
    with TableInfo<MddAudioResource, MddAudioResourceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  MddAudioResource(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<int> mddAudioListId = GeneratedColumn<int>(
      'mdd_audio_list_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  late final GeneratedColumn<int> startOffset = GeneratedColumn<int>(
      'start_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        blockOffset,
        compressedSize,
        endOffset,
        key,
        mddAudioListId,
        startOffset
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mdd_audio_resource';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  MddAudioResourceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MddAudioResourceData(
      blockOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}block_offset'])!,
      compressedSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}compressed_size'])!,
      endOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_offset'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      mddAudioListId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mdd_audio_list_id'])!,
      startOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_offset'])!,
    );
  }

  @override
  MddAudioResource createAlias(String alias) {
    return MddAudioResource(attachedDatabase, alias);
  }
}

class MddAudioResourceData extends DataClass
    implements Insertable<MddAudioResourceData> {
  final int blockOffset;
  final int compressedSize;
  final int endOffset;
  final String key;
  final int mddAudioListId;
  final int startOffset;
  const MddAudioResourceData(
      {required this.blockOffset,
      required this.compressedSize,
      required this.endOffset,
      required this.key,
      required this.mddAudioListId,
      required this.startOffset});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['block_offset'] = Variable<int>(blockOffset);
    map['compressed_size'] = Variable<int>(compressedSize);
    map['end_offset'] = Variable<int>(endOffset);
    map['key'] = Variable<String>(key);
    map['mdd_audio_list_id'] = Variable<int>(mddAudioListId);
    map['start_offset'] = Variable<int>(startOffset);
    return map;
  }

  MddAudioResourceCompanion toCompanion(bool nullToAbsent) {
    return MddAudioResourceCompanion(
      blockOffset: Value(blockOffset),
      compressedSize: Value(compressedSize),
      endOffset: Value(endOffset),
      key: Value(key),
      mddAudioListId: Value(mddAudioListId),
      startOffset: Value(startOffset),
    );
  }

  factory MddAudioResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MddAudioResourceData(
      blockOffset: serializer.fromJson<int>(json['blockOffset']),
      compressedSize: serializer.fromJson<int>(json['compressedSize']),
      endOffset: serializer.fromJson<int>(json['endOffset']),
      key: serializer.fromJson<String>(json['key']),
      mddAudioListId: serializer.fromJson<int>(json['mddAudioListId']),
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
      'mddAudioListId': serializer.toJson<int>(mddAudioListId),
      'startOffset': serializer.toJson<int>(startOffset),
    };
  }

  MddAudioResourceData copyWith(
          {int? blockOffset,
          int? compressedSize,
          int? endOffset,
          String? key,
          int? mddAudioListId,
          int? startOffset}) =>
      MddAudioResourceData(
        blockOffset: blockOffset ?? this.blockOffset,
        compressedSize: compressedSize ?? this.compressedSize,
        endOffset: endOffset ?? this.endOffset,
        key: key ?? this.key,
        mddAudioListId: mddAudioListId ?? this.mddAudioListId,
        startOffset: startOffset ?? this.startOffset,
      );
  MddAudioResourceData copyWithCompanion(MddAudioResourceCompanion data) {
    return MddAudioResourceData(
      blockOffset:
          data.blockOffset.present ? data.blockOffset.value : this.blockOffset,
      compressedSize: data.compressedSize.present
          ? data.compressedSize.value
          : this.compressedSize,
      endOffset: data.endOffset.present ? data.endOffset.value : this.endOffset,
      key: data.key.present ? data.key.value : this.key,
      mddAudioListId: data.mddAudioListId.present
          ? data.mddAudioListId.value
          : this.mddAudioListId,
      startOffset:
          data.startOffset.present ? data.startOffset.value : this.startOffset,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MddAudioResourceData(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('mddAudioListId: $mddAudioListId, ')
          ..write('startOffset: $startOffset')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      blockOffset, compressedSize, endOffset, key, mddAudioListId, startOffset);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MddAudioResourceData &&
          other.blockOffset == this.blockOffset &&
          other.compressedSize == this.compressedSize &&
          other.endOffset == this.endOffset &&
          other.key == this.key &&
          other.mddAudioListId == this.mddAudioListId &&
          other.startOffset == this.startOffset);
}

class MddAudioResourceCompanion extends UpdateCompanion<MddAudioResourceData> {
  final Value<int> blockOffset;
  final Value<int> compressedSize;
  final Value<int> endOffset;
  final Value<String> key;
  final Value<int> mddAudioListId;
  final Value<int> startOffset;
  final Value<int> rowid;
  const MddAudioResourceCompanion({
    this.blockOffset = const Value.absent(),
    this.compressedSize = const Value.absent(),
    this.endOffset = const Value.absent(),
    this.key = const Value.absent(),
    this.mddAudioListId = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MddAudioResourceCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int mddAudioListId,
    required int startOffset,
    this.rowid = const Value.absent(),
  })  : blockOffset = Value(blockOffset),
        compressedSize = Value(compressedSize),
        endOffset = Value(endOffset),
        key = Value(key),
        mddAudioListId = Value(mddAudioListId),
        startOffset = Value(startOffset);
  static Insertable<MddAudioResourceData> custom({
    Expression<int>? blockOffset,
    Expression<int>? compressedSize,
    Expression<int>? endOffset,
    Expression<String>? key,
    Expression<int>? mddAudioListId,
    Expression<int>? startOffset,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (blockOffset != null) 'block_offset': blockOffset,
      if (compressedSize != null) 'compressed_size': compressedSize,
      if (endOffset != null) 'end_offset': endOffset,
      if (key != null) 'key': key,
      if (mddAudioListId != null) 'mdd_audio_list_id': mddAudioListId,
      if (startOffset != null) 'start_offset': startOffset,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MddAudioResourceCompanion copyWith(
      {Value<int>? blockOffset,
      Value<int>? compressedSize,
      Value<int>? endOffset,
      Value<String>? key,
      Value<int>? mddAudioListId,
      Value<int>? startOffset,
      Value<int>? rowid}) {
    return MddAudioResourceCompanion(
      blockOffset: blockOffset ?? this.blockOffset,
      compressedSize: compressedSize ?? this.compressedSize,
      endOffset: endOffset ?? this.endOffset,
      key: key ?? this.key,
      mddAudioListId: mddAudioListId ?? this.mddAudioListId,
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
    if (mddAudioListId.present) {
      map['mdd_audio_list_id'] = Variable<int>(mddAudioListId.value);
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
    return (StringBuffer('MddAudioResourceCompanion(')
          ..write('blockOffset: $blockOffset, ')
          ..write('compressedSize: $compressedSize, ')
          ..write('endOffset: $endOffset, ')
          ..write('key: $key, ')
          ..write('mddAudioListId: $mddAudioListId, ')
          ..write('startOffset: $startOffset, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class AiExplanations extends Table
    with TableInfo<AiExplanations, AiExplanationsData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  AiExplanations(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  late final GeneratedColumn<String> explanation = GeneratedColumn<String>(
      'explanation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [word, explanation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_explanations';
  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  AiExplanationsData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiExplanationsData(
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      explanation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}explanation'])!,
    );
  }

  @override
  AiExplanations createAlias(String alias) {
    return AiExplanations(attachedDatabase, alias);
  }
}

class AiExplanationsData extends DataClass
    implements Insertable<AiExplanationsData> {
  final String word;
  final String explanation;
  const AiExplanationsData({required this.word, required this.explanation});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word'] = Variable<String>(word);
    map['explanation'] = Variable<String>(explanation);
    return map;
  }

  AiExplanationsCompanion toCompanion(bool nullToAbsent) {
    return AiExplanationsCompanion(
      word: Value(word),
      explanation: Value(explanation),
    );
  }

  factory AiExplanationsData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiExplanationsData(
      word: serializer.fromJson<String>(json['word']),
      explanation: serializer.fromJson<String>(json['explanation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
      'explanation': serializer.toJson<String>(explanation),
    };
  }

  AiExplanationsData copyWith({String? word, String? explanation}) =>
      AiExplanationsData(
        word: word ?? this.word,
        explanation: explanation ?? this.explanation,
      );
  AiExplanationsData copyWithCompanion(AiExplanationsCompanion data) {
    return AiExplanationsData(
      word: data.word.present ? data.word.value : this.word,
      explanation:
          data.explanation.present ? data.explanation.value : this.explanation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiExplanationsData(')
          ..write('word: $word, ')
          ..write('explanation: $explanation')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(word, explanation);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiExplanationsData &&
          other.word == this.word &&
          other.explanation == this.explanation);
}

class AiExplanationsCompanion extends UpdateCompanion<AiExplanationsData> {
  final Value<String> word;
  final Value<String> explanation;
  final Value<int> rowid;
  const AiExplanationsCompanion({
    this.word = const Value.absent(),
    this.explanation = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiExplanationsCompanion.insert({
    required String word,
    required String explanation,
    this.rowid = const Value.absent(),
  })  : word = Value(word),
        explanation = Value(explanation);
  static Insertable<AiExplanationsData> custom({
    Expression<String>? word,
    Expression<String>? explanation,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (word != null) 'word': word,
      if (explanation != null) 'explanation': explanation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiExplanationsCompanion copyWith(
      {Value<String>? word, Value<String>? explanation, Value<int>? rowid}) {
    return AiExplanationsCompanion(
      word: word ?? this.word,
      explanation: explanation ?? this.explanation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (word.present) {
      map['word'] = Variable<String>(word.value);
    }
    if (explanation.present) {
      map['explanation'] = Variable<String>(explanation.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiExplanationsCompanion(')
          ..write('word: $word, ')
          ..write('explanation: $explanation, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class WritingCheckHistory extends Table
    with TableInfo<WritingCheckHistory, WritingCheckHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  WritingCheckHistory(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> inputText = GeneratedColumn<String>(
      'input_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<String> outputText = GeneratedColumn<String>(
      'output_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, inputText, outputText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'writing_check_history';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WritingCheckHistoryData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WritingCheckHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      inputText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}input_text'])!,
      outputText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}output_text'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  WritingCheckHistory createAlias(String alias) {
    return WritingCheckHistory(attachedDatabase, alias);
  }
}

class WritingCheckHistoryData extends DataClass
    implements Insertable<WritingCheckHistoryData> {
  final int id;
  final String inputText;
  final String outputText;
  final DateTime createdAt;
  const WritingCheckHistoryData(
      {required this.id,
      required this.inputText,
      required this.outputText,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['input_text'] = Variable<String>(inputText);
    map['output_text'] = Variable<String>(outputText);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WritingCheckHistoryCompanion toCompanion(bool nullToAbsent) {
    return WritingCheckHistoryCompanion(
      id: Value(id),
      inputText: Value(inputText),
      outputText: Value(outputText),
      createdAt: Value(createdAt),
    );
  }

  factory WritingCheckHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WritingCheckHistoryData(
      id: serializer.fromJson<int>(json['id']),
      inputText: serializer.fromJson<String>(json['inputText']),
      outputText: serializer.fromJson<String>(json['outputText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'inputText': serializer.toJson<String>(inputText),
      'outputText': serializer.toJson<String>(outputText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WritingCheckHistoryData copyWith(
          {int? id,
          String? inputText,
          String? outputText,
          DateTime? createdAt}) =>
      WritingCheckHistoryData(
        id: id ?? this.id,
        inputText: inputText ?? this.inputText,
        outputText: outputText ?? this.outputText,
        createdAt: createdAt ?? this.createdAt,
      );
  WritingCheckHistoryData copyWithCompanion(WritingCheckHistoryCompanion data) {
    return WritingCheckHistoryData(
      id: data.id.present ? data.id.value : this.id,
      inputText: data.inputText.present ? data.inputText.value : this.inputText,
      outputText:
          data.outputText.present ? data.outputText.value : this.outputText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WritingCheckHistoryData(')
          ..write('id: $id, ')
          ..write('inputText: $inputText, ')
          ..write('outputText: $outputText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, inputText, outputText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WritingCheckHistoryData &&
          other.id == this.id &&
          other.inputText == this.inputText &&
          other.outputText == this.outputText &&
          other.createdAt == this.createdAt);
}

class WritingCheckHistoryCompanion
    extends UpdateCompanion<WritingCheckHistoryData> {
  final Value<int> id;
  final Value<String> inputText;
  final Value<String> outputText;
  final Value<DateTime> createdAt;
  const WritingCheckHistoryCompanion({
    this.id = const Value.absent(),
    this.inputText = const Value.absent(),
    this.outputText = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WritingCheckHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String inputText,
    required String outputText,
    required DateTime createdAt,
  })  : inputText = Value(inputText),
        outputText = Value(outputText),
        createdAt = Value(createdAt);
  static Insertable<WritingCheckHistoryData> custom({
    Expression<int>? id,
    Expression<String>? inputText,
    Expression<String>? outputText,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (inputText != null) 'input_text': inputText,
      if (outputText != null) 'output_text': outputText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WritingCheckHistoryCompanion copyWith(
      {Value<int>? id,
      Value<String>? inputText,
      Value<String>? outputText,
      Value<DateTime>? createdAt}) {
    return WritingCheckHistoryCompanion(
      id: id ?? this.id,
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (inputText.present) {
      map['input_text'] = Variable<String>(inputText.value);
    }
    if (outputText.present) {
      map['output_text'] = Variable<String>(outputText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WritingCheckHistoryCompanion(')
          ..write('id: $id, ')
          ..write('inputText: $inputText, ')
          ..write('outputText: $outputText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class TranslateHistory extends Table
    with TableInfo<TranslateHistory, TranslateHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TranslateHistory(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  late final GeneratedColumn<String> inputText = GeneratedColumn<String>(
      'input_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, inputText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translate_history';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranslateHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslateHistoryData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      inputText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}input_text'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  TranslateHistory createAlias(String alias) {
    return TranslateHistory(attachedDatabase, alias);
  }
}

class TranslateHistoryData extends DataClass
    implements Insertable<TranslateHistoryData> {
  final int id;
  final String inputText;
  final DateTime createdAt;
  const TranslateHistoryData(
      {required this.id, required this.inputText, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['input_text'] = Variable<String>(inputText);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TranslateHistoryCompanion toCompanion(bool nullToAbsent) {
    return TranslateHistoryCompanion(
      id: Value(id),
      inputText: Value(inputText),
      createdAt: Value(createdAt),
    );
  }

  factory TranslateHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslateHistoryData(
      id: serializer.fromJson<int>(json['id']),
      inputText: serializer.fromJson<String>(json['inputText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'inputText': serializer.toJson<String>(inputText),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TranslateHistoryData copyWith(
          {int? id, String? inputText, DateTime? createdAt}) =>
      TranslateHistoryData(
        id: id ?? this.id,
        inputText: inputText ?? this.inputText,
        createdAt: createdAt ?? this.createdAt,
      );
  TranslateHistoryData copyWithCompanion(TranslateHistoryCompanion data) {
    return TranslateHistoryData(
      id: data.id.present ? data.id.value : this.id,
      inputText: data.inputText.present ? data.inputText.value : this.inputText,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslateHistoryData(')
          ..write('id: $id, ')
          ..write('inputText: $inputText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, inputText, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslateHistoryData &&
          other.id == this.id &&
          other.inputText == this.inputText &&
          other.createdAt == this.createdAt);
}

class TranslateHistoryCompanion extends UpdateCompanion<TranslateHistoryData> {
  final Value<int> id;
  final Value<String> inputText;
  final Value<DateTime> createdAt;
  const TranslateHistoryCompanion({
    this.id = const Value.absent(),
    this.inputText = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TranslateHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String inputText,
    required DateTime createdAt,
  })  : inputText = Value(inputText),
        createdAt = Value(createdAt);
  static Insertable<TranslateHistoryData> custom({
    Expression<int>? id,
    Expression<String>? inputText,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (inputText != null) 'input_text': inputText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TranslateHistoryCompanion copyWith(
      {Value<int>? id, Value<String>? inputText, Value<DateTime>? createdAt}) {
    return TranslateHistoryCompanion(
      id: id ?? this.id,
      inputText: inputText ?? this.inputText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (inputText.present) {
      map['input_text'] = Variable<String>(inputText.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslateHistoryCompanion(')
          ..write('id: $id, ')
          ..write('inputText: $inputText, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV13 extends GeneratedDatabase {
  DatabaseAtV13(QueryExecutor e) : super(e);
  late final DictionaryList dictionaryList = DictionaryList(this);
  late final Wordbook wordbook = Wordbook(this);
  late final WordbookTags wordbookTags = WordbookTags(this);
  late final History history = History(this);
  late final DictGroup dictGroup = DictGroup(this);
  late final MddAudioList mddAudioList = MddAudioList(this);
  late final MddAudioResource mddAudioResource = MddAudioResource(this);
  late final AiExplanations aiExplanations = AiExplanations(this);
  late final WritingCheckHistory writingCheckHistory =
      WritingCheckHistory(this);
  late final TranslateHistory translateHistory = TranslateHistory(this);
  late final Index idxWordbook = Index('idx_wordbook',
      'CREATE INDEX idx_wordbook ON wordbook (word, created_at)');
  late final Index idxWordbookTags = Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  late final Index idxMddAudioResource = Index('idx_mdd_audio_resource',
      'CREATE INDEX idx_mdd_audio_resource ON mdd_audio_resource ("key")');
  late final Index idxAiExplanations = Index('idx_ai_explanations',
      'CREATE INDEX idx_ai_explanations ON ai_explanations (word)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        dictionaryList,
        wordbook,
        wordbookTags,
        history,
        dictGroup,
        mddAudioList,
        mddAudioResource,
        aiExplanations,
        writingCheckHistory,
        translateHistory,
        idxWordbook,
        idxWordbookTags,
        idxMddAudioResource,
        idxAiExplanations
      ];
  @override
  int get schemaVersion => 13;
}
