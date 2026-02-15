package org.eu.mumulhl.ciyue

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.WindowManager
import androidx.core.net.toUri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File

class EngineConfigurator(private val context: Context) {
    var methodChannel: MethodChannel? = null
    var pendingProcessText: String? = null
    var exportContent = ""

    interface Callback {
        fun onOpenDirectory()
        fun onOpenAudioDirectory()
        fun onCreateFile()
        fun onGetDirectory()
    }

    var callback: Callback? = null

    fun configure(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.eu.mumulhl.ciyue").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDirectory" -> {
                        callback?.onOpenDirectory()
                        result.success(0)
                    }

                    "getPendingProcessText" -> {
                        result.success(pendingProcessText)
                        pendingProcessText = null
                    }

                    "openAudioDirectory" -> {
                        callback?.onOpenAudioDirectory()
                        result.success(0)
                    }

                    "createFile" -> {
                        exportContent = call.arguments as String
                        callback?.onCreateFile()
                        result.success(0)
                    }

                    "getDirectory" -> {
                        callback?.onGetDirectory()
                        result.success(0)
                    }

                    "writeFile" -> {
                        val arguments = call.arguments as Map<*, *>
                        writeFile(
                            arguments["directory"] as String,
                            arguments["filename"] as String,
                            arguments["content"] as String
                        )
                        result.success(0)
                    }

                    "setSecureFlag" -> {
                        setSecureFlag(call.arguments as Boolean)
                        result.success(0)
                    }

                    "updateDictionaries" -> {
                        val uri = (call.arguments as String).toUri()
                        copyDirectory(uri, "dictionaries")
                        result.success(0)
                    }

                    else -> result.notImplemented()
                }
            }
        }
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
        // This might need activity context, but we can try to use window flags if possible 
        // Or leave it to MainActivity if it requires an Activity.
    }

    fun copyDirectory(uri: Uri, destination: String) {
        methodChannel?.invokeMethod("showLoadingDialog", null)

        val documents = DocumentFile.fromTreeUri(context, uri)!!
        copy(documents, File(context.filesDir, destination))

        when (destination) {
            "dictionaries" -> methodChannel?.invokeMethod("inputDirectory", uri.toString())
            "audios" -> methodChannel?.invokeMethod("inputAudioDirectory", uri.toString())
        }
    }

    private fun copy(source: DocumentFile, target: File) {
        if (!target.exists()) {
            target.mkdirs()
        }
        source.listFiles().forEach { file ->
            if (file.isFile) {
                BufferedInputStream(context.contentResolver.openInputStream(file.uri)).use { input ->
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

    fun handleProcessText(text: String) {
        if (methodChannel != null) {
            methodChannel?.invokeMethod("processText", text)
        } else {
            pendingProcessText = text
        }
    }
}
