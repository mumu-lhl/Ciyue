package org.eu.mumulhl.ciyue

import android.content.Context
import android.content.Intent
import android.view.Gravity
import io.flutter.util.PathUtils
import java.io.File

/**
 * Floating-window configuration shared with the Dart settings page.
 *
 * The settings page only stores whether the floating window is enabled. The
 * window style is not a user choice: it follows the lookup intent, see
 * ProcessTextActivity.
 */
object FloatingWindowSettings {
    const val MODE_FILE = "floating_window_mode"
    const val LEGACY_DISABLED_FILE = "disable_floating_window"

    const val EXTRA_MODE = "extra_floating_window_mode"

    /** Used when the reader sends a height but no gravity. */
    const val DEFAULT_GRAVITY = Gravity.BOTTOM

    enum class Mode(val value: String) {
        TRANSPARENT("transparent"),
        HALF("half"),
        OFF("off");

        companion object {
            fun parse(value: String?): Mode =
                values().firstOrNull { it.value == value } ?: TRANSPARENT
        }
    }

    private fun dataDirectory(context: Context): String =
        PathUtils.getDataDirectory(context.applicationContext)

    private fun read(context: Context, name: String): String? =
        runCatching {
            val file = File(dataDirectory(context), name)
            if (file.exists()) file.readText().trim() else null
        }.getOrNull()

    fun mode(context: Context): Mode {
        val saved = read(context, MODE_FILE)
        if (saved != null) {
            return Mode.parse(saved)
        }

        // The legacy switch expressed "off" with the presence of an empty
        // marker file rather than with its contents.
        val legacy = File(dataDirectory(context), LEGACY_DISABLED_FILE)
        return if (legacy.exists()) Mode.OFF else Mode.TRANSPARENT
    }

    fun isEnabled(context: Context): Boolean = mode(context) != Mode.OFF
}

/**
 * The ColorDict intent protocol used by readers such as Moon+ Reader.
 *
 * Besides the selected word, the reader sends the geometry of the popup it
 * wants, so the dictionary window can avoid covering the word under the
 * reader's finger. See
 * https://blog.socialnmobile.com/2011/01/colordict-api-for-3rd-party-developers.html
 */
object ColorDict {
    const val SEARCH_ACTION = "colordict.intent.action.SEARCH"
    const val GOLDENDICT_SEARCH_ACTION = "goldendict.intent.action.SEARCH"
    const val SEARCH_LONG_PRESS_ACTION = "android.intent.action.SEARCH_LONG_PRESS"

    const val EXTRA_QUERY = "EXTRA_QUERY"
    const val EXTRA_FULLSCREEN = "EXTRA_FULLSCREEN"
    const val EXTRA_HEIGHT = "EXTRA_HEIGHT"
    const val EXTRA_WIDTH = "EXTRA_WIDTH"
    const val EXTRA_GRAVITY = "EXTRA_GRAVITY"
    const val EXTRA_MARGIN_LEFT = "EXTRA_MARGIN_LEFT"
    const val EXTRA_MARGIN_TOP = "EXTRA_MARGIN_TOP"
    const val EXTRA_MARGIN_BOTTOM = "EXTRA_MARGIN_BOTTOM"
    const val EXTRA_MARGIN_RIGHT = "EXTRA_MARGIN_RIGHT"

    private val FORWARD_KEYS = listOf(
        EXTRA_FULLSCREEN,
        EXTRA_HEIGHT,
        EXTRA_WIDTH,
        EXTRA_GRAVITY,
        EXTRA_MARGIN_LEFT,
        EXTRA_MARGIN_TOP,
        EXTRA_MARGIN_BOTTOM,
        EXTRA_MARGIN_RIGHT,
    )

    /** Keys that describe the popup geometry. EXTRA_FULLSCREEN is only a
     *  display hint, so an intent carrying just that stays a centred card. */
    private val LAYOUT_KEYS = listOf(
        EXTRA_HEIGHT,
        EXTRA_WIDTH,
        EXTRA_GRAVITY,
        EXTRA_MARGIN_LEFT,
        EXTRA_MARGIN_TOP,
        EXTRA_MARGIN_BOTTOM,
        EXTRA_MARGIN_RIGHT,
    )

    /** True when the reader told us where the selected word is; only then the
     *  lookup becomes a half-screen window. */
    fun hasGeometry(intent: Intent?): Boolean {
        val extras = intent?.extras ?: return false
        return LAYOUT_KEYS.any { extras.containsKey(it) }
    }

    /** Copy the reader's geometry from the incoming intent to the one that
     *  launches the floating Activity. Only those keys are forwarded so an
     *  unrelated extra can never change the window layout. */
    fun forwardGeometry(source: Intent?, target: Intent) {
        val extras = source?.extras ?: return
        for (key in FORWARD_KEYS) {
            if (!extras.containsKey(key)) continue
            when (val value = extras.get(key)) {
                is Int -> target.putExtra(key, value)
                is Number -> target.putExtra(key, value.toInt())
                is Boolean -> target.putExtra(key, value)
                is String -> target.putExtra(key, value)
            }
        }
    }

    data class Geometry(
        val gravity: Int,
        val width: Int?,
        val height: Int?,
        val marginLeft: Int,
        val marginTop: Int,
        val marginRight: Int,
        val marginBottom: Int,
    )

    fun geometry(intent: Intent?, fallbackGravity: Int): Geometry {
        val extras = intent?.extras
        val hasGravity = extras?.containsKey(EXTRA_GRAVITY) == true
        val rawGravity = if (hasGravity) {
            (extras?.get(EXTRA_GRAVITY) as? Number)?.toInt() ?: fallbackGravity
        } else {
            fallbackGravity
        }
        val gravity = when (rawGravity and Gravity.VERTICAL_GRAVITY_MASK) {
            Gravity.TOP -> Gravity.TOP
            Gravity.BOTTOM -> Gravity.BOTTOM
            else -> fallbackGravity
        }

        fun positive(key: String): Int? {
            if (extras?.containsKey(key) != true) return null
            return (extras.get(key) as? Number)?.toInt()?.takeIf { it > 0 }
        }

        fun margin(key: String): Int =
            if (extras?.containsKey(key) == true) {
                (extras.get(key) as? Number)?.toInt() ?: 0
            } else {
                0
            }

        return Geometry(
            gravity = gravity,
            width = positive(EXTRA_WIDTH),
            height = positive(EXTRA_HEIGHT),
            marginLeft = margin(EXTRA_MARGIN_LEFT),
            marginTop = margin(EXTRA_MARGIN_TOP),
            marginRight = margin(EXTRA_MARGIN_RIGHT),
            marginBottom = margin(EXTRA_MARGIN_BOTTOM),
        )
    }
}
