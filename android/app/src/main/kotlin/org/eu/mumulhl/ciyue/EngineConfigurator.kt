package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.storage.StorageManager
import android.provider.DocumentsContract
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

    // Held while the directory-tree picker launched by
    // "pickDictionaryDirectoryPath" is on screen; completed from
    // [handleDirectoryPathPickResult] when the picker returns, or with null
    // from [dispose] if the activity goes away first, so Dart never hangs
    // waiting for a result that will never arrive.
    private var pendingDirectoryPathResult: MethodChannel.Result? = null
    private var nextProcessTextId = 0L
    var exportContent = ""

    private data class ProcessTextRequest(val id: Long, val text: String) {
        fun toMap(): Map<String, Any> = mapOf("id" to id, "text" to text)
    }

    interface Callback {
        fun onOpenDirectory() {}
        fun onOpenAudioDirectory() {}
        fun onOpenHunspellDirectory() {}
        fun onPickDictionaryDirectoryPath() {}
        fun onCreateFile() {}
        fun onGetDirectory() {}
        fun onSetSecureFlag(secure: Boolean) {}
        fun onDismissFloatingWindow() {}
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

                    // Full flavor (#800): let Dart pick a directory tree and
                    // read it directly from the filesystem instead of going
                    // through file_selector, whose path resolution throws
                    // for non-"primary" volumes (SD cards, USB drives).
                    // Unlike the fire-and-forget pickers above, the result
                    // is held until the picker returns; see
                    // [handleDirectoryPathPickResult].
                    "pickDictionaryDirectoryPath" -> {
                        // A previous pick that never completed (activity
                        // recreated mid-pick) must not leave Dart hanging.
                        pendingDirectoryPathResult?.success(null)
                        pendingDirectoryPathResult = result
                        callback?.onPickDictionaryDirectoryPath()
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

                    "dismissFloatingWindow" -> {
                        callback?.onDismissFloatingWindow()
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

    /**
     * Completes a pending "pickDictionaryDirectoryPath" call with the
     * filesystem path of the picked tree, null when the user cancelled,
     * or an error when the tree cannot be resolved to a readable directory.
     * Dart falls back to the SAF-copy flow on any error, so resolution
     * failures must be reported, never swallowed as a success.
     */
    fun handleDirectoryPathPickResult(resultCode: Int, data: Intent?) {
        val result = pendingDirectoryPathResult ?: return
        pendingDirectoryPathResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        // Keep the grant usable for any later SAF access, mirroring
        // openDocumentTree; a failure here must not turn a resolvable
        // path into an error, since direct filesystem access does not
        // need the SAF permission.
        try {
            context.contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (_: Exception) {
        }

        try {
            val resolved = resolveTreeUriToPath(uri)
            if (resolved != null) {
                result.success(resolved.absolutePath)
            } else {
                result.error(
                    "UNRESOLVABLE_DIRECTORY",
                    "Selected directory cannot be resolved to a readable filesystem path: $uri",
                    null
                )
            }
        } catch (error: Exception) {
            result.error(
                "DIRECTORY_RESOLUTION_FAILED",
                error.message ?: error.javaClass.simpleName,
                null
            )
        }
    }

    /**
     * Resolves a tree URI returned by ACTION_OPEN_DOCUMENT_TREE to the
     * directory Dart can read with dart:io, using only stable public APIs.
     * Returns null when the URI cannot be resolved to a readable directory.
     *
     * The document ID (already decoded by [DocumentsContract]) looks like
     * `XXXX-XXXX:Sync/dict/Oxford9` for a removable volume,
     * `primary:Download/dicts` for internal storage, or a bare volume id
     * for a volume root. Only the first `:` separates the volume id from
     * the path inside the volume.
     */
    @Suppress("DEPRECATION")
    internal fun resolveTreeUriToPath(uri: Uri): File? {
        try {
            val documentId = DocumentsContract.getTreeDocumentId(uri)
            if (documentId.isBlank()) {
                return null
            }
            val colonIndex = documentId.indexOf(':')
            val volumeId = if (colonIndex >= 0) {
                documentId.substring(0, colonIndex)
            } else {
                documentId
            }
            val relativePath = if (colonIndex >= 0) {
                documentId.substring(colonIndex + 1)
            } else {
                ""
            }
            if (volumeId.isEmpty()) {
                return null
            }

            val volumeRoot = if (volumeId == "primary") {
                // Same mapping file_selector uses today: internal-storage
                // behavior must stay byte-identical.
                Environment.getExternalStorageDirectory()
            } else {
                // Cross-check against the volumes the system knows about:
                // a volume the system reports as ejected is genuinely
                // unavailable, so fail fast instead of probing a stale
                // mount point. A volume the system does not list (or an
                // older SDK without this API) is NOT a failure: the
                // /storage/<uuid> construction plus the existence check
                // below is the deciding verification. No hidden or
                // reflection APIs are used; StorageVolume has no stable
                // public directory accessor, so its path is never read.
                findRemovableVolumeRoot(volumeId)
                    ?: if (isStorageVolumeEjected(volumeId)) {
                        return null
                    } else {
                        File("/storage", volumeId)
                    }
            }

            var resolved = volumeRoot
            for (segment in relativePath.split('/')) {
                // Tolerate trailing/duplicate slashes; never let a crafted
                // document ID escape the volume root.
                if (segment.isEmpty() || segment == ".") {
                    continue
                }
                if (segment == "..") {
                    return null
                }
                resolved = File(resolved, segment)
            }

            // Verify before reporting success so Dart never receives a
            // path it cannot scan: the existence check also covers the
            // /storage/<uuid> fallback when no files-dir entry matched.
            if (!resolved.isDirectory || !resolved.canRead()) {
                return null
            }
            if (resolved.list() == null) {
                return null
            }
            return resolved
        } catch (_: Exception) {
            return null
        }
    }

    /**
     * Derives a removable volume's filesystem root from the app-specific
     * external files directories, which look like
     * `/storage/<uuid>/Android/data/<package>/files`. Strips the
     * `/Android/data/...` suffix from the entry whose volume matches.
     * Returns null when no entry matches, leaving the caller to try the
     * conventional `/storage/<uuid>` location (verified before use).
     */
    private fun findRemovableVolumeRoot(volumeId: String): File? {
        try {
            val filesDirs = context.getExternalFilesDirs(null)
            for (dir in filesDirs) {
                val path = dir?.absolutePath ?: continue
                val markerIndex = path.indexOf("/Android/data/")
                if (markerIndex < 0) {
                    continue
                }
                val prefix = path.substring(0, markerIndex)
                if (prefix.substringAfterLast('/') == volumeId) {
                    return File(prefix)
                }
            }
        } catch (_: Exception) {
            // Fall through: the caller tries /storage/<uuid> next.
        }
        return null
    }

    private fun isStorageVolumeEjected(volumeId: String): Boolean {
        // getStorageVolumes()/StorageVolume.state need API 24. Without
        // this guard, calling them on older devices throws NoSuchMethodError,
        // which catch (Exception) below would not catch.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return false
        }
        return try {
            val storageManager =
                context.getSystemService(StorageManager::class.java) ?: return false
            storageManager.storageVolumes.any { volume ->
                volume.uuid == volumeId &&
                    volume.state != Environment.MEDIA_MOUNTED
            }
        } catch (_: Exception) {
            false
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
        pendingDirectoryPathResult?.success(null)
        pendingDirectoryPathResult = null
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
