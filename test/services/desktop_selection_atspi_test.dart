import "dart:async";
import "dart:io";

import "package:ciyue/services/desktop_selection_atspi.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:dbus/dbus.dart";
import "package:flutter_test/flutter_test.dart";

/// `AtspiRole` value for a plain text object, from the installed
/// `Atspi-2.0.gir` (atspi-constants.h). Used as the non-password role in
/// the fixtures below; the password role under test is
/// [atSpiRolePasswordText].
const _roleText = 61;

const _registry = "org.a11y.atspi.Registry";
const _registryPath = "/org/a11y/atspi/registry";
const _rootPath = "/org/a11y/atspi/accessible/root";
const _appBus = ":1.5";
const _appRoot = "/app/root";
const _textPath = "/app/text";
const _accessible = "org.a11y.atspi.Accessible";
const _text = "org.a11y.atspi.Text";

DBusObjectPath _path(String value) => DBusObjectPath(value);

DBusStruct _ref(String bus, String path) =>
    DBusStruct([DBusString(bus), _path(path)]);

/// A `text-selection-changed` signal as applications emit it: interface
/// `org.a11y.atspi.Event.Object`, member `TextSelectionChanged`, body
/// `(siiva{sv})` — type, detail1, detail2, any-data, properties.
DBusSignal _selectionSignal(String sender, String path) => DBusSignal(
  sender: sender,
  path: _path(path),
  interface: "org.a11y.atspi.Event.Object",
  name: "TextSelectionChanged",
  values: [
    const DBusString("object:text-selection-changed"),
    const DBusInt32(0),
    const DBusInt32(0),
    const DBusVariant(DBusUint32(0)),
    DBusDict(DBusSignature("s"), DBusSignature("v")),
  ],
);

class _Call {
  _Call(this.destination, this.path, this.interface, this.name, this.values);

  final String destination;
  final String path;
  final String interface;
  final String name;
  final List<DBusValue> values;

  @override
  String toString() => "$destination|$path|$interface|$name";
}

/// Fake session bus: scripted replies per method call, controllable signal
/// stream, and a record of every call made.
class _FakeAtSpiBus implements AtSpiBus {
  final Map<String, List<DBusValue>> replies = {};
  final Set<String> failures = {};
  final Map<String, Duration> delays = {};
  final List<_Call> calls = [];
  final _signals = StreamController<DBusSignal>.broadcast();
  var closed = false;

  static String _key(
    String destination,
    String path,
    String interface,
    String name,
  ) => "$destination|$path|$interface|$name";

  void reply(
    String destination,
    String path,
    String interface,
    String name,
    List<DBusValue> values,
  ) {
    replies[_key(destination, path, interface, name)] = values;
  }

  void fail(String destination, String path, String interface, String name) {
    failures.add(_key(destination, path, interface, name));
  }

  void unfail(String destination, String path, String interface, String name) {
    failures.remove(_key(destination, path, interface, name));
  }

  void delay(
    String destination,
    String path,
    String interface,
    String name,
    Duration duration,
  ) {
    delays[_key(destination, path, interface, name)] = duration;
  }

  void emit(DBusSignal signal) => _signals.add(signal);

  bool called(String interface, String name) =>
      calls.any((call) => call.interface == interface && call.name == name);

  int callCount(String interface, String name) => calls
      .where((call) => call.interface == interface && call.name == name)
      .length;

  @override
  Future<DBusMethodSuccessResponse> callMethod({
    required String destination,
    required DBusObjectPath path,
    String? interface,
    required String name,
    Iterable<DBusValue> values = const [],
    DBusSignature? replySignature,
  }) async {
    final key = _key(destination, path.value, interface ?? "", name);
    calls.add(
      _Call(destination, path.value, interface ?? "", name, values.toList()),
    );
    if (failures.contains(key)) throw StateError("scripted failure for $key");
    final delay = delays[key];
    if (delay != null) await Future<void>.delayed(delay);
    final replyValues = replies[key];
    if (replyValues == null) throw StateError("no reply scripted for $key");
    return DBusMethodSuccessResponse(replyValues);
  }

