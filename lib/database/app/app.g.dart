// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// ignore_for_file: type=lint
class $DictionaryListTable extends DictionaryList
    with drift.TableInfo<$DictionaryListTable, DictionaryListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryListTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _titleMeta =
      const drift.VerificationMeta('title');
  @override
  late final drift.GeneratedColumn<String> title =
      drift.GeneratedColumn<String>('title', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
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
  static const drift.VerificationMeta _orderMeta =
      const drift.VerificationMeta('order');
  @override
  late final drift.GeneratedColumn<int> order = drift.GeneratedColumn<int>(
      'order', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const drift.VerificationMeta _pathMeta =
      const drift.VerificationMeta('path');
  @override
  late final drift.GeneratedColumn<String> path = drift.GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _typeMeta =
      const drift.VerificationMeta('type');
  @override
  late final drift.GeneratedColumn<int> type = drift.GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const drift.Constant(0));
  @override
  List<drift.GeneratedColumn> get $columns =>
      [title, fontPath, id, order, path, type];
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
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('font_path')) {
      context.handle(_fontPathMeta,
          fontPath.isAcceptableOrUnknown(data['font_path']!, _fontPathMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
  @override
  DictionaryListData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DictionaryListData(
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      fontPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_path']),
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order']),
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
    );
  }

  @override
  $DictionaryListTable createAlias(String alias) {
    return $DictionaryListTable(attachedDatabase, alias);
  }
}

class DictionaryListData extends drift.DataClass
    implements drift.Insertable<DictionaryListData> {
  final String? title;
  final String? fontPath;
  final int id;
  final int? order;
  final String path;
  final int type;
  const DictionaryListData(
      {this.title,
      this.fontPath,
      required this.id,
      this.order,
      required this.path,
      required this.type});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (!nullToAbsent || title != null) {
      map['title'] = drift.Variable<String>(title);
    }
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = drift.Variable<String>(fontPath);
    }
    map['id'] = drift.Variable<int>(id);
    if (!nullToAbsent || order != null) {
      map['order'] = drift.Variable<int>(order);
    }
    map['path'] = drift.Variable<String>(path);
    map['type'] = drift.Variable<int>(type);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      title: title == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(title),
      fontPath: fontPath == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(fontPath),
      id: drift.Value(id),
      order: order == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(order),
      path: drift.Value(path),
      type: drift.Value(type),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      title: serializer.fromJson<String?>(json['title']),
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      order: serializer.fromJson<int?>(json['order']),
      path: serializer.fromJson<String>(json['path']),
      type: serializer.fromJson<int>(json['type']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'title': serializer.toJson<String?>(title),
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'order': serializer.toJson<int?>(order),
      'path': serializer.toJson<String>(path),
      'type': serializer.toJson<int>(type),
    };
  }

  DictionaryListData copyWith(
          {drift.Value<String?> title = const drift.Value.absent(),
          drift.Value<String?> fontPath = const drift.Value.absent(),
          int? id,
          drift.Value<int?> order = const drift.Value.absent(),
          String? path,
          int? type}) =>
      DictionaryListData(
        title: title.present ? title.value : this.title,
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
        id: id ?? this.id,
        order: order.present ? order.value : this.order,
        path: path ?? this.path,
        type: type ?? this.type,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      title: data.title.present ? data.title.value : this.title,
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
      id: data.id.present ? data.id.value : this.id,
      order: data.order.present ? data.order.value : this.order,
      path: data.path.present ? data.path.value : this.path,
      type: data.type.present ? data.type.value : this.type,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('title: $title, ')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('order: $order, ')
          ..write('path: $path, ')
          ..write('type: $type')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(title, fontPath, id, order, path, type);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.title == this.title &&
          other.fontPath == this.fontPath &&
          other.id == this.id &&
          other.order == this.order &&
          other.path == this.path &&
          other.type == this.type);
}

