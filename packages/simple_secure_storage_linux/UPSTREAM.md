# Upstream tracking

This local package is based on `simple_secure_storage_linux` 0.2.5 from
[Skyost/SimpleSecureStorage](https://github.com/Skyost/SimpleSecureStorage/tree/master/packages/simple_secure_storage_linux).
The upstream license is retained in `LICENSE`.

The local change is limited to `linux/CMakeLists.txt`: reuse an existing
`nlohmann_json::nlohmann_json` CMake target instead of declaring the target a
second time. `flutter_inappwebview_linux` also fetches nlohmann/json, which
causes duplicate CMake targets in a clean Linux build. The app's local
`flutter_inappwebview_linux` CMake file has the matching guard so either plugin
can register the shared target first.

When updating this package, compare the new upstream release against this
copy and reapply only the target guard if upstream has not added an equivalent
fix. If upstream ships the fix, remove the `simple_secure_storage_linux`
`dependency_overrides` entry and this vendored directory, then resolve the
hosted dependency again. In either case, verify with `flutter clean`,
`flutter pub get`, and `flutter build linux --debug`.
