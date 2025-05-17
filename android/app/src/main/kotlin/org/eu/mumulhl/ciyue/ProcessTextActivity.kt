package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle

class ProcessTextActivity : Activity() {
    companion object {
        const val EXTRA_TEXT_TO_SHOW = "extra_text_to_show"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val text = intent?.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString() ?: ""
        
//        val intent = Intent(this, MainActivity::class.java).apply {
//            action = Intent.ACTION_PROCESS_TEXT
//            putExtra(Intent.EXTRA_PROCESS_TEXT, text)
//            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
//            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
//        }
        
//        startActivity(intent)
        val serviceIntent = Intent(this, FloatingWindowService::class.java).apply {
            putExtra(EXTRA_TEXT_TO_SHOW, text)
        }

        startService(serviceIntent)
        finish()
    }
} 