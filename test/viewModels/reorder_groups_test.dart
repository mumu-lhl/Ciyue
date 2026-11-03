import "package:ciyue/database/app/app.dart";
import "package:ciyue/viewModels/dictionary.dart";
import "package:flutter_test/flutter_test.dart";

DictGroupData _group(int id, String name) =>
    DictGroupData(id: id, name: name, dictIds: "", order: id - 1);

void main() {
  final groups = [
    _group(1, "Default"),
    _group(2, "English"),
    _group(3, "Japanese"),
  ];

  test("moves a group down", () {
    final reordered = reorderGroups(groups, 1, 2);

    expect(reordered.map((g) => g.name), ["Default", "Japanese", "English"]);
  });

  test("moves a group up", () {
    final reordered = reorderGroups(groups, 2, 1);

    expect(reordered.map((g) => g.name), ["Default", "Japanese", "English"]);
  });

  test("keeps the default group on top when dropping above it", () {
    final reordered = reorderGroups(groups, 2, 0);

    expect(reordered.map((g) => g.name), ["Default", "Japanese", "English"]);
  });

  test("does not move the default group", () {
    final reordered = reorderGroups(groups, 0, 2);

    expect(identical(reordered, groups), isTrue);
  });

  test("returns the same list when nothing changes", () {
    expect(identical(reorderGroups(groups, 1, 1), groups), isTrue);
    expect(identical(reorderGroups(groups, 3, 1), groups), isTrue);
  });

  test("does not modify the list it is given", () {
    reorderGroups(groups, 1, 2);

    expect(groups.map((g) => g.name), ["Default", "English", "Japanese"]);
  });
}
