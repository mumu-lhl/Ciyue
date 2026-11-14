import "package:ciyue/ui/core/word_display/paging_script.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("the paging script starts inert", () {
    final script = pagingScript();
    expect(script, contains("window.ciyuePagingEnabled = false"));
    expect(script, contains("window.ciyueSetPaging = function"));
  });

  test("one page is 90% of the viewport", () {
    final script = pagingScript();
    expect(script, contains("window.innerHeight"));
    // The positional form is what makes the jump instant on every engine.
    expect(script, contains("Math.round(view * 0.9)"));
    expect(script, contains("window.scrollBy(0, step)"));
    expect(script, isNot(contains("behavior:")));
  });

  test("the script reports the boundary state it ends on", () {
    final script = pagingScript();
    expect(script, contains("atStart: top <= 1"));
    expect(script, contains("atEnd: max <= 1 || top >= max - 1"));
    expect(script, contains("moved: Math.abs(after - before) >= 1"));
  });

  test("scrolling only talks to Dart when the state changes", () {
    final script = pagingScript();
    expect(script, contains("ciyuePageState"));
    expect(script, contains("last.atStart === state.atStart"));
    expect(script, contains("requestAnimationFrame"));
    expect(script, contains("{ passive: true, capture: true }"));
  });

  test("a freshly loaded page can be asked for its state", () {
    expect(pagingScript(), contains("window.ciyueReportPageState = function"));
  });
}
