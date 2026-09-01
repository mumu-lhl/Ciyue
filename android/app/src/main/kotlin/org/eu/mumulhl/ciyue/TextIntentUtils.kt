package org.eu.mumulhl.ciyue

import android.content.Intent

object TextIntentUtils {
    @Suppress("DEPRECATION")
    fun extractText(intent: Intent?): String {
        val value = intent?.extras?.get(Intent.EXTRA_PROCESS_TEXT)
            ?: intent?.extras?.get(Intent.EXTRA_TEXT)
            ?: return ""

        val text = when (value) {
            is CharSequence -> value.toString()
            is Iterable<*> -> value.filterIsInstance<CharSequence>().joinToString(" ")
            else -> ""
        }
        return text.trim()
    }
}
