import "package:ciyue/core/providers.dart";
import "package:ciyue/repositories/dictionary.dart";
import "package:test/test.dart";

class _SlowLoadingDict extends Mdict {
  _SlowLoadingDict() : super(path: "unused");

  var waited = false;

  @override
  bool get isReady => true;

  @override
  Future<void> waitForLoading() async {
    await Future.delayed(const Duration(milliseconds: 100));
    waited = true;
  }
}

void main() {
  setUp(() {
    dictManager.dicts.clear();
    dictManager.dictIds = [];
    dictManager.markLoaded();
  });

  tearDown(() {
    dictManager.dicts.clear();
    dictManager.dictIds = [];
  });

  test("concurrent callers share one wait", () async {
    dictManager.dictIds = [1];
    dictManager.dicts[1] = _SlowLoadingDict();

    final first = dictionariesReady();
    final second = dictionariesReady();

    expect(identical(first, second), isTrue);
    await first;
    expect((dictManager.dicts[1] as _SlowLoadingDict).waited, isTrue);
  });

  test("swapping the dictionary instance starts a fresh wait", () async {
    dictManager.dictIds = [1];
    dictManager.dicts[1] = _SlowLoadingDict();

    final before = dictionariesReady();
    await before;

    // Same id, new instance (a group switch re-adds the dictionary): the
    // old group's "ready" must not be reused for the new group.
    dictManager.dicts[1] = _SlowLoadingDict();
    final after = dictionariesReady();

    expect(identical(after, before), isFalse);
    await after;
    expect((dictManager.dicts[1] as _SlowLoadingDict).waited, isTrue);
  });

  test("no dictionaries means nothing to wait for", () async {
    await dictionariesReady();
  });
}
