import "dart:async";
import "dart:io";

import "package:ciyue/core/app_globals.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:ciyue/services/selection_watcher.dart";
import "package:dbus/dbus.dart";
import "package:flutter/foundation.dart";

/// AT-SPI2 role of a password text field.
///
/// `AtspiRole` in atspi-constants.h (libatspi 2.52, installed GIR
/// `/usr/share/gir-1.0/Atspi-2.0.gir`): `password_text`, value 40. An object
/// with this role shows no visible text, so its content must never be read.
const atSpiRolePasswordText = 40;

/// AT-SPI state of the object holding keyboard focus.
///
/// `AtspiStateType` in atspi-constants.h: `ATSPI_STATE_FOCUSED`, value 12.
/// `Accessible.GetState` returns these enum values as an array of uint32.
const atSpiStateFocused = 12;

/// Event name registered with the AT-SPI registry for text-selection changes.
///
/// `object:text-selection-changed`: the range of text selections within a
/// text object has changed. The event carries no offsets — detail1/detail2
/// are unused for it — so a listener must re-query the source object's Text
/// interface (`GetNSelections`/`GetSelection`) to learn whether a selection
/// is present. (atspi `TextSelectionChangedEvent` has no fields beyond the
/// source object; see also the xa11y event reference.)
const atSpiTextSelectionChangedEvent = "object:text-selection-changed";

/// Bus name of the service that hands out the accessibility bus address.
const _a11yBusName = "org.a11y.Bus";

/// Object path of the `org.a11y.Bus` service.
const _a11yBusPath = "/org/a11y/bus";

/// `org.a11y.Bus`: `GetAddress () -> s`.
const _a11yBusInterface = "org.a11y.Bus";

/// Bus name of the AT-SPI registry daemon.
const _registryBusName = "org.a11y.atspi.Registry";

/// Object path of the registry itself (`Registry.RegisterEvent` lives here).
const _registryPath = "/org/a11y/atspi/registry";

/// Object path of the desktop root: its children are the applications'
/// root accessibles.
const _desktopRootPath = "/org/a11y/atspi/accessible/root";

/// `org.a11y.atspi.Accessible`: `GetRole`, `GetState`, `GetChildren`.
const _accessibleInterface = "org.a11y.atspi.Accessible";

/// `org.a11y.atspi.Text`: `GetText`, `GetSelection`, `GetNSelections`.
const _textInterface = "org.a11y.atspi.Text";

/// `org.a11y.atspi.Registry`: `RegisterEvent`, `DeregisterEvent`.
const _registryInterface = "org.a11y.atspi.Registry";

/// Interface of the signals applications emit for object events.
const _eventObjectInterface = "org.a11y.atspi.Event.Object";

/// Signal member for [atSpiTextSelectionChangedEvent].
const _textSelectionChangedMember = "TextSelectionChanged";

/// Body of an AT-SPI event signal: type, detail1, detail2, any-data,
/// properties. (atspi crate `ATSPI_EVENT`, `siiva{sv}`.)
const _eventSignalSignature = "siiva{sv}";

/// How many accessible objects the focused-object walk may visit. The walk
/// is bounded so a pathological tree cannot stall a lookup.
const _maxWalkNodes = 400;

/// How deep the focused-object walk may descend.
const _maxWalkDepth = 32;

/// How many focused candidates the walk collects before stopping.
const _maxFocusedCandidates = 4;

/// A remote accessible object: the bus that owns it and its object path.
@visibleForTesting
class AtSpiObjectRef {
  const AtSpiObjectRef(this.busName, this.path);

  final String busName;
  final DBusObjectPath path;

  @override
  bool operator ==(Object other) =>
      other is AtSpiObjectRef && other.busName == busName && other.path == path;

  @override
  int get hashCode => Object.hash(busName, path);

  @override
  String toString() => "AtSpiObjectRef($busName, $path)";
}

/// Minimal surface of the session bus the AT-SPI code needs, so tests can
/// substitute a fake without a live bus.
@visibleForTesting
abstract class AtSpiBus {
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    String? interface,
    required String name,
    Iterable<DBusValue> values = const [],
    DBusSignature? replySignature,
  });

  Stream<DBusSignal> signals({
    String? interface,
    String? name,
    DBusSignature? signature,
  });

  Future<void> close();
}