  @override
  Stream<DBusSignal> signals({
    String? interface,
    String? name,
    DBusSignature? signature,
  }) => _signals.stream.where(
    (signal) =>
        (interface == null || signal.interface == interface) &&
        (name == null || signal.name == name),
  );

  @override
  Future<void> close() async {
    closed = true;
  }
}

void _scriptRegistry(_FakeAtSpiBus bus) {
  bus.reply(
    _registry,
    _registryPath,
    "org.a11y.atspi.Registry",
    "RegisterEvent",
    [],
  );
  bus.reply(
    _registry,
    _registryPath,
    "org.a11y.atspi.Registry",
    "DeregisterEvent",
    [],
  );
}

/// Scripts the desktop tree used by the provider tests: one application
/// whose root has one focused text object.
void _scriptTree(_FakeAtSpiBus bus, {int role = _roleText}) {
  bus.reply(_registry, _rootPath, _accessible, "GetChildren", [
    DBusArray(DBusSignature("(so)"), [_ref(_appBus, _appRoot)]),
  ]);
  bus.reply(_appBus, _appRoot, _accessible, "GetChildren", [
    DBusArray(DBusSignature("(so)"), [_ref(_appBus, _textPath)]),
  ]);
  bus.reply(_appBus, _textPath, _accessible, "GetChildren", [
    DBusArray(DBusSignature("(so)")),
  ]);
  bus.reply(_appBus, _appRoot, _accessible, "GetState", [
    DBusArray(DBusSignature("u")),
  ]);
  bus.reply(_appBus, _textPath, _accessible, "GetState", [
    DBusArray(DBusSignature("u"), [const DBusUint32(12)]),
  ]);
  bus.reply(_appBus, _textPath, _accessible, "GetRole", [DBusUint32(role)]);
}

