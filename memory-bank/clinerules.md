# Project Intelligence (.clinerules)

This file serves as a learning journal to capture project-specific patterns, user preferences, and other insights that will improve my effectiveness in this project.

**Current Insights:**

1.  **State Management:** Need to investigate the state management solution to understand how `settings.themeMode` is accessed and updated. (Likely Provider, BLoC, or Riverpod).

2.  **`webview_windows` Plugin:** Project uses `webview_windows` plugin for Windows webview implementation. This plugin likely provides the necessary API to control webview theming on Windows.

3.  **Platform Channel for Themeing:** Platform Channel seems to be the most appropriate approach to communicate theme changes from Flutter to the Windows platform side and apply it to the webview.

4.  **`Win32Window::UpdateTheme()`:**  The `windows/runner/win32_window.cpp` file already contains a `UpdateTheme()` function that uses `DwmSetWindowAttribute` to apply dark/light mode to the window. This function can likely be adapted to apply theme to the webview as well.

5.  **Settings Persistence:** `shared_preferences` plugin is used to persist settings, including `themeMode`.

**To Investigate & Document:**

*   **Specific state management implementation.**
*   **How `settings.themeMode` is accessed and updated in the Flutter code.**
*   **API of `webview_windows` plugin for theme customization.**
*   **How to integrate `Win32Window::UpdateTheme()` with the Flutter side.**
*   **Location of platform-specific code for Windows (if any).**

**User Preferences (To be discovered):**

*   (Will be updated as I learn user preferences and workflow)

**Challenges & Considerations:**

*   Ensuring smooth and efficient theme switching without UI glitches.
*   Maintaining cross-platform compatibility while implementing Windows-specific theming.
*   Thoroughly testing theme switching in both light and dark modes on Windows.

**Tool Usage Patterns:**

*   `read_file`:  Used extensively to read memory bank files, source code, and configuration files.
*   `write_to_file`: Used to create memory bank files and potentially update configuration files.
*   `replace_in_file`:  Will likely be used to modify source code for implementing theme switching.
*   `search_files`:  Could be used to search for specific code patterns or usages of settings.
*   `execute_command`:  Might be used for running Flutter commands or build tasks (if needed).
*   `ask_followup_question`:  Used to ask clarifying questions to the user when necessary.

**Evolution of Project Decisions:**

*   (Will be updated as project decisions evolve)

This `.clinerules.md` file will be continuously updated as I learn more about the project and refine my approach.
