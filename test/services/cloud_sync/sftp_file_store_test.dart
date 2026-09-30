import "package:ciyue/services/cloud_sync/sftp_file_store.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("requires a pinned host key and an authentication method", () {
    expect(
      () => SftpCloudFileStore(
        endpoint: Uri.parse("sftp://server.example.test:22"),
        username: "alice",
        password: "secret",
        expectedHostKeyFingerprint: "",
      ),
      throwsArgumentError,
    );
    expect(
      () => SftpCloudFileStore(
        endpoint: Uri.parse("sftp://server.example.test:22"),
        username: "alice",
        expectedHostKeyFingerprint: "SHA256:abc",
      ),
      throwsArgumentError,
    );
  });

  test("rejects unsafe or ambiguous server URLs", () {
    for (final endpoint in [
      "https://server.example.test",
      "sftp://alice:secret@server.example.test",
      "sftp://server.example.test/path?token=secret",
    ]) {
      expect(
        () => SftpCloudFileStore(
          endpoint: Uri.parse(endpoint),
          username: "alice",
          password: "secret",
          expectedHostKeyFingerprint: "SHA256:abc",
        ),
        throwsArgumentError,
        reason: endpoint,
      );
    }
  });

  test(
    "accepts password or private-key authentication without connecting",
    () async {
      final passwordStore = SftpCloudFileStore(
        endpoint: Uri.parse("sftp://server.example.test:2222/backups"),
        username: "alice",
        password: "secret",
        expectedHostKeyFingerprint: "SHA256:known-host-key",
      );
      final keyStore = SftpCloudFileStore(
        endpoint: Uri.parse("sftp://server.example.test"),
        username: "alice",
        privateKey: "private-key-pem",
        keyPassphrase: "passphrase",
        expectedHostKeyFingerprint: "SHA256:known-host-key",
      );

      await passwordStore.close();
      await keyStore.close();
    },
  );
}
