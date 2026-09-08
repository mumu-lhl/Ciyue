"""WPE release consumption regression tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReleaseRuntimeTest(unittest.TestCase):
    def test_download_is_pinned_and_bundle_uses_matching_helpers(self):
        workflow = (ROOT / ".github/workflows/linux-build.yml").read_text()

        self.assertIn("mumu-lhl/wpewebkit-build/releases/download/", workflow)
        self.assertIn("WPE_RUNTIME_RELEASE: wpewebkit-2.44.2-1", workflow)
        self.assertIn(
            "WPE_RUNTIME_SHA256: "
            "7b52bd62c3651098db321b1971f3a458f98ae4e727485c9339b9cdc5463c6d04",
            workflow,
        )
        self.assertIn("sha256sum --check -", workflow)
        self.assertIn('tar --extract --xz --no-same-owner', workflow)
        self.assertIn('cp -a "$WPE_STAGE"/libWPEWebKit-2.0.so*', workflow)
        self.assertIn('cp -a "$WPE_STAGE/wpe-webkit-2.0/."', workflow)
        self.assertNotIn("tools/build_wpe_runtime.sh", workflow)
        self.assertNotIn("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", workflow)


if __name__ == "__main__":
    unittest.main()
