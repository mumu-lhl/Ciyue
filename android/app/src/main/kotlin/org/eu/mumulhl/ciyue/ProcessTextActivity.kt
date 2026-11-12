package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class ProcessTextActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = TextIntentUtils.extractText(intent)
        if (text.isEmpty()) {
            finish()
            return
        }

        if (FloatingWindowSettings.isEnabled(this)) {
            // The reader decides the style by supplying the selected word's
            // geometry: with it the popup becomes a half-screen window that
            // avoids the word, without it a centred card over the reader.
            val mode = if (ColorDict.hasGeometry(intent)) {
                FloatingWindowSettings.Mode.HALF
            } else {
                FloatingWindowSettings.Mode.TRANSPARENT
            }
            val floatingWindowIntent = Intent(this, FloatingWindowActivity::class.java).apply {
                putExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW, text)
                putExtra(FloatingWindowSettings.EXTRA_MODE, mode.value)
                ColorDict.forwardGeometry(this@ProcessTextActivity.intent, this)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(floatingWindowIntent)
        } else {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_PROCESS_TEXT
                putExtra(Intent.EXTRA_PROCESS_TEXT, text)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        }
        finish()
    }
} 