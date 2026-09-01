package org.eu.mumulhl.ciyue

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
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
    }

    // Tell FlutterActivity that the engine is cached and owned by the engine
    // holder. This prevents the Activity from treating it as a new engine on
    // every floating-window invocation.
    override fun getCachedEngineId(): String? = FloatingWindowEngine.ENGINE_ID

    override fun getTransparencyMode(): io.flutter.embedding.android.TransparencyMode {
        return io.flutter.embedding.android.TransparencyMode.transparent
    }

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
        window.addFlags(
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
        )

        val (screenWidth, screenHeight) = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            @Suppress("DEPRECATION")
            val displayMetrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getMetrics(displayMetrics)
            displayMetrics.widthPixels to displayMetrics.heightPixels
        }

        val layoutParams = WindowManager.LayoutParams()
        layoutParams.copyFrom(window.attributes)
        layoutParams.width = (screenWidth * 0.8).toInt()
        layoutParams.height = (screenHeight * 0.5).toInt()
        window.attributes = layoutParams
    }

    override fun onStart() {
        super.onStart()
        FloatingWindowEngine.cancelIdleShutdown()
    }

    override fun onStop() {
        super.onStop()
        if (isFinishing) {
            FloatingWindowEngine.scheduleIdleShutdown()
        } else {
            // Keep the cached engine while the Activity is merely covered or
            // backgrounded. Destroying it here would leave this Activity with
            // a dead engine when the user returns to it.
            FloatingWindowEngine.cancelIdleShutdown()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        FloatingWindowEngine.prepare(
            this,
            intent.getStringExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW).orEmpty(),
        )
    }

    override fun dispatchTouchEvent(event: MotionEvent): Boolean {
        if (event.action == MotionEvent.ACTION_OUTSIDE) {
            finish()
            return true
        }
        return super.dispatchTouchEvent(event)
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        finish()
    }

    override fun onDestroy() {
        if (activityReference?.get() === this) {
            activityReference = null
        }
        super.onDestroy()
    }
}
