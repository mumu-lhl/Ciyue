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
  @override
  List<GeneratedColumn> get $columns => [fontPath, id, path];
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
      fontPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_path']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
    );
  }

  @override
  DictionaryList createAlias(String alias) {
    return DictionaryList(attachedDatabase, alias);
  }
}

class DictionaryListData extends DataClass
    implements Insertable<DictionaryListData> {
  final String? fontPath;
  final int id;
  final String path;
  const DictionaryListData(
      {this.fontPath, required this.id, required this.path});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = Variable<String>(fontPath);
    }
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      fontPath: fontPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fontPath),
      id: Value(id),
      path: Value(path),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  DictionaryListData copyWith(
          {Value<String?> fontPath = const Value.absent(),
          int? id,
          String? path}) =>
      DictionaryListData(
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
        id: id ?? this.id,
        path: path ?? this.path,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fontPath, id, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.fontPath == this.fontPath &&
          other.id == this.id &&
          other.path == this.path);
}

class DictionaryListCompanion extends UpdateCompanion<DictionaryListData> {
  final Value<String?> fontPath;
  final Value<int> id;
  final Value<String> path;
  const DictionaryListCompanion({
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    this.path = const Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    required String path,
  }) : path = Value(path);
  static Insertable<DictionaryListData> custom({
    Expression<String>? fontPath,
    Expression<int>? id,
    Expression<String>? path,
  }) {
    return RawValuesInsertable({
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  DictionaryListCompanion copyWith(
      {Value<String?>? fontPath, Value<int>? id, Value<String>? path}) {
    return DictionaryListCompanion(
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      path: path ?? this.path,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fontPath.present) {
      map['font_path'] = Variable<String>(fontPath.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }
}

class Wordbook extends Table with TableInfo<Wordbook, WordbookData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Wordbook(this.attachedDatabase, [this._alias]);
  late final GeneratedColumn<int> tag = GeneratedColumn<int>(
      'tag', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  late final GeneratedColumn<String> word = GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [tag, word];
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
  final int? tag;
  final String word;
  const WordbookData({this.tag, required this.word});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<int>(tag);
    }
    map['word'] = Variable<String>(word);
    return map;
  }

  WordbookCompanion toCompanion(bool nullToAbsent) {
    return WordbookCompanion(
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      word: Value(word),
    );
  }

  factory WordbookData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordbookData(
      tag: serializer.fromJson<int?>(json['tag']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<int?>(tag),
      'word': serializer.toJson<String>(word),
    };
  }

  WordbookData copyWith(
          {Value<int?> tag = const Value.absent(), String? word}) =>
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

class WordbookCompanion extends UpdateCompanion<WordbookData> {
  final Value<int?> tag;
  final Value<String> word;
  final Value<int> rowid;
  const WordbookCompanion({
    this.tag = const Value.absent(),
    this.word = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordbookCompanion.insert({
    this.tag = const Value.absent(),
    required String word,
    this.rowid = const Value.absent(),
  }) : word = Value(word);
  static Insertable<WordbookData> custom({
    Expression<int>? tag,
    Expression<String>? word,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (word != null) 'word': word,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordbookCompanion copyWith(
      {Value<int?>? tag, Value<String>? word, Value<int>? rowid}) {
    return WordbookCompanion(
      tag: tag ?? this.tag,
      word: word ?? this.word,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
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
      type: DriftSqlType.string, requiredDuringInsert: true);
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

class DatabaseAtV6 extends GeneratedDatabase {
  DatabaseAtV6(QueryExecutor e) : super(e);
  late final DictionaryList dictionaryList = DictionaryList(this);
  late final Wordbook wordbook = Wordbook(this);
  late final WordbookTags wordbookTags = WordbookTags(this);
  late final History history = History(this);
  late final DictGroup dictGroup = DictGroup(this);
  late final Index idxWordbook =
      Index('idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  late final Index idxWordbookTags = Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
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
        idxWordbook,
        idxWordbookTags
      ];
  @override
  int get schemaVersion => 6;
}
