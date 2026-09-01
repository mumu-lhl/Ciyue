import "package:ciyue/core/app_router.dart";
import "package:ciyue/services/platform.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("process text navigation works before the router is mounted", () {
    expect(() => navigateToProcessText("hello world"), returnsNormally);
    expect(
      router.routeInformationProvider.value.uri,
      Uri.parse("/word/hello%20world"),
    );
  });
}
