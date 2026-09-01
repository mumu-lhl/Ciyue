package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.util.PathUtils
import java.io.File

class ProcessTextActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = TextIntentUtils.extractText(intent)
        if (text.isEmpty()) {
            finish()
            return
        }

        val dataDirectory = PathUtils.getDataDirectory(applicationContext)
        val disableFloatingWindowFile = File(dataDirectory, "disable_floating_window")

        if (!disableFloatingWindowFile.exists()) {
            val floatingWindowIntent = Intent(this, FloatingWindowActivity::class.java).apply {
                putExtra(FloatingWindowEngine.EXTRA_TEXT_TO_SHOW, text)
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