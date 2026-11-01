# Ciyue Project Context

## Project Overview

**Ciyue** is a comprehensive dictionary application built with **Flutter**. It is designed to support **MDX/MDD** dictionary formats and offers a modern user experience with **Material You** design.

### Key Features
*   **Multi-Platform:** Android, Windows, Linux.
*   **Dictionary Support:** MDX/MDD formats, multi-dictionary search.
*   **AI Integration:** AI-powered translation (OpenAI, Gemini, DeepSeek, etc.) and word explanation.
*   **Tools:** Text-to-speech (TTS), word book (bookmarks), history.
*   **Theming:** Dynamic colors (Material You) and dark mode support.

### Architecture & Tech Stack
*   **Framework:** Flutter (Dart).
*   **State Management:** `provider`.
*   **Database:** `drift` (SQLite abstraction) with migration support.
*   **Navigation:** `go_router`.
*   **Networking:** `dio` with `talker_dio_logger` for logging.
*   **WebView:** `flutter_inappwebview` for rendering dictionary content.
*   **Localizations:** `flutter_localizations` with `.arb` files (managed via Weblate).
*   **Build/CI:** GitHub Actions, `just` command runner.

## Building and Running

### Prerequisites
*   **Flutter SDK:** Flutter `>=3.47.0` and Dart `>=3.13.0` (CI uses `3.47.5`).
*   **Just:** Command runner for simplified scripts.
*   **Platform Requirements:**
    *   **Linux:** `libgtk-3-dev`, `libx11-dev`, `libxi-dev`, `libgstreamer1.0-dev`, `libsecret-1-dev` (secure cloud credentials), etc. Runtime cloud credential storage also requires an active Secret Service/keyring.
    *   **Android:** Android SDK, Java 21 (for build).
    *   **Windows:** Visual Studio with C++ workload.

### Common Commands (via `just`)
The project uses `justfile` to manage common development tasks.

| Task | Command | Description |
| :--- | :--- | :--- |
| **Code Generation** | `just build_runner` | Runs `dart run build_runner build` (Essential for Drift, Freezed, etc.) |
| **Migrations** | `just make-migrations` | Generates database migrations using Drift. |
| **Icons** | `just icon` | Generates app launcher icons. |
| **Count Code** | `just count-codes` | Counts lines of code excluding generated files. |

### Standard Flutter Commands
*   **Run:** `flutter run`
*   **Analyze:** `flutter analyze`
*   **Format:** `dart format .` (CI checks changed `.dart` files)
*   **Test:** `flutter test`

### Build Artifacts
*   **Android:** `flutter build apk --flavor full-dev`
*   **Windows:** `flutter build windows`
*   **Linux:** `flutter build linux`

> **Note:** CI builds use `--dart-define` flags to inject build info (Hash, Timestamp, Dev mode).

## Development Conventions

### Code Style
*   **Linter:** Uses `flutter_lints` with `prefer_double_quotes: true`.
*   **Formatting:** Enforced via `dart format`.
*   **Analysis:** `analysis_options.yaml` excludes generated files and platform folders from analysis.

### Native dependencies
*   Hunspell is compiled from the pinned submodule at `packages/hunspell_ffi/third_party/hunspell`; initialize submodules before building or testing native assets (`git submodule update --init --recursive`).

