package org.eu.mumulhl.ciyue

import android.annotation.SuppressLint
import android.os.Bundle
import android.util.DisplayMetrics
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class FloatingWindowActivity : FlutterActivity() {
    // Tell FlutterActivity that the engine is cached and owned by the service.
    // This prevents the activity from treating it as a new engine on every
    // floating-window invocation.
    override fun getCachedEngineId(): String? = FloatingWindowService.ENGINE_ID

    override fun getTransparencyMode(): io.flutter.embedding.android.TransparencyMode {
        return io.flutter.embedding.android.TransparencyMode.transparent
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val rootView = window.decorView.rootView
        rootView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_DOWN) {
                finish()
            }
            true
        }

        val displayMetrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(displayMetrics)
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        val layoutParams = WindowManager.LayoutParams()
        layoutParams.copyFrom(window.attributes)
        layoutParams.width = (screenWidth * 0.8).toInt()
        layoutParams.height = (screenHeight * 0.5).toInt()
        window.attributes = layoutParams
    }
}
