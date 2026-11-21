/**
 * A DOCTYPE inside <body> is ignored by the HTML parser, so an entry's
 * own doctype has to lead the iframe document. MDict/StarDict entries
 * carry an injected HTML5 doctype; a ZIM page keeps whatever its archive
 * author wrote (or none, which yields quirks mode). Leading whitespace
 * and comments stay with the doctype.
 */
function splitEntryDoctype(content: string) {
  const raw = content || "";
  const match = raw.match(/^((?:\s|<!--[\s\S]*?-->)*)(<!doctype[^>]*>)/i);
  if (!match) return { doctype: "", content: raw };
  return {
    doctype: (match[1] ?? "") + (match[2] ?? ""),
    content: raw.slice(match[0].length),
  };
}

export { splitEntryDoctype };

export function ciyueDecode(value: string): string {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

/**
 * Mirrors parseEntryLink in entry_anchor.dart: ## is one literal
 * hash, a lone # starts the anchor.
 */
export function parseEntryLink(raw: string): { word: string; anchor: string } {
  let word = "";
  let i = 0;
  while (i < raw.length) {
    const ch = raw.charAt(i);
    if (ch !== "#") {
      word += ch;
      i++;
      continue;
    }
    if (raw.charAt(i + 1) === "#") {
      word += "#";
      i += 2;
      continue;
    }
    return {
      word: ciyueDecode(word),
      anchor: ciyueDecode(raw.slice(i + 1)),
    };
  }
  return { word: ciyueDecode(word), anchor: "" };
}
