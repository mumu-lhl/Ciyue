# Relocatable WPE runtime

The Linux bundle uses WPE WebKit 2.44.2, matching the archived Arch ABI baseline.
Do not byte-replace `/usr/lib/wpe-webkit-2.0` with a relative path: WebKit also
uses that string as a bubblewrap mount destination. Inside the sandbox it lands
under read-only `/lib`; a host WPE installation can accidentally hide the bug.
This affects AppImage as well as the other formats sharing the Linux bundle.

The relocatable runtime is built and tested in
[`mumu-lhl/wpewebkit-build`](https://github.com/mumu-lhl/wpewebkit-build). Its
patch changes three consumers to resolve paths relative to the loaded WebKit
library:

- network/web process executable lookup;
- injected bundle lookup (including its extra sandbox mount);
- the bubblewrap runtime directory mount.

The helper resolves the actual `libWPEWebKit` DSO with `dladdr` and `realpath`,
then uses its sibling `wpe-webkit-2.0` directory. No working-directory assumption,
fixed AppImage mount point, environment override, or sandbox bypass is needed.
Library, processes, and injected bundle must be shipped from the **same build**.

Ciyue CI downloads a pinned release asset and verifies its SHA-256 digest before
extracting it. The release's WebKit version and glibc baseline must match the
archived Arch build environment. When updating WPE, update the release tag,
asset name, checksum, system development package, and baseline checks together.

Validation without compiling or launching the application:

```sh
python3 test/tools/wpe_runtime_test.py
```

The source patch and native relocation tests live with the runtime build. Ciyue's
test checks the consumer-side download pin and verifies that packaging replaces
the system WebKit library together with its matching helper directory. Resulting
AppImage rendering still needs release validation; this is not a substitute for
an end-to-end WebView test.

Upstream references (pinned tag `wpewebkit-2.44.2`):
- `Source/WebKit/Shared/glib/ProcessExecutablePathGLib.cpp`
- `Source/WebKit/UIProcess/API/glib/WebKitWebContext.cpp`
- `Source/WebKit/UIProcess/Launcher/glib/BubblewrapLauncher.cpp`
- Build baseline: <https://gitlab.archlinux.org/archlinux/packaging/packages/wpewebkit/-/raw/2.44.2-1/PKGBUILD>
