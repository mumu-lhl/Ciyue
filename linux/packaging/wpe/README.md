# Relocatable WPE runtime

The Linux bundle uses WPE WebKit 2.44.2, matching the archived Arch ABI baseline.
Do not byte-replace `/usr/lib/wpe-webkit-2.0` with a relative path: WebKit also
uses that string as a bubblewrap mount destination. Inside the sandbox it lands
under read-only `/lib`; a host WPE installation can accidentally hide the bug.
This affects AppImage as well as the other formats sharing the Linux bundle.

`tools/build_wpe_runtime.sh` builds the checksum-pinned upstream source **in CI**.
`tools/patch_wpe_runtime.py` changes three consumers to use
`WPERuntimeDirectory.h`:

- network/web process executable lookup;
- injected bundle lookup (including its extra sandbox mount);
- the bubblewrap runtime directory mount.

The helper resolves the actual `libWPEWebKit` DSO with `dladdr` and `realpath`,
then uses its sibling `wpe-webkit-2.0` directory. No working-directory assumption,
fixed AppImage mount point, environment override, or sandbox bypass is needed.
Library, processes, and injected bundle must be shipped from the **same build**.

The CI cache stores the installed runtime, keyed by the archived package set
and the build/patch/header inputs. Cache misses require a full WebKit build;
parallelism defaults to two jobs to limit memory consumption. When updating WPE,
update the version, upstream checksum, package baseline, and patch seams together.

Validation without compiling or launching the application:

```sh
python3 test/tools/wpe_runtime_test.py
bash -n tools/build_wpe_runtime.sh
```

CI additionally sets `CIYUE_TEST_WPE_NATIVE=1`: this compiles a small probe DSO
using the actual relocation header and checks a moved directory, spaces, a
symlink, and an unrelated working directory. The bubblewrap regression masks
the host WPE installation and compares failing relative mounts with passing
absolute mounts. It explicitly skips if the host/container forbids namespaces.
Full WPE compilation and resulting AppImage rendering still need CI/release
validation; these tests are not a substitute for an end-to-end WebView test.

Upstream references (pinned tag `wpewebkit-2.44.2`):
- `Source/WebKit/Shared/glib/ProcessExecutablePathGLib.cpp`
- `Source/WebKit/UIProcess/API/glib/WebKitWebContext.cpp`
- `Source/WebKit/UIProcess/Launcher/glib/BubblewrapLauncher.cpp`
- Build baseline: <https://gitlab.archlinux.org/archlinux/packaging/packages/wpewebkit/-/raw/2.44.2-1/PKGBUILD>
