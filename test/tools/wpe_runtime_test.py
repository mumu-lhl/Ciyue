"""WPE release consumption regression tests."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class ReleaseRuntimeTest(unittest.TestCase):
    def test_download_is_pinned_and_bundle_uses_matching_helpers(self):
        workflow = (ROOT / ".github/workflows/linux-build.yml").read_text()

        self.assertIn("mumu-lhl/wpewebkit-build/releases/download/", workflow)
        self.assertIn("WPE_RUNTIME_RELEASE: wpewebkit-2.54.1-1", workflow)
        self.assertIn(
            "WPE_RUNTIME_SHA256: "
            "faa4e191cb550fd916085ca69eedc54716614a09b61012a59b53bf84c430dbca",
            workflow,
        )
        self.assertIn("sha256sum --check -", workflow)
        self.assertIn("tar --extract --xz --no-same-owner", workflow)
        self.assertIn('cp -a "$WPE_STAGE"/libWPEWebKit-2.0.so*', workflow)
        self.assertIn('cp -a "$WPE_STAGE/wpe-webkit-2.0/."', workflow)
        self.assertIn("python3 tools/patch_wpe_sandbox_paths.py", workflow)
        self.assertNotIn("tools/build_wpe_runtime.sh", workflow)
        self.assertNotIn("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", workflow)


class SandboxPathPatchTest(unittest.TestCase):
    def test_patches_sbin_paths_to_bin_without_size_change(self):
        patch_tool = ROOT / "tools/patch_wpe_sandbox_paths.py"
        self.assertTrue(patch_tool.is_file())

        with tempfile.TemporaryDirectory() as tmpdir:
            tmp = Path(tmpdir)
            fake_lib = tmp / "libWPEWebKit-2.0.so.1.3.3"
            fake_content = (
                b"PREFIX\x00/usr/sbin/bwrap\x00MID\x00/usr/sbin/xdg-dbus-proxy\x00SUFFIX"
            )
            fake_lib.write_bytes(fake_content)

            result = subprocess.run(
                [sys.executable, str(patch_tool), str(tmp)],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertIn("Replaced 1 occurrence(s) of /usr/sbin/bwrap", result.stdout)
            self.assertIn("Replaced 1 occurrence(s) of /usr/sbin/xdg-dbus-proxy", result.stdout)

            patched_content = fake_lib.read_bytes()
            self.assertEqual(len(patched_content), len(fake_content))
            self.assertIn(b"/usr/bin/bwrap\0\0", patched_content)
            self.assertIn(b"/usr/bin/xdg-dbus-proxy\0\0", patched_content)
            self.assertNotIn(b"/usr/sbin/bwrap\0", patched_content)
            self.assertNotIn(b"/usr/sbin/xdg-dbus-proxy\0", patched_content)

            # Re-running is idempotent and makes no further changes
            second_run = subprocess.run(
                [sys.executable, str(patch_tool), str(tmp)],
                capture_output=True,
                text=True,
                check=True,
            )
            self.assertEqual(second_run.returncode, 0)
            self.assertEqual(fake_lib.read_bytes(), patched_content)


class LinuxPackagingDependenciesTest(unittest.TestCase):
    def test_deb_depends_on_bubblewrap_and_dbus_proxy(self):
        control = (ROOT / "linux/packaging/deb/control").read_text()
        self.assertIn("bubblewrap", control)
        self.assertIn("xdg-dbus-proxy", control)
        self.assertIn("libgbm1", control)
        self.assertIn("libdrm2", control)

    def test_rpm_requires_bubblewrap_and_dbus_proxy(self):
        spec = (ROOT / "linux/packaging/rpm/ciyue.spec").read_text()
        self.assertIn("bubblewrap", spec)
        self.assertIn("xdg-dbus-proxy", spec)
        self.assertIn("mesa-libgbm", spec)
        self.assertIn("libdrm", spec)

    def test_launcher_checks_sandbox_and_drm_availability(self):
        launcher = (ROOT / "linux/packaging/ciyue-launcher.sh").read_text()
        self.assertIn("WEBKIT_DISABLE_SANDBOX_THIS_IS_DANGEROUS", launcher)
        self.assertIn("bwrap", launcher)
        self.assertIn("xdg-dbus-proxy", launcher)
        self.assertIn("WEBKIT_DISABLE_DMABUF_RENDERER", launcher)

    def test_bundle_excludes_host_graphics_libraries(self):
        sys.path.insert(0, str(ROOT / "tools"))
        import bundle_linux_dependencies

        self.assertIn("libgbm.so.1", bundle_linux_dependencies.SYSTEM_LIBRARIES)
        self.assertIn("libdrm.so.2", bundle_linux_dependencies.SYSTEM_LIBRARIES)
        self.assertIn("libc.so.6", bundle_linux_dependencies.SYSTEM_LIBRARIES)
        self.assertIn("libGLdispatch.so.0", bundle_linux_dependencies.SYSTEM_LIBRARIES)

    def test_bundle_excludes_wayland_libraries(self):
        # A bundled libwayland from the build snapshot shadows the host copy in
        # the global symbol scope, so a newer host Mesa cannot resolve protocol
        # interfaces such as wl_fixes_interface and EGL initialization fails.
        sys.path.insert(0, str(ROOT / "tools"))
        import bundle_linux_dependencies

        for library in (
            "libwayland-client.so.0",
            "libwayland-server.so.0",
            "libwayland-egl.so.1",
            "libwayland-cursor.so.0",
        ):
            self.assertIn(library, bundle_linux_dependencies.SYSTEM_LIBRARIES)

    def test_bundle_excludes_gstreamer(self):
        # GStreamer discovers plugins through a libdir baked into the core build,
        # so a bundled core sees an empty registry on another distribution:
        # playbin cannot be created and audioplayers_linux throws a bare C string.
        sys.path.insert(0, str(ROOT / "tools"))
        import bundle_linux_dependencies

        for library in (
            "libgstreamer-1.0.so.0",
            "libgstapp-1.0.so.0",
            "libgstaudio-1.0.so.0",
            "libgstplayback.so",
            "liborc-0.4.so.0",
            "libpulse.so.0",
        ):
            self.assertTrue(bundle_linux_dependencies.is_system_library(library))
        self.assertFalse(bundle_linux_dependencies.is_system_library("libopus.so.0"))

    def test_bundle_excludes_toolkit_but_keeps_wpe_dependencies(self):
        # GTK resolves immodules and module extras from a libdir baked in at build
        # time, so a bundled GTK cannot see the host's fcitx/ibus immodule (no
        # input method at all) and desktop-injected modules fail to load.
        sys.path.insert(0, str(ROOT / "tools"))
        import bundle_linux_dependencies

        for library in (
            "libgtk-3.so.0",
            "libgdk-3.so.0",
            "libpango-1.0.so.0",
            "libpangocairo-1.0.so.0",
            "libcairo.so.2",
            "libgdk_pixbuf-2.0.so.0",
            "libfontconfig.so.1",
            "libX11.so.6",
            "libxcb.so.1",
        ):
            self.assertTrue(bundle_linux_dependencies.is_system_library(library))

        # WPE links these itself, so the bundle stays responsible for their
        # baseline and they must not be dropped.
        for library in (
            "libharfbuzz.so.0",
            "libfreetype.so.6",
            "libjpeg.so.8",
            "libatk-1.0.so.0",
            "libepoxy.so.0",
            "libxkbcommon.so.0",
            "libWPEWebKit-2.0.so.1",
        ):
            self.assertFalse(bundle_linux_dependencies.is_system_library(library))

    def test_bundle_excludes_glib(self):
        # Host libraries are compiled against the host GLib, so the bundled copy
        # must not shadow it; libgstaudio from a newer distribution asks for
        # g_sort_array (GLib 2.82) and a frozen bundled GLib cannot answer.
        sys.path.insert(0, str(ROOT / "tools"))
        import bundle_linux_dependencies

        for library in (
            "libglib-2.0.so.0",
            "libgobject-2.0.so.0",
            "libgio-2.0.so.0",
            "libgmodule-2.0.so.0",
            "libgthread-2.0.so.0",
            "libpcre2-8.so.0",
            "libffi.so.8",
            "libmount.so.1",
            "libblkid.so.1",
            "libselinux.so.1",
        ):
            self.assertIn(library, bundle_linux_dependencies.SYSTEM_LIBRARIES)


if __name__ == "__main__":
    unittest.main()
