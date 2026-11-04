import "dart:convert";

import "package:mime/mime.dart";

/// Best-effort charset of a text resource (stylesheet or script).
///
/// A dictionary's CSS/JS may be UTF-8, UTF-16 with a BOM, or UTF-16 without
/// one. Some sheets also declare a charset (`@charset`) that disagrees with
/// their bytes — a UTF-8 file claiming `utf-16`, for instance. Measuring the
/// bytes lets the HTTP `Content-Type` charset win over such a declaration,
/// while a genuinely UTF-16 file is still decoded with its real encoding.
///
/// Returns a MIME charset name, or null when it cannot be determined (the
/// caller then leaves the charset unspecified and the browser falls back to
/// the file's BOM / `@charset`).
String? guessTextCharset(List<int> bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return "utf-8";
  }
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    return "utf-16le";
  }
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    return "utf-16be";
  }

  // Without a BOM, UTF-16 ASCII text is half NUL bytes (one 0x00 per
  // character); UTF-8/ASCII text has none. Check the first 512 bytes.
  final sample = bytes.length < 512 ? bytes.length : 512;
  var zeros = 0;
  for (var i = 0; i < sample; i++) {
    if (bytes[i] == 0) zeros++;
  }
  if (sample > 0 && zeros * 5 > sample) {
    var evenZeros = 0;
    var oddZeros = 0;
    for (var i = 0; i < sample; i++) {
      if (bytes[i] != 0) continue;
      if (i.isEven) {
        evenZeros++;
      } else {
        oddZeros++;
      }
    }
    // In UTF-16LE the NUL is the high byte of an ASCII character, so it
    // sits at odd offsets; UTF-16BE puts it at even offsets.
    return oddZeros >= evenZeros ? "utf-16le" : "utf-16be";
  }

  try {
    utf8.decode(bytes);
    return "utf-8";
  } on FormatException {
    return null;
  }
}

/// `Content-Type` for a dictionary resource, pinning the charset for
/// stylesheets/scripts when the bytes make it clear.
String resourceContentType(String path, List<int>? bytes) {
  final lower = path.toLowerCase();
  final isCss = lower.endsWith(".css");
  final isJs = lower.endsWith(".js");
  if (!isCss && !isJs) {
    return lookupMimeType(path) ?? "application/octet-stream";
  }
  final base = isCss ? "text/css" : "application/javascript";
  if (bytes == null) return base;
  final charset = guessTextCharset(bytes);
  return charset == null ? base : "$base; charset=$charset";
}
