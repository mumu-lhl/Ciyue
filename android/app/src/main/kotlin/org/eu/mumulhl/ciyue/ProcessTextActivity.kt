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

        val mode = FloatingWindowSettings.mode(this)
        if (mode != FloatingWindowSettings.Mode.OFF) {
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