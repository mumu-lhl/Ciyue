"""Tests for recursive Linux bundle dependency collection."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / "tools/bundle_linux_dependencies.py"


class LinuxBundleDependenciesTest(unittest.TestCase):
    def test_collects_dependency_and_verify_rejects_host_fallback(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bundle_lib = root / "bundle/lib"
            search = root / "search"
            bundle_lib.mkdir(parents=True)
            search.mkdir()

            child_source = root / "child.c"
            child_source.write_text("int child_value(void) { return 42; }\n")
            parent_source = root / "parent.c"
            parent_source.write_text(
                "extern int child_value(void); int parent_value(void) { return child_value(); }\n"
            )
            child = search / "libchild.so.1"
            parent = bundle_lib / "libparent.so"
            subprocess.run(
                [
                    "gcc", "-shared", "-fPIC", str(child_source),
                    "-Wl,-soname,libchild.so.1", "-o", str(child),
                ],
                check=True,
            )
            subprocess.run(
                [
                    "gcc", "-shared", "-fPIC", str(parent_source),
                    f"-L{search}", "-Wl,-rpath," + str(search),
                    "-Wl,--no-as-needed", "-l:libchild.so.1", "-o", str(parent),
                ],
                check=True,
            )

            verify_before = subprocess.run(
                [sys.executable, str(TOOL), "--bundle", str(root / "bundle"), "--verify-only"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(verify_before.returncode, 0)
            self.assertIn("libchild.so.1", verify_before.stderr)

            subprocess.run(
                [
                    sys.executable, str(TOOL), "--bundle", str(root / "bundle"),
                    "--search", str(search),
                ],
                check=True,
            )
            self.assertTrue((bundle_lib / "libchild.so.1").is_file())

            (bundle_lib / "libchild.so.1").unlink()
            verify_after_removal = subprocess.run(
                [sys.executable, str(TOOL), "--bundle", str(root / "bundle"), "--verify-only"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(verify_after_removal.returncode, 0)
            self.assertIn("would fall back", verify_after_removal.stderr)

            (bundle_lib / "libchild.so.1").symlink_to("missing-library")
            broken_symlink = subprocess.run(
                [sys.executable, str(TOOL), "--bundle", str(root / "bundle"), "--verify-only"],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(broken_symlink.returncode, 0)
            self.assertIn("broken library symlink", broken_symlink.stderr)

    def test_collect_prunes_host_provided_library_left_in_bundle(self):
        # Re-running collection over an existing bundle must not leave a stale
        # copy of a host-provided library shadowing the system one through RPATH.
        with tempfile.TemporaryDirectory() as temporary_directory:
            root = Path(temporary_directory)
            bundle_lib = root / "bundle/lib"
            search = root / "search"
            bundle_lib.mkdir(parents=True)
            search.mkdir()

            source = root / "wayland.c"
            source.write_text("int wl_stub(void) { return 0; }\n")
            stale = bundle_lib / "libwayland-client.so.0"
            subprocess.run(
                [
                    "gcc", "-shared", "-fPIC", str(source),
                    "-Wl,-soname,libwayland-client.so.0", "-o", str(stale),
                ],
                check=True,
            )
            # Prefix-matched host libraries must be pruned the same way.
            stale_gst = bundle_lib / "libgstapp-1.0.so.0"
            subprocess.run(
                [
                    "gcc", "-shared", "-fPIC", str(source),
                    "-Wl,-soname,libgstapp-1.0.so.0", "-o", str(stale_gst),
                ],
                check=True,
            )

            collected = subprocess.run(
                [
                    sys.executable, str(TOOL), "--bundle", str(root / "bundle"),
                    "--search", str(search),
                ],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertIn("Removed host-provided libwayland-client.so.0", collected.stdout)
            self.assertIn("Removed host-provided libgstapp-1.0.so.0", collected.stdout)
            self.assertFalse(stale.exists())
            self.assertFalse(stale_gst.exists())


if __name__ == "__main__":
    unittest.main()
