// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// ignore_for_file: type=lint
class $DictionaryListTable extends DictionaryList
    with drift.TableInfo<$DictionaryListTable, DictionaryListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryListTable(this.attachedDatabase, [this._alias]);
  static const drift.VerificationMeta _backupPathMeta =
      const drift.VerificationMeta('backupPath');
  @override
  late final drift.GeneratedColumn<String> backupPath =
      drift.GeneratedColumn<String>('backup_path', aliasedName, true,
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
  static const drift.VerificationMeta _pathMeta =
      const drift.VerificationMeta('path');
  @override
  late final drift.GeneratedColumn<String> path = drift.GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<drift.GeneratedColumn> get $columns => [backupPath, fontPath, id, path];
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
    if (data.containsKey('backup_path')) {
      context.handle(
          _backupPathMeta,
          backupPath.isAcceptableOrUnknown(
              data['backup_path']!, _backupPathMeta));
    }
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
    return context;
  }

  @override
  Set<drift.GeneratedColumn> get $primaryKey => {id};
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
  $DictionaryListTable createAlias(String alias) {
    return $DictionaryListTable(attachedDatabase, alias);
  }
}

class DictionaryListData extends drift.DataClass
    implements drift.Insertable<DictionaryListData> {
  final String? backupPath;
  final String? fontPath;
  final int id;
  final String path;
  const DictionaryListData(
      {this.backupPath, this.fontPath, required this.id, required this.path});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (!nullToAbsent || backupPath != null) {
      map['backup_path'] = drift.Variable<String>(backupPath);
    }
    if (!nullToAbsent || fontPath != null) {
      map['font_path'] = drift.Variable<String>(fontPath);
    }
    map['id'] = drift.Variable<int>(id);
    map['path'] = drift.Variable<String>(path);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      backupPath: backupPath == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(backupPath),
      fontPath: fontPath == null && nullToAbsent
          ? const drift.Value.absent()
          : drift.Value(fontPath),
      id: drift.Value(id),
      path: drift.Value(path),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      backupPath: serializer.fromJson<String?>(json['backupPath']),
      fontPath: serializer.fromJson<String?>(json['fontPath']),
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'backupPath': serializer.toJson<String?>(backupPath),
      'fontPath': serializer.toJson<String?>(fontPath),
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  DictionaryListData copyWith(
          {drift.Value<String?> backupPath = const drift.Value.absent(),
          drift.Value<String?> fontPath = const drift.Value.absent(),
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

class DictionaryListCompanion
    extends drift.UpdateCompanion<DictionaryListData> {
  final drift.Value<String?> backupPath;
  final drift.Value<String?> fontPath;
  final drift.Value<int> id;
  final drift.Value<String> path;
  const DictionaryListCompanion({
    this.backupPath = const drift.Value.absent(),
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.backupPath = const drift.Value.absent(),
    this.fontPath = const drift.Value.absent(),
    this.id = const drift.Value.absent(),
    required String path,
  }) : path = drift.Value(path);
  static drift.Insertable<DictionaryListData> custom({
    drift.Expression<String>? backupPath,
    drift.Expression<String>? fontPath,
    drift.Expression<int>? id,
    drift.Expression<String>? path,
  }) {
    return drift.RawValuesInsertable({
      if (backupPath != null) 'backup_path': backupPath,
      if (fontPath != null) 'font_path': fontPath,
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  DictionaryListCompanion copyWith(
      {drift.Value<String?>? backupPath,
      drift.Value<String?>? fontPath,
      drift.Value<int>? id,
      drift.Value<String>? path}) {
    return DictionaryListCompanion(
      backupPath: backupPath ?? this.backupPath,
      fontPath: fontPath ?? this.fontPath,
      id: id ?? this.id,
      path: path ?? this.path,
    );
  }

  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    if (backupPath.present) {
      map['backup_path'] = drift.Variable<String>(backupPath.value);
    }
    if (fontPath.present) {
      map['font_path'] = drift.Variable<String>(fontPath.value);
    }
    if (id.present) {
      map['id'] = drift.Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = drift.Variable<String>(path.value);
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

abstract class _$AppDatabase extends drift.GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DictionaryListTable dictionaryList = $DictionaryListTable(this);
  @override
  Iterable<drift.TableInfo<drift.Table, Object?>> get allTables =>
      allSchemaEntities.whereType<drift.TableInfo<drift.Table, Object?>>();
  @override
  List<drift.DatabaseSchemaEntity> get allSchemaEntities => [dictionaryList];
}

typedef $$DictionaryListTableCreateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> backupPath,
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  required String path,
});
typedef $$DictionaryListTableUpdateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<String?> backupPath,
  drift.Value<String?> fontPath,
  drift.Value<int> id,
  drift.Value<String> path,
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
  drift.ColumnFilters<String> get backupPath => $composableBuilder(
      column: $table.backupPath,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnFilters(column));

  drift.ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnFilters(column));
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
  drift.ColumnOrderings<String> get backupPath => $composableBuilder(
      column: $table.backupPath,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get fontPath => $composableBuilder(
      column: $table.fontPath,
      builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => drift.ColumnOrderings(column));

  drift.ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => drift.ColumnOrderings(column));
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
  drift.GeneratedColumn<String> get backupPath => $composableBuilder(
      column: $table.backupPath, builder: (column) => column);

  drift.GeneratedColumn<String> get fontPath =>
      $composableBuilder(column: $table.fontPath, builder: (column) => column);

  drift.GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  drift.GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);
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
            drift.Value<String?> backupPath = const drift.Value.absent(),
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion(
            backupPath: backupPath,
            fontPath: fontPath,
            id: id,
            path: path,
          ),
          createCompanionCallback: ({
            drift.Value<String?> backupPath = const drift.Value.absent(),
            drift.Value<String?> fontPath = const drift.Value.absent(),
            drift.Value<int> id = const drift.Value.absent(),
            required String path,
          }) =>
              DictionaryListCompanion.insert(
            backupPath: backupPath,
            fontPath: fontPath,
            id: id,
            path: path,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DictionaryListTableTableManager get dictionaryList =>
      $$DictionaryListTableTableManager(_db, _db.dictionaryList);
}