/// Resolves the accessibility bus address: `AT_SPI_BUS_ADDRESS` when set,
/// otherwise `org.a11y.Bus.GetAddress` on the session bus.
///
/// The Registry lives on the accessibility bus, a separate bus from the
/// session bus — calling it on the session bus fails with ServiceUnknown.
/// (Probed 2026-11-23: `GetAddress` activates `at-spi-bus-launcher` and
/// returns e.g. `unix:path=$XDG_CACHE_HOME/at-spi/bus`; the Registry then
/// answers `GetRegisteredEvents` on that bus.)
@visibleForTesting
Future<String> resolveAtSpiBusAddress(
  AtSpiBus sessionBus, {
  String? environmentAddress,
}) async {
  final envAddress =
      environmentAddress ?? Platform.environment["AT_SPI_BUS_ADDRESS"];
  if (envAddress != null && envAddress.isNotEmpty) return envAddress;
  final result = await sessionBus.callMethod(
    destination: _a11yBusName,
    path: DBusObjectPath(_a11yBusPath),
    interface: _a11yBusInterface,
    name: "GetAddress",
    replySignature: DBusSignature("s"),
  );
  return result.returnValues.single.asString();
}

class _SessionAtSpiBus implements AtSpiBus {
  _SessionAtSpiBus._(this._client);

  final DBusClient _client;

  /// Connects to the accessibility bus, resolving its address first.
  /// Throws when the address cannot be resolved; the client connects
  /// lazily on first use.
  static Future<AtSpiBus> connect() async {
    final session = _SessionAtSpiBus._(DBusClient.session());
    try {
      final address = await resolveAtSpiBusAddress(session);
      return _SessionAtSpiBus._(DBusClient(DBusAddress(address)));
    } finally {
      await session.close();
    }
  }

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    String? interface,
    required String name,
    Iterable<DBusValue> values = const [],
    DBusSignature? replySignature,
  }) => _client.callMethod(
    destination: destination,
    path: path,
    interface: interface,
    name: name,
    values: values,
    replySignature: replySignature,
  );

  @override
  Stream<DBusSignal> signals({
    String? interface,
    String? name,
    DBusSignature? signature,
  }) => DBusSignalStream(
    _client,
    interface: interface,
    name: name,
    signature: signature ?? DBusSignature(_eventSignalSignature),
  );

  @override
  Future<void> close() => _client.close();
}

/// Thin wrapper over [AtSpiBus] spelling out the AT-SPI calls this file
/// makes, with their spec signatures.
///
/// Sources: GNOME at-spi2-core devel-docs for `org.a11y.atspi.Accessible`
/// (`GetRole () -> u`, `GetState () -> au`, `GetChildren () -> a(so)`),
/// `org.a11y.atspi.Text` (`GetText (i, i) -> s`, `GetSelection (i) -> (i, i)`,
/// `GetNSelections () -> i`) and `org.a11y.atspi.Registry`
/// (`RegisterEvent (s, as, s)`, `DeregisterEvent (s)`).
@visibleForTesting
class AtSpiClient {
  AtSpiClient(this._bus);

  final AtSpiBus _bus;

  Future<List<DBusValue>> _call(
    AtSpiObjectRef ref,
    String interface,
    String name,
    Iterable<DBusValue> values,
    String replySignature,
  ) async {
    final result = await _bus.callMethod(
      destination: ref.busName,
      path: ref.path,
      interface: interface,
      name: name,
      values: values,
      replySignature: DBusSignature(replySignature),
    );
    return result.returnValues;
  }

  /// `Accessible.GetRole () -> u`.
  Future<int> getRole(AtSpiObjectRef ref) async {
    final values = await _call(
      ref,
      _accessibleInterface,
      "GetRole",
      const [],
      "u",
    );
    return values.single.asUint32();
  }

  /// `Accessible.GetState () -> au`: the `AtspiStateType` values held.
  Future<List<int>> getState(AtSpiObjectRef ref) async {
    final values = await _call(
      ref,
      _accessibleInterface,
      "GetState",
      const [],
      "au",
    );
    return values.single.asUint32Array().toList();
  }

  /// `Accessible.GetChildren () -> a(so)`.
  Future<List<AtSpiObjectRef>> getChildren(AtSpiObjectRef ref) async {
    final values = await _call(
      ref,
      _accessibleInterface,
      "GetChildren",
      const [],
      "a(so)",
    );
    final children = (values.single as DBusArray).children;
    return children.map((child) {
      final parts = child.asStruct();
      return AtSpiObjectRef(parts[0].asString(), parts[1].asObjectPath());
    }).toList();
  }

  /// `Text.GetNSelections () -> i`.
  Future<int> getNSelections(AtSpiObjectRef ref) async {
    final values = await _call(
      ref,
      _textInterface,
      "GetNSelections",
      const [],
      "i",
    );
    return values.single.asInt32();
  }

