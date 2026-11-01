import "dart:async";
import "dart:convert";
import "dart:ffi";
import "dart:io";
import "dart:typed_data";

/// Transports for the Speech Synthesis Interface Protocol (SSIP).
///
/// SSIP is the wire protocol spoken by speech-dispatcher. The default
/// daemon configuration exposes a Unix-domain socket only; TCP on
/// 127.0.0.1:6560 is a fallback for non-default configurations.
///
/// Dart has no AF_UNIX socket client (`dart:io` sockets are TCP-only),
/// so the Unix transport below uses a minimal `dart:ffi` binding to
/// libc (`socket`/`connect`/`send`/`recv`/`close`, plus `poll` and
/// `getsockopt` so connects and reads can time out without blocking
/// the isolate forever). No `package:ffi` helpers are used: native
/// memory comes from libc `malloc`/`free`, so this file adds zero pub
/// dependencies. libc is loaded lazily inside the Linux-only connect
/// path and never on other platforms.
///
/// All transports behind this interface are interchangeable, so every
/// SSIP test uses fakes and no test touches a real socket.

/// A byte transport for one SSIP connection.
///
/// Implementations must tolerate being used from a single isolate.
/// [read] returns `null` on end-of-stream; [tryRead] returns `null`
/// when no bytes are available right now (or the transport is closed).
abstract class SsipTransport {
  /// Opens the transport, failing (rather than hanging) within
  /// [timeout] when the daemon is unreachable.
  Future<void> connect(Duration timeout);

  /// Sends [bytes], in full, before returning.
  Future<void> send(List<int> bytes);

  /// Reads one chunk, waiting up to [timeout] for data. Returns `null`
  /// on end-of-stream. Throws [TimeoutException] on timeout.
  Future<List<int>?> read(Duration timeout);

  /// Returns bytes available right now without waiting, or `null`.
  Future<List<int>?> tryRead();

  /// Closes the transport. Idempotent.
  Future<void> close();

  /// Whether the transport is currently open.
  bool get isOpen;
}

/// Creates [SsipTransport]s. Injected so tests can substitute fakes.
typedef SsipTransportFactory = SsipTransport Function();

/// The default factory: Unix socket first, TCP fallback.
SsipTransport createDefaultSsipTransport() => AutoSsipTransport();

/// Candidate speech-dispatcher socket paths, most specific first:
/// `$XDG_RUNTIME_DIR/speech-dispatcher/speechd.sock`, falling back to
/// `~/.cache/speech-dispatcher/speechd.sock` when `XDG_RUNTIME_DIR` is
/// unset (or as an extra candidate when it is set).
List<String> _ssipSocketPaths() {
  final env = Platform.environment;
  final paths = <String>[];
  final runtimeDir = env["XDG_RUNTIME_DIR"];
  if (runtimeDir != null && runtimeDir.isNotEmpty) {
    paths.add("$runtimeDir/speech-dispatcher/speechd.sock");
  }
  final home = env["HOME"];
  if (home != null && home.isNotEmpty) {
    paths.add("$home/.cache/speech-dispatcher/speechd.sock");
  }
  return paths;
}

/// Tries the Unix socket paths in order, then TCP 127.0.0.1:6560.
/// Delegates all I/O to whichever transport connects first.
class AutoSsipTransport implements SsipTransport {
  AutoSsipTransport({
    List<String> Function()? socketPaths,
    SsipTransport Function(String path)? unixTransport,
    SsipTransport Function()? tcpTransport,
  }) : _socketPaths = socketPaths ?? _ssipSocketPaths,
       _unixTransport =
           unixTransport ?? ((path) => UnixSocketSsipTransport(path)),
       _tcpTransport = tcpTransport ?? TcpSsipTransport.new;

  final List<String> Function() _socketPaths;
  final SsipTransport Function(String path) _unixTransport;
  final SsipTransport Function() _tcpTransport;

  SsipTransport? _active;

  @override
  Future<void> connect(Duration timeout) async {
    final deadline = DateTime.now().add(timeout);
    Object lastError = StateError("No SSIP transport could connect.");
    for (final path in _socketPaths()) {
      SsipTransport? transport;
      try {
        transport = _unixTransport(path);
        await transport.connect(_remaining(deadline));
        _active = transport;
        return;
      } catch (error) {
        lastError = error;
        if (transport != null) await transport.close();
      }
    }
    SsipTransport? tcp;
    try {
      tcp = _tcpTransport();
      await tcp.connect(_remaining(deadline));
      _active = tcp;
      return;
    } catch (error) {
      lastError = error;
      if (tcp != null) await tcp.close();
    }
    throw lastError;
  }

