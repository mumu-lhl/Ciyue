import "dart:convert";
import "dart:io";

import "package:process/process.dart";

/// Removes system ccache wrapper directories from a compiler search path.
///
/// Some Linux distributions put compiler-name symlinks in one of these
/// directories. Native toolchain resolution follows those symlinks and then
/// invokes ccache as if it were the compiler, so compiler flags such as
/// `-fPIC` are rejected by ccache.
String removeCcachePathEntries(String path) {
  return path.split(":").where((entry) => !_isCcachePathEntry(entry)).join(":");
}

bool _isCcachePathEntry(String entry) {
  final normalized = entry
      .replaceAll("\\", "/")
      .replaceFirst(RegExp(r"/+$"), "");
  return normalized == "ccache" ||
      normalized.endsWith("/ccache") ||
      normalized.endsWith("/ccache/bin");
}

/// Process manager that keeps ccache wrappers out of native compiler lookup.
class CcacheSafeProcessManager implements ProcessManager {
  final ProcessManager _delegate;

  const CcacheSafeProcessManager({
    this._delegate = const LocalProcessManager(),
  });

  Map<String, String>? _environment(
    Map<String, String>? environment,
    bool includeParentEnvironment,
  ) {
    if (!Platform.isLinux) {
      return environment;
    }

    if (environment == null && !includeParentEnvironment) {
      return null;
    }

    final result = <String, String>{...?environment};
    if (includeParentEnvironment && !result.containsKey("PATH")) {
      final inheritedPath = Platform.environment["PATH"];
      if (inheritedPath != null) {
        result["PATH"] = inheritedPath;
      }
    }

    final path = result["PATH"];
    if (path != null) {
      result["PATH"] = removeCcachePathEntries(path);
    }
    return result;
  }

  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return _delegate.start(
      command,
      workingDirectory: workingDirectory,
      environment: _environment(environment, includeParentEnvironment),
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }

  @override
  Future<ProcessResult> run(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    return _delegate.run(
      command,
      workingDirectory: workingDirectory,
      environment: _environment(environment, includeParentEnvironment),
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  ProcessResult runSync(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    return _delegate.runSync(
      command,
      workingDirectory: workingDirectory,
      environment: _environment(environment, includeParentEnvironment),
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  bool canRun(covariant String executable, {String? workingDirectory}) {
    return _delegate.canRun(executable, workingDirectory: workingDirectory);
  }

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) {
    return _delegate.killPid(pid, signal);
  }
}
