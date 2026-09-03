import "package:code_assets/code_assets.dart";
import "package:hooks/hooks.dart";
import "package:native_toolchain_c/native_toolchain_c.dart";

import "process_manager.dart";

void main(List<String> args) async {
  await build(args, (input, output) async {
    final sources = [
      "src/hunspell_bridge.cc",
      for (final file in [
        "affentry.cxx",
        "affixmgr.cxx",
        "csutil.cxx",
        "filemgr.cxx",
        "hashmgr.cxx",
        "hunspell.cxx",
        "hunzip.cxx",
        "phonet.cxx",
        "replist.cxx",
        "suggestmgr.cxx",
      ])
        "third_party/hunspell/src/hunspell/$file",
    ];

    final builder = CBuilder.library(
      name: "hunspell_ffi",
      assetName: "hunspell_ffi_bindings_generated.dart",
      sources: sources,
      includes: ["third_party/hunspell/src/hunspell"],
      defines: {"HUNSPELL_STATIC": null},
      language: Language.cpp,
      // Android packages this code asset as a standalone .so. Statically link
      // libc++ so loading it does not depend on a separately bundled runtime.
      cppLinkStdLib: input.config.code.targetOS == OS.android
          ? "c++_static"
          : null,
      std: "c++17",
    );

    await builder.run(
      input: input,
      output: output,
      processManager: const CcacheSafeProcessManager(),
    );
  });
}
