package com.sy110.music_car_app

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val installerChannelName = "music_car_app/app_installer"
    private val carLifeChannelName = "music_car_app/carlife"
    private val downloadIds = mutableSetOf<Long>()
    private val installingDownloadIds = mutableSetOf<Long>()
    private val downloadPollHandler = Handler(Looper.getMainLooper())
    private val downloadPollTasks = mutableMapOf<Long, Runnable>()
    private var downloadReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            installerChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "supportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                "downloadAndInstallApk" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val fileName = call.argument<String>("fileName")?.trim().orEmpty()
                    if (url.isEmpty()) {
                        result.error("missing_url", "APK 下载地址为空。", null)
                        return@setMethodCallHandler
                    }
                    downloadAndInstallApk(url, fileName, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            carLifeChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(carLifeStatus())
                "openCarLife" -> result.success(openCarLife())
                "syncPlaybackContext" -> result.success(syncPlaybackContext())
                else -> result.notImplemented()
            }
        }
    }

    private fun carLifeStatus(): Map<String, Any?> {
        val packageName = findInstalledCarLifePackage()
        val launchIntent = packageName?.let { packageManager.getLaunchIntentForPackage(it) }
        return mapOf(
            "available" to (packageName != null),
            "installed" to (packageName != null),
            "launchable" to (launchIntent != null),
            "sdkLinked" to false,
            "packageName" to (packageName ?: ""),
            "integrationMode" to "package_probe",
            "reason" to if (packageName == null) "package_not_found" else "sdk_missing",
        )
    }

    private fun openCarLife(): Map<String, Any?> {
        val packageName = findInstalledCarLifePackage()
        if (packageName != null) {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                return try {
                    startActivity(launchIntent)
                    mapOf(
                        "launched" to true,
                        "packageName" to packageName,
                        "reason" to "launched",
                    )
                } catch (_: Exception) {
                    mapOf(
                        "launched" to false,
                        "packageName" to packageName,
                        "reason" to "launch_failed",
                    )
                }
            }
        }

        val marketIntent = Intent(
            Intent.ACTION_VIEW,
            Uri.parse("market://details?id=$primaryCarLifePackage"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(marketIntent)
            mapOf(
                "launched" to true,
                "packageName" to primaryCarLifePackage,
                "reason" to "market_opened",
            )
        } catch (_: Exception) {
            try {
                startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        Uri.parse("https://carlife.baidu.com/"),
                    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                mapOf(
                    "launched" to true,
                    "packageName" to primaryCarLifePackage,
                    "reason" to "web_opened",
                )
            } catch (_: Exception) {
                mapOf(
                    "launched" to false,
                    "packageName" to primaryCarLifePackage,
                    "reason" to "not_installed",
                )
            }
        }
    }

    private fun syncPlaybackContext(): Map<String, Any?> {
        val packageName = findInstalledCarLifePackage()
        return mapOf(
            "supported" to false,
            "packageName" to (packageName ?: ""),
            "reason" to "sdk_missing",
        )
    }

    private fun findInstalledCarLifePackage(): String? {
        return carLifePackageCandidates.firstOrNull { candidate ->
            isPackageInstalled(candidate)
        }
    }

    private fun isPackageInstalled(candidate: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    candidate,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(candidate, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun downloadAndInstallApk(
        url: String,
        fileName: String,
        result: MethodChannel.Result,
    ) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            val settingsIntent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(settingsIntent)
            result.error(
                "install_permission_required",
                "请先允许本应用安装未知来源应用，然后重新点击立即更新。",
                null,
            )
            return
        }

        try {
            val apkName = sanitizeApkFileName(fileName)
            val request = DownloadManager.Request(Uri.parse(url))
                .setTitle(apkName)
                .setDescription("正在下载车载音乐更新包")
                .setMimeType("application/vnd.android.package-archive")
                .setNotificationVisibility(
                    DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
                )
                .setDestinationInExternalFilesDir(
                    this,
                    Environment.DIRECTORY_DOWNLOADS,
                    apkName,
                )

            val downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
            val downloadId = downloadManager.enqueue(request)
            downloadIds.add(downloadId)
            ensureDownloadReceiver()
            scheduleDownloadPoll(downloadId)
            result.success(null)
        } catch (error: Exception) {
            result.error(
                "download_failed",
                error.message ?: "下载安装包失败。",
                null,
            )
        }
    }

    private fun ensureDownloadReceiver() {
        if (downloadReceiver != null) {
            return
        }

        downloadReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val downloadId = intent.getLongExtra(
                    DownloadManager.EXTRA_DOWNLOAD_ID,
                    -1L,
                )
                if (!downloadIds.remove(downloadId)) {
                    return
                }
                if (!installDownloadedApk(downloadId)) {
                    downloadIds.add(downloadId)
                    scheduleDownloadPoll(downloadId)
                }
            }
        }

        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(downloadReceiver, filter)
        }
    }

    private fun scheduleDownloadPoll(downloadId: Long, attempt: Int = 0) {
        if (!downloadIds.contains(downloadId) || downloadPollTasks.containsKey(downloadId)) {
            return
        }

        val task = Runnable {
            downloadPollTasks.remove(downloadId)
            if (!downloadIds.contains(downloadId)) {
                return@Runnable
            }

            when (downloadStatus(downloadId)) {
                DownloadManager.STATUS_SUCCESSFUL -> {
                    downloadIds.remove(downloadId)
                    if (!installDownloadedApk(downloadId)) {
                        downloadIds.add(downloadId)
                        scheduleDownloadPoll(downloadId, attempt + 1)
                    }
                }
                DownloadManager.STATUS_FAILED -> {
                    downloadIds.remove(downloadId)
                }
                else -> {
                    if (attempt < 1800) {
                        scheduleDownloadPoll(downloadId, attempt + 1)
                    }
                }
            }
        }

        downloadPollTasks[downloadId] = task
        downloadPollHandler.postDelayed(task, 2_000L)
    }

    private fun downloadStatus(downloadId: Long): Int? {
        val downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(downloadId)
        downloadManager.query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return null
            }

            val statusColumn = cursor.getColumnIndex(DownloadManager.COLUMN_STATUS)
            return cursor.getInt(statusColumn)
        }
        return null
    }

    private fun installDownloadedApk(downloadId: Long): Boolean {
        if (!installingDownloadIds.add(downloadId)) {
            return true
        }

        if (downloadStatus(downloadId) != DownloadManager.STATUS_SUCCESSFUL) {
            installingDownloadIds.remove(downloadId)
            return false
        }

        val task = downloadPollTasks.remove(downloadId)
        if (task != null) {
            downloadPollHandler.removeCallbacks(task)
        }

        val downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val apkUri = downloadManager.getUriForDownloadedFile(downloadId)
        if (apkUri == null) {
            installingDownloadIds.remove(downloadId)
            return false
        }
        val installIntent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = apkUri
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            putExtra(Intent.EXTRA_RETURN_RESULT, false)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val fallbackIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        return try {
            startActivity(installIntent)
            true
        } catch (_: Exception) {
            try {
                startActivity(fallbackIntent)
                true
            } catch (_: Exception) {
                installingDownloadIds.remove(downloadId)
                false
            }
        }
    }

    private fun sanitizeApkFileName(fileName: String): String {
        val normalized = fileName
            .ifBlank { "music-car-app-update.apk" }
            .replace(Regex("[^A-Za-z0-9._-]"), "-")
        return if (normalized.endsWith(".apk", ignoreCase = true)) {
            normalized
        } else {
            "$normalized.apk"
        }
    }

    companion object {
        private const val primaryCarLifePackage = "com.baidu.carlife"
        private val carLifePackageCandidates = listOf(
            primaryCarLifePackage,
            "com.baidu.carlifevehicle",
            "com.baidu.carlifeauto",
        )
    }

    override fun onDestroy() {
        downloadReceiver?.let { receiver ->
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
        }
        downloadReceiver = null
        downloadPollTasks.values.forEach { task ->
            downloadPollHandler.removeCallbacks(task)
        }
        downloadPollTasks.clear()
        super.onDestroy()
    }
}
