package org.eu.mumulhl.ciyue

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
// Removed unused imports: TextView, LinearLayout

import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class FloatingWindowService : Service() {

    private var mWindowManager: WindowManager? = null
    private var mFloatingView: FlutterView? = null // Changed type to FlutterView
    private var flutterEngine: FlutterEngine? = null // Added FlutterEngine reference

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is a started service, not a bound service
    }

    override fun onCreate() {
        super.onCreate()

        // Create a new FlutterEngine
        flutterEngine = FlutterEngine(this)

        // Configure the Dart entry point
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(
                this.assets,
                "flutter_assets/lib/main.dart", // Assuming main.dart is the entry file
                "floatingWindow" // The specified Dart function name
            )
        )

        // Create the floating view using FlutterView
        mFloatingView = FlutterView(this)

        // Attach the Flutter engine to the FlutterView
        flutterEngine?.attachToFlutterView(mFloatingView as FlutterView)


        // Get the window manager
        mWindowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        // Define layout parameters for the floating window
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT, // Adjust size as needed for your Flutter content
            WindowManager.LayoutParams.WRAP_CONTENT, // Adjust size as needed for your Flutter content
            // Use TYPE_APPLICATION_OVERLAY for Android O and above
            // Use TYPE_PHONE or TYPE_PRIORITY_PHONE for older versions
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, // Don't receive touch or keyboard events
            PixelFormat.TRANSLUCENT // Allow transparency
        ).apply {
            gravity = Gravity.TOP or Gravity.START // Position the window at top-left
            x = 0 // Initial x position
            y = 100 // Initial y position
        }

        // Add the view to the window
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
    }

    override fun onDestroy() {
        super.onDestroy()
        // Remove the floating view when the service is destroyed
        if (mFloatingView != null) {
            // Detach and destroy the Flutter engine
            flutterEngine?.destroy()
            flutterEngine = null

            mWindowManager?.removeView(mFloatingView)
            mFloatingView = null
        }
    }
}
