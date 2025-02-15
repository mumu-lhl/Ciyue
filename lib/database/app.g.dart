// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// ignore_for_file: type=lint
class $DictionaryListTable extends DictionaryList
    with drift.TableInfo<$DictionaryListTable, DictionaryListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryListTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _fontPathMeta =
      const drift.VerificationMeta('fontPath');
  @override
  late final drift.GeneratedColumn<String> fontPath =
      drift.GeneratedColumn<String>('font_path', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const drift.VerificationMeta _aliasMeta =
      const drift.VerificationMeta('alias');
  @override
  late final drift.GeneratedColumn<String> alias =
      drift.GeneratedColumn<String>('alias', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<drift.GeneratedColumn> get $columns => [fontPath, id, path, alias];
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
    if (data.containsKey('font_path')) {
      context.handle(_fontPathMeta,
          fontPath.isAcceptableOrUnknown(data['font_path']!, _fontPathMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias']),
    );
  }

  @override
  $DictionaryListTable createAlias(String alias) {
    return $DictionaryListTable(attachedDatabase, alias);
  }
}

class DictionaryListData extends drift.DataClass
    implements drift.Insertable<DictionaryListData> {
  final String? fontPath;
  final int id;
  final String path;
  final String? alias;
  const DictionaryListData(
      {this.fontPath, required this.id, required this.path, this.alias});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = drift.Variable<String>(fontPath);
    }
    map['id'] = drift.Variable<int>(id);
    map['path'] = drift.Variable<String>(path);
    if (!nullToAbsent || alias != null) {
      map['alias'] = drift.Variable<String>(alias);
    }
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      fontPath: fontPath == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(fontPath),
      id: drift.Value(id),
      path: drift.Value(path),
      alias: alias == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(alias),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      alias: serializer.fromJson<String?>(json['alias']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'alias': serializer.toJson<String?>(alias),
    };
  }

  DictionaryListData copyWith(
          {drift.Value<String?> fontPath = const drift.Value.absent(),
          int? id,
          String? path,
          drift.Value<String?> alias = const drift.Value.absent()}) =>
      DictionaryListData(
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
        id: id ?? this.id,
        path: path ?? this.path,
        alias: alias.present ? alias.value : this.alias,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      alias: data.alias.present ? data.alias.value : this.alias,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('alias: $alias')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fontPath, id, path, alias);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.fontPath == this.fontPath &&
          other.id == this.id &&
          other.path == this.path &&
          other.alias == this.alias);
}

class DictionaryListCompanion
    extends drift.UpdateCompanion<DictionaryListData> {
  final drift.Value<String?> fontPath;
  final drift.Value<int> id;
  final drift.Value<String> path;
  final drift.Value<String?> alias;
  const DictionaryListCompanion({
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
    this.alias = const drift.Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    required String path,
    this.alias = const drift.Value.absent(),
  }) : path = drift.Value(path);
  static drift.Insertable<DictionaryListData> custom({
    drift.Expression<String>? fontPath,
    drift.Expression<int>? id,
    drift.Expression<String>? path,
    drift.Expression<String>? alias,
  }) {
    return drift.RawValuesInsertable({
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (alias != null) 'alias': alias,
    });
  }

  DictionaryListCompanion copyWith(
      {drift.Value<String?>? fontPath,
      drift.Value<int>? id,
      drift.Value<String>? path,
      drift.Value<String?>? alias}) {
    return DictionaryListCompanion(
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      path: path ?? this.path,
      alias: alias ?? this.alias,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (fontPath.present) {
      map['font_path'] = drift.Variable<String>(fontPath.value);
    }
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = drift.Variable<String>(path.value);
    }
    if (alias.present) {
      map['alias'] = drift.Variable<String>(alias.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('alias: $alias')
          ..write(')'))
        .toString();
  }
}

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

class $HistoryTable extends History
    with drift.TableInfo<$HistoryTable, HistoryData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _wordMeta =
      const drift.VerificationMeta('word');
  @override
  late final drift.GeneratedColumn<String> word = drift.GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [id, word];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<HistoryData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
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
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $HistoryTable createAlias(String alias) {
    return $HistoryTable(attachedDatabase, alias);
  }
}

