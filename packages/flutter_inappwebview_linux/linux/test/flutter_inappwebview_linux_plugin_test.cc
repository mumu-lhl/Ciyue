#include <gtest/gtest.h>

#include "in_app_webview/in_app_webview.h"
#include "in_app_webview/inappwebview_egl_texture.h"

namespace flutter_inappwebview_plugin {
namespace test {

TEST(InAppWebViewPointerEvents, CancelReleasesPressedButton) {
  using flutter_inappwebview_plugin::GetWpePointerButtonAction;
  using flutter_inappwebview_plugin::WpePointerButtonAction;
  using flutter_inappwebview_plugin::WpePointerEventKind;

  EXPECT_EQ(GetWpePointerButtonAction(WpePointerEventKind::Down),
            WpePointerButtonAction::Press);
  EXPECT_EQ(GetWpePointerButtonAction(WpePointerEventKind::Up),
            WpePointerButtonAction::Release);
  EXPECT_EQ(GetWpePointerButtonAction(WpePointerEventKind::Cancel),
            WpePointerButtonAction::Release);
  EXPECT_EQ(GetWpePointerButtonAction(WpePointerEventKind::Leave),
            WpePointerButtonAction::Ignore);
}

TEST(InAppWebViewEGLTexture, DisposeCanBeRunMoreThanOnce) {
  InAppWebViewEGLTexture* texture = inappwebview_egl_texture_new(nullptr);
  ASSERT_NE(texture, nullptr);

  g_object_run_dispose(G_OBJECT(texture));
  g_object_run_dispose(G_OBJECT(texture));
  g_object_unref(texture);
}

}  // namespace test
}  // namespace flutter_inappwebview_plugin
