// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations.dart';
import 'package:ciyue/database/dictionary.dart';
import 'package:test/test.dart';
import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = DictionaryDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // Simple tests ensure the schema is transformed correctly, but some
  // migrations benefit from a test verifying that data is transformed correctly
  // too. This is particularly true for migrations that change existing columns
  // (e.g. altering their type or constraints). Migrations that only add tables
  // or columns typically don't need these advanced tests.
  // TODO: Check whether you have migrations that could benefit from these tests
  // and adapt this example to your database if necessary:
  test("migration from v1 to v2 does not corrupt data", () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    final oldWordbookData = <v1.WordbookData>[];
    final expectedNewWordbookData = <v2.WordbookData>[];

    final oldResourceData = <v1.ResourceData>[];
    final expectedNewResourceData = <v2.ResourceData>[];

    final oldDictionaryData = <v1.DictionaryData>[];
    final expectedNewDictionaryData = <v2.DictionaryData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: DictionaryDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.wordbook, oldWordbookData);
        batch.insertAll(oldDb.resource, oldResourceData);
        batch.insertAll(oldDb.dictionary, oldDictionaryData);
      },
      validateItems: (newDb) async {
        expect(
            expectedNewWordbookData, await newDb.select(newDb.wordbook).get());
        expect(
            expectedNewResourceData, await newDb.select(newDb.resource).get());
        expect(expectedNewDictionaryData,
            await newDb.select(newDb.dictionary).get());
      },
    );
  });
}