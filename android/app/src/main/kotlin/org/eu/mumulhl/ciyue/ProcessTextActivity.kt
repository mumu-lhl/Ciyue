package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.util.PathUtils
import java.io.File

class ProcessTextActivity : Activity() {
    companion object {
        const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString() ?: ""

        val dataDirectory = PathUtils.getDataDirectory(applicationContext)
        val disableFloatingWindowFile = File(dataDirectory, "disable_floating_window")

        if (!disableFloatingWindowFile.exists()) {
            val serviceIntent = Intent(this, FloatingWindowService::class.java).apply {
                putExtra(EXTRA_TEXT_TO_SHOW, text)
            }

            startService(serviceIntent)
        } else {
            val intent = Intent(this, MainActivity::class.java).apply {
                action = Intent.ACTION_PROCESS_TEXT
                putExtra(Intent.EXTRA_PROCESS_TEXT, text)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            startActivity(intent)
        }
        finish()
    }
} 