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
    private lateinit var configurator: EngineConfigurator

    override fun onCreate() {
        super.onCreate()
        configurator = EngineConfigurator(this)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra(EXTRA_TEXT_TO_SHOW)
            ?: return START_NOT_STICKY

        flutterEngine = FlutterEngineCache.getInstance().get(ENGINE_ID)

        if (flutterEngine == null) {
            flutterEngine = FlutterEngine(this).apply {
                configurator.configure(this)
                configurator.handleProcessText(text)
                
                dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "floatingWindow",
                    ), listOf<String>(text)
                )
            }
            FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        } else {
            configurator.configure(flutterEngine!!)
            configurator.handleProcessText(text)
        }

        val activityIntent = Intent(this, FloatingWindowActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        startActivity(activityIntent)

        // This service is only a host for the current floating-window
        // engine. Do not let Android recreate it with a null intent, which
        // would result in an empty lookup request.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        val engine = flutterEngine
        val cache = FlutterEngineCache.getInstance()

        // A destroyed engine must never remain available to the next lookup.
        // Only remove our engine so that a newer service instance cannot be
        // evicted by a stale onDestroy callback.
        if (engine != null && cache.get(ENGINE_ID) === engine) {
            cache.remove(ENGINE_ID)
        }

        flutterEngine = null
        engine?.destroy()
        super.onDestroy()
    }
}
