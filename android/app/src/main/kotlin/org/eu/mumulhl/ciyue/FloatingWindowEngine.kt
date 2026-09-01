package org.eu.mumulhl.ciyue

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.baseflow.permissionhandler.PermissionHandlerPlugin
import com.eyedeadevelopment.fluttertts.FlutterTtsPlugin
import com.github.dart_lang.jni.JniPlugin
import com.github.dart_lang.jni_flutter.JniFlutterPlugin
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import dev.flutter.packages.file_selector_android.FileSelectorAndroidPlugin
import dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import dev.fluttercommunity.plus.share.SharePlusPlugin
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import io.material.plugins.dynamic_color.DynamicColorPlugin
import xyz.luan.audioplayers.AudioplayersPlugin

object FloatingWindowEngine {
    const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
    const val ENGINE_ID = "org.eu.mumulhl.ciyue/floating_window_engine"

    const val IDLE_SHUTDOWN_DELAY_MS = 30_000L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val idleShutdown = Runnable { destroyNow() }
    private var engine: FlutterEngine? = null
    private var configurator: EngineConfigurator? = null

    fun prepare(context: Context, text: String): FlutterEngine {
        cancelIdleShutdown()

        val cache = FlutterEngineCache.getInstance()
        val cachedEngine = cache.get(ENGINE_ID)
        if (cachedEngine != null) {
            engine = cachedEngine
            val currentConfigurator = configurator ?: createConfigurator(context).also {
                configurator = it
            }
            currentConfigurator.configure(cachedEngine)
            currentConfigurator.handleProcessText(text)
            return cachedEngine
        }

        val newEngine = createFlutterEngine(context)
        val newConfigurator = createConfigurator(context)
        try {
            newConfigurator.configure(newEngine)
            newConfigurator.handleProcessText(text)
            newEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "floatingWindow",
                ),
                if (text.isBlank()) emptyList() else listOf(text),
            )
            cache.put(ENGINE_ID, newEngine)
            engine = newEngine
            configurator = newConfigurator
            return newEngine
        } catch (error: Throwable) {
            newConfigurator.dispose()
            newEngine.destroy()
            throw error
        }
    }

    fun cancelIdleShutdown() {
        mainHandler.removeCallbacks(idleShutdown)
    }

    fun scheduleIdleShutdown() {
        mainHandler.removeCallbacks(idleShutdown)
        mainHandler.postDelayed(idleShutdown, IDLE_SHUTDOWN_DELAY_MS)
    }

    private fun createConfigurator(context: Context): EngineConfigurator {
        return EngineConfigurator(context).apply {
            callback = object : EngineConfigurator.Callback {
                override fun onSetSecureFlag(secure: Boolean) {
                    FloatingWindowActivity.setSecureFlag(secure)
                }
            }
        }
    }

    private fun createFlutterEngine(context: Context): FlutterEngine {
        // Keep the plugin list in sync with GeneratedPluginRegistrant, except
        // for process-wide plugins. In particular,
        // flutter_local_notifications uses a static native channel for the
        // main engine.
        return FlutterEngine(context.applicationContext, null, false).apply {
            plugins.add(AudioplayersPlugin())
            plugins.add(DeviceInfoPlusPlugin())
            plugins.add(DynamicColorPlugin())
            plugins.add(FileSelectorAndroidPlugin())
            plugins.add(FlutterTtsPlugin())
            plugins.add(InAppWebViewFlutterPlugin())
            plugins.add(JniPlugin())
            plugins.add(JniFlutterPlugin())
            plugins.add(PackageInfoPlugin())
            plugins.add(PermissionHandlerPlugin())
            plugins.add(SharedPreferencesPlugin())
            plugins.add(SharePlusPlugin())
            plugins.add(UrlLauncherPlugin())
        }
    }

    fun destroyNow() {
        cancelIdleShutdown()

        val currentEngine = engine ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (currentEngine != null &&
            FlutterEngineCache.getInstance().get(ENGINE_ID) === currentEngine
        ) {
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }

        engine = null
        configurator?.dispose()
        configurator = null
        currentEngine?.destroy()
    }
}
