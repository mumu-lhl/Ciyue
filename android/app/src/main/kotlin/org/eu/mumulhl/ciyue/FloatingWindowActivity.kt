package org.eu.mumulhl.ciyue

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import java.lang.ref.WeakReference

class FloatingWindowActivity : FlutterActivity() {
    companion object {
        private var activityReference: WeakReference<FloatingWindowActivity>? = null
        private var secureFlag = false

        fun setSecureFlag(secure: Boolean) {
            secureFlag = secure
            activityReference?.get()?.let { activity ->
                activity.runOnUiThread { activity.applySecureFlag() }
            }
        }

        fun dismissCurrent() {
            activityReference?.get()?.let { activity ->
                activity.runOnUiThread { activity.dismiss() }
            }
        }
    }

    // Tell FlutterActivity that the engine is cached and owned by the engine
    // holder. This prevents the Activity from treating it as a new engine on
    // every floating-window invocation.
    override fun getCachedEngineId(): String? = FloatingWindowEngine.ENGINE_ID

    // Transparent Flutter activities must use a TextureView. Returning only a
    // transparent composition mode leaves Flutter in the opaque SurfaceView
    // render mode, whose cached surface can stop presenting new frames after
    // this task is hidden and restored.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    private fun applySecureFlag() {
        if (secureFlag) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        FloatingWindowEngine.prepare(
            this,
            intent?.getStringExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW).orEmpty(),
        )
        activityReference = WeakReference(this)
        applySecureFlag()
        super.onCreate(savedInstanceState)

        // Keep the Activity window full-screen so Android's edge-back gesture
        // targets this Activity instead of the window underneath it. The
        // Flutter content is constrained to the visible floating panel in the
        // Dart layout.
        val layoutParams = WindowManager.LayoutParams()
        layoutParams.copyFrom(window.attributes)
        layoutParams.width = WindowManager.LayoutParams.MATCH_PARENT
        layoutParams.height = WindowManager.LayoutParams.MATCH_PARENT
        window.attributes = layoutParams
    }

    private fun keepFlutterViewVisible() {
        findViewById<View>(FLUTTER_VIEW_ID)?.visibility = View.VISIBLE
    }

    override fun onStart() {
        super.onStart()
        keepFlutterViewVisible()
    }

    override fun onStop() {
        super.onStop()

        // FlutterActivity sets FlutterView to GONE here as a workaround for a
        // lock-screen issue on some OnePlus devices. That destroys the
        // TextureView surface while hybrid-composition WebViews survive, so a
        // cached floating engine can return showing only its WebView. The task
        // itself is already hidden; keep the Flutter view and surface alive.
        keepFlutterViewVisible()

        // Keep this Activity attached to the cached engine while the
        // window is hidden. The engine now lives for the lifetime of the
        // process (FloatingWindowEngine releases it on memory pressure),
        // so a subsequent lookup brings the same task forward warm
        // instead of re-running the full Dart startup.
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        FloatingWindowEngine.prepare(
            this,
            intent.getStringExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW).orEmpty(),
        )
    }

    private fun dismiss() {
        if (!moveTaskToBack(true)) {
            finish()
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        // Give Flutter's Navigator the first chance to pop a dictionary
        // lookup opened from this floating window. When there is no route to
        // pop, Flutter falls back to closing the Activity.
        super.onBackPressed()
    }

    override fun onDestroy() {
        if (activityReference?.get() === this) {
            activityReference = null
        }
        // The cached engine is not destroyed with the Activity: it is
        // shared by later invocations and released on memory pressure.
        super.onDestroy()
    }
}
