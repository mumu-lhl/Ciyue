build_runner:
    flutter pub run build_runner build

scheme_dump:
    flutter pub run drift_dev schema dump lib/database/app.dart drift_schemas/app/
    flutter pub run drift_dev schema dump lib/database/dictionary.dart drift_schemas/dictionary/

steps:
    flutter pub run drift_dev schema steps drift_schemas/app lib/database/app_schema_versions.dart
    flutter pub run drift_dev schema steps drift_schemas/dictionary lib/database/dictionary_schema_versions.dart

generate_test:
    flutter pub run drift_dev schema generate drift_schemas/app/ test/generated_migrations/app/
    flutter pub run drift_dev schema generate drift_schemas/dictionary/ test/generated_migrations/dictionary/
