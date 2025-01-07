package org.eu.mumulhl.ciyue

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import androidx.documentfile.provider.DocumentFile
import com.anggrayudi.storage.callback.SingleFileConflictCallback
import com.anggrayudi.storage.callback.SingleFolderConflictCallback
import com.anggrayudi.storage.result.SingleFolderResult
import com.anggrayudi.storage.file.DocumentFileCompat
import com.anggrayudi.storage.file.copyFolderTo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.onCompletion
import kotlinx.coroutines.launch
import timber.log.Timber
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.eu.mumulhl.ciyue"
    private var methodChannel: MethodChannel? = null
    private val REQUEST_CODE_OPEN_DOCUMENT_TREE = 0

    private val job = Job()
    private val ioScope = CoroutineScope(Dispatchers.IO + job)
    private val uiScope = CoroutineScope(Dispatchers.IO + job)

    private fun openDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, REQUEST_CODE_OPEN_DOCUMENT_TREE)
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, resultData: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, resultData)

        if (requestCode == REQUEST_CODE_OPEN_DOCUMENT_TREE && resultCode == Activity.RESULT_OK) {
            resultData?.data?.also { uri ->
                val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION
                applicationContext.contentResolver.takePersistableUriPermission(uri, takeFlags)

                val documents = DocumentFile.fromTreeUri(applicationContext, uri)!!

                val cacheDir = File(applicationContext.cacheDir, "dictionaries_cache")
                if (!cacheDir.exists()) {
                    cacheDir.mkdir()
                }
                val targetFolder = DocumentFileCompat.fromFile(applicationContext, cacheDir)!!

                ioScope.launch {
                    documents.copyFolderTo(
                        applicationContext,
                        targetFolder,
                        onConflict = object : SingleFolderConflictCallback(uiScope) {
                            override fun onParentConflict(
                                destinationFolder: DocumentFile,
                                action: ParentFolderConflictAction,
                                canMerge: Boolean
                            ) {
                                action.confirmResolution(ConflictResolution.SKIP)
                            }

                            override fun onContentConflict(
                                destinationFolder: DocumentFile,
                                conflictedFiles: MutableList<FileConflict>,
                                action: FolderContentConflictAction
                            ) {
                                val newSolution = ArrayList<FileConflict>(conflictedFiles.size)
                                conflictedFiles.forEach {
                                    it.solution = SingleFileConflictCallback.ConflictResolution.SKIP
                                }
                                newSolution.addAll(conflictedFiles)
                                action.confirmResolution(newSolution)

                            }
                        }).onCompletion {
                    }.collect { _ ->
                    }

                }
                methodChannel?.invokeMethod("inputDirectory", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            if (call.method == "openDirectory") {
                openDirectory()
                result.success(0)
            } else {
                result.notImplemented()
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
