// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app.dart';

// ignore_for_file: type=lint
class $DictionaryListTable extends DictionaryList
    with drift.TableInfo<$DictionaryListTable, DictionaryListData> {
  @override
  final drift.GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DictionaryListTable(this.attachedDatabase, [this._alias]);
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
  List<drift.GeneratedColumn> get $columns => [id, path];
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
  final int id;
  final String path;
  const DictionaryListData({required this.id, required this.path});
  @override
  Map<String, drift.Expression> toColumns(bool nullToAbsent) {
    final map = <String, drift.Expression>{};
    map['id'] = drift.Variable<int>(id);
    map['path'] = drift.Variable<String>(path);
    return map;
  }

  DictionaryListCompanion toCompanion(bool nullToAbsent) {
    return DictionaryListCompanion(
      id: drift.Value(id),
      path: drift.Value(path),
    );
  }

  factory DictionaryListData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return DictionaryListData(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= drift.driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
    };
  }

  DictionaryListData copyWith({int? id, String? path}) => DictionaryListData(
        id: id ?? this.id,
        path: path ?? this.path,
      );
  DictionaryListData copyWithCompanion(DictionaryListCompanion data) {
    return DictionaryListData(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListData(')
          ..write('id: $id, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DictionaryListData &&
          other.id == this.id &&
          other.path == this.path);
}

class DictionaryListCompanion
    extends drift.UpdateCompanion<DictionaryListData> {
  final drift.Value<int> id;
  final drift.Value<String> path;
  const DictionaryListCompanion({
    this.id = const drift.Value.absent(),
    this.path = const drift.Value.absent(),
  });
  DictionaryListCompanion.insert({
    this.id = const drift.Value.absent(),
    required String path,
  }) : path = drift.Value(path);
  static drift.Insertable<DictionaryListData> custom({
    drift.Expression<int>? id,
    drift.Expression<String>? path,
  }) {
    return drift.RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
    });
  }

  DictionaryListCompanion copyWith(
      {drift.Value<int>? id, drift.Value<String>? path}) {
    return DictionaryListCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DictionaryListCompanion(')
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
  drift.Value<int> id,
  required String path,
});
typedef $$DictionaryListTableUpdateCompanionBuilder = DictionaryListCompanion
    Function({
  drift.Value<int> id,
  drift.Value<String> path,
});

class $$DictionaryListTableFilterComposer
    extends drift.FilterComposer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableFilterComposer(super.$state);
  drift.ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));

  drift.ColumnFilters<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          drift.ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$DictionaryListTableOrderingComposer
    extends drift.OrderingComposer<_$AppDatabase, $DictionaryListTable> {
  $$DictionaryListTableOrderingComposer(super.$state);
  drift.ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));

  drift.ColumnOrderings<String> get path => $state.composableBuilder(
      column: $state.table.path,
      builder: (column, joinBuilders) =>
          drift.ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $$DictionaryListTableTableManager extends drift.RootTableManager<
    _$AppDatabase,
    $DictionaryListTable,
    DictionaryListData,
    $$DictionaryListTableFilterComposer,
    $$DictionaryListTableOrderingComposer,
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
          filteringComposer: $$DictionaryListTableFilterComposer(
              drift.ComposerState(db, table)),
          orderingComposer: $$DictionaryListTableOrderingComposer(
              drift.ComposerState(db, table)),
          updateCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            drift.Value<String> path = const drift.Value.absent(),
          }) =>
              DictionaryListCompanion(
            id: id,
            path: path,
          ),
          createCompanionCallback: ({
            drift.Value<int> id = const drift.Value.absent(),
            required String path,
          }) =>
              DictionaryListCompanion.insert(
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
