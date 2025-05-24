package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
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
        const val CHANNEL = "org.eu.mumulhl.ciyue"

        const val OPEN_DICTIONARY_DOCUMENT_TREE = 0
        const val CREATE_FILE = 1
        const val GET_DIRECTORY = 2
        const val REQUEST_OVERLAY_PERMISSION = 3
        const val OPEN_AUDIO_DOCUMENT_TREE = 4
    }

    var methodChannel: MethodChannel? = null

    var exportContent = ""

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

    private fun writeFile(directory: String, filename: String, content: String) {
        val directoryFile = DocumentFile.fromTreeUri(context, directory.toUri())
        val file = directoryFile!!.findFile(filename)
        if (file == null) {
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.uri.let { context.contentResolver.openOutputStream(it) }.use { outputStream ->
                outputStream!!.write(content.toByteArray())
            }

        } else {
            file.delete()
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.uri.let { context.contentResolver.openOutputStream(it) }.use { outputStream ->
                outputStream!!.write(content.toByteArray())
            }
        }
    }

    private fun setSecureFlag(secure: Boolean) {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun requestFloatingWindowPermission() {
        if (!Settings.canDrawOverlays(this)) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                "package:$packageName".toUri()
            )
            startActivityForResult(intent, REQUEST_OVERLAY_PERMISSION)
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
            methodChannel!!.invokeMethod("getDirectory", uri.toString())
        }
    }

    private fun createFileHandler(data: Intent?) {
        data?.data?.also { uri ->
            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(exportContent.toByteArray())
                exportContent = ""
            }
        }
    }

    private fun copy(source: DocumentFile, target: File) {
        if (!target.exists()) {
            target.mkdirs()
        }
        source.listFiles().forEach { file ->
            if (file.isFile) {
                BufferedInputStream(contentResolver.openInputStream(file.uri)).use { input ->
                    BufferedOutputStream(
                        File(
                            target,
                            file.name ?: ""
                        ).outputStream()
                    ).use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                copy(file, File(target, file.name ?: ""))
            }
        }
    }

    private fun copyDirectory(uri: Uri, destination: String) {
        methodChannel!!.invokeMethod("showLoadingDialog", null)

        val documents = DocumentFile.fromTreeUri(applicationContext, uri)!!
        copy(documents, File(filesDir, destination))

        when (destination) {
            "dictionaries" -> methodChannel!!.invokeMethod("inputDirectory", uri.toString())
            "audios" -> methodChannel!!.invokeMethod("inputAudioDirectory", uri.toString())
        }
    }

    private fun openDocumentTree(data: Intent?, destination: String) {
        data?.data?.also { uri ->
            val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION
            contentResolver.takePersistableUriPermission(
                uri, takeFlags
            )
            copyDirectory(uri, destination)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDirectory" -> {
                        openDirectory()
                    }

                    "openAudioDirectory" -> {
                        openAudioDirectory()
                    }

                    "createFile" -> {
                        exportContent = call.arguments as String
                        createFile()
                    }

                    "getDirectory" -> {
                        getDirectory()
                    }

                    "writeFile" -> {
                        val arguments = call.arguments as Map<*, *>
                        writeFile(
                            arguments["directory"] as String,
                            arguments["filename"] as String,
                            arguments["content"] as String
                        )
                    }

                    "setSecureFlag" -> {
                        setSecureFlag(call.arguments as Boolean)
                    }

                    "updateDictionaries" -> {
                        val uri = (call.arguments as String).toUri()
                        copyDirectory(uri, "dictionaries")
                    }

                    "requestFloatingWindowPermission" -> {
                        requestFloatingWindowPermission()
                    }

                    else -> result.notImplemented()
                }
                result.success(0)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
            val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString() ?: ""
            methodChannel?.invokeMethod("processText", text)
        }
    }
}
