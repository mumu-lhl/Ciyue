import "package:ciyue/core/providers.dart";
import "package:ciyue/services/full_text_search_service.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _SpyFullTextSearchService extends FullTextSearchService {
  Set<int>? cancelledExcept;

  _SpyFullTextSearchService()
    : super(dictionaries: () => [], knownIds: () async => {});

  @override
  void cancelBuildsExcept(Set<int> keepIds) {
    cancelledExcept = keepIds;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("selecting the current dictionary group does not reload it", () async {
    final model = DictManagerModel();
    addTearDown(model.dispose);
    var notifications = 0;
    model.addListener(() => notifications++);

    await model.setCurrentGroup(model.groupId);

    expect(model.isSwitchingGroup, isFalse);
    expect(model.pendingGroupId, isNull);
    expect(notifications, 0);
  });

  test("group switch cancels FTS builds outside the new group", () {
    // The provider wires DictManagerModel.onGroupSwitched to the full-text
    // service's cancelBuildsExcept (P1-6): dictionaries that left the group
    // stop building their indexes instead of copying the whole dictionary
    // into the build isolate. The service behaviour itself is covered by
    // the cancelBuildsExcept test in full_text_search_service_test.dart;
    // this test pins the wiring between the two.
    final spy = _SpyFullTextSearchService();
    final container = ProviderContainer(
      overrides: [fullTextSearchServiceProvider.overrideWith((ref) => spy)],
    );
    addTearDown(container.dispose);

    final model = container.read(dictManagerModelProvider);

    expect(model.onGroupSwitched, isNotNull);
    model.onGroupSwitched!({3, 4});
    expect(spy.cancelledExcept, {3, 4});
  });
}
