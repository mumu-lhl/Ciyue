package org.eu.mumulhl.ciyue

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.*
import android.widget.ImageButton
import android.widget.RelativeLayout
import android.widget.TextView
import android.widget.Toast
import java.lang.IllegalArgumentException

class FloatingWindowService : Service() {

    private lateinit var windowManager: WindowManager
    private lateinit var floatingView: View
    private lateinit var params: WindowManager.LayoutParams
    private lateinit var floatingTextView: TextView
    private lateinit var rootLayout: RelativeLayout

    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var isViewAdded = false

    override fun onBind(intent: Intent?): IBinder? {
        // Not used for started services, return null
        return null
    }

    @SuppressLint("ClickableViewAccessibility") // Suppress warning for performClick override
    override fun onCreate() {
        super.onCreate()

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater

        floatingView = inflater.inflate(R.layout.layout_floating_window, null)

        // Find views after inflating
        val closeButton: ImageButton = floatingView.findViewById(R.id.button_close)
        rootLayout = floatingView.findViewById(R.id.floating_root_layout) // Assign rootLayout

        // Determine LayoutParams type based on Android version
        val layoutParamsType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE // Or TYPE_SYSTEM_ALERT, TYPE_PHONE is common
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutParamsType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT // Allow transparent background
        )

        params.gravity = Gravity.TOP or Gravity.START // Initial position: Top-Left
        params.x = 100 // Initial X offset
        params.y = 100 // Initial Y offset

        // Set close button listener using a lambda
        closeButton.setOnClickListener {
            stopSelf() // Stop the service when closed
        }

        // Set touch listener for dragging using a lambda
        // Use rootLayout for dragging the whole window
//        rootLayout.setOnTouchListener { _, event ->
//            when (event.action) {
//                MotionEvent.ACTION_DOWN -> {
//                    initialX = params.x
//                    initialY = params.y
//                    initialTouchX = event.rawX // Screen coordinates
//                    initialTouchY = event.rawY // Screen coordinates
//                    true // Consume the event
//                }
//                MotionEvent.ACTION_MOVE -> {
//                    // Calculate the new position
//                    params.x = initialX + (event.rawX - initialTouchX).toInt()
//                    params.y = initialY + (event.rawY - initialTouchY).toInt()
//                    // Update the layout only if the view is still attached
//                    if (isViewAdded) {
//                        try {
//                            windowManager.updateViewLayout(floatingView, params)
//                        } catch (e: IllegalArgumentException){
//                            // View might have been removed unexpectedly
//                            isViewAdded = false
//                        }
//                    }
//                    true // Consume the event
//                }
//                MotionEvent.ACTION_UP -> {
//                    // Optional: Save the final position here using SharedPreferences
//                    true // Consume the event
//                }
//                else -> false // Don't consume other actions
//            }
//        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.getStringExtra(ProcessTextActivity.EXTRA_TEXT_TO_SHOW)?.let { textToShow ->
            // Update text view
            floatingTextView.text = textToShow

            // Add the view to the window manager only if it's not already added
            if (!isViewAdded) {
                try {
                    windowManager.addView(floatingView, params)
                    isViewAdded = true
                } catch (e: Exception) {
                    // Handle exceptions during addView (e.g., permission revoked)
                    Toast.makeText(this, "Failed to add floating window: ${e.message}", Toast.LENGTH_LONG).show()
                    e.printStackTrace()
                    stopSelf() // Stop service if view cannot be added
                    return START_NOT_STICKY // Indicate failure, don't restart
                }
            } else {
                // If view is already added, maybe just bring it to front or update params
                // For simplicity, we're just updating the text content above.
                // If you need to ensure params are current (e.g., after screen rotation), update here:
                // windowManager.updateViewLayout(floatingView, params)
            }

        } ?: run {
            // Handle cases where intent or extra is null (e.g., service restarted)
            // If started via Process Text, we expect text. If null, maybe stop.
            if (isViewAdded){
                // Keep window open if it was already visible? Or close it?
                // Let's close it if we don't get valid text on restart/call
                // stopSelf()
            } else {
                // Wasn't added and no text, definitely stop
                stopSelf()
            }
        }

        // If the service is killed, don't automatically restart it.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        // Remove the view from the window manager if it was added
        if (isViewAdded) {
            try {
                windowManager.removeView(floatingView)
                isViewAdded = false // Mark as removed
            } catch (e: IllegalArgumentException) {
                // View was likely already removed or not attached, ignore safely
                e.printStackTrace()
                isViewAdded = false // Ensure flag is false
            }
        }
        // Optional: Release other resources if necessary
    }
}