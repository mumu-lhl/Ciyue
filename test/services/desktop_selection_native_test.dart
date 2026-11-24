import "package:ciyue/services/desktop_selection_native.dart";
import "package:ciyue/services/selection_text_provider.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(NativeSelection.channelName);

  // The fake native side behind the `ciyue/selection` channel.
  Object? Function(MethodCall call)? nextHandler;
  var handlerCalls = 0;
  String? lastMethod;

  // The real platform check is false on the Linux test host, so tests stub
  // it to drive the channel path; the default is restored afterwards.
  final defaultPlatformCheck = NativeSelection.platformCheck;

  setUp(() {
    handlerCalls = 0;
    lastMethod = null;
    nextHandler = null;
    NativeSelection.platformCheck = () => true;
    messenger.setMockMethodCallHandler(channel, (call) async {
      handlerCalls++;
      lastMethod = call.method;
      return nextHandler?.call(call);
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    NativeSelection.platformCheck = defaultPlatformCheck;
  });

  group("NativeSelection.isAvailable", () {
    test("follows the platform check", () {
      NativeSelection.platformCheck = () => true;
      expect(NativeSelection.isAvailable, isTrue);

      NativeSelection.platformCheck = () => false;
      expect(NativeSelection.isAvailable, isFalse);
    });
  });

  group("NativeSelectionProvider", () {
    const provider = NativeSelectionProvider();

    test("returns the channel text trimmed", () async {
      nextHandler = (_) => "  hello  ";

      expect(await provider.getSelectedText(), "hello");
      expect(handlerCalls, 1);
      expect(lastMethod, "getSelectedText");
    });

    test("returns null when the channel returns null", () async {
      nextHandler = (_) => null;

      expect(await provider.getSelectedText(), isNull);
      expect(lastMethod, "getSelectedText");
    });

    test("returns null when the channel returns only whitespace", () async {
      nextHandler = (_) => "   ";

      expect(await provider.getSelectedText(), isNull);
    });

    test("reports the rung unavailable when the channel fails", () async {
      nextHandler = (_) => throw PlatformException(code: "SELECTION_ERROR");

      await expectLater(
        provider.getSelectedText(),
        throwsA(isA<SelectionUnavailableException>()),
      );
      expect(lastMethod, "getSelectedText");
    });

    test(
      "reports the rung unavailable when the native side is missing",
      () async {
        messenger.setMockMethodCallHandler(channel, null);

        await expectLater(
          provider.getSelectedText(),
          throwsA(isA<SelectionUnavailableException>()),
        );
      },
    );

    test("reports the rung unavailable without touching the channel when the platform is unsupported", () async {
      NativeSelection.platformCheck = () => false;
      nextHandler = (_) => throw TestFailure("channel must not be called");

      await expectLater(
        provider.getSelectedText(),
        throwsA(isA<SelectionUnavailableException>()),
      );
      expect(handlerCalls, 0);
    });
  });

  group("NativeCopyKeySender", () {
    const sender = NativeCopyKeySender();

    test("returns the channel result", () async {
      nextHandler = (_) => true;

      expect(await sender.sendCopy(), isTrue);
      expect(handlerCalls, 1);
      expect(lastMethod, "sendCopy");
    });

    test("returns false when the channel reports failure", () async {
      nextHandler = (_) => false;

      expect(await sender.sendCopy(), isFalse);
      expect(lastMethod, "sendCopy");
    });

    test("returns false instead of throwing when the channel fails", () async {
      nextHandler = (_) => throw PlatformException(code: "SEND_COPY_ERROR");

      expect(await sender.sendCopy(), isFalse);
    });

    test("returns false when the native side is missing", () async {
      messenger.setMockMethodCallHandler(channel, null);

      expect(await sender.sendCopy(), isFalse);
    });

    test(
      "never touches the channel when the platform is unsupported",
      () async {
        NativeSelection.platformCheck = () => false;
        nextHandler = (_) => throw TestFailure("channel must not be called");

        expect(await sender.sendCopy(), isFalse);
        expect(handlerCalls, 0);
      },
    );
  });

  group("NativeFocusedAppResolver", () {
    const resolver = NativeFocusedAppResolver();

    test("returns the channel id trimmed", () async {
      nextHandler = (_) => "  com.example.app  ";

      expect(await resolver.getFocusedAppId(), "com.example.app");
      expect(handlerCalls, 1);
      expect(lastMethod, "getFocusedAppId");
    });

    test("returns null when the channel returns null", () async {
      nextHandler = (_) => null;

      expect(await resolver.getFocusedAppId(), isNull);
      expect(lastMethod, "getFocusedAppId");
    });

    test("returns null when the channel returns only whitespace", () async {
      nextHandler = (_) => "   ";

      expect(await resolver.getFocusedAppId(), isNull);
    });

    test("returns null instead of throwing when the channel fails", () async {
      nextHandler = (_) => throw PlatformException(code: "APP_ID_ERROR");

      expect(await resolver.getFocusedAppId(), isNull);
    });

    test(
      "never touches the channel when the platform is unsupported",
      () async {
        NativeSelection.platformCheck = () => false;
        nextHandler = (_) => throw TestFailure("channel must not be called");

        expect(await resolver.getFocusedAppId(), isNull);
        expect(handlerCalls, 0);
      },
    );
  });
}
