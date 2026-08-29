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
*   **Flutter SDK:** Version constraint `>=3.13.0 <4.0.0` (CI uses `3.47.2`).
*   **Just:** Command runner for simplified scripts.
*   **Platform Requirements:**
    *   **Linux:** `libgtk-3-dev`, `libgstreamer1.0-dev`, `libayatana-appindicator3-dev`, etc.
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

### Database (Drift)
*   **Schema:** Managed in `lib/database/` and `drift_schemas/`.
*   **Migrations:** Must be generated using `just make-migrations` when schema changes.
*   **Migration workflow:** After changing a table, update the database `schemaVersion` and add the corresponding `fromNToN+1` migration step. Run `just build_runner`, then `just make-migrations`. Review the table change, migration semantics, and migration tests before running `flutter test`; generated output only needs a successful-generation and expected-version sanity check.
*   **Generated files:** Do not edit Drift-generated files manually. Keep all existing schema versions; only add the new version and its migration. Commit generated files required by the build, but do not review them line by line.

### Translations
*   **Source:** `.arb` files in `lib/l10n/`.
*   **Management:** **Do NOT edit `.arb` files directly.** Use [Weblate](https://hosted.weblate.org/engage/ciyue/) for translations.

### Contribution Guidelines
*   **Commits:** Use clear, descriptive commit messages.
*   **Testing:** Ensure `flutter test` passes before submitting.
*   **Issues:** Search existing issues before creating new ones.
