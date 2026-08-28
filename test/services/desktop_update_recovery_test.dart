import "dart:io";

import "package:ciyue/services/desktop_update_recovery.dart";
import "package:desktop_updater/desktop_updater.dart" as desktop_updater;
import "package:flutter_test/flutter_test.dart";

void main() {
  test("recovery store round-trips pending installs by channel", () async {
    final directory = await Directory.systemTemp.createTemp(
      "ciyue-desktop-update-recovery-",
    );
    addTearDown(() => directory.delete(recursive: true));

    final file = File("${directory.path}/pending-install-stable.json");
    final store = JsonFileUpdateRecoveryStore(file);
    final marker = desktop_updater.UpdateInstallRecoveryMarker(
      createdAt: DateTime.utc(2026, 1, 1),
      packageVersion: "3.1.6",
      platform: "linux",
      channel: "stable",
      updateVersion: "1.24.0",
      updateBuildNumber: 88,
    );

    await store.writePendingInstall(marker);

    final restored = await store.readPendingInstall(channel: "stable");
    expect(restored?.updateVersion, "1.24.0");
    expect(restored?.updateBuildNumber, 88);
    expect(await store.readPendingInstall(channel: "beta"), isNull);

    await store.clearPendingInstall(channel: "stable");
    expect(await file.exists(), isFalse);
  });
}