  static Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Future<void> send(List<int> bytes) async {
    final active = _active;
    if (active == null) throw StateError("SSIP transport is not connected.");
    await active.send(bytes);
  }

  @override
  Future<List<int>?> read(Duration timeout) async {
    final active = _active;
    if (active == null) throw StateError("SSIP transport is not connected.");
    return active.read(timeout);
  }

  @override
  Future<List<int>?> tryRead() async {
    final active = _active;
    if (active == null) return null;
    return active.tryRead();
  }

  @override
  Future<void> close() async {
    final active = _active;
    _active = null;
    if (active != null) await active.close();
  }

  @override
  bool get isOpen => _active?.isOpen ?? false;
}

/// SSIP over TCP (dart:io). Used only as a fallback when the Unix
/// socket is unreachable; the default daemon configuration does not
/// listen on TCP.
class TcpSsipTransport implements SsipTransport {
  Socket? _socket;
  StreamSubscription<List<int>>? _subscription;
  bool _open = false;
  final List<List<int>> _buffered = [];
  final List<Completer<List<int>?>> _waiters = [];

  @override
  Future<void> connect(Duration timeout) async {
    final socket = await Socket.connect("127.0.0.1", 6560, timeout: timeout);
    _socket = socket;
    _open = true;
    _subscription = socket.listen(
      _onData,
      onError: (_) => _onClosed(),
      onDone: _onClosed,
      cancelOnError: false,
    );
  }

  void _onData(List<int> chunk) {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete(chunk);
    } else {
      _buffered.add(chunk);
    }
  }

  void _onClosed() {
    _open = false;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    _waiters.clear();
  }

  @override
  Future<void> send(List<int> bytes) async {
    final socket = _socket;
    if (socket == null || !_open) {
      throw StateError("TCP SSIP transport is not connected.");
    }
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<List<int>?> read(Duration timeout) {
    if (_buffered.isNotEmpty) return Future.value(_buffered.removeAt(0));
    if (!_open) return Future.value(null);
    final waiter = Completer<List<int>?>();
    _waiters.add(waiter);
    return waiter.future.timeout(
      timeout,
      onTimeout: () {
        _waiters.remove(waiter);
        throw TimeoutException("SSIP TCP read timed out.", timeout);
      },
    );
  }

  @override
  Future<List<int>?> tryRead() async {
    if (_buffered.isNotEmpty) return _buffered.removeAt(0);
    return null;
  }

  @override
  Future<void> close() async {
    _open = false;
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _onClosed();
  }

  @override
  bool get isOpen => _open && _socket != null;
}

// ---------------------------------------------------------------------------
// Unix-domain socket transport via libc FFI.
// ---------------------------------------------------------------------------

const int _afUnix = 1;
const int _sockStream = 1;
const int _sockNonblock = 0x800;
const int _sockCloexec = 0x80000;
const int _solSocket = 1;
const int _soError = 4;
const int _pollIn = 0x1;
const int _pollOut = 0x4;
const int _eintr = 4;
const int _eagain = 11;
const int _einprogress = 115;
const int _msgDontwait = 0x40;

typedef _SocketC = Int32 Function(Int32 domain, Int32 type, Int32 protocol);
typedef _SocketDart = int Function(int domain, int type, int protocol);
typedef _ConnectC = Int32 Function(
  Int32 fd,
  Pointer<Void> addr,
  Uint32 addrLen,
);
typedef _ConnectDart = int Function(int fd, Pointer<Void> addr, int addrLen);
typedef _SendRecvC = IntPtr Function(
  Int32 fd,
  Pointer<Void> buf,
  UintPtr len,
  Int32 flags,
);
typedef _SendRecvDart = int Function(
  int fd,
  Pointer<Void> buf,
  int len,
  int flags,
);
typedef _CloseC = Int32 Function(Int32 fd);
typedef _CloseDart = int Function(int fd);
typedef _PollC = Int32 Function(Pointer<Void> fds, Uint32 nfds, Int32 timeout);
typedef _PollDart = int Function(Pointer<Void> fds, int nfds, int timeout);
typedef _GetsockoptC = Int32 Function(
  Int32 fd,
  Int32 level,
  Int32 optname,
  Pointer<Void> optval,
  Pointer<Uint32> optlen,
);
typedef _GetsockoptDart = int Function(
  int fd,
  int level,
  int optname,
  Pointer<Void> optval,
  Pointer<Uint32> optlen,
);
typedef _MallocC = Pointer<Void> Function(UintPtr size);
typedef _MallocDart = Pointer<Void> Function(int size);
typedef _FreeC = Void Function(Pointer<Void> ptr);
typedef _FreeDart = void Function(Pointer<Void> ptr);
typedef _ErrnoLocationC = Pointer<Int32> Function();
typedef _ErrnoLocationDart = Pointer<Int32> Function();