  /// `Text.GetSelection (i) -> (i, i)`: start and end character offsets.
  Future<(int, int)> getSelection(AtSpiObjectRef ref, int selectionNum) async {
    final values = await _call(ref, _textInterface, "GetSelection", [
      DBusInt32(selectionNum),
    ], "ii");
    return (values[0].asInt32(), values[1].asInt32());
  }

  /// `Text.GetText (i, i) -> s`.
  Future<String> getText(
    AtSpiObjectRef ref,
    int startOffset,
    int endOffset,
  ) async {
    final values = await _call(ref, _textInterface, "GetText", [
      DBusInt32(startOffset),
      DBusInt32(endOffset),
    ], "s");
    return values.single.asString();
  }

  /// Whether [ref] currently has a non-empty text selection.
  Future<bool> hasNonEmptySelection(AtSpiObjectRef ref) async {
    if (await getNSelections(ref) <= 0) return false;
    final (start, end) = await getSelection(ref, 0);
    return end > start;
  }

  /// Depth-first walk from the desktop root collecting the objects that
  /// currently hold keyboard focus, stopping early once enough are found.
  /// Throws when the registry cannot be reached; per-node failures are
  /// skipped so one dead object does not abort the walk.
  Future<List<AtSpiObjectRef>> findFocusedObjects() async {
    final found = <AtSpiObjectRef>[];
    var visited = 0;
    final stack = <(AtSpiObjectRef, int)>[
      (AtSpiObjectRef(_registryBusName, DBusObjectPath(_desktopRootPath)), 0),
    ];
    while (stack.isNotEmpty &&
        visited < _maxWalkNodes &&
        found.length < _maxFocusedCandidates) {
      final (ref, depth) = stack.removeLast();
      visited++;
      List<AtSpiObjectRef> children;
      try {
        children = await getChildren(ref);
      } catch (error, stackTrace) {
        // The walk starts at the desktop root: if even that cannot be
        // listed, enumeration is impossible rather than empty, so the
        // failure must reach the caller instead of reading as "no
        // selection". Deeper nodes stay best-effort.
        if (depth == 0) rethrow;
        talker.warning(
          "AT-SPI walk could not list children of $ref",
          error,
          stackTrace,
        );
        continue;
      }
      for (final child in children.reversed) {
        try {
          if ((await getState(child)).contains(atSpiStateFocused)) {
            found.add(child);
            if (found.length >= _maxFocusedCandidates) break;
          }
        } catch (error, stackTrace) {
          talker.warning(
            "AT-SPI walk could not read state of $child",
            error,
            stackTrace,
          );
        }
        if (depth + 1 < _maxWalkDepth) stack.add((child, depth + 1));
      }
    }
    return found;
  }

  /// `Registry.RegisterEvent (s, as, s)` with an empty application name,
  /// i.e. the event from every application.
  Future<void> registerEvent(String event) async {
    await _bus.callMethod(
      destination: _registryBusName,
      path: DBusObjectPath(_registryPath),
      interface: _registryInterface,
      name: "RegisterEvent",
      values: [
        DBusString(event),
        DBusArray(DBusSignature("s")),
        const DBusString(""),
      ],
    );
  }

  /// `Registry.DeregisterEvent (s)`: one argument only — verified against
  /// the live registry introspection (at-spi2-registryd 2.52.0, 2026-11-23).
  /// Sending a second argument fails the call with InvalidArgs.
  Future<void> deregisterEvent(String event) async {
    await _bus.callMethod(
      destination: _registryBusName,
      path: DBusObjectPath(_registryPath),
      interface: _registryInterface,
      name: "DeregisterEvent",
      values: [DBusString(event)],
    );
  }

  /// `Registry.GetRegisteredEvents () -> a(ss)`: answers only when the
  /// registry daemon is up, which is what availability probing uses.
  Future<void> checkRegistry() async {
    await _bus.callMethod(
      destination: _registryBusName,
      path: DBusObjectPath(_registryPath),
      interface: _registryInterface,
      name: "GetRegisteredEvents",
      replySignature: DBusSignature("a(ss)"),
    );
  }
}

/// Reads the text selected in the focused application through AT-SPI2.
///
/// AT-SPI2 runs over the accessibility bus, not X11, so this is the
/// selection path that also works on Wayland — unlike the XTest synthetic
/// copy. It is not verified on Wayland here: the sandbox has no Wayland
/// session.
class AtSpiSelectionProvider implements SelectionTextProvider {
  AtSpiSelectionProvider({Future<AtSpiBus> Function()? busFactory})
    : _busFactory = busFactory ?? _SessionAtSpiBus.connect;

  final Future<AtSpiBus> Function() _busFactory;

  static bool? _available;

