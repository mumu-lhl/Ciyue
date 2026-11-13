/// Runs the e-ink paging inside a dictionary page.
///
/// The script is injected into every entry and stays inert until
/// `window.ciyueSetPaging(true)` is called, so the mode can be switched on
/// while a page is already open instead of rebuilding the WebView (which
/// would blank the entry for a frame).
///
/// It exposes:
/// * `window.ciyueSetPaging(bool)` — turns the mode and the scroll reporting
///   on or off;
/// * `window.ciyuePageBy(screens)` — moves the page by 90% of a viewport and
///   returns a JSON payload with the new boundary state;
/// * `window.ciyueReportPageState()` — reports the state once, which the app
///   calls after loading so the buttons start out right.
///
/// The boundary state is posted through the `ciyuePageState` handler, and
/// only when it actually changes: scrolling must not talk to Dart.
String pagingScript() => r"""
(function () {
  window.ciyuePagingEnabled = false;
  window.ciyuePagingBounds = null;

  function scroller() {
    return document.scrollingElement || document.documentElement;
  }

  function scrollTop() {
    var el = scroller();
    return window.scrollY || (el && el.scrollTop) || 0;
  }

  function pageBounds() {
    var el = scroller();
    var view = window.innerHeight || 0;
    var total = el ? el.scrollHeight : 0;
    var max = total - view;
    var top = scrollTop();
    return {
      atStart: top <= 1,
      atEnd: max <= 1 || top >= max - 1
    };
  }

  function post(state) {
    if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
      window.flutter_inappwebview.callHandler(
        'ciyuePageState',
        JSON.stringify(state)
      );
    }
  }

  function report(force) {
    var state = pageBounds();
    var last = window.ciyuePagingBounds;
    if (!force && last &&
        last.atStart === state.atStart && last.atEnd === state.atEnd) {
      return;
    }
    window.ciyuePagingBounds = state;
    post(state);
  }

  var scheduled = false;
  function onScroll() {
    if (!window.ciyuePagingEnabled || scheduled) return;
    scheduled = true;
    var run = function () {
      scheduled = false;
      report(false);
    };
    if (window.requestAnimationFrame) {
      window.requestAnimationFrame(run);
    } else {
      setTimeout(run, 16);
    }
  }

  function listen(add) {
    var method = add ? 'addEventListener' : 'removeEventListener';
    var options = { passive: true, capture: true };
    document[method]('scroll', onScroll, options);
    window[method]('scroll', onScroll, options);
  }

  window.ciyueReportPageState = function () {
    report(true);
  };

  window.ciyueSetPaging = function (enabled) {
    enabled = !!enabled;
    if (window.ciyuePagingEnabled === enabled) {
      if (enabled) report(true);
      return;
    }
    window.ciyuePagingEnabled = enabled;
    window.ciyuePagingBounds = null;
    if (enabled) {
      listen(true);
      report(true);
    } else {
      listen(false);
    }
  };

  window.ciyuePageBy = function (screens) {
    var view = window.innerHeight || 0;
    var step = Math.round(view * 0.9) * (screens < 0 ? -1 : 1);
    var before = scrollTop();
    // The positional form is deliberate: the options object needs an engine
    // that understands `behavior`, while scrollBy(0, n) is an instant jump
    // everywhere.
    window.scrollBy(0, step);
    var after = scrollTop();
    var state = pageBounds();
    window.ciyuePagingBounds = state;
    post(state);
    return JSON.stringify({
      moved: Math.abs(after - before) >= 1,
      atStart: state.atStart,
      atEnd: state.atEnd
    });
  };
})();
""";
