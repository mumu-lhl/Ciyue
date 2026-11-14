package org.eu.mumulhl.ciyue

import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import java.lang.ref.WeakReference

class FloatingWindowActivity : FlutterActivity() {
    companion object {
        private var activityReference: WeakReference<FloatingWindowActivity>? = null
        private var secureFlag = false

        fun current(): FloatingWindowActivity? = activityReference?.get()

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

    private var releaseEngineOnDestroy = false
    private var mode = FloatingWindowSettings.Mode.TRANSPARENT

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

    private fun readConfiguration(intent: Intent?) {
        mode = FloatingWindowSettings.Mode.parse(
            intent?.getStringExtra(FloatingWindowSettings.EXTRA_MODE),
        )
    }

    @Suppress("DEPRECATION")
    private fun displaySize(): Pair<Int, Int> {
        val manager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = manager.maximumWindowMetrics.bounds
            return bounds.width() to bounds.height()
        }
        val metrics = DisplayMetrics()
        manager.defaultDisplay.getRealMetrics(metrics)
        return metrics.widthPixels to metrics.heightPixels
    }

    /**
     * Give the window its final size as soon as it is created.
     *
     * The Activity uses a dialog-style theme (like the ColorDict popups
     * readers expect), so Window.setLayout/setGravity fully control the
     * window. Resizing a full-screen translucent Activity after the fact
     * leaves the old full-screen surface behind in Waydroid, which shows up
     * as a black rectangle above the popup.
     *
     * In the half-screen mode the reader tells us where the selected word is
     * through the ColorDict extras; Dart fills the whole window, so there are
     * no transparent pixels left either.
     */
    private fun applyWindowLayout() {
        if (mode != FloatingWindowSettings.Mode.HALF) {
            window.setLayout(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
            )
            window.setGravity(Gravity.TOP or Gravity.START)
            return
        }

        val geometry = ColorDict.geometry(
            intent,
            FloatingWindowSettings.DEFAULT_GRAVITY,
        )

        val (displayWidth, displayHeight) = displaySize()

        // The reader proposes a popup; the user's panel fraction is an upper
        // bound so a reader that requests a full-width popup cannot cover more
        // than the preferred size (issue #857). A smaller reader request is
        // kept as-is. A missing width means the reader wanted the full width,
        // which is also capped here.
        val cap = FloatingWindowSettings.readPanelFraction(this)
        val maxWidth = (displayWidth * cap.width).toInt()
        val maxHeight = (displayHeight * cap.height).toInt()

        val readerWidth = geometry.width ?: displayWidth
        val readerHeight = geometry.height ?: (displayHeight * 0.5f).toInt()
        val width = readerWidth.coerceAtMost(maxWidth).coerceAtMost(displayWidth)
        val height = readerHeight.coerceAtMost(maxHeight).coerceAtMost(displayHeight)
        window.setLayout(width, height)
        window.setGravity(geometry.gravity or Gravity.START)

        val layoutParams = window.attributes
        layoutParams.x = geometry.marginLeft - geometry.marginRight
        layoutParams.y = geometry.marginTop - geometry.marginBottom
        window.attributes = layoutParams
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        readConfiguration(intent)
        FloatingWindowEngine.prepare(
            this,
            intent?.getStringExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW).orEmpty(),
            mode.value,
        )
        activityReference = WeakReference(this)
        applySecureFlag()
        super.onCreate(savedInstanceState)

        applyWindowLayout()
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
        readConfiguration(intent)
        applyWindowLayout()
        FloatingWindowEngine.prepare(
            this,
            intent.getStringExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW).orEmpty(),
            mode.value,
        )
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // The fallback half-screen height is derived from the display size,
        // so a rotation or a window resize has to recompute it.
        applyWindowLayout()
    }

    private fun dismiss() {
        if (!moveTaskToBack(true)) {
            finish()
        }
    }

    // Called when the engine has to go away while this Activity still renders
    // it. The Activity cannot be rebound to another engine, so it is closed and
    // the engine is released from onDestroy, once the Flutter view is detached.
    fun closeForEngineReset() {
        releaseEngineOnDestroy = true
        runOnUiThread {
            if (!isFinishing) {
                finish()
            }
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
        val engine = getFlutterEngine()
        if (activityReference?.get() === this) {
            activityReference = null
        }
        // The cached engine is not destroyed with the Activity: it is
        // shared by later invocations and released on memory pressure.
        super.onDestroy()

        if (releaseEngineOnDestroy) {
            releaseEngineOnDestroy = false
            FloatingWindowEngine.release(engine)
        }
    }
}