class DictionaryListCompanion
    extends drift.UpdateCompanion<DictionaryListData> {
  final drift.Value<String?> title;
  final drift.Value<String?> fontPath;
  final drift.Value<int> id;
  final drift.Value<int?> order;
  final drift.Value<String> path;
  final drift.Value<int> type;
  const DictionaryListCompanion({
    this.title = const drift.Value.absent(),
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    this.order = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
    this.type = const drift.Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.title = const drift.Value.absent(),
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    this.order = const drift.Value.absent(),
    required String path,
    this.type = const drift.Value.absent(),
  }) : path = drift.Value(path);
  static drift.Insertable<DictionaryListData> custom({
    drift.Expression<String>? title,
    drift.Expression<String>? fontPath,
    drift.Expression<int>? id,
    drift.Expression<int>? order,
    drift.Expression<String>? path,
    drift.Expression<int>? type,
  }) {
    return drift.RawValuesInsertable({
      if (title != null) 'title': title,
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (order != null) 'order': order,
      if (path != null) 'path': path,
      if (type != null) 'type': type,
    });
  }

  DictionaryListCompanion copyWith(
      {drift.Value<String?>? title,
      drift.Value<String?>? fontPath,
      drift.Value<int>? id,
      drift.Value<int?>? order,
      drift.Value<String>? path,
      drift.Value<int>? type}) {
    return DictionaryListCompanion(
      title: title ?? this.title,
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      order: order ?? this.order,
      path: path ?? this.path,
      type: type ?? this.type,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (title.present) {
      map['title'] = drift.Variable<String>(title.value);
    }
    if (fontPath.present) {
      map['font_path'] = drift.Variable<String>(fontPath.value);
    }
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (order.present) {
      map['order'] = drift.Variable<int>(order.value);
    }
    if (path.present) {
      map['path'] = drift.Variable<String>(path.value);
    }
    if (type.present) {
      map['type'] = drift.Variable<int>(type.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('title: $title, ')
          ..write('fontPath: $fontPath, ')
          ..write('id: $id, ')
          ..write('order: $order, ')
          ..write('path: $path, ')
          ..write('type: $type')
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
  static const drift.VerificationMeta _createdAtMeta =
      const drift.VerificationMeta('createdAt');
  @override
  late final drift.GeneratedColumn<DateTime> createdAt =
      drift.GeneratedColumn<DateTime>('created_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
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
  List<drift.GeneratedColumn> get $columns => [createdAt, tag, word];
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
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
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
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
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
  final DateTime createdAt;
  final int? tag;
  final String word;
  const WordbookData({required this.createdAt, this.tag, required this.word});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['created_at'] = drift.Variable<DateTime>(createdAt);
    if (!nullToAbsent || tag != null) {
      map['tag'] = drift.Variable<int>(tag);
    }
    map['word'] = drift.Variable<String>(word);
    return map;
  }

  WordbookCompanion toCompanion(bool nullToAbsent) {
    return WordbookCompanion(
      createdAt: drift.Value(createdAt),
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
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      tag: serializer.fromJson<int?>(json['tag']),
      word: serializer.fromJson<String>(json['word']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'tag': serializer.toJson<int?>(tag),
      'word': serializer.toJson<String>(word),
    };
  }

  WordbookData copyWith(
          {DateTime? createdAt,
          drift.Value<int?> tag = const drift.Value.absent(),
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

class WordbookCompanion extends drift.UpdateCompanion<WordbookData> {
  final drift.Value<DateTime> createdAt;
  final drift.Value<int?> tag;
  final drift.Value<String> word;
  final drift.Value<int> rowid;
  const WordbookCompanion({
    this.createdAt = const drift.Value.absent(),
    this.tag = const drift.Value.absent(),
    this.word = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  WordbookCompanion.insert({
    required DateTime createdAt,
    this.tag = const drift.Value.absent(),
    required String word,
    this.rowid = const drift.Value.absent(),
  })  : createdAt = drift.Value(createdAt),
        word = drift.Value(word);
  static drift.Insertable<WordbookData> custom({
    drift.Expression<DateTime>? createdAt,
    drift.Expression<int>? tag,
    drift.Expression<String>? word,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (tag != null) 'tag': tag,
      if (word != null) 'word': word,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordbookCompanion copyWith(
      {drift.Value<DateTime>? createdAt,
      drift.Value<int?>? tag,
      drift.Value<String>? word,
      drift.Value<int>? rowid}) {
    return WordbookCompanion(
      createdAt: createdAt ?? this.createdAt,
      tag: tag ?? this.tag,
      word: word ?? this.word,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (createdAt.present) {
      map['created_at'] = drift.Variable<DateTime>(createdAt.value);
    }
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
          ..write('createdAt: $createdAt, ')
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

class $MddAudioListTable extends MddAudioList
    with drift.TableInfo<$MddAudioListTable, MddAudioListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MddAudioListTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _titleMeta =
      const drift.VerificationMeta('title');
  @override
  late final drift.GeneratedColumn<String> title =
      drift.GeneratedColumn<String>('title', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _orderMeta =
      const drift.VerificationMeta('order');
  @override
  late final drift.GeneratedColumn<int> order = drift.GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [id, path, title, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mdd_audio_list';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<MddAudioListData> instance,
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
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $MddAudioListTable createAlias(String alias) {
    return $MddAudioListTable(attachedDatabase, alias);
  }
}

class MddAudioListData extends drift.DataClass
    implements drift.Insertable<MddAudioListData> {
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
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['path'] = drift.Variable<String>(path);
    map['title'] = drift.Variable<String>(title);
    map['order'] = drift.Variable<int>(order);
    return map;
  }

  MddAudioListCompanion toCompanion(bool nullToAbsent) {
    return MddAudioListCompanion(
      id: drift.Value(id),
      path: drift.Value(path),
      title: drift.Value(title),
      order: drift.Value(order),
    );
  }

  factory MddAudioListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return MddAudioListData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      title: serializer.fromJson<String>(json['title']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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

class MddAudioListCompanion extends drift.UpdateCompanion<MddAudioListData> {
  final drift.Value<int> id;
  final drift.Value<String> path;
  final drift.Value<String> title;
  final drift.Value<int> order;
  const MddAudioListCompanion({
    this.id = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
    this.title = const drift.Value.absent(),
    this.order = const drift.Value.absent(),
  });
  MddAudioListCompanion.insert({
    this.id = const drift.Value.absent(),
    required String path,
    required String title,
    required int order,
  })  : path = drift.Value(path),
        title = drift.Value(title),
        order = drift.Value(order);
  static drift.Insertable<MddAudioListData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? path,
    drift.Expression<String>? title,
    drift.Expression<int>? order,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (title != null) 'title': title,
      if (order != null) 'order': order,
    });
  }

  MddAudioListCompanion copyWith(
      {drift.Value<int>? id,
      drift.Value<String>? path,
      drift.Value<String>? title,
      drift.Value<int>? order}) {
    return MddAudioListCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      order: order ?? this.order,
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
    if (title.present) {
      map['title'] = drift.Variable<String>(title.value);
    }
    if (order.present) {
      map['order'] = drift.Variable<int>(order.value);
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

class $MddAudioResourceTable extends MddAudioResource
    with drift.TableInfo<$MddAudioResourceTable, MddAudioResourceData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MddAudioResourceTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _mddAudioListIdMeta =
      const drift.VerificationMeta('mddAudioListId');
  @override
  late final drift.GeneratedColumn<int> mddAudioListId =
      drift.GeneratedColumn<int>('mdd_audio_list_id', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _startOffsetMeta =
      const drift.VerificationMeta('startOffset');
  @override
  late final drift.GeneratedColumn<int> startOffset =
      drift.GeneratedColumn<int>('start_offset', aliasedName, false,
          type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [
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
  drift.VerificationContext validateIntegrity(
      drift.Insertable<MddAudioResourceData> instance,
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
    if (data.containsKey('mdd_audio_list_id')) {
      context.handle(
          _mddAudioListIdMeta,
          mddAudioListId.isAcceptableOrUnknown(
              data['mdd_audio_list_id']!, _mddAudioListIdMeta));
    } else if (isInserting) {
      context.missing(_mddAudioListIdMeta);
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
  $MddAudioResourceTable createAlias(String alias) {
    return $MddAudioResourceTable(attachedDatabase, alias);
  }
}

class MddAudioResourceData extends drift.DataClass
    implements drift.Insertable<MddAudioResourceData> {
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
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['block_offset'] = drift.Variable<int>(blockOffset);
    map['compressed_size'] = drift.Variable<int>(compressedSize);
    map['end_offset'] = drift.Variable<int>(endOffset);
    map['key'] = drift.Variable<String>(key);
    map['mdd_audio_list_id'] = drift.Variable<int>(mddAudioListId);
    map['start_offset'] = drift.Variable<int>(startOffset);
    return map;
  }

  MddAudioResourceCompanion toCompanion(bool nullToAbsent) {
    return MddAudioResourceCompanion(
      blockOffset: drift.Value(blockOffset),
      compressedSize: drift.Value(compressedSize),
      endOffset: drift.Value(endOffset),
      key: drift.Value(key),
      mddAudioListId: drift.Value(mddAudioListId),
      startOffset: drift.Value(startOffset),
    );
  }

  factory MddAudioResourceData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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

class MddAudioResourceCompanion
    extends drift.UpdateCompanion<MddAudioResourceData> {
  final drift.Value<int> blockOffset;
  final drift.Value<int> compressedSize;
  final drift.Value<int> endOffset;
  final drift.Value<String> key;
  final drift.Value<int> mddAudioListId;
  final drift.Value<int> startOffset;
  final drift.Value<int> rowid;
  const MddAudioResourceCompanion({
    this.blockOffset = const drift.Value.absent(),
    this.compressedSize = const drift.Value.absent(),
    this.endOffset = const drift.Value.absent(),
    this.key = const drift.Value.absent(),
    this.mddAudioListId = const drift.Value.absent(),
    this.startOffset = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  MddAudioResourceCompanion.insert({
    required int blockOffset,
    required int compressedSize,
    required int endOffset,
    required String key,
    required int mddAudioListId,
    required int startOffset,
    this.rowid = const drift.Value.absent(),
  })  : blockOffset = drift.Value(blockOffset),
        compressedSize = drift.Value(compressedSize),
        endOffset = drift.Value(endOffset),
        key = drift.Value(key),
        mddAudioListId = drift.Value(mddAudioListId),
        startOffset = drift.Value(startOffset);
  static drift.Insertable<MddAudioResourceData> custom({
    drift.Expression<int>? blockOffset,
    drift.Expression<int>? compressedSize,
    drift.Expression<int>? endOffset,
    drift.Expression<String>? key,
    drift.Expression<int>? mddAudioListId,
    drift.Expression<int>? startOffset,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
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
      {drift.Value<int>? blockOffset,
      drift.Value<int>? compressedSize,
      drift.Value<int>? endOffset,
      drift.Value<String>? key,
      drift.Value<int>? mddAudioListId,
      drift.Value<int>? startOffset,
      drift.Value<int>? rowid}) {
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
    if (mddAudioListId.present) {
      map['mdd_audio_list_id'] = drift.Variable<int>(mddAudioListId.value);
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

class $AiExplanationsTable extends AiExplanations
    with drift.TableInfo<$AiExplanationsTable, AiExplanation> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiExplanationsTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _wordMeta =
      const drift.VerificationMeta('word');
  @override
  late final drift.GeneratedColumn<String> word = drift.GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const drift.VerificationMeta _explanationMeta =
      const drift.VerificationMeta('explanation');
  @override
  late final drift.GeneratedColumn<String> explanation =
      drift.GeneratedColumn<String>('explanation', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [word, explanation];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_explanations';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<AiExplanation> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word')) {
      context.handle(
          _wordMeta, word.isAcceptableOrUnknown(data['word']!, _wordMeta));
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('explanation')) {
      context.handle(
          _explanationMeta,
          explanation.isAcceptableOrUnknown(
              data['explanation']!, _explanationMeta));
    } else if (isInserting) {
      context.missing(_explanationMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => const {};
  @override
  AiExplanation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiExplanation(
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      explanation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}explanation'])!,
    );
  }

  @override
  $AiExplanationsTable createAlias(String alias) {
    return $AiExplanationsTable(attachedDatabase, alias);
  }
}

class AiExplanation extends drift.DataClass
    implements drift.Insertable<AiExplanation> {
  final String word;
  final String explanation;
  const AiExplanation({required this.word, required this.explanation});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['word'] = drift.Variable<String>(word);
    map['explanation'] = drift.Variable<String>(explanation);
    return map;
  }

  AiExplanationsCompanion toCompanion(bool nullToAbsent) {
    return AiExplanationsCompanion(
      word: drift.Value(word),
      explanation: drift.Value(explanation),
    );
  }

  factory AiExplanation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return AiExplanation(
      word: serializer.fromJson<String>(json['word']),
      explanation: serializer.fromJson<String>(json['explanation']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
      'explanation': serializer.toJson<String>(explanation),
    };
  }

  AiExplanation copyWith({String? word, String? explanation}) => AiExplanation(
        word: word ?? this.word,
        explanation: explanation ?? this.explanation,
      );
  AiExplanation copyWithCompanion(AiExplanationsCompanion data) {
    return AiExplanation(
      word: data.word.present ? data.word.value : this.word,
      explanation:
          data.explanation.present ? data.explanation.value : this.explanation,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiExplanation(')
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
      (other is AiExplanation &&
          other.word == this.word &&
          other.explanation == this.explanation);
}

class AiExplanationsCompanion extends drift.UpdateCompanion<AiExplanation> {
  final drift.Value<String> word;
  final drift.Value<String> explanation;
  final drift.Value<int> rowid;
  const AiExplanationsCompanion({
    this.word = const drift.Value.absent(),
    this.explanation = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  AiExplanationsCompanion.insert({
    required String word,
    required String explanation,
    this.rowid = const drift.Value.absent(),
  })  : word = drift.Value(word),
        explanation = drift.Value(explanation);
  static drift.Insertable<AiExplanation> custom({
    drift.Expression<String>? word,
    drift.Expression<String>? explanation,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (word != null) 'word': word,
      if (explanation != null) 'explanation': explanation,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiExplanationsCompanion copyWith(
      {drift.Value<String>? word,
      drift.Value<String>? explanation,
      drift.Value<int>? rowid}) {
    return AiExplanationsCompanion(
      word: word ?? this.word,
      explanation: explanation ?? this.explanation,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (word.present) {
      map['word'] = drift.Variable<String>(word.value);
    }
    if (explanation.present) {
      map['explanation'] = drift.Variable<String>(explanation.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
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

class $WritingCheckHistoryTable extends WritingCheckHistory
    with drift.TableInfo<$WritingCheckHistoryTable, WritingCheckHistoryData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WritingCheckHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _inputTextMeta =
      const drift.VerificationMeta('inputText');
  @override
  late final drift.GeneratedColumn<String> inputText =
      drift.GeneratedColumn<String>('input_text', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _outputTextMeta =
      const drift.VerificationMeta('outputText');
  @override
  late final drift.GeneratedColumn<String> outputText =
      drift.GeneratedColumn<String>('output_text', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _createdAtMeta =
      const drift.VerificationMeta('createdAt');
  @override
  late final drift.GeneratedColumn<DateTime> createdAt =
      drift.GeneratedColumn<DateTime>('created_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [id, inputText, outputText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'writing_check_history';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<WritingCheckHistoryData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('input_text')) {
      context.handle(_inputTextMeta,
          inputText.isAcceptableOrUnknown(data['input_text']!, _inputTextMeta));
    } else if (isInserting) {
      context.missing(_inputTextMeta);
    }
    if (data.containsKey('output_text')) {
      context.handle(
          _outputTextMeta,
          outputText.isAcceptableOrUnknown(
              data['output_text']!, _outputTextMeta));
    } else if (isInserting) {
      context.missing(_outputTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $WritingCheckHistoryTable createAlias(String alias) {
    return $WritingCheckHistoryTable(attachedDatabase, alias);
  }
}

class WritingCheckHistoryData extends drift.DataClass
    implements drift.Insertable<WritingCheckHistoryData> {
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
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['input_text'] = drift.Variable<String>(inputText);
    map['output_text'] = drift.Variable<String>(outputText);
    map['created_at'] = drift.Variable<DateTime>(createdAt);
    return map;
  }

  WritingCheckHistoryCompanion toCompanion(bool nullToAbsent) {
    return WritingCheckHistoryCompanion(
      id: drift.Value(id),
      inputText: drift.Value(inputText),
      outputText: drift.Value(outputText),
      createdAt: drift.Value(createdAt),
    );
  }

  factory WritingCheckHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return WritingCheckHistoryData(
      id: serializer.fromJson<int>(json['id']),
      inputText: serializer.fromJson<String>(json['inputText']),
      outputText: serializer.fromJson<String>(json['outputText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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
    extends drift.UpdateCompanion<WritingCheckHistoryData> {
  final drift.Value<int> id;
  final drift.Value<String> inputText;
  final drift.Value<String> outputText;
  final drift.Value<DateTime> createdAt;
  const WritingCheckHistoryCompanion({
    this.id = const drift.Value.absent(),
    this.inputText = const drift.Value.absent(),
    this.outputText = const drift.Value.absent(),
    this.createdAt = const drift.Value.absent(),
  });
  WritingCheckHistoryCompanion.insert({
    this.id = const drift.Value.absent(),
    required String inputText,
    required String outputText,
    required DateTime createdAt,
  })  : inputText = drift.Value(inputText),
        outputText = drift.Value(outputText),
        createdAt = drift.Value(createdAt);
  static drift.Insertable<WritingCheckHistoryData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? inputText,
    drift.Expression<String>? outputText,
    drift.Expression<DateTime>? createdAt,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (inputText != null) 'input_text': inputText,
      if (outputText != null) 'output_text': outputText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WritingCheckHistoryCompanion copyWith(
      {drift.Value<int>? id,
      drift.Value<String>? inputText,
      drift.Value<String>? outputText,
      drift.Value<DateTime>? createdAt}) {
    return WritingCheckHistoryCompanion(
      id: id ?? this.id,
      inputText: inputText ?? this.inputText,
      outputText: outputText ?? this.outputText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (inputText.present) {
      map['input_text'] = drift.Variable<String>(inputText.value);
    }
    if (outputText.present) {
      map['output_text'] = drift.Variable<String>(outputText.value);
    }
    if (createdAt.present) {
      map['created_at'] = drift.Variable<DateTime>(createdAt.value);
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

class $TranslateHistoryTable extends TranslateHistory
    with drift.TableInfo<$TranslateHistoryTable, TranslateHistoryData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslateHistoryTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _inputTextMeta =
      const drift.VerificationMeta('inputText');
  @override
  late final drift.GeneratedColumn<String> inputText =
      drift.GeneratedColumn<String>('input_text', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _createdAtMeta =
      const drift.VerificationMeta('createdAt');
  @override
  late final drift.GeneratedColumn<DateTime> createdAt =
      drift.GeneratedColumn<DateTime>('created_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [id, inputText, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translate_history';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<TranslateHistoryData> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('input_text')) {
      context.handle(_inputTextMeta,
          inputText.isAcceptableOrUnknown(data['input_text']!, _inputTextMeta));
    } else if (isInserting) {
      context.missing(_inputTextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $TranslateHistoryTable createAlias(String alias) {
    return $TranslateHistoryTable(attachedDatabase, alias);
  }
}

class TranslateHistoryData extends drift.DataClass
    implements drift.Insertable<TranslateHistoryData> {
  final int id;
  final String inputText;
  final DateTime createdAt;
  const TranslateHistoryData(
      {required this.id, required this.inputText, required this.createdAt});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['input_text'] = drift.Variable<String>(inputText);
    map['created_at'] = drift.Variable<DateTime>(createdAt);
    return map;
  }

  TranslateHistoryCompanion toCompanion(bool nullToAbsent) {
    return TranslateHistoryCompanion(
      id: drift.Value(id),
      inputText: drift.Value(inputText),
      createdAt: drift.Value(createdAt),
    );
  }

  factory TranslateHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return TranslateHistoryData(
      id: serializer.fromJson<int>(json['id']),
      inputText: serializer.fromJson<String>(json['inputText']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
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

class TranslateHistoryCompanion
    extends drift.UpdateCompanion<TranslateHistoryData> {
  final drift.Value<int> id;
  final drift.Value<String> inputText;
  final drift.Value<DateTime> createdAt;
  const TranslateHistoryCompanion({
    this.id = const drift.Value.absent(),
    this.inputText = const drift.Value.absent(),
    this.createdAt = const drift.Value.absent(),
  });
  TranslateHistoryCompanion.insert({
    this.id = const drift.Value.absent(),
    required String inputText,
    required DateTime createdAt,
  })  : inputText = drift.Value(inputText),
        createdAt = drift.Value(createdAt);
  static drift.Insertable<TranslateHistoryData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? inputText,
    drift.Expression<DateTime>? createdAt,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (inputText != null) 'input_text': inputText,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TranslateHistoryCompanion copyWith(
      {drift.Value<int>? id,
      drift.Value<String>? inputText,
      drift.Value<DateTime>? createdAt}) {
    return TranslateHistoryCompanion(
      id: id ?? this.id,
      inputText: inputText ?? this.inputText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (inputText.present) {
      map['input_text'] = drift.Variable<String>(inputText.value);
    }
    if (createdAt.present) {
      map['created_at'] = drift.Variable<DateTime>(createdAt.value);
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

class $OpenRecordsTable extends OpenRecords
    with drift.TableInfo<$OpenRecordsTable, OpenRecord> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OpenRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _createdAtMeta =
      const drift.VerificationMeta('createdAt');
  @override
  late final drift.GeneratedColumn<DateTime> createdAt =
      drift.GeneratedColumn<DateTime>('created_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [id, word, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'open_records';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<OpenRecord> instance,
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
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
  @override
  OpenRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OpenRecord(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OpenRecordsTable createAlias(String alias) {
    return $OpenRecordsTable(attachedDatabase, alias);
  }
}

class OpenRecord extends drift.DataClass
    implements drift.Insertable<OpenRecord> {
  final int id;
  final String word;
  final DateTime createdAt;
  const OpenRecord(
      {required this.id, required this.word, required this.createdAt});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['word'] = drift.Variable<String>(word);
    map['created_at'] = drift.Variable<DateTime>(createdAt);
    return map;
  }

  OpenRecordsCompanion toCompanion(bool nullToAbsent) {
    return OpenRecordsCompanion(
      id: drift.Value(id),
      word: drift.Value(word),
      createdAt: drift.Value(createdAt),
    );
  }

  factory OpenRecord.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return OpenRecord(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OpenRecord copyWith({int? id, String? word, DateTime? createdAt}) =>
      OpenRecord(
        id: id ?? this.id,
        word: word ?? this.word,
        createdAt: createdAt ?? this.createdAt,
      );
  OpenRecord copyWithCompanion(OpenRecordsCompanion data) {
    return OpenRecord(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OpenRecord(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OpenRecord &&
          other.id == this.id &&
          other.word == this.word &&
          other.createdAt == this.createdAt);
}

class OpenRecordsCompanion extends drift.UpdateCompanion<OpenRecord> {
  final drift.Value<int> id;
  final drift.Value<String> word;
  final drift.Value<DateTime> createdAt;
  const OpenRecordsCompanion({
    this.id = const drift.Value.absent(),
    this.word = const drift.Value.absent(),
    this.createdAt = const drift.Value.absent(),
  });
  OpenRecordsCompanion.insert({
    this.id = const drift.Value.absent(),
    required String word,
    required DateTime createdAt,
  })  : word = drift.Value(word),
        createdAt = drift.Value(createdAt);
  static drift.Insertable<OpenRecord> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? word,
    drift.Expression<DateTime>? createdAt,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OpenRecordsCompanion copyWith(
      {drift.Value<int>? id,
      drift.Value<String>? word,
      drift.Value<DateTime>? createdAt}) {
    return OpenRecordsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      createdAt: createdAt ?? this.createdAt,
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
    if (createdAt.present) {
      map['created_at'] = drift.Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OpenRecordsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $FlashcardsTable extends Flashcards
    with drift.TableInfo<$FlashcardsTable, Flashcard> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardsTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _wordMeta =
      const drift.VerificationMeta('word');
  @override
  late final drift.GeneratedColumn<String> word = drift.GeneratedColumn<String>(
      'word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const drift.VerificationMeta _stateMeta =
      const drift.VerificationMeta('state');
  @override
  late final drift.GeneratedColumn<int> state = drift.GeneratedColumn<int>(
      'state', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _stepMeta =
      const drift.VerificationMeta('step');
  @override
  late final drift.GeneratedColumn<int> step = drift.GeneratedColumn<int>(
      'step', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const drift.VerificationMeta _stabilityMeta =
      const drift.VerificationMeta('stability');
  @override
  late final drift.GeneratedColumn<double> stability =
      drift.GeneratedColumn<double>('stability', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const drift.VerificationMeta _difficultyMeta =
      const drift.VerificationMeta('difficulty');
  @override
  late final drift.GeneratedColumn<double> difficulty =
      drift.GeneratedColumn<double>('difficulty', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const drift.VerificationMeta _dueMeta =
      const drift.VerificationMeta('due');
  @override
  late final drift.GeneratedColumn<DateTime> due =
      drift.GeneratedColumn<DateTime>('due', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const drift.VerificationMeta _lastReviewMeta =
      const drift.VerificationMeta('lastReview');
  @override
  late final drift.GeneratedColumn<DateTime> lastReview =
      drift.GeneratedColumn<DateTime>('last_review', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const drift.VerificationMeta _introducedAtMeta =
      const drift.VerificationMeta('introducedAt');
  @override
  late final drift.GeneratedColumn<DateTime> introducedAt =
      drift.GeneratedColumn<DateTime>('introduced_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [word, state, step, stability, difficulty, due, lastReview, introducedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcards';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<Flashcard> instance,
      {bool isInserting = false}) {
    final context = drift.VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word')) {
      context.handle(
          _wordMeta, word.isAcceptableOrUnknown(data['word']!, _wordMeta));
    } else if (isInserting) {
      context.missing(_wordMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('step')) {
      context.handle(
          _stepMeta, step.isAcceptableOrUnknown(data['step']!, _stepMeta));
    }
    if (data.containsKey('stability')) {
      context.handle(_stabilityMeta,
          stability.isAcceptableOrUnknown(data['stability']!, _stabilityMeta));
    }
    if (data.containsKey('difficulty')) {
      context.handle(
          _difficultyMeta,
          difficulty.isAcceptableOrUnknown(
              data['difficulty']!, _difficultyMeta));
    }
    if (data.containsKey('due')) {
      context.handle(
          _dueMeta, due.isAcceptableOrUnknown(data['due']!, _dueMeta));
    } else if (isInserting) {
      context.missing(_dueMeta);
    }
    if (data.containsKey('last_review')) {
      context.handle(
          _lastReviewMeta,
          lastReview.isAcceptableOrUnknown(
              data['last_review']!, _lastReviewMeta));
    }
    if (data.containsKey('introduced_at')) {
      context.handle(
          _introducedAtMeta,
          introducedAt.isAcceptableOrUnknown(
              data['introduced_at']!, _introducedAtMeta));
    } else if (isInserting) {
      context.missing(_introducedAtMeta);
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {word};
  @override
  Flashcard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Flashcard(
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}state'])!,
      step: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}step']),
      stability: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}stability']),
      difficulty: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}difficulty']),
      due: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}due'])!,
      lastReview: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_review']),
      introducedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}introduced_at'])!,
    );
  }

  @override
  $FlashcardsTable createAlias(String alias) {
    return $FlashcardsTable(attachedDatabase, alias);
  }
}

class Flashcard extends drift.DataClass implements drift.Insertable<Flashcard> {
  final String word;
  final int state;
  final int? step;
  final double? stability;
  final double? difficulty;
  final DateTime due;
  final DateTime? lastReview;
  final DateTime introducedAt;
  const Flashcard(
      {required this.word,
      required this.state,
      this.step,
      this.stability,
      this.difficulty,
      required this.due,
      this.lastReview,
      required this.introducedAt});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['word'] = drift.Variable<String>(word);
    map['state'] = drift.Variable<int>(state);
    if (!nullToAbsent || step != null) {
      map['step'] = drift.Variable<int>(step);
    }
    if (!nullToAbsent || stability != null) {
      map['stability'] = drift.Variable<double>(stability);
    }
    if (!nullToAbsent || difficulty != null) {
      map['difficulty'] = drift.Variable<double>(difficulty);
    }
    map['due'] = drift.Variable<DateTime>(due);
    if (!nullToAbsent || lastReview != null) {
      map['last_review'] = drift.Variable<DateTime>(lastReview);
    }
    map['introduced_at'] = drift.Variable<DateTime>(introducedAt);
    return map;
  }

  FlashcardsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardsCompanion(
      word: drift.Value(word),
      state: drift.Value(state),
      step: step == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(step),
      stability: stability == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(stability),
      difficulty: difficulty == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(difficulty),
      due: drift.Value(due),
      lastReview: lastReview == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(lastReview),
      introducedAt: drift.Value(introducedAt),
    );
  }

  factory Flashcard.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return Flashcard(
      word: serializer.fromJson<String>(json['word']),
      state: serializer.fromJson<int>(json['state']),
      step: serializer.fromJson<int?>(json['step']),
      stability: serializer.fromJson<double?>(json['stability']),
      difficulty: serializer.fromJson<double?>(json['difficulty']),
      due: serializer.fromJson<DateTime>(json['due']),
      lastReview: serializer.fromJson<DateTime?>(json['lastReview']),
      introducedAt: serializer.fromJson<DateTime>(json['introducedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'word': serializer.toJson<String>(word),
      'state': serializer.toJson<int>(state),
      'step': serializer.toJson<int?>(step),
      'stability': serializer.toJson<double?>(stability),
      'difficulty': serializer.toJson<double?>(difficulty),
      'due': serializer.toJson<DateTime>(due),
      'lastReview': serializer.toJson<DateTime?>(lastReview),
      'introducedAt': serializer.toJson<DateTime>(introducedAt),
    };
  }

  Flashcard copyWith(
          {String? word,
          int? state,
          drift.Value<int?> step = const drift.Value.absent(),
          drift.Value<double?> stability = const drift.Value.absent(),
          drift.Value<double?> difficulty = const drift.Value.absent(),
          DateTime? due,
          drift.Value<DateTime?> lastReview = const drift.Value.absent(),
          DateTime? introducedAt}) =>
      Flashcard(
        word: word ?? this.word,
        state: state ?? this.state,
        step: step.present ? step.value : this.step,
        stability: stability.present ? stability.value : this.stability,
        difficulty: difficulty.present ? difficulty.value : this.difficulty,
        due: due ?? this.due,
        lastReview: lastReview.present ? lastReview.value : this.lastReview,
        introducedAt: introducedAt ?? this.introducedAt,
      );
  Flashcard copyWithCompanion(FlashcardsCompanion data) {
    return Flashcard(
      word: data.word.present ? data.word.value : this.word,
      state: data.state.present ? data.state.value : this.state,
      step: data.step.present ? data.step.value : this.step,
      stability: data.stability.present ? data.stability.value : this.stability,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      due: data.due.present ? data.due.value : this.due,
      lastReview:
          data.lastReview.present ? data.lastReview.value : this.lastReview,
      introducedAt: data.introducedAt.present
          ? data.introducedAt.value
          : this.introducedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Flashcard(')
          ..write('word: $word, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('introducedAt: $introducedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      word, state, step, stability, difficulty, due, lastReview, introducedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Flashcard &&
          other.word == this.word &&
          other.state == this.state &&
          other.step == this.step &&
          other.stability == this.stability &&
          other.difficulty == this.difficulty &&
          other.due == this.due &&
          other.lastReview == this.lastReview &&
          other.introducedAt == this.introducedAt);
}

class FlashcardsCompanion extends drift.UpdateCompanion<Flashcard> {
  final drift.Value<String> word;
  final drift.Value<int> state;
  final drift.Value<int?> step;
  final drift.Value<double?> stability;
  final drift.Value<double?> difficulty;
  final drift.Value<DateTime> due;
  final drift.Value<DateTime?> lastReview;
  final drift.Value<DateTime> introducedAt;
  final drift.Value<int> rowid;
  const FlashcardsCompanion({
    this.word = const drift.Value.absent(),
    this.state = const drift.Value.absent(),
    this.step = const drift.Value.absent(),
    this.stability = const drift.Value.absent(),
    this.difficulty = const drift.Value.absent(),
    this.due = const drift.Value.absent(),
    this.lastReview = const drift.Value.absent(),
    this.introducedAt = const drift.Value.absent(),
    this.rowid = const drift.Value.absent(),
  });
  FlashcardsCompanion.insert({
    required String word,
    required int state,
    this.step = const drift.Value.absent(),
    this.stability = const drift.Value.absent(),
    this.difficulty = const drift.Value.absent(),
    required DateTime due,
    this.lastReview = const drift.Value.absent(),
    required DateTime introducedAt,
    this.rowid = const drift.Value.absent(),
  })  : word = drift.Value(word),
        state = drift.Value(state),
        due = drift.Value(due),
        introducedAt = drift.Value(introducedAt);
  static drift.Insertable<Flashcard> custom({
    drift.Expression<String>? word,
    drift.Expression<int>? state,
    drift.Expression<int>? step,
    drift.Expression<double>? stability,
    drift.Expression<double>? difficulty,
    drift.Expression<DateTime>? due,
    drift.Expression<DateTime>? lastReview,
    drift.Expression<DateTime>? introducedAt,
    drift.Expression<int>? rowid,
  }) {
    return drift.RawValuesInsertable({
      if (word != null) 'word': word,
      if (state != null) 'state': state,
      if (step != null) 'step': step,
      if (stability != null) 'stability': stability,
      if (difficulty != null) 'difficulty': difficulty,
      if (due != null) 'due': due,
      if (lastReview != null) 'last_review': lastReview,
      if (introducedAt != null) 'introduced_at': introducedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlashcardsCompanion copyWith(
      {drift.Value<String>? word,
      drift.Value<int>? state,
      drift.Value<int?>? step,
      drift.Value<double?>? stability,
      drift.Value<double?>? difficulty,
      drift.Value<DateTime>? due,
      drift.Value<DateTime?>? lastReview,
      drift.Value<DateTime>? introducedAt,
      drift.Value<int>? rowid}) {
    return FlashcardsCompanion(
      word: word ?? this.word,
      state: state ?? this.state,
      step: step ?? this.step,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      due: due ?? this.due,
      lastReview: lastReview ?? this.lastReview,
      introducedAt: introducedAt ?? this.introducedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (word.present) {
      map['word'] = drift.Variable<String>(word.value);
    }
    if (state.present) {
      map['state'] = drift.Variable<int>(state.value);
    }
    if (step.present) {
      map['step'] = drift.Variable<int>(step.value);
    }
    if (stability.present) {
      map['stability'] = drift.Variable<double>(stability.value);
    }
    if (difficulty.present) {
      map['difficulty'] = drift.Variable<double>(difficulty.value);
    }
    if (due.present) {
      map['due'] = drift.Variable<DateTime>(due.value);
    }
    if (lastReview.present) {
      map['last_review'] = drift.Variable<DateTime>(lastReview.value);
    }
    if (introducedAt.present) {
      map['introduced_at'] = drift.Variable<DateTime>(introducedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = drift.Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardsCompanion(')
          ..write('word: $word, ')
          ..write('state: $state, ')
          ..write('step: $step, ')
          ..write('stability: $stability, ')
          ..write('difficulty: $difficulty, ')
          ..write('due: $due, ')
          ..write('lastReview: $lastReview, ')
          ..write('introducedAt: $introducedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlashcardReviewLogsTable extends FlashcardReviewLogs
    with drift.TableInfo<$FlashcardReviewLogsTable, FlashcardReviewLog> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashcardReviewLogsTable(this.attachedDatabase, [this._alias]);
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
  static const drift.VerificationMeta _ratingMeta =
      const drift.VerificationMeta('rating');
  @override
  late final drift.GeneratedColumn<int> rating = drift.GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const drift.VerificationMeta _reviewedAtMeta =
      const drift.VerificationMeta('reviewedAt');
  @override
  late final drift.GeneratedColumn<DateTime> reviewedAt =
      drift.GeneratedColumn<DateTime>('reviewed_at', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const drift.VerificationMeta _durationMsMeta =
      const drift.VerificationMeta('durationMs');
  @override
  late final drift.GeneratedColumn<int> durationMs = drift.GeneratedColumn<int>(
      'duration_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<drift.GeneratedColumn> get $columns =>
      [id, word, rating, reviewedAt, durationMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flashcard_review_logs';
  @override
  drift.VerificationContext validateIntegrity(
      drift.Insertable<FlashcardReviewLog> instance,
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
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('reviewed_at')) {
      context.handle(
          _reviewedAtMeta,
          reviewedAt.isAcceptableOrUnknown(
              data['reviewed_at']!, _reviewedAtMeta));
    } else if (isInserting) {
      context.missing(_reviewedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
          _durationMsMeta,
          durationMs.isAcceptableOrUnknown(
              data['duration_ms']!, _durationMsMeta));
    }
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
  @override
  FlashcardReviewLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlashcardReviewLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      word: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}word'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      reviewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}reviewed_at'])!,
      durationMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_ms']),
    );
  }

  @override
  $FlashcardReviewLogsTable createAlias(String alias) {
    return $FlashcardReviewLogsTable(attachedDatabase, alias);
  }
}

class FlashcardReviewLog extends drift.DataClass
    implements drift.Insertable<FlashcardReviewLog> {
  final int id;
  final String word;
  final int rating;
  final DateTime reviewedAt;
  final int? durationMs;
  const FlashcardReviewLog(
      {required this.id,
      required this.word,
      required this.rating,
      required this.reviewedAt,
      this.durationMs});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['word'] = drift.Variable<String>(word);
    map['rating'] = drift.Variable<int>(rating);
    map['reviewed_at'] = drift.Variable<DateTime>(reviewedAt);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = drift.Variable<int>(durationMs);
    }
    return map;
  }

  FlashcardReviewLogsCompanion toCompanion(bool nullToAbsent) {
    return FlashcardReviewLogsCompanion(
      id: drift.Value(id),
      word: drift.Value(word),
      rating: drift.Value(rating),
      reviewedAt: drift.Value(reviewedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(durationMs),
    );
  }

  factory FlashcardReviewLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return FlashcardReviewLog(
      id: serializer.fromJson<int>(json['id']),
      word: serializer.fromJson<String>(json['word']),
      rating: serializer.fromJson<int>(json['rating']),
      reviewedAt: serializer.fromJson<DateTime>(json['reviewedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'word': serializer.toJson<String>(word),
      'rating': serializer.toJson<int>(rating),
      'reviewedAt': serializer.toJson<DateTime>(reviewedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
    };
  }

  FlashcardReviewLog copyWith(
          {int? id,
          String? word,
          int? rating,
          DateTime? reviewedAt,
          drift.Value<int?> durationMs = const drift.Value.absent()}) =>
      FlashcardReviewLog(
        id: id ?? this.id,
        word: word ?? this.word,
        rating: rating ?? this.rating,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        durationMs: durationMs.present ? durationMs.value : this.durationMs,
      );
  FlashcardReviewLog copyWithCompanion(FlashcardReviewLogsCompanion data) {
    return FlashcardReviewLog(
      id: data.id.present ? data.id.value : this.id,
      word: data.word.present ? data.word.value : this.word,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviewedAt:
          data.reviewedAt.present ? data.reviewedAt.value : this.reviewedAt,
      durationMs:
          data.durationMs.present ? data.durationMs.value : this.durationMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardReviewLog(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('durationMs: $durationMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, word, rating, reviewedAt, durationMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlashcardReviewLog &&
          other.id == this.id &&
          other.word == this.word &&
          other.rating == this.rating &&
          other.reviewedAt == this.reviewedAt &&
          other.durationMs == this.durationMs);
}

class FlashcardReviewLogsCompanion
    extends drift.UpdateCompanion<FlashcardReviewLog> {
  final drift.Value<int> id;
  final drift.Value<String> word;
  final drift.Value<int> rating;
  final drift.Value<DateTime> reviewedAt;
  final drift.Value<int?> durationMs;
  const FlashcardReviewLogsCompanion({
    this.id = const drift.Value.absent(),
    this.word = const drift.Value.absent(),
    this.rating = const drift.Value.absent(),
    this.reviewedAt = const drift.Value.absent(),
    this.durationMs = const drift.Value.absent(),
  });
  FlashcardReviewLogsCompanion.insert({
    this.id = const drift.Value.absent(),
    required String word,
    required int rating,
    required DateTime reviewedAt,
    this.durationMs = const drift.Value.absent(),
  })  : word = drift.Value(word),
        rating = drift.Value(rating),
        reviewedAt = drift.Value(reviewedAt);
  static drift.Insertable<FlashcardReviewLog> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? word,
    drift.Expression<int>? rating,
    drift.Expression<DateTime>? reviewedAt,
    drift.Expression<int>? durationMs,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (word != null) 'word': word,
      if (rating != null) 'rating': rating,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (durationMs != null) 'duration_ms': durationMs,
    });
  }

  FlashcardReviewLogsCompanion copyWith(
      {drift.Value<int>? id,
      drift.Value<String>? word,
      drift.Value<int>? rating,
      drift.Value<DateTime>? reviewedAt,
      drift.Value<int?>? durationMs}) {
    return FlashcardReviewLogsCompanion(
      id: id ?? this.id,
      word: word ?? this.word,
      rating: rating ?? this.rating,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      durationMs: durationMs ?? this.durationMs,
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
    if (rating.present) {
      map['rating'] = drift.Variable<int>(rating.value);
    }
    if (reviewedAt.present) {
      map['reviewed_at'] = drift.Variable<DateTime>(reviewedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = drift.Variable<int>(durationMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashcardReviewLogsCompanion(')
          ..write('id: $id, ')
          ..write('word: $word, ')
          ..write('rating: $rating, ')
          ..write('reviewedAt: $reviewedAt, ')
          ..write('durationMs: $durationMs')
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
  late final $MddAudioListTable mddAudioList = $MddAudioListTable(this);
  late final $MddAudioResourceTable mddAudioResource =
      $MddAudioResourceTable(this);
  late final $AiExplanationsTable aiExplanations = $AiExplanationsTable(this);
  late final $WritingCheckHistoryTable writingCheckHistory =
      $WritingCheckHistoryTable(this);
  late final $TranslateHistoryTable translateHistory =
      $TranslateHistoryTable(this);
  late final $OpenRecordsTable openRecords = $OpenRecordsTable(this);
  late final $FlashcardsTable flashcards = $FlashcardsTable(this);
  late final $FlashcardReviewLogsTable flashcardReviewLogs =
      $FlashcardReviewLogsTable(this);
  late final drift.Index idxWordbook = drift.Index('idx_wordbook',
      'CREATE INDEX idx_wordbook ON wordbook (word, created_at)');
  late final drift.Index idxWordbookTags = drift.Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  late final drift.Index idxMddAudioResource = drift.Index(
      'idx_mdd_audio_resource',
      'CREATE INDEX idx_mdd_audio_resource ON mdd_audio_resource ("key")');
  late final drift.Index idxAiExplanations = drift.Index('idx_ai_explanations',
      'CREATE INDEX idx_ai_explanations ON ai_explanations (word)');
  late final drift.Index idxOpenRecords = drift.Index('idx_open_records',
      'CREATE INDEX idx_open_records ON open_records (word, created_at)');
  late final drift.Index idxFlashcardsDue = drift.Index('idx_flashcards_due',
      'CREATE INDEX idx_flashcards_due ON flashcards (due)');
  late final drift.Index idxFlashcardReviewLogsWord = drift.Index(
      'idx_flashcard_review_logs_word',
      'CREATE INDEX idx_flashcard_review_logs_word ON flashcard_review_logs (word)');
  late final DictionaryListDao dictionaryListDao =
      DictionaryListDao(this as AppDatabase);
  late final WordbookDao wordbookDao = WordbookDao(this as AppDatabase);
  late final WordbookTagsDao wordbookTagsDao =
      WordbookTagsDao(this as AppDatabase);
  late final HistoryDao historyDao = HistoryDao(this as AppDatabase);
  late final DictGroupDao dictGroupDao = DictGroupDao(this as AppDatabase);
  late final MddAudioListDao mddAudioListDao =
      MddAudioListDao(this as AppDatabase);
  late final MddAudioResourceDao mddAudioResourceDao =
      MddAudioResourceDao(this as AppDatabase);
  late final AiExplanationDao aiExplanationDao =
      AiExplanationDao(this as AppDatabase);
  late final WritingCheckHistoryDao writingCheckHistoryDao =
      WritingCheckHistoryDao(this as AppDatabase);
  late final TranslateHistoryDao translateHistoryDao =
      TranslateHistoryDao(this as AppDatabase);
  late final OpenRecordsDao openRecordsDao =
      OpenRecordsDao(this as AppDatabase);
  late final FlashcardDao flashcardDao = FlashcardDao(this as AppDatabase);
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
        mddAudioList,
        mddAudioResource,
        aiExplanations,
        writingCheckHistory,
        translateHistory,
        openRecords,
        flashcards,
        flashcardReviewLogs,
        idxWordbook,
        idxWordbookTags,
        idxMddAudioResource,
        idxAiExplanations,
        idxOpenRecords,
        idxFlashcardsDue,
        idxFlashcardReviewLogsWord
      ];
}

typedef $$DictionaryListTableCreateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> title,
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  drift.Value<int?> order,
  required String path,
  drift.Value<int> type,
});
typedef $$DictionaryListTableUpdateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> title,
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  drift.Value<int?> order,
  drift.Value<String> path,
  drift.Value<int> type,
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
  drift.ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => drift.ColumnFilters(column));
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
  drift.ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get type => $composableBuilder(
      column: $table.type, builder: (column) => drift.ColumnOrderings(column));
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
  drift.GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  drift.GeneratedColumn<String> get fontPath =>
      $composableBuilder(column: $table.fontPath, builder: (column) => column);

  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);

  drift.GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  drift.GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);
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
            drift.Value<String?> title = const drift.Value.absent(),
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<int?> order = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
            drift.Value<int> type = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion(
            title: title,
            fontPath: fontPath,
            id: id,
            order: order,
            path: path,
            type: type,
          ),
          createCompanionCallback: ({
            drift.Value<String?> title = const drift.Value.absent(),
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<int?> order = const drift.Value.absent(),
            required String path,
            drift.Value<int> type = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion.insert(
            title: title,
            fontPath: fontPath,
            id: id,
            order: order,
            path: path,
            type: type,
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
  required DateTime createdAt,
  drift.Value<int?> tag,
  required String word,
  drift.Value<int> rowid,
});
typedef $$WordbookTableUpdateCompanionBuilder = WordbookCompanion Function({
  drift.Value<DateTime> createdAt,
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
  drift.ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnFilters(column));

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
  drift.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnOrderings(column));

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
  drift.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

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
            drift.Value<DateTime> createdAt = const drift.Value.absent(),
            drift.Value<int?> tag = const drift.Value.absent(),
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion(
            createdAt: createdAt,
            tag: tag,
            word: word,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required DateTime createdAt,
            drift.Value<int?> tag = const drift.Value.absent(),
            required String word,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              WordbookCompanion.insert(
            createdAt: createdAt,
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
typedef $$MddAudioListTableCreateCompanionBuilder = MddAudioListCompanion
    Function({
  drift.Value<int> id,
  required String path,
  required String title,
  required int order,
});
typedef $$MddAudioListTableUpdateCompanionBuilder = MddAudioListCompanion
    Function({
  drift.Value<int> id,
  drift.Value<String> path,
  drift.Value<String> title,
  drift.Value<int> order,
});

class $$MddAudioListTableFilterComposer
    extends drift.Composer<_$AppDatabase, $MddAudioListTable> {
  $$MddAudioListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => drift.ColumnFilters(column));
}

class $$MddAudioListTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $MddAudioListTable> {
  $$MddAudioListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get order => $composableBuilder(
      column: $table.order, builder: (column) => drift.ColumnOrderings(column));
}

class $$MddAudioListTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $MddAudioListTable> {
  $$MddAudioListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  drift.GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  drift.GeneratedColumn<int> get order =>
      $composableBuilder(column: $table.order, builder: (column) => column);
}

class $$MddAudioListTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $MddAudioListTable,
    MddAudioListData,
    $$MddAudioListTableFilterComposer,
    $$MddAudioListTableOrderingComposer,
    $$MddAudioListTableAnnotationComposer,
    $$MddAudioListTableCreateCompanionBuilder,
    $$MddAudioListTableUpdateCompanionBuilder,
    (
      MddAudioListData,
      drift.BaseReferences<_$AppDatabase, $MddAudioListTable, MddAudioListData>
    ),
    MddAudioListData,
    drift.PrefetchHooks Function()> {
  $$MddAudioListTableTableManager(_$AppDatabase db, $MddAudioListTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MddAudioListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MddAudioListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MddAudioListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
            drift.Value<String> title = const drift.Value.absent(),
            drift.Value<int> order = const drift.Value.absent(),
          }) =>
              MddAudioListCompanion(
            id: id,
            path: path,
            title: title,
            order: order,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String path,
            required String title,
            required int order,
          }) =>
              MddAudioListCompanion.insert(
            id: id,
            path: path,
            title: title,
            order: order,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MddAudioListTableProcessedTableManager = drift.ProcessedTableManager<
    _$AppDatabase,
    $MddAudioListTable,
    MddAudioListData,
    $$MddAudioListTableFilterComposer,
    $$MddAudioListTableOrderingComposer,
    $$MddAudioListTableAnnotationComposer,
    $$MddAudioListTableCreateCompanionBuilder,
    $$MddAudioListTableUpdateCompanionBuilder,
    (
      MddAudioListData,
      drift.BaseReferences<_$AppDatabase, $MddAudioListTable, MddAudioListData>
    ),
    MddAudioListData,
    drift.PrefetchHooks Function()>;
typedef $$MddAudioResourceTableCreateCompanionBuilder
    = MddAudioResourceCompanion Function({
  required int blockOffset,
  required int compressedSize,
  required int endOffset,
  required String key,
  required int mddAudioListId,
  required int startOffset,
  drift.Value<int> rowid,
});
typedef $$MddAudioResourceTableUpdateCompanionBuilder
    = MddAudioResourceCompanion Function({
  drift.Value<int> blockOffset,
  drift.Value<int> compressedSize,
  drift.Value<int> endOffset,
  drift.Value<String> key,
  drift.Value<int> mddAudioListId,
  drift.Value<int> startOffset,
  drift.Value<int> rowid,
});

class $$MddAudioResourceTableFilterComposer
    extends drift.Composer<_$AppDatabase, $MddAudioResourceTable> {
  $$MddAudioResourceTableFilterComposer({
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

  drift.ColumnFilters<int> get mddAudioListId => $composableBuilder(
      column: $table.mddAudioListId,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnFilters(column));
}

class $$MddAudioResourceTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $MddAudioResourceTable> {
  $$MddAudioResourceTableOrderingComposer({
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

  drift.ColumnOrderings<int> get mddAudioListId => $composableBuilder(
      column: $table.mddAudioListId,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get startOffset => $composableBuilder(
      column: $table.startOffset,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$MddAudioResourceTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $MddAudioResourceTable> {
  $$MddAudioResourceTableAnnotationComposer({
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

  drift.GeneratedColumn<int> get mddAudioListId => $composableBuilder(
      column: $table.mddAudioListId, builder: (column) => column);

  drift.GeneratedColumn<int> get startOffset => $composableBuilder(
      column: $table.startOffset, builder: (column) => column);
}

class $$MddAudioResourceTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $MddAudioResourceTable,
    MddAudioResourceData,
    $$MddAudioResourceTableFilterComposer,
    $$MddAudioResourceTableOrderingComposer,
    $$MddAudioResourceTableAnnotationComposer,
    $$MddAudioResourceTableCreateCompanionBuilder,
    $$MddAudioResourceTableUpdateCompanionBuilder,
    (
      MddAudioResourceData,
      drift.BaseReferences<_$AppDatabase, $MddAudioResourceTable,
          MddAudioResourceData>
    ),
    MddAudioResourceData,
    drift.PrefetchHooks Function()> {
  $$MddAudioResourceTableTableManager(
      _$AppDatabase db, $MddAudioResourceTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MddAudioResourceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MddAudioResourceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MddAudioResourceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> blockOffset = const drift.Value.absent(),
            drift.Value<int> compressedSize = const drift.Value.absent(),
            drift.Value<int> endOffset = const drift.Value.absent(),
            drift.Value<String> key = const drift.Value.absent(),
            drift.Value<int> mddAudioListId = const drift.Value.absent(),
            drift.Value<int> startOffset = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              MddAudioResourceCompanion(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            mddAudioListId: mddAudioListId,
            startOffset: startOffset,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int blockOffset,
            required int compressedSize,
            required int endOffset,
            required String key,
            required int mddAudioListId,
            required int startOffset,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              MddAudioResourceCompanion.insert(
            blockOffset: blockOffset,
            compressedSize: compressedSize,
            endOffset: endOffset,
            key: key,
            mddAudioListId: mddAudioListId,
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

typedef $$MddAudioResourceTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $MddAudioResourceTable,
        MddAudioResourceData,
        $$MddAudioResourceTableFilterComposer,
        $$MddAudioResourceTableOrderingComposer,
        $$MddAudioResourceTableAnnotationComposer,
        $$MddAudioResourceTableCreateCompanionBuilder,
        $$MddAudioResourceTableUpdateCompanionBuilder,
        (
          MddAudioResourceData,
          drift.BaseReferences<_$AppDatabase, $MddAudioResourceTable,
              MddAudioResourceData>
        ),
        MddAudioResourceData,
        drift.PrefetchHooks Function()>;
typedef $$AiExplanationsTableCreateCompanionBuilder = AiExplanationsCompanion
    Function({
  required String word,
  required String explanation,
  drift.Value<int> rowid,
});
typedef $$AiExplanationsTableUpdateCompanionBuilder = AiExplanationsCompanion
    Function({
  drift.Value<String> word,
  drift.Value<String> explanation,
  drift.Value<int> rowid,
});

class $$AiExplanationsTableFilterComposer
    extends drift.Composer<_$AppDatabase, $AiExplanationsTable> {
  $$AiExplanationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get explanation => $composableBuilder(
      column: $table.explanation,
      builder: (column) => drift.ColumnFilters(column));
}

class $$AiExplanationsTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $AiExplanationsTable> {
  $$AiExplanationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get explanation => $composableBuilder(
      column: $table.explanation,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$AiExplanationsTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $AiExplanationsTable> {
  $$AiExplanationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  drift.GeneratedColumn<String> get explanation => $composableBuilder(
      column: $table.explanation, builder: (column) => column);
}

class $$AiExplanationsTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $AiExplanationsTable,
    AiExplanation,
    $$AiExplanationsTableFilterComposer,
    $$AiExplanationsTableOrderingComposer,
    $$AiExplanationsTableAnnotationComposer,
    $$AiExplanationsTableCreateCompanionBuilder,
    $$AiExplanationsTableUpdateCompanionBuilder,
    (
      AiExplanation,
      drift.BaseReferences<_$AppDatabase, $AiExplanationsTable, AiExplanation>
    ),
    AiExplanation,
    drift.PrefetchHooks Function()> {
  $$AiExplanationsTableTableManager(
      _$AppDatabase db, $AiExplanationsTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiExplanationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiExplanationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiExplanationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<String> explanation = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              AiExplanationsCompanion(
            word: word,
            explanation: explanation,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String word,
            required String explanation,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              AiExplanationsCompanion.insert(
            word: word,
            explanation: explanation,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiExplanationsTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $AiExplanationsTable,
        AiExplanation,
        $$AiExplanationsTableFilterComposer,
        $$AiExplanationsTableOrderingComposer,
        $$AiExplanationsTableAnnotationComposer,
        $$AiExplanationsTableCreateCompanionBuilder,
        $$AiExplanationsTableUpdateCompanionBuilder,
        (
          AiExplanation,
          drift
          .BaseReferences<_$AppDatabase, $AiExplanationsTable, AiExplanation>
        ),
        AiExplanation,
        drift.PrefetchHooks Function()>;
typedef $$WritingCheckHistoryTableCreateCompanionBuilder
    = WritingCheckHistoryCompanion Function({
  drift.Value<int> id,
  required String inputText,
  required String outputText,
  required DateTime createdAt,
});
typedef $$WritingCheckHistoryTableUpdateCompanionBuilder
    = WritingCheckHistoryCompanion Function({
  drift.Value<int> id,
  drift.Value<String> inputText,
  drift.Value<String> outputText,
  drift.Value<DateTime> createdAt,
});

class $$WritingCheckHistoryTableFilterComposer
    extends drift.Composer<_$AppDatabase, $WritingCheckHistoryTable> {
  $$WritingCheckHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get inputText => $composableBuilder(
      column: $table.inputText,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get outputText => $composableBuilder(
      column: $table.outputText,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnFilters(column));
}

class $$WritingCheckHistoryTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $WritingCheckHistoryTable> {
  $$WritingCheckHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get inputText => $composableBuilder(
      column: $table.inputText,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get outputText => $composableBuilder(
      column: $table.outputText,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$WritingCheckHistoryTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $WritingCheckHistoryTable> {
  $$WritingCheckHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get inputText =>
      $composableBuilder(column: $table.inputText, builder: (column) => column);

  drift.GeneratedColumn<String> get outputText => $composableBuilder(
      column: $table.outputText, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WritingCheckHistoryTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $WritingCheckHistoryTable,
    WritingCheckHistoryData,
    $$WritingCheckHistoryTableFilterComposer,
    $$WritingCheckHistoryTableOrderingComposer,
    $$WritingCheckHistoryTableAnnotationComposer,
    $$WritingCheckHistoryTableCreateCompanionBuilder,
    $$WritingCheckHistoryTableUpdateCompanionBuilder,
    (
      WritingCheckHistoryData,
      drift.BaseReferences<_$AppDatabase, $WritingCheckHistoryTable,
          WritingCheckHistoryData>
    ),
    WritingCheckHistoryData,
    drift.PrefetchHooks Function()> {
  $$WritingCheckHistoryTableTableManager(
      _$AppDatabase db, $WritingCheckHistoryTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WritingCheckHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WritingCheckHistoryTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WritingCheckHistoryTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> inputText = const drift.Value.absent(),
            drift.Value<String> outputText = const drift.Value.absent(),
            drift.Value<DateTime> createdAt = const drift.Value.absent(),
          }) =>
              WritingCheckHistoryCompanion(
            id: id,
            inputText: inputText,
            outputText: outputText,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String inputText,
            required String outputText,
            required DateTime createdAt,
          }) =>
              WritingCheckHistoryCompanion.insert(
            id: id,
            inputText: inputText,
            outputText: outputText,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WritingCheckHistoryTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $WritingCheckHistoryTable,
        WritingCheckHistoryData,
        $$WritingCheckHistoryTableFilterComposer,
        $$WritingCheckHistoryTableOrderingComposer,
        $$WritingCheckHistoryTableAnnotationComposer,
        $$WritingCheckHistoryTableCreateCompanionBuilder,
        $$WritingCheckHistoryTableUpdateCompanionBuilder,
        (
          WritingCheckHistoryData,
          drift.BaseReferences<_$AppDatabase, $WritingCheckHistoryTable,
              WritingCheckHistoryData>
        ),
        WritingCheckHistoryData,
        drift.PrefetchHooks Function()>;
typedef $$TranslateHistoryTableCreateCompanionBuilder
    = TranslateHistoryCompanion Function({
  drift.Value<int> id,
  required String inputText,
  required DateTime createdAt,
});
typedef $$TranslateHistoryTableUpdateCompanionBuilder
    = TranslateHistoryCompanion Function({
  drift.Value<int> id,
  drift.Value<String> inputText,
  drift.Value<DateTime> createdAt,
});

class $$TranslateHistoryTableFilterComposer
    extends drift.Composer<_$AppDatabase, $TranslateHistoryTable> {
  $$TranslateHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get inputText => $composableBuilder(
      column: $table.inputText,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnFilters(column));
}

class $$TranslateHistoryTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $TranslateHistoryTable> {
  $$TranslateHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get inputText => $composableBuilder(
      column: $table.inputText,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$TranslateHistoryTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $TranslateHistoryTable> {
  $$TranslateHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get inputText =>
      $composableBuilder(column: $table.inputText, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TranslateHistoryTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $TranslateHistoryTable,
    TranslateHistoryData,
    $$TranslateHistoryTableFilterComposer,
    $$TranslateHistoryTableOrderingComposer,
    $$TranslateHistoryTableAnnotationComposer,
    $$TranslateHistoryTableCreateCompanionBuilder,
    $$TranslateHistoryTableUpdateCompanionBuilder,
    (
      TranslateHistoryData,
      drift.BaseReferences<_$AppDatabase, $TranslateHistoryTable,
          TranslateHistoryData>
    ),
    TranslateHistoryData,
    drift.PrefetchHooks Function()> {
  $$TranslateHistoryTableTableManager(
      _$AppDatabase db, $TranslateHistoryTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslateHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslateHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslateHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> inputText = const drift.Value.absent(),
            drift.Value<DateTime> createdAt = const drift.Value.absent(),
          }) =>
              TranslateHistoryCompanion(
            id: id,
            inputText: inputText,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String inputText,
            required DateTime createdAt,
          }) =>
              TranslateHistoryCompanion.insert(
            id: id,
            inputText: inputText,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TranslateHistoryTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $TranslateHistoryTable,
        TranslateHistoryData,
        $$TranslateHistoryTableFilterComposer,
        $$TranslateHistoryTableOrderingComposer,
        $$TranslateHistoryTableAnnotationComposer,
        $$TranslateHistoryTableCreateCompanionBuilder,
        $$TranslateHistoryTableUpdateCompanionBuilder,
        (
          TranslateHistoryData,
          drift.BaseReferences<_$AppDatabase, $TranslateHistoryTable,
              TranslateHistoryData>
        ),
        TranslateHistoryData,
        drift.PrefetchHooks Function()>;
typedef $$OpenRecordsTableCreateCompanionBuilder = OpenRecordsCompanion
    Function({
  drift.Value<int> id,
  required String word,
  required DateTime createdAt,
});
typedef $$OpenRecordsTableUpdateCompanionBuilder = OpenRecordsCompanion
    Function({
  drift.Value<int> id,
  drift.Value<String> word,
  drift.Value<DateTime> createdAt,
});

class $$OpenRecordsTableFilterComposer
    extends drift.Composer<_$AppDatabase, $OpenRecordsTable> {
  $$OpenRecordsTableFilterComposer({
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

  drift.ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnFilters(column));
}

class $$OpenRecordsTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $OpenRecordsTable> {
  $$OpenRecordsTableOrderingComposer({
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

  drift.ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$OpenRecordsTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $OpenRecordsTable> {
  $$OpenRecordsTableAnnotationComposer({
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

  drift.GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OpenRecordsTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $OpenRecordsTable,
    OpenRecord,
    $$OpenRecordsTableFilterComposer,
    $$OpenRecordsTableOrderingComposer,
    $$OpenRecordsTableAnnotationComposer,
    $$OpenRecordsTableCreateCompanionBuilder,
    $$OpenRecordsTableUpdateCompanionBuilder,
    (
      OpenRecord,
      drift.BaseReferences<_$AppDatabase, $OpenRecordsTable, OpenRecord>
    ),
    OpenRecord,
    drift.PrefetchHooks Function()> {
  $$OpenRecordsTableTableManager(_$AppDatabase db, $OpenRecordsTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OpenRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OpenRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OpenRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<DateTime> createdAt = const drift.Value.absent(),
          }) =>
              OpenRecordsCompanion(
            id: id,
            word: word,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String word,
            required DateTime createdAt,
          }) =>
              OpenRecordsCompanion.insert(
            id: id,
            word: word,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OpenRecordsTableProcessedTableManager = drift.ProcessedTableManager<
    _$AppDatabase,
    $OpenRecordsTable,
    OpenRecord,
    $$OpenRecordsTableFilterComposer,
    $$OpenRecordsTableOrderingComposer,
    $$OpenRecordsTableAnnotationComposer,
    $$OpenRecordsTableCreateCompanionBuilder,
    $$OpenRecordsTableUpdateCompanionBuilder,
    (
      OpenRecord,
      drift.BaseReferences<_$AppDatabase, $OpenRecordsTable, OpenRecord>
    ),
    OpenRecord,
    drift.PrefetchHooks Function()>;
typedef $$FlashcardsTableCreateCompanionBuilder = FlashcardsCompanion Function({
  required String word,
  required int state,
  drift.Value<int?> step,
  drift.Value<double?> stability,
  drift.Value<double?> difficulty,
  required DateTime due,
  drift.Value<DateTime?> lastReview,
  required DateTime introducedAt,
  drift.Value<int> rowid,
});
typedef $$FlashcardsTableUpdateCompanionBuilder = FlashcardsCompanion Function({
  drift.Value<String> word,
  drift.Value<int> state,
  drift.Value<int?> step,
  drift.Value<double?> stability,
  drift.Value<double?> difficulty,
  drift.Value<DateTime> due,
  drift.Value<DateTime?> lastReview,
  drift.Value<DateTime> introducedAt,
  drift.Value<int> rowid,
});

class $$FlashcardsTableFilterComposer
    extends drift.Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnFilters<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get state => $composableBuilder(
      column: $table.state, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get step => $composableBuilder(
      column: $table.step, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<double> get stability => $composableBuilder(
      column: $table.stability,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<double> get difficulty => $composableBuilder(
      column: $table.difficulty,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get due => $composableBuilder(
      column: $table.due, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get introducedAt => $composableBuilder(
      column: $table.introducedAt,
      builder: (column) => drift.ColumnFilters(column));
}

class $$FlashcardsTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.ColumnOrderings<String> get word => $composableBuilder(
      column: $table.word, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get state => $composableBuilder(
      column: $table.state, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get step => $composableBuilder(
      column: $table.step, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<double> get stability => $composableBuilder(
      column: $table.stability,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<double> get difficulty => $composableBuilder(
      column: $table.difficulty,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get due => $composableBuilder(
      column: $table.due, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get introducedAt => $composableBuilder(
      column: $table.introducedAt,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$FlashcardsTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $FlashcardsTable> {
  $$FlashcardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  drift.GeneratedColumn<String> get word =>
      $composableBuilder(column: $table.word, builder: (column) => column);

  drift.GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  drift.GeneratedColumn<int> get step =>
      $composableBuilder(column: $table.step, builder: (column) => column);

  drift.GeneratedColumn<double> get stability =>
      $composableBuilder(column: $table.stability, builder: (column) => column);

  drift.GeneratedColumn<double> get difficulty => $composableBuilder(
      column: $table.difficulty, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get due =>
      $composableBuilder(column: $table.due, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get lastReview => $composableBuilder(
      column: $table.lastReview, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get introducedAt => $composableBuilder(
      column: $table.introducedAt, builder: (column) => column);
}

class $$FlashcardsTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $FlashcardsTable,
    Flashcard,
    $$FlashcardsTableFilterComposer,
    $$FlashcardsTableOrderingComposer,
    $$FlashcardsTableAnnotationComposer,
    $$FlashcardsTableCreateCompanionBuilder,
    $$FlashcardsTableUpdateCompanionBuilder,
    (
      Flashcard,
      drift.BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard>
    ),
    Flashcard,
    drift.PrefetchHooks Function()> {
  $$FlashcardsTableTableManager(_$AppDatabase db, $FlashcardsTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<int> state = const drift.Value.absent(),
            drift.Value<int?> step = const drift.Value.absent(),
            drift.Value<double?> stability = const drift.Value.absent(),
            drift.Value<double?> difficulty = const drift.Value.absent(),
            drift.Value<DateTime> due = const drift.Value.absent(),
            drift.Value<DateTime?> lastReview = const drift.Value.absent(),
            drift.Value<DateTime> introducedAt = const drift.Value.absent(),
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              FlashcardsCompanion(
            word: word,
            state: state,
            step: step,
            stability: stability,
            difficulty: difficulty,
            due: due,
            lastReview: lastReview,
            introducedAt: introducedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String word,
            required int state,
            drift.Value<int?> step = const drift.Value.absent(),
            drift.Value<double?> stability = const drift.Value.absent(),
            drift.Value<double?> difficulty = const drift.Value.absent(),
            required DateTime due,
            drift.Value<DateTime?> lastReview = const drift.Value.absent(),
            required DateTime introducedAt,
            drift.Value<int> rowid = const drift.Value.absent(),
          }) =>
              FlashcardsCompanion.insert(
            word: word,
            state: state,
            step: step,
            stability: stability,
            difficulty: difficulty,
            due: due,
            lastReview: lastReview,
            introducedAt: introducedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FlashcardsTableProcessedTableManager = drift.ProcessedTableManager<
    _$AppDatabase,
    $FlashcardsTable,
    Flashcard,
    $$FlashcardsTableFilterComposer,
    $$FlashcardsTableOrderingComposer,
    $$FlashcardsTableAnnotationComposer,
    $$FlashcardsTableCreateCompanionBuilder,
    $$FlashcardsTableUpdateCompanionBuilder,
    (
      Flashcard,
      drift.BaseReferences<_$AppDatabase, $FlashcardsTable, Flashcard>
    ),
    Flashcard,
    drift.PrefetchHooks Function()>;
typedef $$FlashcardReviewLogsTableCreateCompanionBuilder
    = FlashcardReviewLogsCompanion Function({
  drift.Value<int> id,
  required String word,
  required int rating,
  required DateTime reviewedAt,
  drift.Value<int?> durationMs,
});
typedef $$FlashcardReviewLogsTableUpdateCompanionBuilder
    = FlashcardReviewLogsCompanion Function({
  drift.Value<int> id,
  drift.Value<String> word,
  drift.Value<int> rating,
  drift.Value<DateTime> reviewedAt,
  drift.Value<int?> durationMs,
});

class $$FlashcardReviewLogsTableFilterComposer
    extends drift.Composer<_$AppDatabase, $FlashcardReviewLogsTable> {
  $$FlashcardReviewLogsTableFilterComposer({
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

  drift.ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get durationMs => $composableBuilder(
      column: $table.durationMs,
      builder: (column) => drift.ColumnFilters(column));
}

class $$FlashcardReviewLogsTableOrderingComposer
    extends drift.Composer<_$AppDatabase, $FlashcardReviewLogsTable> {
  $$FlashcardReviewLogsTableOrderingComposer({
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

  drift.ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get durationMs => $composableBuilder(
      column: $table.durationMs,
      builder: (column) => drift.ColumnOrderings(column));
}

class $$FlashcardReviewLogsTableAnnotationComposer
    extends drift.Composer<_$AppDatabase, $FlashcardReviewLogsTable> {
  $$FlashcardReviewLogsTableAnnotationComposer({
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

  drift.GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  drift.GeneratedColumn<DateTime> get reviewedAt => $composableBuilder(
      column: $table.reviewedAt, builder: (column) => column);

  drift.GeneratedColumn<int> get durationMs => $composableBuilder(
      column: $table.durationMs, builder: (column) => column);
}

class $$FlashcardReviewLogsTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $FlashcardReviewLogsTable,
    FlashcardReviewLog,
    $$FlashcardReviewLogsTableFilterComposer,
    $$FlashcardReviewLogsTableOrderingComposer,
    $$FlashcardReviewLogsTableAnnotationComposer,
    $$FlashcardReviewLogsTableCreateCompanionBuilder,
    $$FlashcardReviewLogsTableUpdateCompanionBuilder,
    (
      FlashcardReviewLog,
      drift.BaseReferences<_$AppDatabase, $FlashcardReviewLogsTable,
          FlashcardReviewLog>
    ),
    FlashcardReviewLog,
    drift.PrefetchHooks Function()> {
  $$FlashcardReviewLogsTableTableManager(
      _$AppDatabase db, $FlashcardReviewLogsTable table)
      : super(drift.TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashcardReviewLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashcardReviewLogsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashcardReviewLogsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> word = const drift.Value.absent(),
            drift.Value<int> rating = const drift.Value.absent(),
            drift.Value<DateTime> reviewedAt = const drift.Value.absent(),
            drift.Value<int?> durationMs = const drift.Value.absent(),
          }) =>
              FlashcardReviewLogsCompanion(
            id: id,
            word: word,
            rating: rating,
            reviewedAt: reviewedAt,
            durationMs: durationMs,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String word,
            required int rating,
            required DateTime reviewedAt,
            drift.Value<int?> durationMs = const drift.Value.absent(),
          }) =>
              FlashcardReviewLogsCompanion.insert(
            id: id,
            word: word,
            rating: rating,
            reviewedAt: reviewedAt,
            durationMs: durationMs,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), drift.BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FlashcardReviewLogsTableProcessedTableManager
    = drift.ProcessedTableManager<
        _$AppDatabase,
        $FlashcardReviewLogsTable,
        FlashcardReviewLog,
        $$FlashcardReviewLogsTableFilterComposer,
        $$FlashcardReviewLogsTableOrderingComposer,
        $$FlashcardReviewLogsTableAnnotationComposer,
        $$FlashcardReviewLogsTableCreateCompanionBuilder,
        $$FlashcardReviewLogsTableUpdateCompanionBuilder,
        (
          FlashcardReviewLog,
          drift.BaseReferences<_$AppDatabase, $FlashcardReviewLogsTable,
              FlashcardReviewLog>
        ),
        FlashcardReviewLog,
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
  $$MddAudioListTableTableManager get mddAudioList =>
      $$MddAudioListTableTableManager(_db, _db.mddAudioList);
  $$MddAudioResourceTableTableManager get mddAudioResource =>
      $$MddAudioResourceTableTableManager(_db, _db.mddAudioResource);
  $$AiExplanationsTableTableManager get aiExplanations =>
      $$AiExplanationsTableTableManager(_db, _db.aiExplanations);
  $$WritingCheckHistoryTableTableManager get writingCheckHistory =>
      $$WritingCheckHistoryTableTableManager(_db, _db.writingCheckHistory);
  $$TranslateHistoryTableTableManager get translateHistory =>
      $$TranslateHistoryTableTableManager(_db, _db.translateHistory);
  $$OpenRecordsTableTableManager get openRecords =>
      $$OpenRecordsTableTableManager(_db, _db.openRecords);
  $$FlashcardsTableTableManager get flashcards =>
      $$FlashcardsTableTableManager(_db, _db.flashcards);
  $$FlashcardReviewLogsTableTableManager get flashcardReviewLogs =>
      $$FlashcardReviewLogsTableTableManager(_db, _db.flashcardReviewLogs);
}
