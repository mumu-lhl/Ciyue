// Single source of truth for how WebView frames reach Flutter.
//
// Three parties have to agree on one mode:
//
//   host texture      FlTextureGL          vs  FlPixelBufferTexture
//   WPE exportable    wpe_fdo_initialize_for_egl_display()  vs  wpe_fdo_initialize_shm()
//   WebProcess        DMA-BUF frames      vs  SHM frames
//
// They are chosen by different libraries with no shared state, so they used to
// be kept in sync by every call site reading the same environment variable.
// That worked only as long as all call sites agreed; a single missing check
// produced a WebView that received no frame at all (blank view, live DOM, text
// still selectable). ResolveRenderingMode() now decides once, and every call
// site derives from it instead of re-reading the environment.

#ifndef FLUTTER_INAPPWEBVIEW_LINUX_UTILS_SOFTWARE_RENDERING_H_
#define FLUTTER_INAPPWEBVIEW_LINUX_UTILS_SOFTWARE_RENDERING_H_

namespace flutter_inappwebview_plugin {

enum class RenderingMode {
  // Host: FlTextureGL, zero-copy. WPE exports DMA-BUF EGLImages.
  kHardwareEgl,
  // Host: FlPixelBufferTexture, CPU copy. WPE exports SHM buffers.
  kSoftwareShm,
};

// Resolve the rendering mode exactly once per process and reconcile the
// environment variables read by WebKit's WebProcess, which inherits them at
// spawn time. Thread-safe; later calls return the cached value.
//
// Must run before the first WebView is created and before the WebProcess
// starts, otherwise the WebProcess may have inherited a different mode.
//
// Inputs, in priority order:
//   - FLUTTER_INAPPWEBVIEW_SKIP_DMABUF_CHECK=1 : force hardware, skip detection
//   - FLUTTER_INAPPWEBVIEW_LINUX_DISABLE_GL    : (presence) force software
//   - WEBKIT_DISABLE_DMABUF_RENDERER           : (presence) force software; set
//     by the launcher when no DRM device exists, so the host has to match
//   - LIBGL_ALWAYS_SOFTWARE=1                  : honoured, never set here
//   - no accessible DRM node                   : software
//   - known good GPU driver                    : hardware
//   - virtual machine / problematic driver     : software
//   - otherwise                                : hardware
//
// LIBGL_ALWAYS_SOFTWARE is never set by this code: it is a process-wide Mesa
// switch that also pushes Flutter's own GL backend onto llvmpipe, which can
// blank the whole window.
RenderingMode ResolveRenderingMode();

// True when the host uses FlPixelBufferTexture and the WebProcess must export
// SHM buffers. Equivalent to ResolveRenderingMode() == kSoftwareShm.
inline bool UsesSoftwareRendering() {
  return ResolveRenderingMode() == RenderingMode::kSoftwareShm;
}

// Applies the resolved mode's environment. Kept as the plugin-registration
// entry point: calling it early pins the decision before any WebView exists.
// Returns true when software/SHM rendering is in effect.
bool ApplySoftwareRenderingIfNeeded();

// Records that the hardware path produced no frame within the watchdog window.
//
// A heuristic can guess wrong on a GPU it considers "known good", and the
// result is a blank WebView with a live DOM. Writing a marker turns that into
// a one-time failure: the next start reads it and switches to software, so the
// machine heals itself instead of rendering blank again.
//
// The marker expires after a week, and forcing hardware clears it. Both exist
// so a single slow start -- a large dictionary, a cold page load -- cannot pin
// the process to software permanently.
void RecordRenderingFailure();

// True when an unexpired failure marker exists. Internal to the mode decision;
// exposed for tests and for the watchdog's own "already recorded" check.
bool HasRecentRenderingFailure();

// Removes the marker, so the next start tries hardware again.
void ClearRenderingFailure();

}  // namespace flutter_inappwebview_plugin

#endif  // FLUTTER_INAPPWEBVIEW_LINUX_UTILS_SOFTWARE_RENDERING_H_
