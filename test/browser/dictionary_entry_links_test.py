"""Desktop Chromium regression for dictionary links (#725, #738); no Android app.

Setup: uv run --with playwright playwright install chromium
Run: uv run --with playwright python test/browser/dictionary_entry_links_test.py

The assertions are about the *word*, not about the URL shape: every dictionary
link is canonicalised into `gdlookup://localhost/<payload>`, and a test that
pinned the old `entry://<word>` target would break every time the container
changes (path -> query, extra parameters) without anything being wrong.
"""

from html import escape
from pathlib import Path
import re
import unittest
from urllib.parse import quote, unquote

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "lib/ui/core/word_display/entry_link_script.dart"

# The word never travels in the authority part of the URL: a host is folded to
# lower case, ":" after the host is read as a port and "@" as userinfo, which is
# how `entry://Haus`, `entry://tag:sumeru` and `entry://@smk8-...` used to break.
PREFIX = "gdlookup://localhost/"


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

    def click(self, href, markup="link", keyboard=False):
        """Clicks the link and returns the href the page is about to follow."""
        self.page.evaluate("html => document.body.innerHTML = html",
                           f'<a href="{escape(href, quote=True)}">{markup}</a>')
        if keyboard:
            self.page.locator("a").focus()
            self.page.keyboard.press("Enter")
        else:
            self.page.locator("a").click()
        return self.page.locator("a").get_attribute("href")

    def target_of(self, url):
        """The (word, anchor) the WebView will look up, whatever the container."""
        self.assertTrue(url.startswith(PREFIX), f"unexpected target: {url}")
        rest = url[len(PREFIX):]
        # What #725 was about: unescaped Unicode in the URL is truncated before
        # shouldOverrideUrlLoading ever runs, so nothing may be left raw.
        self.assertTrue(rest.isascii(), f"target still carries raw bytes: {url}")
        for char in ":@#":
            self.assertNotIn(char, rest, f"{char!r} left unescaped in {url}")
        # The anchor rides as a query item, never as a fragment: a `#` in the
        # URL is a same-document position and would never reach the handler.
        payload, _, query = rest.partition("?")
        word = unquote(payload)
        anchor = None
        for pair in query.split("&"):
            name, sep, value = pair.partition("=")
            if sep and name == "gdanchor":
                anchor = unquote(value)
        return word, anchor

    def word_of(self, url):
        """The word alone, for the tests that only care about the headword."""
        return self.target_of(url)[0]

    def lookup_word(self, href, markup="link", keyboard=False):
        return self.word_of(self.click(href, markup, keyboard))

    def lookup_target(self, href, markup="link", keyboard=False):
        return self.target_of(self.click(href, markup, keyboard))

    # --- #725: the displayed text is not the lookup key -----------------------

    def test_issue_725_targets(self):
        # Minimal links from the three supplied MDX files. The visible text is
        # not the key: one renders a full-width ～, another a CSS <tilde>.
        for word, markup in [
            ("怀刷", "怀～"),
            ("人怕出名猪怕壮", "人<tilde></tilde>出名猪怕壮"),
            ("卡尺", "卡尺"),
        ]:
            with self.subTest(word=word):
                self.assertEqual(self.lookup_word("entry://" + word, markup), word)

    def test_clicking_a_nested_element(self):
        self.page.evaluate('''() => {
          document.body.innerHTML = '<a href="entry://怀刷"><span>怀～</span></a>';
        }''')
        self.page.locator("span").click()
        href = self.page.locator("a").get_attribute("href")
        self.assertEqual(self.word_of(href), "怀刷")

    def test_keyboard_activation(self):
        self.assertEqual(self.lookup_word("entry://卡尺", keyboard=True), "卡尺")

    # --- #738: ASCII characters that the URL grammar used to eat --------------

    def test_url_metacharacters_reach_the_dictionary(self):
        for word in [
            "tag:sumeru",         # ":" was parsed as a port -> FormatException
            "@smk8-000001-0001",  # "@" was parsed as userinfo and dropped
            "a/b",                # "/" would start a new path segment
            "A?B",                # "?" would start a query
        ]:
            with self.subTest(word=word):
                self.assertEqual(self.lookup_word("entry://" + word), word)

    def test_ascii_case_is_preserved(self):
        # Host names are case-insensitive, so `entry://Haus` arrived as "haus".
        for word in ["Haus", "CamelCase", "CYCD0001", "卡拉OK"]:
            with self.subTest(word=word):
                self.assertEqual(self.lookup_word("entry://" + word), word)

    def test_bword_links_are_entry_links(self):
        # Babylon spelling of the same thing (クラウン独和).
        self.assertEqual(self.lookup_word("bword://Abend"), "Abend")

    def test_bword_links_carry_the_same_anchor(self):
        # Both schemes go through the same `#` parser in the page script.
        self.assertEqual(
            self.lookup_target("bword://tag#sumeru"), ("tag", "sumeru")
        )
        self.assertEqual(
            self.lookup_target("bword://tag##sumeru"), ("tag#sumeru", None)
        )

    # --- the payload is a reversible, injective encoding ----------------------

    def test_escaped_links_are_decoded_once(self):
        self.assertEqual(self.lookup_word("entry://%E5%8D%A1尺"), "卡尺")

    def test_a_literal_percent_survives(self):
        # %2541 -> "%41": encode(decode(w)) must be injective, or a headword
        # that really contains "%41" becomes indistinguishable from "A".
        self.assertEqual(self.lookup_word("entry://%2541"), "%41")

    def test_a_lone_hash_splits_the_headword_from_the_anchor(self):
        word, anchor = self.lookup_target("entry://怀刷#section")
        self.assertEqual(word, "怀刷")
        self.assertEqual(anchor, "section")

    def test_a_doubled_hash_escapes_a_literal_hash(self):
        # `##` is the only way to name a headword that contains a `#`.
        word, anchor = self.lookup_target("entry://tag##sumeru")
        self.assertEqual(word, "tag#sumeru")
        self.assertIsNone(anchor)

    def test_escaping_and_splitting_combine(self):
        word, anchor = self.lookup_target("entry://tag##sumeru#x")
        self.assertEqual(word, "tag#sumeru")
        self.assertEqual(anchor, "x")
        word, anchor = self.lookup_target("entry://tag###sumeru")
        self.assertEqual(word, "tag#")
        self.assertEqual(anchor, "sumeru")

    def test_percent_encoded_hash_is_a_literal_hash(self):
        # %23 is a literal `#` in the headword, not a separator.
        word, anchor = self.lookup_target("entry://A%23B")
        self.assertEqual(word, "A#B")
        self.assertIsNone(anchor)

    # --- in-place scrolling ---------------------------------------------------

    def _load_scroll_page(self, target_attr):
        """The link sits at the top, the anchor 2000px below it."""
        self.page.evaluate('''attr => {
          document.body.innerHTML =
            '<a href="entry://#sumeru">jump</a>' +
            '<div style="height:2000px"></div>' +
            '<a ' + attr + '="sumeru">target</a>';
        }''', target_attr)

    def test_anchor_only_link_scrolls_instead_of_navigating(self):
        self._load_scroll_page("id")
        self.page.locator('a[href="entry://#sumeru"]').click()
        # There is no headword to look up, so nothing may reach the handler.
        self.assertFalse(self.targets, "an anchor-only link must not navigate")
        self.assertGreater(self.page.evaluate("window.scrollY"), 0)

    def test_anchor_only_link_matches_a_name_attribute(self):
        self._load_scroll_page("name")
        self.page.locator('a[href="entry://#sumeru"]').click()
        self.assertFalse(self.targets, "an anchor-only link must not navigate")
        self.assertGreater(self.page.evaluate("window.scrollY"), 0)

    def test_a_missing_anchor_leaves_the_page_alone(self):
        self.page.evaluate('''() => {
          document.body.innerHTML = '<a href="entry://#absent">jump</a>';
        }''')
        self.page.locator('a[href="entry://#absent"]').click()
        self.assertEqual(self.page.evaluate("window.scrollY"), 0)

    def test_canonical_gdlookup_is_left_alone(self):
        href = PREFIX + quote("怀刷")
        self.assertEqual(self.click(href), href)

    # --- what must not change -------------------------------------------------

    def test_clicking_still_navigates(self):
        # The rewriter stays transparent: no preventDefault, the WebView still
        # receives a navigation action it can intercept.
        self.click("entry://怀刷")
        self.assertTrue(self.targets, "click did not request navigation")
        self.assertEqual(self.word_of(self.targets[-1]), "怀刷")

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
