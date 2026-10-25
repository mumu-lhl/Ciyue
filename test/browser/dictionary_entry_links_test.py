"""Desktop Chromium regression for #725 and #738; no Android app required.

Setup: uv run --with playwright playwright install chromium
Run: uv run --with playwright python test/browser/dictionary_entry_links_test.py

A clicked link is rewritten so the word travels in the URL **path**
(`gdlookup://localhost/<percent-encoded>`). A word kept in the host would be
folded to lower case by the URL parser, turning `Haus` into `haus` and
`A.D.` into a host with a port, which is what #738 was about.

Assertions therefore check **which word the navigation resolves to**, not what
the URL looks like: the container may change again, the resolved word may not.
"""

from html import escape
from pathlib import Path
import re
import unittest
from urllib.parse import unquote

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "lib/ui/core/word_display/entry_link_script.dart"
LOOKUP_PREFIX = "gdlookup://localhost/"


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

    @staticmethod
    def word_of(url):
        """The headword a navigation target resolves to, whatever the container."""
        url = url or ""
        for prefix in (LOOKUP_PREFIX, "entry://", "bword://"):
            if url.startswith(prefix):
                return unquote(url[len(prefix):])
        return unquote(url)

    def navigate(self, href, markup="link", keyboard=False):
        # Inserted after document-start, also covering dynamic dictionary HTML.
        self.page.evaluate("html => document.body.innerHTML = html",
                           f'<a href="{escape(href, quote=True)}">{markup}</a>')
        if keyboard:
            self.page.locator("a").focus()
            self.page.keyboard.press("Enter")
        else:
            self.page.locator("a").click()
        if self.targets:
            return self.targets[-1]
        # Chromium may decline to navigate to a custom scheme; the href it was
        # handed is the same information, and it is what the app would receive.
        href_after = self.page.locator("a").get_attribute("href")
        self.assertTrue(href_after, "click produced neither navigation nor href")
        return href_after

    def test_issue_725_targets(self):
        # Minimal links from the three supplied MDX files. Display text is not
        # the lookup key: one uses ～ and another uses a CSS-rendered <tilde>.
        for word, markup in [
            ("怀刷", "怀～"),
            ("人怕出名猪怕壮", "人<tilde></tilde>出名猪怕壮"),
            ("卡尺", "卡尺"),
        ]:
            with self.subTest(word=word):
                self.assertEqual(self.word_of(self.navigate("entry://" + word, markup)), word)

    def test_nested_target(self):
        self.page.evaluate('''() => {
          document.body.innerHTML = '<a href="entry://怀刷"><span>怀～</span></a>';
        }''')
        self.page.locator("span").click()
        self.assertEqual(self.word_of(self.targets[-1]), "怀刷")

    def test_keyboard_activation(self):
        self.assertEqual(self.word_of(self.navigate("entry://卡尺", keyboard=True)), "卡尺")

    def test_existing_escapes_are_not_double_encoded(self):
        self.assertEqual(self.word_of(self.navigate("entry://%E5%8D%A1尺")), "卡尺")

    def test_issue_738_counterexamples(self):
        # The four shapes that used to break: colon, userinfo, upper case and
        # the Babylon scheme. Each must still resolve to the original string.
        for href, word in [
            ("entry://tag:sumeru", "tag:sumeru"),
            ("entry://@smk8-000001-0001", "@smk8-000001-0001"),
            ("entry://Haus", "Haus"),
            ("bword://Abend", "Abend"),
        ]:
            with self.subTest(href=href):
                self.assertEqual(self.word_of(self.navigate(href)), word)

    def test_word_is_carried_in_the_path(self):
        target = self.navigate("entry://Haus")
        self.assertTrue(target.startswith(LOOKUP_PREFIX), target)
        self.assertNotIn("Haus", target, "the word must be percent-encoded in the path")

    def test_anchor_is_dropped(self):
        self.assertEqual(self.word_of(self.navigate("entry://Haus#section")), "Haus")

    def test_already_normalised_links_are_left_alone(self):
        href = LOOKUP_PREFIX + "%41%62%65%6E%64"
        target = self.navigate(href)
        self.assertEqual(target, href)
        self.assertEqual(self.word_of(target), "Abend")

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
