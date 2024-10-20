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

class DatabaseAtV3 extends GeneratedDatabase {
  DatabaseAtV3(QueryExecutor e) : super(e);
  late final DictionaryList dictionaryList = DictionaryList(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [dictionaryList];
  @override
  int get schemaVersion => 3;
}
