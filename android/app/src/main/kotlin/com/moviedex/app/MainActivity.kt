package com.moviedex.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.moviedex.app/updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "installUpdate" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath != null && filePath.isNotEmpty()) {
                            installUpdate(filePath)
                            result.success(null)
                        } else {
                            result.error("INVALID_PATH", "Update file path was null or empty", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Method channel error: ${e.message}", e)
                result.error("ERROR", "An error occurred: ${e.message}", null)
            }
        }
    }

    private fun installUpdate(filePath: String) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                android.util.Log.e("MainActivity", "Update file does not exist: $filePath")
                return
            }
            
            val intent = Intent(Intent.ACTION_VIEW)
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(this, "${packageName}.provider", file)
            } else {
                Uri.fromFile(file)
            }
            
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
            } else {
                android.util.Log.e("MainActivity", "No activity found to handle APK installation")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error installing update: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up any running services
    }
}
