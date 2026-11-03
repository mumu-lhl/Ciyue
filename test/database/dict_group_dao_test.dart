import "package:ciyue/database/app/app.dart";
import "package:ciyue/database/app/daos.dart";
import "package:drift/drift.dart";
import "package:drift/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late AppDatabase database;
  late DictGroupDao dao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = DictGroupDao(database);
  });

  tearDown(() => database.close());

  test("lists the groups in the order they were added", () async {
    await dao.addGroup("Default", []);
    await dao.addGroup("English", []);
    await dao.addGroup("Japanese", []);

    final groups = await dao.getAllGroups();

    expect(groups.map((g) => g.name), ["Default", "English", "Japanese"]);
  });

  test("updateOrder persists the given order", () async {
    await dao.addGroup("Default", []);
    await dao.addGroup("English", []);
    await dao.addGroup("Japanese", []);
    final groups = await dao.getAllGroups();

    await dao.updateOrder([groups[0], groups[2], groups[1]]);

    expect((await dao.getAllGroups()).map((g) => g.name), [
      "Default",
      "Japanese",
      "English",
    ]);
  });

  test("a group added after a reorder goes to the end", () async {
    await dao.addGroup("Default", []);
    await dao.addGroup("English", []);
    await dao.addGroup("Japanese", []);
    final groups = await dao.getAllGroups();
    await dao.updateOrder([groups[0], groups[2], groups[1]]);

    await dao.addGroup("French", []);

    expect((await dao.getAllGroups()).map((g) => g.name), [
      "Default",
      "Japanese",
      "English",
      "French",
    ]);
  });

  test("groups sharing an order fall back to their id", () async {
    // Rows migrated from v24 all get order 0, so they have to keep the order
    // they were created in, with the default group first.
    Future<void> insertLegacy(String name) {
      return database
          .into(database.dictGroup)
          .insert(
            DictGroupCompanion.insert(
              dictIds: "[]",
              name: name,
              order: const Value(0),
            ),
          );
    }

    await insertLegacy("Default");
    await insertLegacy("English");

    final groups = await dao.getAllGroups();

    expect(groups.map((g) => g.name), ["Default", "English"]);
    expect(groups.map((g) => g.order), [0, 0]);
  });
}