/// Lazily loaded libc entry points. Loading happens only inside
/// [UnixSocketSsipTransport.connect] on Linux, never at import time
/// and never on other platforms.
class _Libc {
  _Libc._(
    this._socket,
    this._connect,
    this._send,
    this._recv,
    this._close,
    this._poll,
    this._getsockopt,
    this._malloc,
    this._free,
    this._errnoLocation,
  );

  static _Libc? _cached;
  static bool _loadFailed = false;

  static _Libc loadCached() {
    final cached = _cached;
    if (cached != null) return cached;
    if (_loadFailed) throw StateError("libc could not be loaded.");
    try {
      DynamicLibrary library;
      try {
        library = DynamicLibrary.open("libc.so.6");
      } catch (_) {
        library = DynamicLibrary.process();
      }
      final loaded = _Libc._(
        library
            .lookup<NativeFunction<_SocketC>>("socket")
            .asFunction<_SocketDart>(),
        library
            .lookup<NativeFunction<_ConnectC>>("connect")
            .asFunction<_ConnectDart>(),
        library
            .lookup<NativeFunction<_SendRecvC>>("send")
            .asFunction<_SendRecvDart>(),
        library
            .lookup<NativeFunction<_SendRecvC>>("recv")
            .asFunction<_SendRecvDart>(),
        library
            .lookup<NativeFunction<_CloseC>>("close")
            .asFunction<_CloseDart>(),
        library.lookup<NativeFunction<_PollC>>("poll").asFunction<_PollDart>(),
        library
            .lookup<NativeFunction<_GetsockoptC>>("getsockopt")
            .asFunction<_GetsockoptDart>(),
        library
            .lookup<NativeFunction<_MallocC>>("malloc")
            .asFunction<_MallocDart>(),
        library.lookup<NativeFunction<_FreeC>>("free").asFunction<_FreeDart>(),
        library
            .lookup<NativeFunction<_ErrnoLocationC>>("__errno_location")
            .asFunction<_ErrnoLocationDart>(),
      );
      _cached = loaded;
      return loaded;
    } catch (_) {
      _loadFailed = true;
      rethrow;
    }
  }

  final _SocketDart _socket;
  final _ConnectDart _connect;
  final _SendRecvDart _send;
  final _SendRecvDart _recv;
  final _CloseDart _close;
  final _PollDart _poll;
  final _GetsockoptDart _getsockopt;
  final _MallocDart _malloc;
  final _FreeDart _free;
  final _ErrnoLocationDart _errnoLocation;

  int get errno => _errnoLocation().value;

  int socket(int domain, int type, int protocol) =>
      _socket(domain, type, protocol);

  int connect(int fd, Pointer<Void> addr, int addrLen) =>
      _connect(fd, addr, addrLen);

  int send(int fd, Pointer<Void> buf, int len, int flags) =>
      _send(fd, buf, len, flags);

  int recv(int fd, Pointer<Void> buf, int len, int flags) =>
      _recv(fd, buf, len, flags);

  int close(int fd) => _close(fd);

  int poll(Pointer<Void> fds, int nfds, int timeout) =>
      _poll(fds, nfds, timeout);

  int getsockopt(
    int fd,
    int level,
    int optname,
    Pointer<Void> optval,
    Pointer<Uint32> optlen,
  ) => _getsockopt(fd, level, optname, optval, optlen);

  Pointer<Void> malloc(int size) => _malloc(size);

  void free(Pointer<Void> ptr) {
    if (ptr != nullptr) _free(ptr);
  }
}

/// SSIP over a Unix-domain socket, via a minimal libc FFI binding.
///
/// The socket is created non-blocking (`SOCK_NONBLOCK`) so [connect]
/// and [read] can honor their timeouts with `poll` instead of
/// blocking the isolate indefinitely. [send] polls for writability
/// when the kernel buffer is full.
class UnixSocketSsipTransport implements SsipTransport {
  UnixSocketSsipTransport(this._path);

