package org.eu.mumulhl.ciyue

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterSurfaceView

import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class FloatingWindowService : Service() {
    companion object {
        const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
        const val ENGINE_ID = "org.eu.mumulhl.ciyue/floating_window_engine"
    }

    private var mWindowManager: WindowManager? = null
    private var mFloatingView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is a started service, not a bound service
    }

    @RequiresApi(Build.VERSION_CODES.O)
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT_TO_SHOW) ?: ""

        flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)

        if (flutterEngine == null) {
            flutterEngine = FlutterEngine(this).apply {
                dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "floatingWindow",
                    ),
                    listOf<String>(text)
                )
            }
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        }

        mFloatingView = FlutterView(this, FlutterSurfaceView(this)).apply {
            attachToFlutterEngine(flutterEngine!!)
            isFocusable = true
            isFocusableInTouchMode = true
            fitsSystemWindows = true
        }

        val params = WindowManager.LayoutParams(
            600,
            800,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            0,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 20
            y = 100
        }

        flutterEngine!!.lifecycleChannel.appIsResumed()

        mWindowManager = (getSystemService(WINDOW_SERVICE) as WindowManager).apply {
            addView(mFloatingView, params)
        }

        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        super.onDestroy()

        if (mFloatingView != null) {
            mFloatingView!!.detachFromFlutterEngine()

            flutterEngine?.destroy()
            flutterEngine = null

            mWindowManager?.removeView(mFloatingView)
            mFloatingView = null
        }
    }
}