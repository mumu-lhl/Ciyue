/// Resource URLs in dictionary entries are frequently not valid URLs.
///
/// Entries built on Windows often keep a `file://` base (`<img
/// src="file://img/40.jpg">`), which is not an absolute path: URI parsing turns
/// `img` into a host and leaves `/40.jpg` as the path, and the file system
/// never has an `/img` directory. What the dictionary means is `img/40.jpg`
/// inside its own resource archive, so the scheme is noise.
///
/// GoldenDict strips exactly that prefix in `Mdx::srcRe`
/// (`(?:file://)?[\x00-\x1f\x7f]*\.*/?([^">]+)`), which is why those images
/// display there. This script applies the same normalisation in the WebView:
/// `file://img/40.jpg`, `/img/40.jpg` and `./img/40.jpg` all become
/// `img/40.jpg`, a relative path served by `LocalResourcesPathHandler` from the
/// dictionary's `.mdd` or from the directory next to it.
///
/// Absolute URLs (`http(s)`, `data:`, `javascript:`, protocol-relative `//` and
/// any other scheme) are left untouched, as are Windows drive paths
/// (`file:///C:/...`), which do not point inside the dictionary.
const resourceUrlScript = r"""
(function () {
  var FILE_PREFIX = /^file:(\/\/)?/i;
  var ANY_SCHEME = /^[a-z][a-z0-9+.\-]*:/i;

  function dictionaryPath(value) {
    if (!value) return null;
    var raw = String(value).trim();
    if (!raw) return null;
    // Protocol-relative and every scheme except `file:` are other resources.
    if (/^\/\//.test(raw)) return null;
    if (ANY_SCHEME.test(raw) && !FILE_PREFIX.test(raw)) return null;

    var path = raw.replace(FILE_PREFIX, '');
    path = path.replace(/^[\x00-\x1f\x7f]+/, '');
    path = path.replace(/\\/g, '/').replace(/\/{2,}/g, '/');
    // file:///C:/dict/img.png and /home/user/img.png live outside the
    // dictionary; leave them alone instead of looking up a bogus resource.
    if (/^\/?[a-z]:\//i.test(path)) return null;
    path = path.replace(/^(?:\.\/)+/, '').replace(/^\/+/, '');
    if (!path || path === raw) return null;
    return path;
  }

  var ATTRIBUTES = {
    img: ['src'],
    script: ['src'],
    link: ['href'],
    source: ['src'],
    audio: ['src'],
    video: ['src', 'poster'],
    object: ['data'],
    embed: ['src'],
    track: ['src'],
    iframe: ['src'],
    input: ['src'],
  };

  function fixSrcset(value) {
    var chunks = String(value).split(',');
    var changed = false;
    for (var i = 0; i < chunks.length; i++) {
      var chunk = chunks[i].trim();
      if (!chunk) continue;
      var split = chunk.search(/\s/);
      var url = split < 0 ? chunk : chunk.slice(0, split);
      var descriptor = split < 0 ? '' : chunk.slice(split);
      var fixed = dictionaryPath(url);
      if (fixed !== null) {
        chunks[i] = fixed + descriptor;
        changed = true;
      } else {
        chunks[i] = chunk;
      }
    }
    return changed ? chunks.join(', ') : null;
  }

  function fixElement(element) {
    if (!element || element.nodeType !== 1) return;
    var tag = (element.tagName || '').toLowerCase();
    var attributes = ATTRIBUTES[tag];
    if (attributes) {
      for (var i = 0; i < attributes.length; i++) {
        var name = attributes[i];
        if (!element.hasAttribute(name)) continue;
        var fixed = dictionaryPath(element.getAttribute(name));
        if (fixed !== null) element.setAttribute(name, fixed);
      }
      if ((tag === 'img' || tag === 'source') && element.hasAttribute('srcset')) {
        var srcset = fixSrcset(element.getAttribute('srcset'));
        if (srcset !== null) element.setAttribute('srcset', srcset);
      }
    }
    if (tag === 'image') {
      // Inline SVG <image> keeps its reference in href/xlink:href.
      var hasHref = element.hasAttribute('href');
      var href = element.getAttribute(hasHref ? 'href' : 'xlink:href');
      var fixedHref = dictionaryPath(href);
      if (fixedHref !== null) {
        element.setAttribute(hasHref ? 'href' : 'xlink:href', fixedHref);
      }
    }
  }

  function fixTree(root) {
    if (!root || root.nodeType !== 1) return;
    fixElement(root);
    if (!root.querySelectorAll) return;
    var children = root.querySelectorAll(
      'img,script,link,source,audio,video,object,embed,track,iframe,input,image'
    );
    for (var i = 0; i < children.length; i++) fixElement(children[i]);
  }

  // Fix elements as the parser inserts them, which is normally before the
  // browser commits to fetching them.
  var observer = new MutationObserver(function (records) {
    for (var i = 0; i < records.length; i++) {
      var added = records[i].addedNodes;
      for (var j = 0; j < added.length; j++) fixTree(added[j]);
    }
  });
  observer.observe(document, { childList: true, subtree: true });

  document.addEventListener('DOMContentLoaded', function () {
    fixTree(document.documentElement);
  });

  // A request may already be in flight when the observer runs. Retry once on
  // failure instead of leaving a broken image behind.
  document.addEventListener('error', function (event) {
    var element = event.target;
    if (!element || !element.getAttribute) return;
    var attributes = ATTRIBUTES[(element.tagName || '').toLowerCase()];
    if (!attributes) return;
    for (var i = 0; i < attributes.length; i++) {
      var value = element.getAttribute(attributes[i]);
      if (!value || !FILE_PREFIX.test(value)) continue;
      var fixed = dictionaryPath(value);
      if (fixed !== null) element.setAttribute(attributes[i], fixed);
    }
  }, true);
})();
""";
