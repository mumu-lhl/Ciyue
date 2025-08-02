package org.eu.mumulhl.ciyue

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class FloatingWindowActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? {
        return io.flutter.embedding.engine.FlutterEngineCache.getInstance().get(FloatingWindowService.ENGINE_ID)
    }

    // This is needed to ensure the transparent background is rendered correctly.
    override fun getTransparencyMode(): io.flutter.embedding.android.TransparencyMode {
        return io.flutter.embedding.android.TransparencyMode.transparent
    }
}
