package org.eu.mumulhl.ciyue

import android.content.ComponentCallbacks2
import android.content.Context
import android.content.res.Configuration
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

    private var engine: FlutterEngine? = null
    private var configurator: EngineConfigurator? = null
    private var trimMemoryReleaseRegistered = false

    fun prepare(context: Context, text: String): FlutterEngine {
        registerTrimMemoryRelease(context)

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

    // The engine is intentionally kept alive for the lifetime of the
    // process: destroying it after a short idle timeout forced every
    // process-text invocation to re-run the full Dart startup, including
    // loading every dictionary index in the current group. Memory
    // pressure is the release signal instead — when the system asks the
    // app to trim, the engine goes away and the next invocation pays
    // the cold start only then.
    private fun registerTrimMemoryRelease(context: Context) {
        if (trimMemoryReleaseRegistered) {
            return
        }
        trimMemoryReleaseRegistered = true
        context.applicationContext.registerComponentCallbacks(
            object : ComponentCallbacks2 {
                override fun onTrimMemory(level: Int) {
                    // These levels are numerically higher than
                    // TRIM_MEMORY_RUNNING_CRITICAL but do not describe memory
                    // pressure: TRIM_MEMORY_UI_HIDDEN (20) is sent every time
                    // our activities stop, and TRIM_MEMORY_BACKGROUND (40) every
                    // time the process moves to the cached list. Treating them
                    // as pressure destroyed the warm engine whenever the
                    // floating window was dismissed and left the next
                    // invocation with a black window.
                    val memoryPressure =
                        level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW ||
                            level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL ||
                            level == ComponentCallbacks2.TRIM_MEMORY_MODERATE ||
                            level == ComponentCallbacks2.TRIM_MEMORY_COMPLETE
                    if (memoryPressure) {
                        destroyNow()
                    }
                }

                override fun onConfigurationChanged(newConfig: Configuration) {}

                override fun onLowMemory() {
                    destroyNow()
                }
            },
        )
    }

    private fun createConfigurator(context: Context): EngineConfigurator {
        return EngineConfigurator(context).apply {
            callback = object : EngineConfigurator.Callback {
                override fun onSetSecureFlag(secure: Boolean) {
                    FloatingWindowActivity.setSecureFlag(secure)
                }

                override fun onDismissFloatingWindow() {
                    FloatingWindowActivity.dismissCurrent()
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
        val attachedActivity = FloatingWindowActivity.current()
        if (attachedActivity != null) {
            // FlutterActivity binds its FlutterView to the engine exactly once,
            // in onCreate. Destroying the engine while that Activity is alive
            // would leave the window attached to a dead engine and black until
            // the Activity is recreated. Close the window instead and release
            // the engine once it has detached.
            attachedActivity.closeForEngineReset()
            return
        }

        release(null)
    }

    fun release(engineToRelease: FlutterEngine?) {
        val currentEngine = engineToRelease
            ?: engine
            ?: FlutterEngineCache.getInstance().get(ENGINE_ID)
        if (engine === currentEngine) {
            engine = null
        }
        if (currentEngine != null &&
            FlutterEngineCache.getInstance().get(ENGINE_ID) === currentEngine
        ) {
            FlutterEngineCache.getInstance().remove(ENGINE_ID)
        }

        configurator?.dispose()
        configurator = null
        currentEngine?.destroy()
    }
}
