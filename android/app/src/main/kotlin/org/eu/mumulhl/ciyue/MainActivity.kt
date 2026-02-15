package org.eu.mumulhl.ciyue

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.core.net.toUri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        const val OPEN_DICTIONARY_DOCUMENT_TREE = 0
        const val CREATE_FILE = 1
        const val GET_DIRECTORY = 2
        const val REQUEST_OVERLAY_PERMISSION = 3
        const val OPEN_AUDIO_DOCUMENT_TREE = 4
    }

    private lateinit var configurator: EngineConfigurator

    private fun openDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_DICTIONARY_DOCUMENT_TREE)
    }

    private fun openAudioDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_AUDIO_DOCUMENT_TREE)
    }

    private fun createFile() {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            setType("application/json")
            putExtra(Intent.EXTRA_TITLE, "ciyue.json")
        }
        startActivityForResult(intent, CREATE_FILE)
    }

    private fun getDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, GET_DIRECTORY)
    }

    private fun setSecureFlag(secure: Boolean) {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (resultCode == RESULT_OK) {
            when (requestCode) {
                OPEN_DICTIONARY_DOCUMENT_TREE -> openDocumentTree(data, "dictionaries")
                OPEN_AUDIO_DOCUMENT_TREE -> openDocumentTree(data, "audios")
                CREATE_FILE -> createFileHandler(data)
                GET_DIRECTORY -> getDirectoryHandler(data)
                REQUEST_OVERLAY_PERMISSION -> {}
            }
        }
    }

    private fun getDirectoryHandler(data: Intent?) {
        data?.data?.also { uri ->
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            configurator.methodChannel!!.invokeMethod("getDirectory", uri.toString())
        }
    }

    private fun createFileHandler(data: Intent?) {
        data?.data?.also { uri ->
            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(configurator.exportContent.toByteArray())
                configurator.exportContent = ""
            }
        }
    }

    private fun openDocumentTree(data: Intent?, destination: String) {
        data?.data?.also { uri ->
            val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION
            contentResolver.takePersistableUriPermission(
                uri, takeFlags
            )
            configurator.copyDirectory(uri, destination)
        }
    }

    private fun ensureConfigurator() {
        if (!::configurator.isInitialized) {
            configurator = EngineConfigurator(this)
            configurator.callback = object : EngineConfigurator.Callback {
                override fun onOpenDirectory() = openDirectory()
                override fun onOpenAudioDirectory() = openAudioDirectory()
                override fun onCreateFile() = createFile()
                override fun onGetDirectory() = getDirectory()
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureConfigurator()
        configurator.configure(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ensureConfigurator()
        handleProcessTextIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleProcessTextIntent(intent)
    }

    private fun handleProcessTextIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString() ?: ""
            configurator.handleProcessText(text)
        }
    }
}
