import "package:ciyue/database/app.dart";
import "package:drift_dev/api/migrations.dart";
import "package:test/test.dart";

import "../../generated_migrations/app/schema.dart";

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('upgrade from v1 to v2', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    await verifier.migrateAndValidate(db, 2);
  });
}
