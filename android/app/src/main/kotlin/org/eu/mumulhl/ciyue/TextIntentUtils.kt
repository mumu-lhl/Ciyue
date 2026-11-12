package org.eu.mumulhl.ciyue

import android.content.Intent

object TextIntentUtils {
    @Suppress("DEPRECATION")
    fun extractText(intent: Intent?): String {
        val extras = intent?.extras
        val value = extras?.get(ColorDict.EXTRA_QUERY)
            ?: extras?.get(Intent.EXTRA_PROCESS_TEXT)
            ?: extras?.get(Intent.EXTRA_TEXT)
            ?: return ""

        val text = when (value) {
            is CharSequence -> value.toString()
            is Iterable<*> -> value.filterIsInstance<CharSequence>().joinToString(" ")
            else -> ""
        }
        return text.trim()
    }
}
