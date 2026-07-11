import "package:ciyue/core/app_initialization.dart";
import "package:ciyue/repositories/settings.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

void main() {
  test("preferences allowlist loads every startup setting", () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    await initPrefs();

    expect(Settings.new, returnsNormally);
  });
}
