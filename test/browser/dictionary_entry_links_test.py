"""Desktop Chromium regression for #725; no Android app required.

Setup: uv run --with playwright playwright install chromium
Run: uv run --with playwright python test/browser/dictionary_entry_links_test.py
"""

from html import escape
from pathlib import Path
import re
import unittest
from urllib.parse import unquote

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "lib/ui/core/word_display/entry_link_script.dart"


class DictionaryEntryLinksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.playwright = sync_playwright().start()
        cls.browser = cls.playwright.chromium.launch()
        cls.script = re.search(r'r"""\n(.*?)""";', SOURCE.read_text(), re.S).group(1)

    @classmethod
    def tearDownClass(cls):
        cls.browser.close()
        cls.playwright.stop()

    def setUp(self):
        self.page = self.browser.new_page()
        self.page.add_init_script(self.script)
        # A real document navigation runs the same document-start script as
        # initialUserScripts; set_content alone does not run init scripts.
        self.page.route("http://ciyue.internal/**", lambda r: r.fulfill(
            content_type="text/html", body="<!doctype html><html><body></body></html>"
        ))
        self.page.goto("http://ciyue.internal/")
        self.cdp = self.page.context.new_cdp_session(self.page)
        self.cdp.send("Page.enable")
        self.targets = []
        self.cdp.on("Page.frameRequestedNavigation", lambda e: self.targets.append(e["url"]))

    def tearDown(self):
        self.page.close()

    def navigate(self, href, markup="link", keyboard=False):
        # Inserted after document-start, also covering dynamic dictionary HTML.
        self.page.evaluate("html => document.body.innerHTML = html",
                           f'<a href="{escape(href, quote=True)}">{markup}</a>')
        if keyboard:
            self.page.locator("a").focus()
            self.page.keyboard.press("Enter")
        else:
            self.page.locator("a").click()
        self.assertTrue(self.targets, "click did not request navigation")
        return self.targets[-1]

    def test_issue_725_targets(self):
        # Minimal links from the three supplied MDX files. Display text is not
        # the lookup key: one uses ～ and another uses a CSS-rendered <tilde>.
        for word, markup in [
            ("怀刷", "怀～"),
            ("人怕出名猪怕壮", "人<tilde></tilde>出名猪怕壮"),
            ("卡尺", "卡尺"),
        ]:
            with self.subTest(word=word):
                self.assertEqual(unquote(self.navigate("entry://" + word, markup)),
                                 "entry://" + word)

    def test_nested_target(self):
        self.page.evaluate('''() => {
          document.body.innerHTML = '<a href="entry://怀刷"><span>怀～</span></a>';
        }''')
        self.page.locator("span").click()
        self.assertEqual(unquote(self.targets[-1]), "entry://怀刷")

    def test_keyboard_activation(self):
        self.assertEqual(unquote(self.navigate("entry://卡尺", keyboard=True)), "entry://卡尺")

    def test_existing_escapes_are_not_double_encoded(self):
        href = "entry://%E5%8D%A1尺"
        self.assertEqual(unquote(self.navigate(href)), "entry://卡尺")

    def test_ascii_entry_links_are_unchanged(self):
        href = "entry://CamelCase%20word/path?x=1#section"
        self.assertEqual(self.navigate(href), href)

    def test_other_links_are_not_rewritten(self):
        for href in ["sound://voice.mp3", "https://example.com/", "#section"]:
            with self.subTest(href=href):
                self.page.evaluate('''href => {
                  document.body.innerHTML = '<a>link</a>';
                  const a = document.querySelector('a');
                  a.setAttribute('href', href);
                  a.addEventListener('click', e => e.preventDefault());
                }''', href)
                self.page.locator("a").click()
                self.assertEqual(self.page.locator("a").get_attribute("href"), href)


if __name__ == "__main__":
    unittest.main()
