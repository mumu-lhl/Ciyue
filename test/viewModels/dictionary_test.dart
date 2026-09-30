import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_test/flutter_test.dart";

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
}
