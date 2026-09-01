package org.eu.mumulhl.ciyue

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.net.toUri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class EngineConfigurator(context: Context) {
    private val context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    var methodChannel: MethodChannel? = null
    private var pendingProcessText: ProcessTextRequest? = null
    private var nextProcessTextId = 0L
    var exportContent = ""

    private data class ProcessTextRequest(val id: Long, val text: String) {
        fun toMap(): Map<String, Any> = mapOf("id" to id, "text" to text)
    }

    interface Callback {
        fun onOpenDirectory() {}
        fun onOpenAudioDirectory() {}
        fun onOpenHunspellDirectory() {}
        fun onCreateFile() {}
        fun onGetDirectory() {}
        fun onSetSecureFlag(secure: Boolean) {}
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
                        result.success(pendingProcessText?.toMap())
                    }

                    "processTextHandled" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val id = (arguments?.get("id") as? Number)?.toLong()
                        if (id != null && id == pendingProcessText?.id) {
                            pendingProcessText = null
                        }
                        result.success(0)
                    }

                    "openAudioDirectory" -> {
                        callback?.onOpenAudioDirectory()
                        result.success(0)
                    }

                    "openHunspellDirectory" -> {
                        callback?.onOpenHunspellDirectory()
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
                        callback?.onSetSecureFlag(call.arguments as Boolean)
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

    fun copyDirectory(uri: Uri, destination: String) {
        val channel = methodChannel ?: return
        channel.invokeMethod("showLoadingDialog", null)

        ioExecutor.execute {
            try {
                val documents = DocumentFile.fromTreeUri(context, uri)
                    ?: throw IOException("Unable to access selected directory")
                copy(documents, File(context.filesDir, destination))

                mainHandler.post {
                    when (destination) {
                        "dictionaries" -> channel.invokeMethod("inputDirectory", uri.toString())
                        "audios" -> channel.invokeMethod("inputAudioDirectory", uri.toString())
                        "hunspell" -> channel.invokeMethod("inputHunspellDirectory", uri.toString())
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    channel.invokeMethod(
                        "copyDirectoryError",
                        error.message ?: error.javaClass.simpleName,
                    )
                }
            }
        }
    }

    private fun copy(source: DocumentFile, target: File) {
        if (!target.exists() && !target.mkdirs()) {
            throw IOException("Unable to create destination directory: $target")
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

    fun dispose() {
        mainHandler.removeCallbacksAndMessages(null)
        ioExecutor.shutdownNow()
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        callback = null
    }

    fun handleProcessText(text: String) {
        if (text.isBlank()) {
            return
        }

        // Keep the latest request until Dart acknowledges it. The method call
        // may arrive before the Dart entrypoint has installed its handler.
        val request = ProcessTextRequest(++nextProcessTextId, text)
        pendingProcessText = request
        methodChannel?.invokeMethod("processText", request.toMap())
    }
}
