// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
//@dart=2.12
import 'package:drift/drift.dart';

class DictionaryList extends Table
    with TableInfo<DictionaryList, DictionaryListData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DictionaryList(this.attachedDatabase, [this._alias]);
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
  late final GeneratedColumn<String> fontPath = GeneratedColumn<String>(
      'font_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, path, fontPath];
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      fontPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}font_path']),
    );
  }

  @override
  DictionaryList createAlias(String alias) {
    return DictionaryList(attachedDatabase, alias);
  }
}

class DictionaryListData extends DataClass
    implements Insertable<DictionaryListData> {
  final int id;
  final String path;
  final String? fontPath;
  const DictionaryListData(
      {required this.id, required this.path, this.fontPath});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = Variable<String>(fontPath);
    }
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      id: Value(id),
      path: Value(path),
      fontPath: fontPath == null && nullToAbsent
          ? const Value.absent()
          : Value(fontPath),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      fontPath: serializer.fromJson<String?>(json['fontPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'fontPath': serializer.toJson<String?>(fontPath),
    };
  }

  DictionaryListData copyWith(
          {int? id,
          String? path,
          Value<String?> fontPath = const Value.absent()}) =>
      DictionaryListData(
        id: id ?? this.id,
        path: path ?? this.path,
        fontPath: fontPath.present ? fontPath.value : this.fontPath,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      fontPath: data.fontPath.present ? data.fontPath.value : this.fontPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('fontPath: $fontPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, fontPath);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.id == this.id &&
          other.path == this.path &&
          other.fontPath == this.fontPath);
}

class DictionaryListCompanion extends UpdateCompanion<DictionaryListData> {
  final Value<int> id;
  final Value<String> path;
  final Value<String?> fontPath;
  const DictionaryListCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.fontPath = const Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.fontPath = const Value.absent(),
  }) : path = Value(path);
  static Insertable<DictionaryListData> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<String>? fontPath,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (fontPath != null) 'font_path': fontPath,
    });
  }

  DictionaryListCompanion copyWith(
      {Value<int>? id, Value<String>? path, Value<String?>? fontPath}) {
    return DictionaryListCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      fontPath: fontPath ?? this.fontPath,
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
    if (fontPath.present) {
      map['font_path'] = Variable<String>(fontPath.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('fontPath: $fontPath')
          ..write(')'))
        .toString();
  }
}

class DatabaseAtV2 extends GeneratedDatabase {
  DatabaseAtV2(QueryExecutor e) : super(e);
  late final DictionaryList dictionaryList = DictionaryList(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dictionaryList];
  @override
  int get schemaVersion => 2;
}