void _scriptSelection(
  _FakeAtSpiBus bus, {
  int count = 1,
  int start = 2,
  int end = 7,
  String text = "hello",
}) {
  bus.reply(_appBus, _textPath, _text, "GetNSelections", [DBusInt32(count)]);
  bus.reply(_appBus, _textPath, _text, "GetSelection", [
    DBusInt32(start),
    DBusInt32(end),
  ]);
  bus.reply(_appBus, _textPath, _text, "GetText", [DBusString(text)]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AtSpiSelectionProvider.resetAvailabilityForTesting);
  tearDown(AtSpiSelectionProvider.resetAvailabilityForTesting);

  group("protocol constants", () {
    test("password role matches AtspiRole.password_text", () {
      expect(atSpiRolePasswordText, 40);
    });

    test("focused state matches AtspiStateType.focused", () {
      expect(atSpiStateFocused, 12);
    });

    test("selection event name", () {
      expect(atSpiTextSelectionChangedEvent, "object:text-selection-changed");
    });
  });

  group("resolveAtSpiBusAddress", () {
    test("prefers AT_SPI_BUS_ADDRESS when set", () async {
      final bus = _FakeAtSpiBus();

      expect(
        await resolveAtSpiBusAddress(
          bus,
          environmentAddress: "unix:path=/tmp/fake-bus",
        ),
        "unix:path=/tmp/fake-bus",
      );
      expect(bus.calls, isEmpty);
    });

    test("falls back to org.a11y.Bus GetAddress on the session bus", () async {
      final bus = _FakeAtSpiBus();
      bus.reply("org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress", [
        const DBusString("unix:path=/tmp/fake-bus,guid=1"),
      ]);

      expect(
        await resolveAtSpiBusAddress(bus, environmentAddress: ""),
        "unix:path=/tmp/fake-bus,guid=1",
      );
    });

    test("throws when GetAddress fails", () async {
      final bus = _FakeAtSpiBus();
      bus.fail("org.a11y.Bus", "/org/a11y/bus", "org.a11y.Bus", "GetAddress");

      await expectLater(
        resolveAtSpiBusAddress(bus, environmentAddress: ""),
        throwsStateError,
      );
    });
  });

  group("AtSpiSelectionProvider", () {
    test("returns the focused object's selection, trimmed", () async {
      final bus = _FakeAtSpiBus();
      _scriptTree(bus);
      _scriptSelection(bus, text: "  hello  ");
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      expect(await provider.getSelectedText(), "hello");
      expect(bus.closed, isTrue);
    });

    test("returns null when the focused object has no selection", () async {
      final bus = _FakeAtSpiBus();
      _scriptTree(bus);
      bus.reply(_appBus, _textPath, _text, "GetNSelections", [
        const DBusInt32(0),
      ]);
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      expect(await provider.getSelectedText(), isNull);
      expect(bus.called(_text, "GetText"), isFalse);
    });

    test("returns null for an empty selection range", () async {
      final bus = _FakeAtSpiBus();
      _scriptTree(bus);
      _scriptSelection(bus, start: 4, end: 4);
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      expect(await provider.getSelectedText(), isNull);
      expect(bus.called(_text, "GetText"), isFalse);
    });

    test("returns null for whitespace-only text", () async {
      final bus = _FakeAtSpiBus();
      _scriptTree(bus);
      _scriptSelection(bus, text: "   ");
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      expect(await provider.getSelectedText(), isNull);
    });

    test(
      "returns null for a password field without reading its text",
      () async {
        final bus = _FakeAtSpiBus();
        _scriptTree(bus, role: atSpiRolePasswordText);
        final provider = AtSpiSelectionProvider(busFactory: () async => bus);

        expect(await provider.getSelectedText(), isNull);
        expect(bus.called(_text, "GetNSelections"), isFalse);
        expect(bus.called(_text, "GetSelection"), isFalse);
        expect(bus.called(_text, "GetText"), isFalse);
      },
    );

    test("returns null when a password field is a later candidate, without reading it", () async {
      // The walk reports a parent's children in reverse scripted
      // order, so the text object comes first and the password field
      // second: the role of every candidate is checked, not just the
      // first one's.
      const passwordPath = "/app/password";
      final bus = _FakeAtSpiBus();
      bus.reply(_registry, _rootPath, _accessible, "GetChildren", [
        DBusArray(DBusSignature("(so)"), [_ref(_appBus, _appRoot)]),
      ]);
      bus.reply(_appBus, _appRoot, _accessible, "GetChildren", [
        DBusArray(DBusSignature("(so)"), [
          _ref(_appBus, passwordPath),
          _ref(_appBus, _textPath),
        ]),
      ]);
      bus.reply(_appBus, _appRoot, _accessible, "GetState", [
        DBusArray(DBusSignature("u")),
      ]);
      for (final (path, role) in [
        (_textPath, _roleText),
        (passwordPath, atSpiRolePasswordText),
      ]) {
        bus.reply(_appBus, path, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)")),
        ]);
        bus.reply(_appBus, path, _accessible, "GetState", [
          DBusArray(DBusSignature("u"), [const DBusUint32(12)]),
        ]);
        bus.reply(_appBus, path, _accessible, "GetRole", [DBusUint32(role)]);
      }
      // The text object has no selection; the password field claims
      // one, so a missing role check on later candidates would read it.
      bus.reply(_appBus, _textPath, _text, "GetNSelections", [
        const DBusInt32(0),
      ]);
      bus.reply(_appBus, passwordPath, _text, "GetNSelections", [
        const DBusInt32(1),
      ]);
      bus.reply(_appBus, passwordPath, _text, "GetSelection", [
        const DBusInt32(0),
        const DBusInt32(7),
      ]);
      bus.reply(_appBus, passwordPath, _text, "GetText", [
        const DBusString("hunter2"),
      ]);
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      expect(await provider.getSelectedText(), isNull);
      expect(bus.called(_text, "GetText"), isFalse);
    });

    test(
      "throws SelectionUnavailableException when the bus is unreachable",
      () async {
        // The ladder catches this and tries the next rung; returning
        // null would stop the ladder and silently drop the lookup.
        final bus = _FakeAtSpiBus();
        bus.fail(_registry, _rootPath, _accessible, "GetChildren");
        final provider = AtSpiSelectionProvider(busFactory: () async => bus);

        await expectLater(
          provider.getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        expect(bus.closed, isTrue);
      },
    );

    test(
      "throws SelectionUnavailableException when the bus cannot be reached",
      () async {
        final provider = AtSpiSelectionProvider(
          busFactory: () async =>
              throw const SocketException("No such file or directory"),
        );

        await expectLater(
          provider.getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
      },
    );

    test("throws SelectionUnavailableException when the selection text cannot be read", () async {
      final bus = _FakeAtSpiBus();
      _scriptTree(bus);
      _scriptSelection(bus, text: "hello");
      bus.fail(_appBus, _textPath, _text, "GetText");
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      await expectLater(
        provider.getSelectedText(),
        throwsA(isA<SelectionUnavailableException>()),
      );
    });

    test(
      "tries the next focused object when one has no Text interface",
      () async {
        const secondPath = "/app/second";
        final bus = _FakeAtSpiBus();
        bus.reply(_registry, _rootPath, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)"), [_ref(_appBus, _appRoot)]),
        ]);
        bus.reply(_appBus, _appRoot, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)"), [
            _ref(_appBus, _textPath),
            _ref(_appBus, secondPath),
          ]),
        ]);
        for (final path in [_textPath, secondPath]) {
          bus.reply(_appBus, path, _accessible, "GetChildren", [
            DBusArray(DBusSignature("(so)")),
          ]);
          bus.reply(_appBus, path, _accessible, "GetState", [
            DBusArray(DBusSignature("u"), [const DBusUint32(12)]),
          ]);
          bus.reply(_appBus, path, _accessible, "GetRole", [
            DBusUint32(_roleText),
          ]);
        }
        bus.reply(_appBus, _appRoot, _accessible, "GetState", [
          DBusArray(DBusSignature("u")),
        ]);
        bus.fail(_appBus, _textPath, _text, "GetNSelections");
        bus.reply(_appBus, secondPath, _text, "GetNSelections", [
          const DBusInt32(1),
        ]);
        bus.reply(_appBus, secondPath, _text, "GetSelection", [
          const DBusInt32(0),
          const DBusInt32(3),
        ]);
        bus.reply(_appBus, secondPath, _text, "GetText", [
          const DBusString("abc"),
        ]);
        final provider = AtSpiSelectionProvider(busFactory: () async => bus);

        expect(await provider.getSelectedText(), "abc");
      },
    );

    test("refreshAvailability is true when the registry answers", () async {
      final bus = _FakeAtSpiBus();
      bus.reply(
        _registry,
        _registryPath,
        "org.a11y.atspi.Registry",
        "GetRegisteredEvents",
        [DBusArray(DBusSignature("(ss)"))],
      );

      expect(
        await AtSpiSelectionProvider.refreshAvailability(
          busFactory: () async => bus,
        ),
        isTrue,
      );
      expect(AtSpiSelectionProvider.isAvailable, isTrue);
    });

    test(
      "refreshAvailability is false when the registry does not answer",
      () async {
        final bus = _FakeAtSpiBus();
        bus.fail(
          _registry,
          _registryPath,
          "org.a11y.atspi.Registry",
          "GetRegisteredEvents",
        );

        expect(
          await AtSpiSelectionProvider.refreshAvailability(
            busFactory: () async => bus,
          ),
          isFalse,
        );
        expect(AtSpiSelectionProvider.isAvailable, isFalse);
      },
    );

    test(
      "refreshAvailability is false when the bus itself cannot be reached",
      () async {
        // Regression: the connect used to sit outside the try, so a
        // missing session bus threw out of the probe and aborted the
        // whole provider installation at startup, leaving the X11
        // PRIMARY rung uninstalled as well.
        expect(
          await AtSpiSelectionProvider.refreshAvailability(
            busFactory: () async =>
                throw const SocketException("No such file or directory"),
          ),
          isFalse,
        );
        expect(AtSpiSelectionProvider.isAvailable, isFalse);
      },
    );

    test("re-probes lazily when the registry appears after startup", () async {
      final bus = _FakeAtSpiBus();
      bus.fail(_registry, _rootPath, _accessible, "GetChildren");
      bus.fail(
        _registry,
        _registryPath,
        "org.a11y.atspi.Registry",
        "GetRegisteredEvents",
      );
      final oldInterval = AtSpiSelectionProvider.probeRetryInterval;
      AtSpiSelectionProvider.probeRetryInterval = Duration.zero;
      addTearDown(() {
        AtSpiSelectionProvider.probeRetryInterval = oldInterval;
      });
      final provider = AtSpiSelectionProvider(busFactory: () async => bus);

      await expectLater(
        provider.getSelectedText(),
        throwsA(isA<SelectionUnavailableException>()),
      );
      expect(AtSpiSelectionProvider.isAvailable, isFalse);

      // The registry comes up: the tree answers and the probe succeeds.
      bus.unfail(_registry, _rootPath, _accessible, "GetChildren");
      bus.unfail(
        _registry,
        _registryPath,
        "org.a11y.atspi.Registry",
        "GetRegisteredEvents",
      );
      bus.reply(
        _registry,
        _registryPath,
        "org.a11y.atspi.Registry",
        "GetRegisteredEvents",
        [DBusArray(DBusSignature("(ss)"))],
      );
      _scriptTree(bus);
      _scriptSelection(bus);

      expect(await provider.getSelectedText(), "hello");
      expect(AtSpiSelectionProvider.isAvailable, isTrue);
    });

    test(
      "does not re-probe on every acquire while the registry is down",
      () async {
        final bus = _FakeAtSpiBus();
        bus.fail(_registry, _rootPath, _accessible, "GetChildren");
        bus.fail(
          _registry,
          _registryPath,
          "org.a11y.atspi.Registry",
          "GetRegisteredEvents",
        );
        final provider = AtSpiSelectionProvider(busFactory: () async => bus);

        await expectLater(
          provider.getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        await expectLater(
          provider.getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
        expect(
          bus.callCount("org.a11y.atspi.Registry", "GetRegisteredEvents"),
          1,
        );
      },
    );
  });

  group("AtSpiClient.findFocusedObjects caps", () {
    test("stops the walk after 400 visited nodes", () async {
      final bus = _FakeAtSpiBus();
      final children = <DBusValue>[];
      for (var i = 0; i < 500; i++) {
        final path = "/n$i";
        children.add(_ref(_appBus, path));
        bus.reply(_appBus, path, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)")),
        ]);
        bus.reply(_appBus, path, _accessible, "GetState", [
          DBusArray(DBusSignature("u")),
        ]);
      }
      bus.reply(_registry, _rootPath, _accessible, "GetChildren", [
        DBusArray(DBusSignature("(so)"), children),
      ]);

      expect(await AtSpiClient(bus).findFocusedObjects(), isEmpty);
      expect(bus.callCount(_accessible, "GetChildren"), 400);
    });

    test("does not descend past 32 levels", () async {
      final bus = _FakeAtSpiBus();
      var parentPath = _rootPath;
      var parentBus = _registry;
      for (var depth = 1; depth <= 40; depth++) {
        final path = "/d$depth";
        bus.reply(parentBus, parentPath, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)"), [_ref(_appBus, path)]),
        ]);
        bus.reply(_appBus, path, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)")),
        ]);
        bus.reply(_appBus, path, _accessible, "GetState", [
          DBusArray(DBusSignature("u"), [
            if (depth == 40) const DBusUint32(12),
          ]),
        ]);
        parentPath = path;
        parentBus = _appBus;
      }

      expect(await AtSpiClient(bus).findFocusedObjects(), isEmpty);
    });

    test("finds a focused object at depth 31", () async {
      final bus = _FakeAtSpiBus();
      var parentPath = _rootPath;
      var parentBus = _registry;
      for (var depth = 1; depth <= 31; depth++) {
        final path = "/d$depth";
        bus.reply(parentBus, parentPath, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)"), [_ref(_appBus, path)]),
        ]);
        bus.reply(_appBus, path, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)")),
        ]);
        bus.reply(_appBus, path, _accessible, "GetState", [
          DBusArray(DBusSignature("u"), [
            if (depth == 31) const DBusUint32(12),
          ]),
        ]);
        parentPath = path;
        parentBus = _appBus;
      }

      final found = await AtSpiClient(bus).findFocusedObjects();
      expect(found, hasLength(1));
      expect(found.single.path.value, "/d31");
    });

    test("collects at most 4 focused candidates", () async {
      final bus = _FakeAtSpiBus();
      final children = <DBusValue>[];
      for (var i = 0; i < 6; i++) {
        final path = "/c$i";
        children.add(_ref(_appBus, path));
        bus.reply(_appBus, path, _accessible, "GetChildren", [
          DBusArray(DBusSignature("(so)")),
        ]);
        bus.reply(_appBus, path, _accessible, "GetState", [
          DBusArray(DBusSignature("u"), [const DBusUint32(12)]),
        ]);
      }
      bus.reply(_registry, _rootPath, _accessible, "GetChildren", [
        DBusArray(DBusSignature("(so)"), children),
      ]);

      expect(await AtSpiClient(bus).findFocusedObjects(), hasLength(4));
    });
  });

  group("AtSpiSelectionWatcher", () {
    test(
      "registers the event and emits true, then false when cleared",
      () async {
        final bus = _FakeAtSpiBus();
        _scriptRegistry(bus);
        bus.reply(_appBus, _textPath, _accessible, "GetRole", [
          DBusUint32(_roleText),
        ]);
        bus.reply(_appBus, _textPath, _text, "GetNSelections", [
          const DBusInt32(1),
        ]);
        bus.reply(_appBus, _textPath, _text, "GetSelection", [
          const DBusInt32(0),
          const DBusInt32(3),
        ]);
        final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);
        final emitted = <bool>[];
        watcher.onSelectionChanged.listen(emitted.add);

        await watcher.start();
        final register = bus.calls.singleWhere(
          (call) => call.name == "RegisterEvent",
        );
        expect(register.values[0].asString(), "object:text-selection-changed");
        expect(register.values[1], isA<DBusArray>());
        expect((register.values[1] as DBusArray).children, isEmpty);
        expect(register.values[2].asString(), isEmpty);

        bus.emit(_selectionSignal(_appBus, _textPath));
        await Future<void>.delayed(Duration.zero);
        expect(emitted, [true]);

        bus.reply(_appBus, _textPath, _text, "GetNSelections", [
          const DBusInt32(0),
        ]);
        bus.emit(_selectionSignal(_appBus, _textPath));
        await Future<void>.delayed(Duration.zero);
        expect(emitted, [true, false]);

        await watcher.stop();
        expect(
          bus.called("org.a11y.atspi.Registry", "DeregisterEvent"),
          isTrue,
        );
        // The registry takes exactly one argument: a second argument
        // fails the call (verified against the live registry
        // introspection, at-spi2-registryd 2.52.0).
        final deregister = bus.calls.singleWhere(
          (call) => call.name == "DeregisterEvent",
        );
        expect(deregister.values, [
          const DBusString(atSpiTextSelectionChangedEvent),
        ]);
        expect(bus.closed, isTrue);
      },
    );

    test("does not emit twice for a repeated selection", () async {
      final bus = _FakeAtSpiBus();
      _scriptRegistry(bus);
      bus.reply(_appBus, _textPath, _accessible, "GetRole", [
        DBusUint32(_roleText),
      ]);
      bus.reply(_appBus, _textPath, _text, "GetNSelections", [
        const DBusInt32(1),
      ]);
      bus.reply(_appBus, _textPath, _text, "GetSelection", [
        const DBusInt32(0),
        const DBusInt32(3),
      ]);
      final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);
      final emitted = <bool>[];
      watcher.onSelectionChanged.listen(emitted.add);

      await watcher.start();
      bus.emit(_selectionSignal(_appBus, _textPath));
      bus.emit(_selectionSignal(_appBus, _textPath));
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [true]);

      await watcher.stop();
    });

    test(
      "reports no selection for a password field without reading it",
      () async {
        final bus = _FakeAtSpiBus();
        _scriptRegistry(bus);
        bus.reply(_appBus, _textPath, _accessible, "GetRole", [
          DBusUint32(atSpiRolePasswordText),
        ]);
        final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);
        final emitted = <bool>[];
        watcher.onSelectionChanged.listen(emitted.add);

        await watcher.start();
        bus.emit(_selectionSignal(_appBus, _textPath));
        await Future<void>.delayed(Duration.zero);
        expect(emitted, [false]);
        expect(bus.called(_text, "GetNSelections"), isFalse);
        expect(bus.called(_text, "GetText"), isFalse);

        await watcher.stop();
      },
    );

    test("start and stop are idempotent", () async {
      final bus = _FakeAtSpiBus();
      _scriptRegistry(bus);
      final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);

      await watcher.start();
      await watcher.start();
      expect(bus.callCount("org.a11y.atspi.Registry", "RegisterEvent"), 1);

      await watcher.stop();
      await watcher.stop();
      expect(bus.callCount("org.a11y.atspi.Registry", "DeregisterEvent"), 1);
    });

    test("start never throws when registration fails", () async {
      final bus = _FakeAtSpiBus();
      _scriptRegistry(bus);
      bus.fail(
        _registry,
        _registryPath,
        "org.a11y.atspi.Registry",
        "RegisterEvent",
      );
      final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);

      await watcher.start();
      await watcher.stop();
    });

    test("emits again after stop and start on the same instance", () async {
      final bus = _FakeAtSpiBus();
      _scriptRegistry(bus);
      bus.reply(_appBus, _textPath, _accessible, "GetRole", [
        DBusUint32(_roleText),
      ]);
      bus.reply(_appBus, _textPath, _text, "GetNSelections", [
        const DBusInt32(1),
      ]);
      bus.reply(_appBus, _textPath, _text, "GetSelection", [
        const DBusInt32(0),
        const DBusInt32(3),
      ]);
      final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);
      final emitted = <bool>[];
      watcher.onSelectionChanged.listen(emitted.add);

      await watcher.start();
      bus.emit(_selectionSignal(_appBus, _textPath));
      await Future<void>.delayed(Duration.zero);
      expect(emitted, [true]);

      await watcher.stop();

      // The stream closed on stop, so a restart exposes a fresh one.
      await watcher.start();
      expect(bus.callCount("org.a11y.atspi.Registry", "RegisterEvent"), 2);
      final emittedAfterRestart = <bool>[];
      watcher.onSelectionChanged.listen(emittedAfterRestart.add);
      bus.reply(_appBus, _textPath, _text, "GetNSelections", [
        const DBusInt32(0),
      ]);
      bus.emit(_selectionSignal(_appBus, _textPath));
      await Future<void>.delayed(Duration.zero);
      expect(emittedAfterRestart, [false]);

      await watcher.stop();
    });

    test("handles signals in arrival order, not completion order", () async {
      const slowPath = "/app/slow";
      const fastPath = "/app/fast";
      final bus = _FakeAtSpiBus();
      _scriptRegistry(bus);
      for (final path in [slowPath, fastPath]) {
        bus.reply(_appBus, path, _accessible, "GetRole", [
          DBusUint32(_roleText),
        ]);
      }
      bus.reply(_appBus, slowPath, _text, "GetNSelections", [
        const DBusInt32(1),
      ]);
      bus.reply(_appBus, slowPath, _text, "GetSelection", [
        const DBusInt32(0),
        const DBusInt32(3),
      ]);
      bus.reply(_appBus, fastPath, _text, "GetNSelections", [
        const DBusInt32(0),
      ]);
      // The first signal's lookup is slow; without serialization the
      // second signal would emit first and the stale `true` after it.
      bus.delay(
        _appBus,
        slowPath,
        _accessible,
        "GetRole",
        const Duration(milliseconds: 100),
      );
      final watcher = AtSpiSelectionWatcher(busFactory: () async => bus);
      final emitted = <bool>[];
      watcher.onSelectionChanged.listen(emitted.add);

      await watcher.start();
      bus.emit(_selectionSignal(_appBus, slowPath));
      bus.emit(_selectionSignal(_appBus, fastPath));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(emitted, [true, false]);

      await watcher.stop();
    });
  });
}