class HistoryData extends drift.DataClass
    implements drift.Insertable<HistoryData> {
  final int id;
  final String word;
  const HistoryData({required this.id, required this.word});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['word'] = drift.Variable<String>(word);
    return map;
  }

  HistoryCompanion toCompanion(bool nullToAbsent) {
    return HistoryCompanion(
      id: drift.Value(id),
      word: drift.Value(word),
    );
  }

  factory HistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return HistoryData(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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

class HistoryCompanion extends drift.UpdateCompanion<HistoryData> {
  final drift.Value<int> id;
  final drift.Value<String> word;
  const HistoryCompanion({
    this.id = const drift.Value.absent(),
    this.word = const drift.Value.absent(),
  });
  HistoryCompanion.insert({
    this.id = const drift.Value.absent(),
    required String word,
  }) : word = drift.Value(word);
  static drift.Insertable<HistoryData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? word,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
    });
  }

  HistoryCompanion copyWith({drift.Value<int>? id, drift.Value<String>? word}) {
    return HistoryCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (word.present) {
      map['word'] = drift.Variable<String>(word.value);
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

class $DictGroupTable extends DictGroup
    with drift.TableInfo<$DictGroupTable, DictGroupData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictGroupTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _dictIdsMeta =
      const drift.VerificationMeta('dictIds');
  @override
  late final drift.GeneratedColumn<String> dictIds =
      drift.GeneratedColumn<String>('dict_ids', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const drift.VerificationMeta _nameMeta =
      const drift.VerificationMeta('name');
  @override
  late final drift.GeneratedColumn<String> name = drift.GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  @override
  List<drift.GeneratedColumn> get $columns => [dictIds, id, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dict_group';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<DictGroupData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dict_ids')) {
      context.handle(_dictIdsMeta,
          dictIds.isAcceptableOrUnknown(data['dict_ids']!, _dictIdsMeta));
    } else if (isInserting) {
      context.missing(_dictIdsMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $DictGroupTable createAlias(String alias) {
    return $DictGroupTable(attachedDatabase, alias);
  }
}

class DictGroupData extends drift.DataClass
    implements drift.Insertable<DictGroupData> {
  final String dictIds;
  final int id;
  final String name;
  const DictGroupData(
      {required this.dictIds, required this.id, required this.name});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['dict_ids'] = drift.Variable<String>(dictIds);
    map['id'] = drift.Variable<int>(id);
    map['name'] = drift.Variable<String>(name);
    return map;
  }

  DictGroupCompanion toCompanion(bool nullToAbsent) {
    return DictGroupCompanion(
      dictIds: drift.Value(dictIds),
      id: drift.Value(id),
      name: drift.Value(name),
    );
  }

  factory DictGroupData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictGroupData(
      dictIds: serializer.fromJson<String>(json['dictIds']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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

class DictGroupCompanion extends drift.UpdateCompanion<DictGroupData> {
  final drift.Value<String> dictIds;
  final drift.Value<int> id;
  final drift.Value<String> name;
  const DictGroupCompanion({
    this.dictIds = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    this.name = const drift.Value.absent(),
  });
  DictGroupCompanion.insert({
    required String dictIds,
    this.id = const drift.Value.absent(),
    required String name,
  })  : dictIds = drift.Value(dictIds),
        name = drift.Value(name);
  static drift.Insertable<DictGroupData> custom({
    drift.Expression<String>? dictIds,
    drift.Expression<int>? id,
    drift.Expression<String>? name,
  }) {
    return drift.RawValuesInsertable({
      if (dictIds != null) 'dict_ids': dictIds,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  DictGroupCompanion copyWith(
      {drift.Value<String>? dictIds,
      drift.Value<int>? id,
      drift.Value<String>? name}) {
    return DictGroupCompanion(
      dictIds: dictIds ?? this.dictIds,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (dictIds.present) {
      map['dict_ids'] = drift.Variable<String>(dictIds.value);
    }
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = drift.Variable<String>(name.value);
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

abstract class _$AppDatabase extends drift.GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DictionaryListTable dictionaryList = $DictionaryListTable(this);
  late final $WordbookTable wordbook = $WordbookTable(this);
  late final $WordbookTagsTable wordbookTags = $WordbookTagsTable(this);
  late final $HistoryTable history = $HistoryTable(this);
  late final $DictGroupTable dictGroup = $DictGroupTable(this);
  late final drift.Index idxWordbook = drift.Index(
      'idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  late final drift.Index idxWordbookTags = drift.Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities => [
        dictionaryList,
        wordbook,
        wordbookTags,
        history,
        dictGroup,
        idxWordbook,
        idxWordbookTags
      ];
}

typedef $$DictionaryListTableCreateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  required String path,
  drift.Value<String?> alias,
});
typedef $$DictionaryListTableUpdateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  drift.Value<String> path,
  drift.Value<String?> alias,
});

class $$DictionaryListTableFilterComposer
    extends drift.Composer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => drift.ColumnFilters(column));
}

class $$DictionaryListTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => drift.ColumnOrderings(column));
}

class $$DictionaryListTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<String> get fontPath =>
      $composableBuilder(column: $table.fontPath, builder: (column) => column);

  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  drift.GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);
}

