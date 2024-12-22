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
  late final GeneratedColumn<String> backupPath = GeneratedColumn<String>(
      'backup_path', aliasedName, true,
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
  @override
  List<GeneratedColumn> get $columns => [backupPath, fontPath, id, path];
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
      backupPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}backup_path']),
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
  final String? backupPath;
  final String? fontPath;
  final int id;
  final String path;
  const DictionaryListData(
      {this.backupPath, this.fontPath, required this.id, required this.path});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (!nullToAbsent || backupPath != null) {
      map['backup_path'] = Variable<String>(backupPath);
    }
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = Variable<String>(fontPath);
    }
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      backupPath: backupPath == null && nullToAbsent
          ? const Value.absent()
          : Value(backupPath),
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
      backupPath: serializer.fromJson<String?>(json['backupPath']),
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'backupPath': serializer.toJson<String?>(backupPath),
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  DictionaryListData copyWith(
          {Value<String?> backupPath = const Value.absent(),
          Value<String?> fontPath = const Value.absent(),
          int? id,
          String? path}) =>
      DictionaryListData(
        backupPath: backupPath.present ? backupPath.value : this.backupPath,
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
        id: id ?? this.id,
        path: path ?? this.path,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      backupPath:
          data.backupPath.present ? data.backupPath.value : this.backupPath,
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('backupPath: $backupPath, ')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(backupPath, fontPath, id, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.backupPath == this.backupPath &&
          other.fontPath == this.fontPath &&
          other.id == this.id &&
          other.path == this.path);
}

class DictionaryListCompanion extends UpdateCompanion<DictionaryListData> {
  final Value<String?> backupPath;
  final Value<String?> fontPath;
  final Value<int> id;
  final Value<String> path;
  const DictionaryListCompanion({
    this.backupPath = const Value.absent(),
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    this.path = const Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.backupPath = const Value.absent(),
    this.fontPath = const Value.absent(),
    this.id = const Value.absent(),
    required String path,
  }) : path = Value(path);
  static Insertable<DictionaryListData> custom({
    Expression<String>? backupPath,
    Expression<String>? fontPath,
    Expression<int>? id,
    Expression<String>? path,
  }) {
    return RawValuesInsertable({
      if (backupPath != null) 'backup_path': backupPath,
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  DictionaryListCompanion copyWith(
      {Value<String?>? backupPath,
      Value<String?>? fontPath,
      Value<int>? id,
      Value<String>? path}) {
    return DictionaryListCompanion(
      backupPath: backupPath ?? this.backupPath,
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      path: path ?? this.path,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (backupPath.present) {
      map['backup_path'] = Variable<String>(backupPath.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('backupPath: $backupPath, ')
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

class DatabaseAtV4 extends GeneratedDatabase {
  DatabaseAtV4(QueryExecutor e) : super(e);
  late final DictionaryList dictionaryList = DictionaryList(this);
  late final Wordbook wordbook = Wordbook(this);
  late final WordbookTags wordbookTags = WordbookTags(this);
  late final Index idxWordbook =
      Index('idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  late final Index idxWordbookTags = Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [dictionaryList, wordbook, wordbookTags, idxWordbook, idxWordbookTags];
  @override
  int get schemaVersion => 4;
}
