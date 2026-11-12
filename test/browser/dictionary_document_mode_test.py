"""Desktop Chromium regression for per-entry document modes in Web 查词.

Setup: uv run --with playwright playwright install chromium
Run: uv run --with playwright python test/browser/dictionary_document_mode_test.py

Each dictionary result lives in its own iframe. A DOCTYPE that lands inside
<body> is ignored by the HTML parser, so the Web UI lifts the entry's own
declaration to the front of the iframe document. MDict/StarDict entries carry
an injected HTML5 doctype (standards mode); a ZIM page keeps whatever its
archive author wrote, including no doctype at all (quirks mode).
"""

import re
import unittest
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "lib" / "services" / "web_server_service.dart"
FUNCTION = re.compile(
    r"    function splitEntryDoctype\(content\) \{[\s\S]*?\n    \}"
)

# The Web UI's iframe document, reduced to the part that decides the mode.
DOCUMENT_JS = """({script, content}) => {
  const split = new Function(script + '; return splitEntryDoctype;')();
  const parts = split(content);
  return parts.doctype + '<html><head><meta charset="utf-8"></head><body>'
       + parts.content + '</body></html>';
}"""


class DocumentModeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch()
        match = FUNCTION.search(SOURCE.read_text())
        if match is None:
            raise AssertionError("splitEntryDoctype not found in _webUiHtml")
        cls.script = match.group(0)

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()

    def setUp(self):
        self.page = self.browser.new_page()

    def tearDown(self):
        self.page.close()

    def document_for(self, content):
        return self.page.evaluate(
            DOCUMENT_JS, {"script": self.script, "content": content}
        )

    def compat_mode(self, content):
        self.page.set_content(self.document_for(content))
        return self.page.evaluate("() => document.compatMode")

    def test_mdx_and_stardict_fragments_use_standards_mode(self):
        self.assertEqual(
            self.compat_mode("<!DOCTYPE html>\n<p>definition</p>"),
            "CSS1Compat",
        )

    def test_zim_page_without_doctype_uses_quirks_mode(self):
        self.assertEqual(
            self.compat_mode(
                "<html><head></head><body><p>wiki</p></body></html>"
            ),
            "BackCompat",
        )

    def test_zim_html5_page_uses_standards_mode(self):
        self.assertEqual(
            self.compat_mode(
                "<!DOCTYPE html><html><head></head><body><p>wiki</p></body></html>"
            ),
            "CSS1Compat",
        )

    def test_legacy_doctype_is_lifted_verbatim(self):
        legacy = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">'
        document = self.document_for(
            legacy + "\n<html><body><p>wiki</p></body></html>"
        )
        self.assertTrue(document.startswith(legacy))
        self.assertNotIn(legacy, document[len(legacy):])

    def test_leading_comment_does_not_hide_the_doctype(self):
        document = self.document_for(
            "<!-- archived page -->\n<!DOCTYPE html>\n<p>wiki</p>"
        )
        self.assertTrue(document.startswith("<!-- archived page -->"))
        self.page.set_content(document)
        self.assertEqual(
            self.page.evaluate("() => document.compatMode"), "CSS1Compat"
        )


if __name__ == "__main__":
    unittest.main()
