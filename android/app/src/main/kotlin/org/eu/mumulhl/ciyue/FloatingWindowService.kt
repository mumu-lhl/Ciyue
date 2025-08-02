package org.eu.mumulhl.ciyue

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.os.IBinder
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

class FloatingWindowService : Service() {
    companion object {
        const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
        const val ENGINE_ID = "org.eu.mumulhl.ciyue/floating_window_engine"
    }

    private var flutterEngine: FlutterEngine? = null

    override fun onBind(intent: Intent?): IBinder? {
        return null // This is a started service, not a bound service
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT_TO_SHOW) ?: ""

        flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)

        if (flutterEngine == null) {
            flutterEngine = FlutterEngine(this).apply {
                dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "floatingWindow",
                    ), listOf<String>(text)
                )
            }
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        }

        // Start the transparent activity
        val activityIntent = Intent(this, FloatingWindowActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(activityIntent)

        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        super.onDestroy()
        flutterEngine?.destroy()
        flutterEngine = null
    }
}
