#include <gtest/gtest.h>

#include "in_app_webview/inappwebview_egl_texture.h"

namespace flutter_inappwebview_plugin {
namespace test {

TEST(InAppWebViewEGLTexture, DisposeCanBeRunMoreThanOnce) {
  InAppWebViewEGLTexture* texture = inappwebview_egl_texture_new(nullptr);
  ASSERT_NE(texture, nullptr);

  g_object_run_dispose(G_OBJECT(texture));
  g_object_run_dispose(G_OBJECT(texture));
  g_object_unref(texture);
}

}  // namespace test
}  // namespace flutter_inappwebview_plugin
