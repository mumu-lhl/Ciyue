package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.documentfile.provider.DocumentFile
import com.anggrayudi.storage.callback.SingleFileConflictCallback
import com.anggrayudi.storage.callback.SingleFolderConflictCallback
import com.anggrayudi.storage.file.DocumentFileCompat
import com.anggrayudi.storage.file.copyFolderTo
import com.anggrayudi.storage.file.openOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.launch
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.eu.mumulhl.ciyue"
    private var methodChannel: MethodChannel? = null


    private val OPEN_DOCUMENT_TREE = 0
    private val CREATE_FILE = 1
    private val GET_DIRECTORY = 2

    private val job = Job()
    private val ioScope = CoroutineScope(Dispatchers.IO + job)
    private val uiScope = CoroutineScope(Dispatchers.IO + job)

    var exportContent = ""

    private fun openDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_DOCUMENT_TREE)
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
        val directoryFile = DocumentFile.fromTreeUri(context, Uri.parse(directory))
        val file = directoryFile!!.findFile(filename)
        if (file == null) {
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.openOutputStream(context, append = false).use { outputStream ->
                outputStream!!.write(content.toByteArray())
            }

        } else {
            file.delete()
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.openOutputStream(context, append = false).use { outputStream ->
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

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (resultCode == Activity.RESULT_OK) {
            when (requestCode) {
                OPEN_DOCUMENT_TREE -> openDocumentTree(data)
                CREATE_FILE -> createFileHandler(data)
                GET_DIRECTORY -> getDirectoryHandler(data)
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

    private fun copyDictionariesDirectory(uri: Uri) {
        methodChannel!!.invokeMethod("showLoadingDialog", null)

        val documents = DocumentFile.fromTreeUri(applicationContext, uri)!!

        val cacheDir = File(applicationContext.cacheDir, "dictionaries_cache")
        if (!cacheDir.exists()) {
            cacheDir.mkdir()
        }
        val targetFolder = DocumentFileCompat.fromFile(applicationContext, cacheDir)!!

        ioScope.launch {
            documents.copyFolderTo(applicationContext,
                targetFolder,
                onConflict = object : SingleFolderConflictCallback(uiScope) {
                    override fun onParentConflict(
                        destinationFolder: DocumentFile,
                        action: ParentFolderConflictAction,
                        canMerge: Boolean
                    ) {
                        action.confirmResolution(ConflictResolution.MERGE)
                    }

                    override fun onContentConflict(
                        destinationFolder: DocumentFile,
                        conflictedFiles: MutableList<FileConflict>,
                        action: FolderContentConflictAction
                    ) {
                        val newSolution = ArrayList<FileConflict>(conflictedFiles.size)
                        conflictedFiles.forEach {
                            it.solution = SingleFileConflictCallback.ConflictResolution.REPLACE
                        }
                        newSolution.addAll(conflictedFiles)
                        action.confirmResolution(newSolution)
                    }
                }).onCompletion {
                withContext(Dispatchers.Main) {
                    methodChannel!!.invokeMethod("inputDirectory", uri.toString())
                }
            }.collect { _ -> }
        }
    }

    private fun openDocumentTree(data: Intent?) {
        data?.data?.also { uri ->
            val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION
            contentResolver.takePersistableUriPermission(
                uri, takeFlags
            )
            copyDictionariesDirectory(uri)
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
                        val uri = Uri.parse(call.arguments as String)
                        copyDictionariesDirectory(uri)
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
