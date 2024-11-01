import 'package:drift/internal/versioned_schema.dart' as i0;
import 'package:drift/drift.dart' as i1;
import 'package:drift/drift.dart'; // ignore_for_file: type=lint,unused_import

// GENERATED BY drift_dev, DO NOT MODIFY.
final class Schema2 extends i0.VersionedSchema {
  Schema2({required super.database}) : super(version: 2);
  @override
  late final List<i1.DatabaseSchemaEntity> entities = [
    wordbook,
    resource,
    dictionary,
    idxWordbook,
    idxData,
    idxWord,
  ];
  late final Shape0 wordbook = Shape0(
      source: i0.VersionedTable(
        entityName: 'wordbook',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_0,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  late final Shape1 resource = Shape1(
      source: i0.VersionedTable(
        entityName: 'resource',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_1,
          _column_2,
          _column_3,
          _column_4,
          _column_5,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  late final Shape1 dictionary = Shape1(
      source: i0.VersionedTable(
        entityName: 'dictionary',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_1,
          _column_2,
          _column_3,
          _column_4,
          _column_5,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  final i1.Index idxWordbook =
      i1.Index('idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  final i1.Index idxData =
      i1.Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  final i1.Index idxWord =
      i1.Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
}

class Shape0 extends i0.VersionedTable {
  Shape0({required super.source, required super.alias}) : super.aliased();
  i1.GeneratedColumn<String> get word =>
      columnsByName['word']! as i1.GeneratedColumn<String>;
}

i1.GeneratedColumn<String> _column_0(String aliasedName) =>
    i1.GeneratedColumn<String>('word', aliasedName, false,
        type: i1.DriftSqlType.string,
        defaultConstraints: i1.GeneratedColumn.constraintIsAlways('UNIQUE'));

class Shape1 extends i0.VersionedTable {
  Shape1({required super.source, required super.alias}) : super.aliased();
  i1.GeneratedColumn<int> get blockOffset =>
      columnsByName['block_offset']! as i1.GeneratedColumn<int>;
  i1.GeneratedColumn<int> get compressedSize =>
      columnsByName['compressed_size']! as i1.GeneratedColumn<int>;
  i1.GeneratedColumn<int> get endOffset =>
      columnsByName['end_offset']! as i1.GeneratedColumn<int>;
  i1.GeneratedColumn<String> get key =>
      columnsByName['key']! as i1.GeneratedColumn<String>;
  i1.GeneratedColumn<int> get startOffset =>
      columnsByName['start_offset']! as i1.GeneratedColumn<int>;
}

i1.GeneratedColumn<int> _column_1(String aliasedName) =>
    i1.GeneratedColumn<int>('block_offset', aliasedName, false,
        type: i1.DriftSqlType.int);
i1.GeneratedColumn<int> _column_2(String aliasedName) =>
    i1.GeneratedColumn<int>('compressed_size', aliasedName, false,
        type: i1.DriftSqlType.int);
i1.GeneratedColumn<int> _column_3(String aliasedName) =>
    i1.GeneratedColumn<int>('end_offset', aliasedName, false,
        type: i1.DriftSqlType.int);
i1.GeneratedColumn<String> _column_4(String aliasedName) =>
    i1.GeneratedColumn<String>('key', aliasedName, false,
        type: i1.DriftSqlType.string);
i1.GeneratedColumn<int> _column_5(String aliasedName) =>
    i1.GeneratedColumn<int>('start_offset', aliasedName, false,
        type: i1.DriftSqlType.int);

final class Schema3 extends i0.VersionedSchema {
  Schema3({required super.database}) : super(version: 3);
  @override
  late final List<i1.DatabaseSchemaEntity> entities = [
    wordbookTags,
    wordbook,
    resource,
    dictionary,
    idxWordbook,
    idxWordbookTags,
    idxData,
    idxWord,
  ];
  late final Shape2 wordbookTags = Shape2(
      source: i0.VersionedTable(
        entityName: 'wordbook_tags',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_6,
          _column_7,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  late final Shape3 wordbook = Shape3(
      source: i0.VersionedTable(
        entityName: 'wordbook',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_8,
          _column_0,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  late final Shape1 resource = Shape1(
      source: i0.VersionedTable(
        entityName: 'resource',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_1,
          _column_2,
          _column_3,
          _column_4,
          _column_5,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  late final Shape1 dictionary = Shape1(
      source: i0.VersionedTable(
        entityName: 'dictionary',
        withoutRowId: false,
        isStrict: false,
        tableConstraints: [],
        columns: [
          _column_1,
          _column_2,
          _column_3,
          _column_4,
          _column_5,
        ],
        attachedDatabase: database,
      ),
      alias: null);
  final i1.Index idxWordbook =
      i1.Index('idx_wordbook', 'CREATE INDEX idx_wordbook ON wordbook (word)');
  final i1.Index idxWordbookTags = i1.Index('idx_wordbook_tags',
      'CREATE INDEX idx_wordbook_tags ON wordbook_tags (tag)');
  final i1.Index idxData =
      i1.Index('idx_data', 'CREATE INDEX idx_data ON resource ("key")');
  final i1.Index idxWord =
      i1.Index('idx_word', 'CREATE INDEX idx_word ON dictionary ("key")');
}

class Shape2 extends i0.VersionedTable {
  Shape2({required super.source, required super.alias}) : super.aliased();
  i1.GeneratedColumn<int> get id =>
      columnsByName['id']! as i1.GeneratedColumn<int>;
  i1.GeneratedColumn<String> get tag =>
      columnsByName['tag']! as i1.GeneratedColumn<String>;
}

i1.GeneratedColumn<int> _column_6(String aliasedName) =>
    i1.GeneratedColumn<int>('id', aliasedName, false,
        hasAutoIncrement: true,
        type: i1.DriftSqlType.int,
        defaultConstraints:
            i1.GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
i1.GeneratedColumn<String> _column_7(String aliasedName) =>
    i1.GeneratedColumn<String>('tag', aliasedName, false,
        type: i1.DriftSqlType.string,
        defaultConstraints: i1.GeneratedColumn.constraintIsAlways('UNIQUE'));

class Shape3 extends i0.VersionedTable {
  Shape3({required super.source, required super.alias}) : super.aliased();
  i1.GeneratedColumn<int> get tag =>
      columnsByName['tag']! as i1.GeneratedColumn<int>;
  i1.GeneratedColumn<String> get word =>
      columnsByName['word']! as i1.GeneratedColumn<String>;
}

i1.GeneratedColumn<int> _column_8(String aliasedName) =>
    i1.GeneratedColumn<int>('tag', aliasedName, true,
        type: i1.DriftSqlType.int,
        defaultConstraints: i1.GeneratedColumn.constraintIsAlways(
            'REFERENCES wordbook_tags (id)'));
i0.MigrationStepWithVersion migrationSteps({
  required Future<void> Function(i1.Migrator m, Schema2 schema) from1To2,
  required Future<void> Function(i1.Migrator m, Schema3 schema) from2To3,
}) {
  return (currentVersion, database) async {
    switch (currentVersion) {
      case 1:
        final schema = Schema2(database: database);
        final migrator = i1.Migrator(database, schema);
        await from1To2(migrator, schema);
        return 2;
      case 2:
        final schema = Schema3(database: database);
        final migrator = i1.Migrator(database, schema);
        await from2To3(migrator, schema);
        return 3;
      default:
        throw ArgumentError.value('Unknown migration from $currentVersion');
    }
  };
}

i1.OnUpgrade stepByStep({
  required Future<void> Function(i1.Migrator m, Schema2 schema) from1To2,
  required Future<void> Function(i1.Migrator m, Schema3 schema) from2To3,
}) =>
    i0.VersionedSchema.stepByStepHelper(
        step: migrationSteps(
      from1To2: from1To2,
      from2To3: from2To3,
    ));