  final String _path;
  int _fd = -1;
  bool _open = false;
  _Libc? _libc;

  @override
  bool get isOpen => _open && _fd >= 0;

  @override
  Future<void> connect(Duration timeout) async {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        "Unix socket SSIP transport is only supported on Linux.",
      );
    }
    if (_fd >= 0) throw StateError("Unix socket transport is already open.");
    final libc = _Libc.loadCached();
    _libc = libc;
    final pathBytes = utf8.encode(_path);
    // sockaddr_un.sun_path holds 108 bytes including the NUL terminator.
    if (pathBytes.length > 107) {
      throw ArgumentError("Unix socket path is too long: $_path");
    }
    // struct sockaddr_un: sa_family_t (2 bytes) + sun_path[108].
    final address = libc.malloc(110).cast<Uint8>();
    if (address == nullptr) throw StateError("malloc failed.");
    try {
      (address + 0).value = _afUnix;
      (address + 1).value = 0;
      for (var i = 0; i < pathBytes.length; i++) {
        (address + 2 + i).value = pathBytes[i];
      }
      for (var i = 2 + pathBytes.length; i < 110; i++) {
        (address + i).value = 0;
      }
      final fd = libc.socket(
        _afUnix,
        _sockStream | _sockNonblock | _sockCloexec,
        0,
      );
      if (fd < 0) {
        throw StateError("socket() failed (errno ${libc.errno}).");
      }
      _fd = fd;
      _open = true;
      final result = libc.connect(
        fd,
        address.cast<Void>(),
        2 + pathBytes.length + 1,
      );
      if (result == 0) return;
      final connectErrno = libc.errno;
      if (connectErrno != _einprogress) {
        _closeFd();
        throw StateError("connect() to $_path failed (errno $connectErrno).");
      }
      // Connection in progress: wait for writability, then check
      // SO_ERROR for the real outcome.
      final deadline = DateTime.now().add(timeout);
      while (true) {
        final remaining = deadline.difference(DateTime.now()).inMilliseconds;
        final ready = _pollOnce(
          libc,
          fd,
          _pollOut,
          remaining < 0 ? 0 : remaining,
        );
        if (ready > 0) break;
        if (ready == 0) {
          _closeFd();
          throw TimeoutException("Timed out connecting to $_path.", timeout);
        }
        if (libc.errno == _eintr && DateTime.now().isBefore(deadline)) {
          continue;
        }
        _closeFd();
        throw StateError("poll() failed (errno ${libc.errno}).");
      }
      final socketErrno = _pendingSocketError(libc, fd);
      if (socketErrno != 0) {
        _closeFd();
        throw StateError("connect() to $_path failed (errno $socketErrno).");
      }
    } finally {
      libc.free(address.cast<Void>());
    }
  }

  /// Runs one `poll()` for [events] on [fd] with a [timeoutMs]
  /// deadline. Returns the `poll()` result unchanged.
  int _pollOnce(_Libc libc, int fd, int events, int timeoutMs) {
    final fds = libc.malloc(8).cast<Uint8>();
    if (fds == nullptr) throw StateError("malloc failed.");
    try {
      (fds.cast<Int32>() + 0).value = fd;
      (fds.cast<Int16>() + 2).value = events;
      (fds.cast<Int16>() + 3).value = 0;
      return libc.poll(fds.cast<Void>(), 1, timeoutMs);
    } finally {
      libc.free(fds.cast<Void>());
    }
  }

  int _pendingSocketError(_Libc libc, int fd) {
    final value = libc.malloc(4).cast<Int32>();
    final length = libc.malloc(4).cast<Uint32>();
    if (value == nullptr || length == nullptr) {
      if (value != nullptr) libc.free(value.cast<Void>());
      if (length != nullptr) libc.free(length.cast<Void>());
      throw StateError("malloc failed.");
    }
    try {
      value.value = 0;
      length.value = 4;
      final result = libc.getsockopt(
        fd,
        _solSocket,
        _soError,
        value.cast<Void>(),
        length,
      );
      if (result != 0) return libc.errno;
      return value.value;
    } finally {
      libc.free(value.cast<Void>());
      libc.free(length.cast<Void>());
    }
  }

  void _closeFd() {
    final fd = _fd;
    final libc = _libc;
    _fd = -1;
    _open = false;
    if (fd >= 0 && libc != null) {
      try {
        libc.close(fd);
      } catch (_) {}
    }
  }

  @override
  Future<void> send(List<int> bytes) async {
    final fd = _fd;
    final libc = _libc;
    if (fd < 0 || libc == null || !_open) {
      throw StateError("Unix socket transport is not connected.");
    }
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var offset = 0;
    while (offset < bytes.length) {
      final chunkLength = bytes.length - offset < 16384
          ? bytes.length - offset
          : 16384;
      final buffer = libc.malloc(chunkLength).cast<Uint8>();
      if (buffer == nullptr) throw StateError("malloc failed.");
      try {
        for (var i = 0; i < chunkLength; i++) {
          (buffer + i).value = bytes[offset + i];
        }
        final sent = libc.send(fd, buffer.cast<Void>(), chunkLength, 0);
        if (sent > 0) {
          offset += sent;
          continue;
        }
        if (sent == 0) {
          // Nothing accepted; wait briefly for writability instead of
          // spinning.
          if (!_waitFor(libc, fd, _pollOut, deadline)) {
            throw TimeoutException("Timed out sending SSIP data.");
          }
          continue;
        }
        final sendErrno = libc.errno;
        if (sendErrno == _eintr) continue;
        if (sendErrno == _eagain) {
          if (!_waitFor(libc, fd, _pollOut, deadline)) {
            throw TimeoutException("Timed out sending SSIP data.");
          }
          continue;
        }
        _open = false;
        throw StateError("send() failed (errno $sendErrno).");
      } finally {
        libc.free(buffer.cast<Void>());
      }
    }
  }

  /// Polls until [fd] is ready for [events] or [deadline] passes.
  /// Returns `false` on timeout. `poll()` errors (other than EINTR)
  /// are treated as "retry the operation", which surfaces the real
  /// error from the following `send`/`recv`.
  bool _waitFor(_Libc libc, int fd, int events, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now()).inMilliseconds;
    if (remaining < 0) return false;
    final ready = _pollOnce(libc, fd, events, remaining);
    if (ready == 0) return false;
    return true;
  }

  @override
  Future<List<int>?> read(Duration timeout) async {
    final fd = _fd;
    final libc = _libc;
    if (fd < 0 || libc == null || !_open) return null;
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final remaining = deadline.difference(DateTime.now()).inMilliseconds;
      if (remaining < 0) {
        throw TimeoutException("Timed out reading SSIP reply.", timeout);
      }
      final ready = _pollOnce(libc, fd, _pollIn, remaining);
      if (ready == 0) {
        throw TimeoutException("Timed out reading SSIP reply.", timeout);
      }
      if (ready < 0) {
        if (libc.errno == _eintr) continue;
        _open = false;
        throw StateError("poll() failed (errno ${libc.errno}).");
      }
      final buffer = libc.malloc(8192).cast<Uint8>();
      if (buffer == nullptr) throw StateError("malloc failed.");
      try {
        final received = libc.recv(fd, buffer.cast<Void>(), 8192, 0);
        if (received > 0) {
          final chunk = Uint8List(received);
          for (var i = 0; i < received; i++) {
            chunk[i] = (buffer + i).value;
          }
          return chunk;
        }
        if (received == 0) {
          _open = false;
          return null;
        }
        final recvErrno = libc.errno;
        if (recvErrno == _eagain || recvErrno == _eintr) continue;
        _open = false;
        throw StateError("recv() failed (errno $recvErrno).");
      } finally {
        libc.free(buffer.cast<Void>());
      }
    }
  }

  @override
  Future<List<int>?> tryRead() async {
    final fd = _fd;
    final libc = _libc;
    if (fd < 0 || libc == null || !_open) return null;
    final buffer = libc.malloc(8192).cast<Uint8>();
    if (buffer == nullptr) return null;
    try {
      final received = libc.recv(fd, buffer.cast<Void>(), 8192, _msgDontwait);
      if (received > 0) {
        final chunk = Uint8List(received);
        for (var i = 0; i < received; i++) {
          chunk[i] = (buffer + i).value;
        }
        return chunk;
      }
      if (received == 0) _open = false;
      return null;
    } catch (_) {
      return null;
    } finally {
      libc.free(buffer.cast<Void>());
    }
  }

  @override
  Future<void> close() async {
    _closeFd();
  }
}
