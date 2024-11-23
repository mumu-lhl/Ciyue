package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class ShareTextActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = intent?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: ""

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_PROCESS_TEXT
            putExtra(Intent.EXTRA_PROCESS_TEXT, text)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }

        startActivity(intent)
        finish()
    }
} 