class $$DictionaryListTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $DictionaryListTable,
    DictionaryListData,
    $$DictionaryListTableFilterComposer,
    $$DictionaryListTableOrderingComposer,
    $$DictionaryListTableAnnotationComposer,
    $$DictionaryListTableCreateCompanionBuilder,
    $$DictionaryListTableUpdateCompanionBuilder,
    (
      DictionaryListData,
      drift
      .BaseReferences<_$AppDatabase, $DictionaryListTable, DictionaryListData>
    ),
    DictionaryListData,
    drift.PrefetchHooks Function()> {
  $$DictionaryListTableTableManager(
      _$AppDatabase db, $DictionaryListTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictionaryListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictionaryListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictionaryListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
            drift.Value<String?> alias = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion(
            fontPath: fontPath,
            id: id,
            path: path,
            alias: alias,
          ),
          createCompanionCallback: ({
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            required String path,
            drift.Value<String?> alias = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion.insert(
            fontPath: fontPath,
            id: id,
            path: path,
            alias: alias,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DictionaryListTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $DictionaryListTable,
        DictionaryListData,
        $$DictionaryListTableFilterComposer,
        $$DictionaryListTableOrderingComposer,
        $$DictionaryListTableAnnotationComposer,
        $$DictionaryListTableCreateCompanionBuilder,
        $$DictionaryListTableUpdateCompanionBuilder,
        (
          DictionaryListData,
          drift.BaseReferences<_$AppDatabase, $DictionaryListTable,
              DictionaryListData>
        ),
        DictionaryListData,
        drift.PrefetchHooks Function()>;
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
    extends drift.Composer<_$AppDatabase, $WordbookTable> {
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
    extends drift.Composer<_$AppDatabase, $WordbookTable> {
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
    extends drift.Composer<_$AppDatabase, $WordbookTable> {
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
    _$AppDatabase,
    $WordbookTable,
    WordbookData,
    $$WordbookTableFilterComposer,
    $$WordbookTableOrderingComposer,
    $$WordbookTableAnnotationComposer,
    $$WordbookTableCreateCompanionBuilder,
    $$WordbookTableUpdateCompanionBuilder,
    (
      WordbookData,
      drift.BaseReferences<_$AppDatabase, $WordbookTable, WordbookData>
    ),
    WordbookData,
    drift.PrefetchHooks Function()> {
  $$WordbookTableTableManager(_$AppDatabase db, $WordbookTable table)
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
    _$AppDatabase,
    $WordbookTable,
    WordbookData,
    $$WordbookTableFilterComposer,
    $$WordbookTableOrderingComposer,
    $$WordbookTableAnnotationComposer,
    $$WordbookTableCreateCompanionBuilder,
    $$WordbookTableUpdateCompanionBuilder,
    (
      WordbookData,
      drift.BaseReferences<_$AppDatabase, $WordbookTable, WordbookData>
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
    extends drift.Composer<_$AppDatabase, $WordbookTagsTable> {
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
    extends drift.Composer<_$AppDatabase, $WordbookTagsTable> {
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
    extends drift.Composer<_$AppDatabase, $WordbookTagsTable> {
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
    _$AppDatabase,
    $WordbookTagsTable,
    WordbookTag,
    $$WordbookTagsTableFilterComposer,
    $$WordbookTagsTableOrderingComposer,
    $$WordbookTagsTableAnnotationComposer,
    $$WordbookTagsTableCreateCompanionBuilder,
    $$WordbookTagsTableUpdateCompanionBuilder,
    (
      WordbookTag,
      drift.BaseReferences<_$AppDatabase, $WordbookTagsTable, WordbookTag>
    ),
    WordbookTag,
    drift.PrefetchHooks Function()> {
  $$WordbookTagsTableTableManager(_$AppDatabase db, $WordbookTagsTable table)
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
    _$AppDatabase,
    $WordbookTagsTable,
    WordbookTag,
    $$WordbookTagsTableFilterComposer,
    $$WordbookTagsTableOrderingComposer,
    $$WordbookTagsTableAnnotationComposer,
    $$WordbookTagsTableCreateCompanionBuilder,
    $$WordbookTagsTableUpdateCompanionBuilder,
    (
      WordbookTag,
      drift.BaseReferences<_$AppDatabase, $WordbookTagsTable, WordbookTag>
    ),
    WordbookTag,
    drift.PrefetchHooks Function()>;
typedef $$HistoryTableCreateCompanionBuilder = HistoryCompanion Function({
  drift.Value<int> id,
  required String word,
});
typedef $$HistoryTableUpdateCompanionBuilder = HistoryCompanion Function({
  drift.Value<int> id,
  drift.Value<String> word,
});

class $$HistoryTableFilterComposer
    extends drift.Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnFilters(column));
}

class $$HistoryTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnOrderings(column));
}

class $$HistoryTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $HistoryTable> {
  $$HistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);
}

class $$HistoryTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $HistoryTable,
    HistoryData,
    $$HistoryTableFilterComposer,
    $$HistoryTableOrderingComposer,
    $$HistoryTableAnnotationComposer,
    $$HistoryTableCreateCompanionBuilder,
    $$HistoryTableUpdateCompanionBuilder,
    (
      HistoryData,
      drift.BaseReferences<_$AppDatabase, $HistoryTable, HistoryData>
    ),
    HistoryData,
    drift.PrefetchHooks Function()> {
  $$HistoryTableTableManager(_$AppDatabase db, $HistoryTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> word = const drift.Value.absent(),
          }) =>
              HistoryCompanion(
            id: id,
            word: word,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String word,
          }) =>
              HistoryCompanion.insert(
            id: id,
            word: word,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HistoryTableProcessedTableManager = drift.ProcessedTableManager<
    _$AppDatabase,
    $HistoryTable,
    HistoryData,
    $$HistoryTableFilterComposer,
    $$HistoryTableOrderingComposer,
    $$HistoryTableAnnotationComposer,
    $$HistoryTableCreateCompanionBuilder,
    $$HistoryTableUpdateCompanionBuilder,
    (
      HistoryData,
      drift.BaseReferences<_$AppDatabase, $HistoryTable, HistoryData>
    ),
    HistoryData,
    drift.PrefetchHooks Function()>;
typedef $$DictGroupTableCreateCompanionBuilder = DictGroupCompanion Function({
  required String dictIds,
  drift.Value<int> id,
  required String name,
});
typedef $$DictGroupTableUpdateCompanionBuilder = DictGroupCompanion Function({
  drift.Value<String> dictIds,
  drift.Value<int> id,
  drift.Value<String> name,
});

class $$DictGroupTableFilterComposer
    extends drift.Composer<_$AppDatabase, $DictGroupTable> {
  $$DictGroupTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<String> get dictIds => $composableBuilder(
      column: $table.dictIds, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => drift.ColumnFilters(column));
}

class $$DictGroupTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $DictGroupTable> {
  $$DictGroupTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<String> get dictIds => $composableBuilder(
      column: $table.dictIds,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => drift.ColumnOrderings(column));
}

class $$DictGroupTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $DictGroupTable> {
  $$DictGroupTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<String> get dictIds =>
      $composableBuilder(column: $table.dictIds, builder: (column) => column);

  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$DictGroupTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $DictGroupTable,
    DictGroupData,
    $$DictGroupTableFilterComposer,
    $$DictGroupTableOrderingComposer,
    $$DictGroupTableAnnotationComposer,
    $$DictGroupTableCreateCompanionBuilder,
    $$DictGroupTableUpdateCompanionBuilder,
    (
      DictGroupData,
      drift.BaseReferences<_$AppDatabase, $DictGroupTable, DictGroupData>
    ),
    DictGroupData,
    drift.PrefetchHooks Function()> {
  $$DictGroupTableTableManager(_$AppDatabase db, $DictGroupTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DictGroupTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DictGroupTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DictGroupTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<String> dictIds = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> name = const drift.Value.absent(),
          }) =>
              DictGroupCompanion(
            dictIds: dictIds,
            id: id,
            name: name,
          ),
          createCompanionCallback: ({
            required String dictIds,
            drift.Value<int> id = const drift.Value.absent(),
            required String name,
          }) =>
              DictGroupCompanion.insert(
            dictIds: dictIds,
            id: id,
            name: name,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DictGroupTableProcessedTableManager = drift.ProcessedTableManager<
    _$AppDatabase,
    $DictGroupTable,
    DictGroupData,
    $$DictGroupTableFilterComposer,
    $$DictGroupTableOrderingComposer,
    $$DictGroupTableAnnotationComposer,
    $$DictGroupTableCreateCompanionBuilder,
    $$DictGroupTableUpdateCompanionBuilder,
    (
      DictGroupData,
      drift.BaseReferences<_$AppDatabase, $DictGroupTable, DictGroupData>
    ),
    DictGroupData,
    drift.PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DictionaryListTableTableManager get dictionaryList =>
      $$DictionaryListTableTableManager(_db, _db.dictionaryList);
  $$WordbookTableTableManager get wordbook =>
      $$WordbookTableTableManager(_db, _db.wordbook);
  $$WordbookTagsTableTableManager get wordbookTags =>
      $$WordbookTagsTableTableManager(_db, _db.wordbookTags);
  $$HistoryTableTableManager get history =>
      $$HistoryTableTableManager(_db, _db.history);
  $$DictGroupTableTableManager get dictGroup =>
      $$DictGroupTableTableManager(_db, _db.dictGroup);
}

mixin _$DictGroupDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictGroupTable get dictGroup => attachedDatabase.dictGroup;
}
mixin _$DictionaryListDaoMixin on DatabaseAccessor<AppDatabase> {
  $DictionaryListTable get dictionaryList => attachedDatabase.dictionaryList;
}
mixin _$HistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $HistoryTable get history => attachedDatabase.history;
}
mixin _$WordbookDaoMixin on DatabaseAccessor<AppDatabase> {
  $WordbookTable get wordbook => attachedDatabase.wordbook;
}
mixin _$WordbookTagsDaoMixin on DatabaseAccessor<AppDatabase> {
  $WordbookTagsTable get wordbookTags => attachedDatabase.wordbookTags;
}
