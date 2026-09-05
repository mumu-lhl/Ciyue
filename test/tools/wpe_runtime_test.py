"""WPE packaging regression tests. No application is started.

python3 test/tools/wpe_runtime_test.py runs source/packaging and bwrap tests.
CIYUE_TEST_WPE_NATIVE=1 additionally compiles a tiny probe DSO (CI only).
"""
import importlib.util
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("patch_wpe", ROOT / "tools/patch_wpe_runtime.py")
patch_wpe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(patch_wpe)


class SourcePatchTest(unittest.TestCase):
    def test_all_runtime_paths_are_relocated(self):
        # Minimal upstream seams; the build script also applies this patch to
        # the checksum-verified, complete 2.44.2 source and rejects any drift.
        snippets = {
            "Shared/glib/ProcessExecutablePathGLib.cpp":
                "FileSystem::stringFromFileSystemRepresentation(PKGLIBEXECDIR)",
            "UIProcess/API/glib/WebKitWebContext.cpp":
                'static const char* injectedBundlePath = PKGLIBDIR G_DIR_SEPARATOR_S "injected-bundle" G_DIR_SEPARATOR_S;',
            "UIProcess/Launcher/glib/BubblewrapLauncher.cpp":
                '"--ro-bind-try", PKGLIBEXECDIR, PKGLIBEXECDIR,',
        }
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp)
            for name, text in snippets.items():
                path = source / "Source/WebKit" / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('#include "config.h"\n' + text)
            patch_wpe.patch(source)
            for name in snippets:
                text = (source / "Source/WebKit" / name).read_text()
                self.assertIn("wpeRuntimeDirectory()", text)
                self.assertIn('#include "WPERuntimeDirectory.h"', text)
                self.assertNotIn("PKGLIBEXECDIR", text)
                self.assertNotIn("PKGLIBDIR", text)
            with self.assertRaises(ValueError):
                patch_wpe.patch(source)

    def test_bundle_uses_matching_source_built_library_and_helpers(self):
        workflow = (ROOT / ".github/workflows/linux-build.yml").read_text()
        self.assertNotIn('new = b"./lib/wpe-webkit-2.0/./"', workflow)
        self.assertIn('cp -a "$WPE_STAGE"/libWPEWebKit-2.0.so*', workflow)
        self.assertIn('cp -a "$WPE_STAGE/wpe-webkit-2.0/."', workflow)
        self.assertNotIn("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", workflow)


class SandboxTest(unittest.TestCase):
    def test_relative_mount_fails_but_absolute_mount_succeeds(self):
        if not shutil.which("bwrap"):
            self.skipTest("bubblewrap not installed")
        with tempfile.TemporaryDirectory(prefix="ciyue-wpe-test-") as tmp:
            root = Path(tmp)
            runtime = root / "lib/wpe-webkit-2.0"
            (runtime / "injected-bundle").mkdir(parents=True)
            empty = root / "empty-lib"
            empty.mkdir()
            # Don't let an installed host WPE hide the bug: /lib is read-only
            # and deliberately contains no WPE. Preserve the system ELF loader.
            base = ["bwrap", "--ro-bind", "/usr", "/usr"]
            if Path("/lib64").exists():
                base += ["--ro-bind", "/lib64", "/lib64"]
            base += ["--ro-bind", str(empty), "/lib"]

            def run(path):
                return subprocess.run(base + [
                    "--ro-bind", path, path,
                    "--ro-bind", path + "/injected-bundle", path + "/injected-bundle",
                    "/usr/bin/true",
                ], cwd=root, capture_output=True, text=True, timeout=10)

            bad = run("./lib/wpe-webkit-2.0/./")
            if "Operation not permitted" in bad.stderr or "No permissions" in bad.stderr:
                self.skipTest("host/container disallows bubblewrap namespaces: " + bad.stderr.strip())
            self.assertNotEqual(bad.returncode, 0)
            self.assertIn("Read-only file system", bad.stderr)
            good = run(str(runtime))
            self.assertEqual(good.returncode, 0, good.stderr)


@unittest.skipUnless(os.environ.get("CIYUE_TEST_WPE_NATIVE") == "1", "native probe is CI-only")
class NativeRuntimeTest(unittest.TestCase):
    def test_runtime_follows_library_after_relocation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "probe.cpp"
            source.write_text('''#include "WPERuntimeDirectory.h"
extern "C" const char* runtime_path() { return WebKit::wpeRuntimeDirectory(); }
''')
            bundle = root / "original AppDir"
            (bundle / "lib/wpe-webkit-2.0/injected-bundle").mkdir(parents=True)
            library = bundle / "lib/libWPEWebKit-probe.so"
            flags = shlex.split(subprocess.check_output(
                ["pkg-config", "--cflags", "--libs", "glib-2.0"], text=True))
            subprocess.run([
                "clang++", "-std=c++17", "-shared", "-fPIC", "-O2", "-Werror",
                "-I" + str(ROOT / "linux/packaging/wpe"), str(source), "-o", str(library),
                *flags, "-ldl",
            ], check=True)
            # Different mount-like location, spaces, symlink, and unrelated cwd.
            moved = root / ".mount_Ciyue random"
            bundle.rename(moved)
            alias = root / "library-alias.so"
            alias.symlink_to(moved / "lib/libWPEWebKit-probe.so")
            code = '''import ctypes, sys
lib = ctypes.CDLL(sys.argv[1])
lib.runtime_path.restype = ctypes.c_char_p
print(lib.runtime_path().decode())
'''
            result = subprocess.check_output(
                ["python3", "-c", code, str(alias)], cwd="/", text=True).strip()
            self.assertEqual(result, str(moved / "lib/wpe-webkit-2.0"))


if __name__ == "__main__":
    unittest.main()
