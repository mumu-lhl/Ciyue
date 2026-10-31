import "dart:io";

import "package:ciyue/models/dictionary_lookup.dart";
import "package:path/path.dart";

/// The file a dictionary needs but cannot find, or null when every file it
/// needs is present.
///
/// An MDX dictionary is a single file. A StarDict one is three — the `.ifo`
/// header, the `.idx` index and the `.dict` body, the last two optionally
/// gzip-compressed — so a check written for `.mdx` alone made every StarDict
/// dictionary look broken, and switching one on in the settings deleted its
/// registration (#766).
///
/// Returns the bare file name, which is what the message shows; null means the
/// dictionary can be opened.
Future<String?> missingDictionaryFile(String path, int type) async {
  final required = DictionaryType.isZim(type)
      ? const [
          [".zim"],
        ]
      : DictionaryType.isStardict(type)
      ? const [
          [".ifo"],
          [".idx", ".idx.gz"],
          [".dict", ".dict.dz"],
        ]
      : const [
          [".mdx"],
        ];

  for (final extensions in required) {
    var found = false;
    for (final extension in extensions) {
      if (await File("$path$extension").exists()) {
        found = true;
        break;
      }
    }
    // Name the first spelling of the missing piece: "…idx" is what the user
    // was told to expect, whether or not the compressed form was the one
    // looked for.
    if (!found) return basename("$path${extensions.first}");
  }

  return null;
}