### Linux packaging (bundle)
*   **Pipeline:** `flutter build linux` produces the bundle, `tools/bundle_linux_dependencies.py` copies its recursive `DT_NEEDED` closure out of the build container (Arch, with the glibc pin from `.github/workflows/linux-build.yml`), then `tools/build_{appimage,deb,rpm}.sh` wrap it. `ciyue.bin` gets `DT_RPATH=$ORIGIN/lib` and the launcher also exports `LD_LIBRARY_PATH`, so **a bundled copy always wins over the host's**.
*   **Rule:** never bundle a library that host code also loads. Every host library in the process (`libEGL_mesa`, GStreamer plugins, GTK immodules, DRI drivers, GTK modules) was compiled against the *host* copy, and GLib/Wayland/GTK ABIs are additive, so a newer host copy satisfies both sides while a frozen bundled copy cannot.
*   **Close the exclusion over the dependency graph.** Excluding GLib means excluding what GLib links (`libpcre2-8`, `libffi`, `libmount`, `libblkid`, `libselinux`); excluding GTK means pango/cairo/gdk-pixbuf/X11 *and* `libfontconfig` (pango 1.58 calls `FcConfigSetDefaultSubstitute`, which the 2.15.0 snapshot does not export).
*   **Host-provided groups** live in `tools/bundle_linux_dependencies.py`: glibc, graphics/DRM (`libgbm`, `libdrm`, `libGL*`, `libEGL`, `libGLdispatch`, …), Wayland client libraries, the GLib family, GStreamer (`libgst*`) with `liborc`/`libpulse`/`libasound`, and the GTK toolkit with the X11 client stack. Baked-in search paths are the underlying reason: GStreamer scans the plugin libdir compiled into the core and GTK scans the immodule/module libdirs compiled into it, so a foreign copy finds an empty registry — no `playbin`, no input method.
*   **What stays bundled:** the Flutter engine, `libapp.so`, plugin `.so` files, the WPE runtime, plus the libraries WPE links itself (`harfbuzz`, `freetype`, `expat`, `libpng16`, `atk(-bridge)`, `epoxy`, `xkbcommon`, `systemd`, `seccomp`, `z`, and Arch-only SONAMEs such as `libjpeg.so.8`). WPE's build baseline is the bundle's responsibility; the toolkit's is not.
*   **Keep the packages in sync:** every group handed to the host needs a matching `Depends`/`Requires` in `linux/packaging/deb/control` and `linux/packaging/rpm/ciyue.spec`, otherwise the exclusion turns a working start into a missing-library error.
*   **Verification:** `python3 test/tools/wpe_runtime_test.py` and `python3 test/tools/linux_bundle_dependencies_test.py` pin the split. For a real check, copy `/opt/ciyue/lib` to a scratch directory, delete everything `is_system_library()` matches, then run `LD_LIBRARY_PATH=<scratch> ldd -r` on the engine, the plugins and `libWPEWebKit-2.0.so.1`; it must report no undefined symbols.
*   **Symptom signatures:** `symbol lookup error ... undefined symbol: X (fatal)` from a host vendor library, `undefined symbol: X` when loading an app library, or `terminate called after throwing an instance of 'char const*'` (an uncaught C++ exception from `audioplayers_linux` when GStreamer has no `playbin`). All three mean a host library met a bundled copy of its own stack.

### Database (Drift)
*   **Schema:** Managed in `lib/database/` and `drift_schemas/`.
*   **Migrations:** Must be generated using `just make-migrations` when schema changes.
*   **Migration workflow:** After changing a table, update the database `schemaVersion` and add the corresponding `fromNToN+1` migration step. Run `just build_runner`, then `just make-migrations`. Review the table change, migration semantics, and migration tests before running `flutter test`; generated output only needs a successful-generation and expected-version sanity check.
*   **make-migrations quirk (2026-10-15):** `drift_dev make-migrations` silently drops index entities when regenerating Dart test fixtures (`test/drift/*/generated/schema_vN.dart`) and `app.steps.dart` for a schema version whose `drift_schema_vN.json` was hand-authored (observed with v20's `idx_history_word`). The JSON itself is read correctly. If this happens, manually add the missing index to `SchemaN` in `app.steps.dart` and to `DatabaseAtVN` in the test fixture, then verify with the migration test.
*   **Generated files:** Do not edit Drift-generated files manually. Keep all existing schema versions; only add the new version and its migration. Commit generated files required by the build, but do not review them line by line.

### Translations
*   **Source:** Add new source messages to `lib/l10n/app_en.arb`; keep user-visible strings out of widget code and access them through `AppLocalizations`.
*   **Generation:** After changing an ARB file, run `flutter gen-l10n` to regenerate `lib/src/generated/i18n/app_localizations*.dart`. Never edit generated Dart files manually.
*   **Translation:** Non-English locale files (`app_*.arb`) are managed through [Weblate](https://hosted.weblate.org/engage/ciyue/); contributors may also edit them directly in a pull request for languages they know.

### Contribution Guidelines
*   **Commits:** Use clear, descriptive commit messages.
*   **Testing:** Ensure `flutter test` passes before submitting.
*   **Issues:** Search existing issues before creating new ones.
