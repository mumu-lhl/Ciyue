package org.eu.mumulhl.ciyue

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.MotionEvent
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

    private val mainHandler = Handler(Looper.getMainLooper())
    private var dismissed = false
    private var idleExpired = false
    private val finishAfterIdle = Runnable {
        if (!isFinishing && !isDestroyed) {
            idleExpired = true
            finishAndRemoveTask()
        }
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
        mainHandler.removeCallbacks(finishAfterIdle)
        dismissed = false
        idleExpired = false
        FloatingWindowEngine.cancelIdleShutdown()
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
        when {
            isFinishing -> FloatingWindowEngine.scheduleIdleShutdown()
            dismissed -> {
                // Keep this Activity attached to the cached engine while the
                // window is hidden. A subsequent lookup can bring the same
                // task forward without racing an old Activity's onDestroy.
                mainHandler.removeCallbacks(finishAfterIdle)
                mainHandler.postDelayed(
                    finishAfterIdle,
                    FloatingWindowEngine.IDLE_SHUTDOWN_DELAY_MS,
                )
            }
            else -> FloatingWindowEngine.cancelIdleShutdown()
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
            dismiss()
            return true
        }
        return super.dispatchTouchEvent(event)
    }

    private fun dismiss() {
        dismissed = true
        if (!moveTaskToBack(true)) {
            finish()
        }
    }

    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        dismiss()
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(finishAfterIdle)
        if (activityReference?.get() === this) {
            activityReference = null
        }
        super.onDestroy()

        if (idleExpired) {
            FloatingWindowEngine.destroyNow()
        } else {
            FloatingWindowEngine.scheduleIdleShutdown()
        }
    }
}
