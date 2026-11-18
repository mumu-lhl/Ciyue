#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_FRAME_TRACE_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_FRAME_TRACE_H_

#include <glib.h>

#include <cstdint>
#include <string>

#include "log.h"

namespace flutter_inappwebview_plugin {

// Opt-in tracing for the zero-copy DMA-BUF frame path.
//
// Set FLUTTER_INAPPWEBVIEW_LINUX_TRACE_FRAMES=1 to turn it on; anything else
// (including "0") leaves it off and every function below returns before it
// builds a string, so shipped builds pay one branch per call site.
//
// The four events are enough to reconstruct why a frame looked wrong on screen:
//
//   export   WPE handed us an exported image (a buffer it wants us to show)
//   bind     the raster thread bound that image into Flutter's GL texture
//   present  the frame was presented; this is where buffers get retired
//   release  retired buffers went back to WPE
//
// A tearing report usually comes down to one of two broken invariants, both of
// which are reported as FRAME ANOMALY lines:
//
//   * WPE re-exported the image Flutter is still sampling. That means the
//     buffer was returned too early, and the next frame is painted into pixels
//     the compositor is reading.
//   * The presented image is not the newest export. That means the bookkeeping
//     is a frame behind, so a buffer can be retired while it is still bound.
//
// Tracing is diagnostic only: it never changes what gets released or when.
inline bool frameTraceEnabled() {
  static const bool enabled = [] {
    const char* value = g_getenv("FLUTTER_INAPPWEBVIEW_LINUX_TRACE_FRAMES");
    return value != nullptr && *value != '\0' && g_strcmp0(value, "0") != 0;
  }();
  return enabled;
}

inline std::string frameTracePtr(const void* pointer) {
  char buffer[32];
  g_snprintf(buffer, sizeof(buffer), "0x%" G_GINT64_MODIFIER "x",
             static_cast<guint64>(reinterpret_cast<uintptr_t>(pointer)));
  return std::string(buffer);
}

inline std::string frameTraceTime() {
  // Microseconds since boot: correlates with the GLib/WPE side of a log.
  return "t=" + std::to_string(g_get_monotonic_time() / 1000) + "ms";
}

inline void frameTraceExport(const void* image, const void* egl_image, uint32_t width,
                             uint32_t height) {
  if (!frameTraceEnabled()) {
    return;
  }
  static uint64_t sequence = 0;
  infoLog("FRAME export #" + std::to_string(++sequence) + " " + frameTraceTime() + " image=" +
          frameTracePtr(image) + " egl=" + frameTracePtr(egl_image) +
          " size=" + std::to_string(width) + "x" + std::to_string(height));
}

inline void frameTraceBind(const void* egl_image, uint32_t width, uint32_t height) {
  if (!frameTraceEnabled()) {
    return;
  }
  static uint64_t sequence = 0;
  infoLog("FRAME bind #" + std::to_string(++sequence) + " " + frameTraceTime() +
          " egl=" + frameTracePtr(egl_image) + " size=" + std::to_string(width) + "x" +
          std::to_string(height));
}

inline void frameTracePresent(const void* egl_image, const void* exported_image,
                              const void* displayed_image) {
  if (!frameTraceEnabled()) {
    return;
  }
  static uint64_t sequence = 0;
  infoLog("FRAME present #" + std::to_string(++sequence) + " " + frameTraceTime() +
          " egl=" + frameTracePtr(egl_image) + " exported=" + frameTracePtr(exported_image) +
          " displayed=" + frameTracePtr(displayed_image));
}

inline void frameTraceRelease(size_t retired, bool frame_complete, const void* const* images,
                              size_t image_count) {
  if (!frameTraceEnabled()) {
    return;
  }
  static uint64_t sequence = 0;
  std::string released;
  for (size_t i = 0; i < image_count; ++i) {
    if (i != 0) {
      released += ",";
    }
    released += frameTracePtr(images[i]);
  }
  infoLog("FRAME release #" + std::to_string(++sequence) + " " + frameTraceTime() +
          " retired=" + std::to_string(retired) +
          " frame_complete=" + (frame_complete ? "1" : "0") +
          (released.empty() ? "" : " images=" + released));
}

// Reports a broken buffer-lifetime invariant. Rate limited: the first few
// occurrences and then every hundredth, so a burst cannot drown the log.
inline void frameTraceAnomaly(const char* what, const void* first, const void* second,
                              const void* third) {
  if (!frameTraceEnabled()) {
    return;
  }
  static int64_t occurrences = 0;
  ++occurrences;
  if (occurrences > 5 && (occurrences % 100) != 0) {
    return;
  }
  errorLog(std::string("FRAME ANOMALY ") + what + " a=" + frameTracePtr(first) +
           " b=" + frameTracePtr(second) + " c=" + frameTracePtr(third) +
           " count=" + std::to_string(occurrences));
}

}  // namespace flutter_inappwebview_plugin

#endif  // FLUTTER_INAPPWEBVIEW_PLUGIN_FRAME_TRACE_H_
