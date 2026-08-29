import "../hook/process_manager.dart";

import "package:test/test.dart";

void main() {
  test("removes common Linux ccache wrapper directories", () {
    expect(
      removeCcachePathEntries(
        "/usr/lib64/ccache:/usr/bin:/usr/lib/ccache/bin:/usr/local/bin",
      ),
      "/usr/bin:/usr/local/bin",
    );
  });

  test("keeps non-ccache compiler directories", () {
    expect(
      removeCcachePathEntries("/opt/llvm/bin:/usr/local/bin"),
      "/opt/llvm/bin:/usr/local/bin",
    );
  });
}