  /// Last time availability was probed, explicit or lazy.
  static DateTime? _lastProbeAttempt;

  /// Minimum time between lazy re-probes (see [_ensureProbed]).
  @visibleForTesting
  static Duration probeRetryInterval = const Duration(seconds: 10);

  /// Re-probes availability when the registry was not up at the last
  /// probe, so a registry that starts after the app still enables this
  /// lane without a restart. Throttled: a failed probe is not repeated
  /// on every acquire. Never throws.
  static Future<void> _ensureProbed({
    Future<AtSpiBus> Function()? busFactory,
  }) async {
    if (_available == true) return;
    final last = _lastProbeAttempt;
    if (last != null && DateTime.now().difference(last) < probeRetryInterval) {
      return;
    }
    await refreshAvailability(busFactory: busFactory);
  }

  /// Last probed availability: true when the session bus is reachable and
  /// the registry daemon answers. False until [refreshAvailability] has
  /// probed successfully — D-Bus is async, so there is no synchronous probe.
  static bool get isAvailable => _available ?? false;

  /// Probes the registry daemon and records the result for [isAvailable].
  /// Never throws.
  static Future<bool> refreshAvailability({
    Future<AtSpiBus> Function()? busFactory,
  }) async {
    AtSpiBus? bus;
    try {
      _lastProbeAttempt = DateTime.now();
      bus = await (busFactory ?? _SessionAtSpiBus.connect)();
      await AtSpiClient(bus).checkRegistry();
      _available = true;
      return true;
    } catch (error, stackTrace) {
      talker.warning("AT-SPI registry is unavailable", error, stackTrace);
      _available = false;
      return false;
    } finally {
      if (bus != null) await _closeQuietly(bus);
    }
  }

  @visibleForTesting
  static void resetAvailabilityForTesting() {
    _available = null;
    _lastProbeAttempt = null;
  }

  static Future<void> _closeQuietly(AtSpiBus bus) async {
    try {
      await bus.close();
    } catch (error, stackTrace) {
      talker.warning("Failed to close the AT-SPI bus", error, stackTrace);
    }
  }

  @override
  Future<String?> getSelectedText() async {
    // The registry may have started after the app: re-probe lazily on
    // acquire instead of trusting the startup probe forever.
    await AtSpiSelectionProvider._ensureProbed(busFactory: _busFactory);
    final AtSpiBus bus;
    try {
      bus = await _busFactory();
    } catch (error) {
      // The bus itself is unreachable: this provider cannot tell
      // whether a selection exists, so the ladder must try the next
      // rung instead of treating this as "no selection".
      throw SelectionUnavailableException("AT-SPI bus unavailable: $error");
    }
    SelectionUnavailableException? readError;
    try {
      final client = AtSpiClient(bus);
      for (final focused in await client.findFocusedObjects()) {
        // Fail closed on password fields: never read their text, and do
        // not fall through to another object while the user is typing a
        // password. When the role itself cannot be read, this object
        // stays unread.
        final bool isPassword;
        try {
          isPassword = await client.getRole(focused) == atSpiRolePasswordText;
        } catch (_) {
          continue;
        }
        if (isPassword) return null;
        try {
          final text = await _readSelection(client, focused);
          if (text != null) return text;
        } on SelectionUnavailableException catch (error) {
          readError ??= error;
        }
      }
      if (readError != null) throw readError;
      return null;
    } catch (error, stackTrace) {
      if (error is SelectionUnavailableException) rethrow;
      talker.warning(
        "Failed to read the selection through AT-SPI",
        error,
        stackTrace,
      );
      throw SelectionUnavailableException(
        "Failed to read the selection through AT-SPI: $error",
      );
    } finally {
      await _closeQuietly(bus);
    }
  }

  /// Reads the first selection of [ref] as trimmed non-empty text, or null
  /// when it has no selection or does not implement the Text interface.
  static Future<String?> _readSelection(
    AtSpiClient client,
    AtSpiObjectRef ref,
  ) async {
    try {
      if (await client.getNSelections(ref) <= 0) return null;
      final (start, end) = await client.getSelection(ref, 0);
      if (end <= start) return null;
      // The object at this path may have been replaced since the
      // earlier role check, so re-check immediately before reading
      // its text: a password field must never be read. If the role
      // itself cannot be read, this object stays unread.
      try {
        if (await client.getRole(ref) == atSpiRolePasswordText) return null;
      } catch (_) {
        return null;
      }
      final text = (await client.getText(ref, start, end)).trim();
      return text.isEmpty ? null : text;
    } catch (error, stackTrace) {
      // The bus call failed after the role was verified as non-password,
      // so this provider cannot tell whether a selection exists: the
      // ladder must try the next rung instead of treating this as "no
      // selection".
      talker.warning(
        "Failed to read the text selection of $ref",
        error,
        stackTrace,
      );
      throw SelectionUnavailableException(
        "Failed to read the text selection of $ref: $error",
      );
    }
  }
}

