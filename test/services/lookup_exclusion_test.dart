import "package:ciyue/services/lookup_exclusion.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("LookupExclusionService.isExcluded", () {
    test("never excludes a null or blank app id", () {
      expect(LookupExclusionService.isExcluded(null, ["firefox"]), isFalse);
      expect(LookupExclusionService.isExcluded("", ["firefox"]), isFalse);
      expect(LookupExclusionService.isExcluded("   ", ["firefox"]), isFalse);
    });

    test("never excludes when the list is empty", () {
      expect(LookupExclusionService.isExcluded("firefox", []), isFalse);
    });

    test("matches an exactly equal pattern", () {
      expect(LookupExclusionService.isExcluded("firefox", ["firefox"]), isTrue);
    });

    test("matches case-insensitively", () {
      expect(LookupExclusionService.isExcluded("Firefox", ["firefox"]), isTrue);
      expect(LookupExclusionService.isExcluded("firefox", ["FIREFOX"]), isTrue);
    });

    test("matches when the pattern is contained in the id", () {
      expect(
        LookupExclusionService.isExcluded("org.mozilla.firefox", ["firefox"]),
        isTrue,
      );
      expect(
        LookupExclusionService.isExcluded("com.google.Chrome", ["chrome"]),
        isTrue,
      );
    });

    test("does not match when the id is contained in the pattern", () {
      expect(LookupExclusionService.isExcluded("fire", ["firefox"]), isFalse);
    });

    test("ignores blank patterns", () {
      expect(
        LookupExclusionService.isExcluded("firefox", ["", "   "]),
        isFalse,
      );
    });

    test("trims patterns before matching", () {
      expect(
        LookupExclusionService.isExcluded("firefox", ["  firefox  "]),
        isTrue,
      );
    });

    test("matches when any pattern matches", () {
      expect(
        LookupExclusionService.isExcluded("code", ["firefox", "code"]),
        isTrue,
      );
      expect(
        LookupExclusionService.isExcluded("slack", ["firefox", "code"]),
        isFalse,
      );
    });
  });

  group("LookupExclusionService.isOwnApp", () {
    test("recognises Ciyue ids", () {
      expect(LookupExclusionService.isOwnApp("ciyue"), isTrue);
      expect(LookupExclusionService.isOwnApp("Ciyue"), isTrue);
      expect(LookupExclusionService.isOwnApp("com.mumulhl.ciyue"), isTrue);
      expect(LookupExclusionService.isOwnApp("org.ciyue.Ciyue"), isTrue);
    });

    test("rejects other apps and unknown ids", () {
      expect(LookupExclusionService.isOwnApp("firefox"), isFalse);
      expect(LookupExclusionService.isOwnApp(null), isFalse);
      expect(LookupExclusionService.isOwnApp(""), isFalse);
    });
  });
}
