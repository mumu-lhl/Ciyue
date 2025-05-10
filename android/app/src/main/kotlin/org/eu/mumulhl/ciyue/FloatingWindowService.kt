package org.eu.mumulhl.ciyue

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import io.flutter.FlutterInjector

import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class FloatingWindowService : Service() {
    companion object {
        const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
    }

    private var mWindowManager: WindowManager? = null
    private var mFloatingView: FlutterView? = null
    private var flutterEngine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is a started service, not a bound service
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT_TO_SHOW) ?: ""

        flutterEngine = FlutterEngine(this)
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "floatingWindow",
            ),
            listOf<String>(text)
        )

        mFloatingView = FlutterView(this)
        mFloatingView?.attachToFlutterEngine(flutterEngine!!)

        val params = WindowManager.LayoutParams(
            600,
            800,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT // Allow transparency
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 20
            y = 100
        }

        mWindowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        mWindowManager?.addView(mFloatingView, params)

        // Add touch listener to the floating view to enable dragging
        mFloatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX: Int = 0
            private var initialY: Int = 0
            private var initialTouchX: Float = 0.toFloat()
            private var initialTouchY: Float = 0.toFloat()

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        // Remember the initial position and touch point
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        return true
                    }

                    MotionEvent.ACTION_MOVE -> {
                        // Calculate the new position based on touch movement
                        params.x = initialX + (event.rawX - initialTouchX).toInt()
                        params.y = initialY + (event.rawY - initialTouchY).toInt()

                        // Update the window layout
                        mWindowManager?.updateViewLayout(mFloatingView, params)
                        return true
                    }

                    MotionEvent.ACTION_UP -> {
                        // Optional: Handle click event if needed (e.g., if movement was minimal)
                        // val deltaX = event.rawX - initialTouchX
                        // val deltaY = event.rawY - initialTouchY
                        // if (abs(deltaX) < 10 && abs(deltaY) < 10) {
                        //     // Handle click
                        // }
                        return true
                    }
                }
                return false
            }
        })

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