/// Emits whether the user currently has text selected, driven by AT-SPI2
/// `object:text-selection-changed` signals.
///
/// The D-Bus signal stream is async: `dbus` delivers signals through a
/// `Stream` fed by the client's socket reader, so no thread or blocking
/// loop is parked on the UI isolate. Each signal re-queries the source
/// object's Text interface, because the event itself carries no offsets.
class AtSpiSelectionWatcher implements SelectionWatcher {
  AtSpiSelectionWatcher({Future<AtSpiBus> Function()? busFactory})
    : _busFactory = busFactory ?? _SessionAtSpiBus.connect;

  final Future<AtSpiBus> Function() _busFactory;

  StreamController<bool> _controller = StreamController<bool>.broadcast();

  var _started = false;
  bool? _lastEmitted;
  AtSpiBus? _bus;
  StreamSubscription<DBusSignal>? _subscription;

  // Signal handlers run one at a time, in arrival order: overlapping
  // handlers could otherwise emit stale states out of order.
  Future<void> _signalQueue = Future<void>.value();

  @override
  bool get isAvailable => AtSpiSelectionProvider.isAvailable;

  @override
  Stream<bool> get onSelectionChanged => _controller.stream;

  /// Registers for `object:text-selection-changed` and starts emitting.
  /// Idempotent; never throws.
  @override
  Future<void> start() async {
    if (_started) return;
    // The registry may have started after the app: re-probe lazily on
    // acquire instead of trusting the startup probe forever.
    await AtSpiSelectionProvider._ensureProbed(busFactory: _busFactory);
    if (_controller.isClosed) {
      _controller = StreamController<bool>.broadcast();
    }
    try {
      final bus = await _busFactory();
      _bus = bus;
      final client = AtSpiClient(bus);
      await client.registerEvent(atSpiTextSelectionChangedEvent);
      _subscription = bus
          .signals(
            interface: _eventObjectInterface,
            name: _textSelectionChangedMember,
          )
          .listen(
            (signal) {
              _signalQueue = _signalQueue.then((_) => _onSignal(signal));
            },
            onError: (Object error, StackTrace stackTrace) {
              talker.warning("AT-SPI event stream error", error, stackTrace);
            },
          );
      _started = true;
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to start the AT-SPI selection watcher",
        error,
        stackTrace,
      );
      await _tearDown();
    }
  }

  /// Stops emitting and deregisters the event. Idempotent; never throws.
  ///
  /// Closes the stream; a later [start] exposes a fresh one, so
  /// subscribe to [onSelectionChanged] again after restarting an
  /// instance.
  @override
  Future<void> stop() async {
    if (!_started && _bus == null) return;
    _started = false;
    await _tearDown();
    if (!_controller.isClosed) await _controller.close();
  }

  Future<void> _tearDown() async {
    await _subscription?.cancel();
    _subscription = null;
    final bus = _bus;
    _bus = null;
    if (bus == null) return;
    try {
      await AtSpiClient(bus).deregisterEvent(atSpiTextSelectionChangedEvent);
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to deregister the AT-SPI event",
        error,
        stackTrace,
      );
    }
    try {
      await bus.close();
    } catch (error, stackTrace) {
      talker.warning("Failed to close the AT-SPI bus", error, stackTrace);
    }
  }

  Future<void> _onSignal(DBusSignal signal) async {
    try {
      final hasSelection = await _sourceHasSelection(signal);
      if (hasSelection == _lastEmitted) return;
      _lastEmitted = hasSelection;
      // A queued handler may run after stop() closed the stream.
      if (_controller.isClosed) return;
      _controller.add(hasSelection);
    } catch (error, stackTrace) {
      talker.warning(
        "Failed to handle an AT-SPI selection event",
        error,
        stackTrace,
      );
    }
  }

  /// Whether the object the signal came from has a non-empty selection.
  /// Password fields report no selection without their text being read.
  Future<bool> _sourceHasSelection(DBusSignal signal) async {
    final bus = _bus;
    final sender = signal.sender;
    if (bus == null || sender == null) return false;
    final client = AtSpiClient(bus);
    final ref = AtSpiObjectRef(sender, signal.path);
    if (await client.getRole(ref) == atSpiRolePasswordText) return false;
    return client.hasNonEmptySelection(ref);
  }
}
