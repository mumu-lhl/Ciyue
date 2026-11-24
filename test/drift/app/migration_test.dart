import "package:drift/drift.dart";
import "package:drift_dev/api/migrations_native.dart";
import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:test/test.dart";

import "generated/schema.dart";
import "generated/schema_v26.dart" as v26;
import "generated/schema_v27.dart" as v27;
import "generated/schema_v28.dart" as v28;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group("simple database migrations", () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    final versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group("from $fromVersion", () {
        for (final toVersion in versions.skip(i + 1)) {
          test("to $toVersion", () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group("v26 to v27 personal dictionary foreign keys (P2-2)", () {
    test("preserves personal data and enforces the new foreign keys", () async {
      final schema = await verifier.schemaAt(26);
      final oldDb = v26.DatabaseAtV26(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO dictionary_list (path, title, type) "
        "VALUES ('personal:1', 'Words', 4)",
      );
      await oldDb.customStatement(
        "INSERT INTO personal_articles "
        "(dictionary_id, body, created_at, updated_at) "
        "VALUES (1, 'a fruit', 0, 0)",
      );
      await oldDb.customStatement(
        "INSERT INTO personal_headwords "
        "(dictionary_id, article_id, headword, normalized_headword) "
        "VALUES (1, 1, 'apple', 'apple')",
      );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 27);

      // The table rebuilds copied every row.
      final dao = PersonalDictionaryDao(db);
      expect(await dao.countArticles(1), 1);
      expect((await dao.articlesForDictionary(1)).single.body, "a fruit");
      expect(await dao.countHeadwords(1), 1);

      // Foreign keys are actually enforced: drift leaves the pragma off
      // unless beforeOpen turns it on.
      final foreignKeys = await db
          .customSelect("PRAGMA foreign_keys")
          .getSingle();
      expect(foreignKeys.read<bool>("foreign_keys"), isTrue);

      // A headword for a dictionary that does not exist is rejected.
      await expectLater(
        dao.insertHeadwords([
          PersonalHeadwordsCompanion(
            dictionaryId: const Value(99999),
            articleId: const Value(1),
            headword: const Value("ghost"),
            normalizedHeadword: const Value("ghost"),
          ),
        ]),
        throwsA(isA<Object>()),
      );

      // Deleting the list row directly — bypassing the service — no
      // longer orphans the dictionary's rows: the cascade removes them.
      await DictionaryListDao(db).removeById(1);
      expect(await dao.countArticles(1), 0);
      expect(await dao.countHeadwords(1), 0);
      await db.close();
    });
  });

  group("v27 to v28 Hunspell group membership", () {
    test("seeds every enabled word list into every existing group", () async {
      final schema = await verifier.schemaAt(27);
      final oldDb = v27.DatabaseAtV27(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO dict_group (name, dict_ids) VALUES ('Default', '')",
      );
      await oldDb.customStatement(
        "INSERT INTO dict_group (name, dict_ids) VALUES ('English', '')",
      );
      await oldDb.customStatement(
        "INSERT INTO hunspell_source (name, aff_path, dic_path, enabled) "
        "VALUES ('de_DE', 'de.aff', 'de.dic', 1)",
      );
      await oldDb.customStatement(
        "INSERT INTO hunspell_source (name, aff_path, dic_path, enabled) "
        "VALUES ('en_US', 'en.aff', 'en.dic', 1)",
      );
      await oldDb.customStatement(
        "INSERT INTO hunspell_source (name, aff_path, dic_path, enabled) "
        "VALUES ('ja_JP', 'ja.aff', 'ja.dic', 0)",
      );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 28);

      final dao = DictGroupDao(db);
      final groups = await dao.getAllGroups();
      expect(groups, hasLength(2));
      for (final group in groups) {
        expect(await dao.getHunspellIds(group.id), [1, 2]);
      }
      await db.close();
    });

    test(
      "leaves every group with an empty set when no word list is enabled",
      () async {
        final schema = await verifier.schemaAt(27);
        final oldDb = v27.DatabaseAtV27(schema.newConnection());
        await oldDb.customStatement(
          "INSERT INTO dict_group (name, dict_ids) VALUES ('Default', '')",
        );
        await oldDb.customStatement(
          "INSERT INTO dict_group (name, dict_ids) VALUES ('English', '')",
        );
        // Only a disabled word list: group_concat over enabled rows is NULL.
        await oldDb.customStatement(
          "INSERT INTO hunspell_source (name, aff_path, dic_path, enabled) "
          "VALUES ('ja_JP', 'ja.aff', 'ja.dic', 0)",
        );
        await oldDb.close();

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 28);

        final dao = DictGroupDao(db);
        final groups = await dao.getAllGroups();
        expect(groups, hasLength(2));
        for (final group in groups) {
          expect(await dao.getHunspellIds(group.id), isEmpty);
        }
        await db.close();
      },
    );

    test(
      "retries cleanly when the column was left behind by a failed run",
      () async {
        final schema = await verifier.schemaAt(27);
        final oldDb = v27.DatabaseAtV27(schema.newConnection());
        await oldDb.customStatement(
          "INSERT INTO dict_group (name, dict_ids) VALUES ('Default', '')",
        );
        await oldDb.customStatement(
          "INSERT INTO hunspell_source (name, aff_path, dic_path, enabled) "
          "VALUES ('en_US', 'en.aff', 'en.dic', 1)",
        );
        // The state a pre-fix build left behind: the step added the
        // column, then the UPDATE threw, so the version stayed 27.
        await oldDb.customStatement(
          "ALTER TABLE dict_group ADD COLUMN hunspell_ids "
          "TEXT NOT NULL DEFAULT ''",
        );
        await oldDb.close();

        final db = AppDatabase(schema.newConnection());
        await verifier.migrateAndValidate(db, 28);

        final dao = DictGroupDao(db);
        final groups = await dao.getAllGroups();
        expect(groups, hasLength(1));
        expect(await dao.getHunspellIds(groups.single.id), [1]);
        await db.close();
      },
    );
  });

  group("v28 to v29 AI explanation source language", () {
    test("preserves old rows as auto and allows per-language rows", () async {
      final schema = await verifier.schemaAt(28);
      final oldDb = v28.DatabaseAtV28(schema.newConnection());
      await oldDb.customStatement(
        "INSERT INTO ai_explanations (word, explanation) "
        "VALUES ('中国', 'old explanation')",
      );
      await oldDb.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 29);

      final dao = AiExplanationDao(db);
      final legacy = await dao.getAiExplanation("中国");
      expect(legacy?.explanation, "old explanation");

      await dao.insertAiExplanation(
        AiExplanation(
          word: "中国",
          sourceLanguage: "ja",
          explanation: "Japanese explanation",
        ),
      );
      expect(
        (await dao.getAiExplanation("中国", sourceLanguage: "ja"))?.explanation,
        "Japanese explanation",
      );
      expect(
        (await dao.getAiExplanation("中国"))?.explanation,
        "old explanation",
      );

      await db.close();
    });
  });
}
