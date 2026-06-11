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
import com.baidu.carlife.platform.CLPlatformCallback
import com.baidu.carlife.platform.CLPlatformManager
import com.baidu.carlife.platform.model.CLAlbum
import com.baidu.carlife.platform.model.CLSong
import com.baidu.carlife.platform.model.CLSongData
import com.baidu.carlife.platform.request.CLGetAlbumListReq
import com.baidu.carlife.platform.request.CLGetSongDataReq
import com.baidu.carlife.platform.request.CLGetSongListReq
import com.baidu.carlife.platform.request.CLRequest
import com.baidu.carlife.platform.response.CLGetAlbumListResp
import com.baidu.carlife.platform.response.CLGetSongDataResp
import com.baidu.carlife.platform.response.CLGetSongListResp
import com.baidu.carlife.platform.response.CLResponse
import com.baidu.carlife.platform.response.CLUnsupportAPIResp
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList

class MainActivity : AudioServiceActivity() {
    private val installerChannelName = "music_car_app/app_installer"
    private val carLifeChannelName = "music_car_app/carlife"
    private val downloadIds = mutableSetOf<Long>()
    private val installingDownloadIds = mutableSetOf<Long>()
    private val downloadPollHandler = Handler(Looper.getMainLooper())
    private val downloadPollTasks = mutableMapOf<Long, Runnable>()
    private var downloadReceiver: BroadcastReceiver? = null
    private var lastCarLifePlaybackContext: Map<String, Any?> = emptyMap()
    private var carLifeChannel: MethodChannel? = null
    private val carLifeManager: CLPlatformManager by lazy { CLPlatformManager.getInstance() }
    private var carLifeSdkInitialized = false
    private var carLifeSdkConnected = false
    private var lastCarLifeSdkError = ""
    private var lastCarLifeControlResult = ""

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

        carLifeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            carLifeChannelName,
        )
        carLifeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(carLifeStatus())
                "openCarLife" -> result.success(openCarLife())
                "syncPlaybackContext" -> {
                    val context = call.arguments as? Map<*, *>
                    result.success(syncPlaybackContext(context))
                }
                "sendLyricBroadcast" -> {
                    val lyric = call.argument<String>("lyric").orEmpty()
                    val title = call.argument<String>("title").orEmpty()
                    val artist = call.argument<String>("artist").orEmpty()
                    val album = call.argument<String>("album").orEmpty()
                    val duration = call.argument<Number>("duration")?.toLong() ?: 0L
                    val position = call.argument<Number>("position")?.toLong() ?: 0L
                    val playing = call.argument<Boolean>("playing") ?: false
                    sendLyricBroadcast(lyric, title, artist, album, duration, position, playing)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun carLifeStatus(): Map<String, Any?> {
        val packageName = findInstalledCarLifePackage()
        val launchIntent = packageName?.let { packageManager.getLaunchIntentForPackage(it) }
        val appKeyConfigured = BuildConfig.CARLIFE_APP_KEY.isNotBlank()
        return mapOf(
            "available" to (packageName != null),
            "installed" to (packageName != null),
            "launchable" to (launchIntent != null),
            "sdkLinked" to true,
            "appKeyConfigured" to appKeyConfigured,
            "sdkInitialized" to carLifeSdkInitialized,
            "sdkConnected" to carLifeSdkConnected,
            "packageName" to (packageName ?: ""),
            "integrationMode" to if (appKeyConfigured) "sdk_platform" else "sdk_platform_unconfigured",
            "reason" to carLifeStatusReason(packageName, appKeyConfigured),
            "lastControlResult" to lastCarLifeControlResult,
        )
    }

    private fun carLifeStatusReason(packageName: String?, appKeyConfigured: Boolean): String {
        if (packageName == null) {
            return "package_not_found"
        }
        if (!appKeyConfigured) {
            return "app_key_missing"
        }
        if (carLifeSdkConnected) {
            return "sdk_connected"
        }
        if (carLifeSdkInitialized) {
            return "sdk_initialized"
        }
        return lastCarLifeSdkError.ifBlank { "sdk_ready" }
    }

    private fun openCarLife(): Map<String, Any?> {
        ensureCarLifeSdkInitialized()
        if (CLPlatformManager.jumpToCarlife(this)) {
            return mapOf(
                "launched" to true,
                "packageName" to (findInstalledCarLifePackage() ?: primaryCarLifePackage),
                "reason" to "sdk_jump",
            )
        }
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

    private fun syncPlaybackContext(context: Map<*, *>?): Map<String, Any?> {
        val packageName = findInstalledCarLifePackage()
        val normalizedContext = normalizeCarLifePlaybackContext(context)
        lastCarLifePlaybackContext = normalizedContext
        ensureCarLifeSdkInitialized()
        val queue = normalizedContext["queue"] as? List<*>
        return mapOf(
            "supported" to carLifeSdkInitialized,
            "packageName" to (packageName ?: ""),
            "integrationMode" to if (BuildConfig.CARLIFE_APP_KEY.isNotBlank()) {
                "sdk_platform"
            } else {
                "sdk_platform_unconfigured"
            },
            "sdkLinked" to true,
            "appKeyConfigured" to BuildConfig.CARLIFE_APP_KEY.isNotBlank(),
            "sdkInitialized" to carLifeSdkInitialized,
            "sdkConnected" to carLifeSdkConnected,
            "reason" to if (carLifeSdkInitialized) {
                if (carLifeSdkConnected) "sdk_connected" else "sdk_initialized"
            } else {
                carLifeStatusReason(packageName, BuildConfig.CARLIFE_APP_KEY.isNotBlank())
            },
            "syncedQueueLength" to (queue?.size ?: 0),
            "syncedQueueIndex" to (normalizedContext["queueIndex"] as? Int ?: -1),
            "syncedTitle" to (normalizedContext["title"] as? String ?: ""),
            "lastControlResult" to lastCarLifeControlResult,
        )
    }

    private fun sendLyricBroadcast(
        lyric: String,
        title: String,
        artist: String,
        album: String,
        duration: Long,
        position: Long,
        playing: Boolean
    ) {
        val flagIncludeBackground = 0x01000000 // Intent.FLAG_RECEIVER_INCLUDE_BACKGROUND

        // 1. 通用/系统广播
        val intentKuGou = Intent("com.android.music.metachanged").apply {
            addFlags(flagIncludeBackground)
            putExtra("lyric", lyric)
            putExtra("track", title)
            putExtra("artist", artist)
            putExtra("album", album)
            putExtra("duration", duration)
            putExtra("position", position)
            putExtra("playing", playing)
        }
        sendBroadcast(intentKuGou)

        // 2. 酷狗专有广播
        val intentKuGouSpecial = Intent("com.kugou.android.music.metachanged").apply {
            addFlags(flagIncludeBackground)
            putExtra("lyric", lyric)
            putExtra("track", title)
            putExtra("artist", artist)
            putExtra("album", album)
            putExtra("duration", duration)
            putExtra("position", position)
            putExtra("playing", playing)
        }
        sendBroadcast(intentKuGouSpecial)

        // 3. QQ音乐广播
        val intentQQ = Intent("com.tencent.qqmusic.ACTION_LYRIC").apply {
            addFlags(flagIncludeBackground)
            putExtra("lyric", lyric)
            putExtra("track", title)
            putExtra("song_name", title)
            putExtra("artist", artist)
            putExtra("singer_name", artist)
            putExtra("playing", playing)
            putExtra("position", position)
            putExtra("lyric_time", position)
        }
        sendBroadcast(intentQQ)

        // 4. 网易云广播
        val intentNetease = Intent("com.netease.cloudmusic.music.lyric").apply {
            addFlags(flagIncludeBackground)
            putExtra("lyric", lyric)
            putExtra("track", title)
            putExtra("artist", artist)
            putExtra("playing", playing)
            putExtra("position", position)
            putExtra("lyric_time", position)
        }
        sendBroadcast(intentNetease)
    }

    private fun ensureCarLifeSdkInitialized(): Boolean {
        if (carLifeSdkInitialized) {
            return true
        }
        val appKey = BuildConfig.CARLIFE_APP_KEY.trim()
        if (appKey.isEmpty()) {
            lastCarLifeSdkError = "app_key_missing"
            return false
        }
        val initIntent = Intent().apply {
            putExtra("targetpackagename", primaryCarLifePackage)
            putExtra("targetserviceactionname", primaryCarLifeService)
            putExtra("targetactivityactionname", primaryCarLifeAction)
        }
        carLifeManager.enableLog(true)
        carLifeSdkInitialized = carLifeManager.init(
            applicationContext,
            appKey,
            carLifeCallback,
            initIntent,
        )
        if (!carLifeSdkInitialized && lastCarLifeSdkError.isBlank()) {
            lastCarLifeSdkError = "sdk_init_failed"
        }
        return carLifeSdkInitialized
    }

    private val carLifeCallback = object : CLPlatformCallback {
        override fun onConnected() {
            carLifeSdkConnected = true
            lastCarLifeSdkError = ""
        }

        override fun onCarlifeRequest(request: CLRequest) {
            when (request) {
                is CLGetAlbumListReq -> sendCarLifeAlbumList(request)
                is CLGetSongListReq -> sendCarLifeSongList(request)
                is CLGetSongDataReq -> sendCarLifeSongData(request)
                else -> carLifeManager.sendResp(CLUnsupportAPIResp(request.requestId))
            }
        }

        override fun onCarlifeResponse(response: CLResponse) = Unit

        override fun onCarlifeError(errorNo: Int, errorMsg: String) {
            carLifeSdkConnected = false
            lastCarLifeSdkError = "sdk_error_$errorNo:${errorMsg.trim()}"
        }
    }

    private fun sendCarLifeAlbumList(request: CLGetAlbumListReq) {
        val queue = carLifeQueueItems()
        val album = CLAlbum().apply {
            albumId = currentCarLifeAlbumId
            albumName = "当前播放队列"
            artistId = stringArgument(lastCarLifePlaybackContext["source"]).ifBlank { "music_car_app" }
            artistName = stringArgument(lastCarLifePlaybackContext["artist"]).ifBlank { "车载音乐" }
            coverUrl = stringArgument(lastCarLifePlaybackContext["coverUrl"])
            songCount = queue.size
        }
        val response = CLGetAlbumListResp().apply {
            requestId = request.requestId
            errorNo = CLResponse.ERROR_NONE
            errorMsg = ""
            albumList = arrayListOf(album)
        }
        carLifeManager.sendResp(response)
    }

    private fun sendCarLifeSongList(request: CLGetSongListReq) {
        val queue = carLifeQueueItems()
        val requestedPage = if (request.pn > 0) request.pn else 1
        val requestedSize = if (request.rn > 0) request.rn else queue.size.coerceAtLeast(1)
        val fromIndex = ((requestedPage - 1) * requestedSize).coerceIn(0, queue.size)
        val toIndex = (fromIndex + requestedSize).coerceAtMost(queue.size)
        val response = CLGetSongListResp().apply {
            requestId = request.requestId
            errorNo = CLResponse.ERROR_NONE
            errorMsg = ""
            version = if (request.version > 0) request.version else 1
            songListId = request.songListId?.ifBlank { currentCarLifeAlbumId } ?: currentCarLifeAlbumId
            playSongId = currentCarLifeSongId()
            pn = requestedPage
            rn = requestedSize
            total = queue.size
            songList = ArrayList(queue.subList(fromIndex, toIndex).map(::carLifeSongFromQueueItem))
        }
        carLifeManager.sendResp(response)
    }

    private fun sendCarLifeSongData(request: CLGetSongDataReq) {
        val dispatched = dispatchCarLifeSelectQueueItem(request.songId.orEmpty())
        sendCarLifeSongDataUnsupported(
            request,
            if (dispatched) {
                "phone_playback_dispatched_audio_stream_not_available"
            } else {
                "queue_item_not_found_audio_stream_not_available"
            },
        )
    }

    private fun sendCarLifeSongDataUnsupported(request: CLGetSongDataReq, reason: String) {
        val response = CLGetSongDataResp().apply {
            requestId = request.requestId
            errorNo = CLResponse.ERROR_UNKNOWN
            errorMsg = reason
            songData = CLSongData().apply {
                songId = request.songId.orEmpty()
                tag = CLSongData.TAG_END
                offset = 0L
                totalSize = 0L
                data = null
                len = 0
            }
        }
        carLifeManager.sendResp(response)
    }

    private fun dispatchCarLifeSelectQueueItem(carLifeSongId: String): Boolean {
        val queue = carLifeQueueItems()
        val queueIndex = queueIndexForCarLifeSongId(carLifeSongId, queue)
        if (queueIndex < 0) {
            lastCarLifeControlResult = "queue_item_not_found"
            return false
        }
        val item = queue[queueIndex]
        val payload = mapOf(
            "action" to "selectQueueItem",
            "queueIndex" to queueIndex,
            "source" to stringArgument(item["source"]),
            "songId" to stringArgument(item["id"]),
        )
        downloadPollHandler.post {
            carLifeChannel?.invokeMethod(
                "onCarLifeControl",
                payload,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val resultMap = result as? Map<*, *>
                        val handled = resultMap?.get("handled") == true
                        val reason = stringArgument(resultMap?.get("reason"))
                        lastCarLifeControlResult = if (handled) {
                            reason.ifBlank { "handled" }
                        } else {
                            reason.ifBlank { "unhandled" }
                        }
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        lastCarLifeControlResult = "control_error:$errorCode"
                    }

                    override fun notImplemented() {
                        lastCarLifeControlResult = "control_not_implemented"
                    }
                },
            )
        }
        lastCarLifeControlResult = "select_dispatched"
        return true
    }

    private fun carLifeQueueItems(): List<Map<String, Any?>> {
        val queue = lastCarLifePlaybackContext["queue"] as? List<*> ?: emptyList<Any>()
        return queue.mapNotNull { item ->
            @Suppress("UNCHECKED_CAST")
            item as? Map<String, Any?>
        }
    }

    private fun carLifeSongFromQueueItem(item: Map<String, Any?>): CLSong {
        val source = stringArgument(item["source"])
        val id = stringArgument(item["id"])
        return CLSong().apply {
            this.id = carLifeSongId(source, id)
            name = stringArgument(item["name"]).ifBlank { "未知歌曲" }
            albumName = stringArgument(item["album"])
            albumId = currentCarLifeAlbumId
            albumArtistId = source.ifBlank { "music_car_app" }
            albumArtistName = stringArgument(item["artist"])
            coverUrl = stringArgument(item["cover"])
            duration = intArgument(item["duration"], 0).coerceAtLeast(0).toString()
            mediaUrl = carLifeMediaUrlForQueueItem(source, id, item)
            totalSize = 0L
            songType = CLSong.CL_SONG_TYPE_DEFAULT
        }
    }

    private fun carLifeMediaUrlForQueueItem(
        source: String,
        id: String,
        item: Map<String, Any?>,
    ): String {
        val itemAudioUrl = stringArgument(item["audioUrl"])
        if (itemAudioUrl.isNotBlank()) {
            return itemAudioUrl
        }
        val currentAudioUrl = stringArgument(lastCarLifePlaybackContext["audioUrl"])
        val currentSource = stringArgument(lastCarLifePlaybackContext["source"])
        val currentSongId = stringArgument(lastCarLifePlaybackContext["songId"])
        return if (
            currentAudioUrl.isNotBlank() &&
            source == currentSource &&
            id == currentSongId
        ) {
            currentAudioUrl
        } else {
            ""
        }
    }

    private fun currentCarLifeSongId(): String {
        val source = stringArgument(lastCarLifePlaybackContext["source"])
        val songId = stringArgument(lastCarLifePlaybackContext["songId"])
        if (source.isNotBlank() && songId.isNotBlank()) {
            return carLifeSongId(source, songId)
        }
        val queue = carLifeQueueItems()
        val index = intArgument(lastCarLifePlaybackContext["queueIndex"], -1)
        if (index >= 0 && index < queue.size) {
            return carLifeSongId(
                stringArgument(queue[index]["source"]),
                stringArgument(queue[index]["id"]),
            )
        }
        return ""
    }

    private fun carLifeSongId(source: String, id: String): String {
        return if (source.isBlank()) id else "$source:$id"
    }

    private fun queueIndexForCarLifeSongId(
        carLifeSongId: String,
        queue: List<Map<String, Any?>>,
    ): Int {
        if (carLifeSongId.isBlank()) {
            return -1
        }
        return queue.indexOfFirst { item ->
            val source = stringArgument(item["source"])
            val id = stringArgument(item["id"])
            carLifeSongId(source, id) == carLifeSongId || id == carLifeSongId
        }
    }

    private fun normalizeCarLifePlaybackContext(context: Map<*, *>?): Map<String, Any?> {
        if (context == null) {
            return emptyMap()
        }
        val queue = (context["queue"] as? List<*>)
            ?.mapNotNull { item -> normalizeCarLifeQueueItem(item as? Map<*, *>) }
            ?: emptyList()
        return mapOf(
            "title" to stringArgument(context["title"]),
            "artist" to stringArgument(context["artist"]),
            "album" to stringArgument(context["album"]),
            "coverUrl" to stringArgument(context["coverUrl"]),
            "audioUrl" to stringArgument(context["audioUrl"]),
            "source" to stringArgument(context["source"]),
            "songId" to stringArgument(context["songId"]),
            "playing" to (context["playing"] == true),
            "durationMs" to longArgument(context["durationMs"]),
            "positionMs" to longArgument(context["positionMs"]),
            "queueIndex" to intArgument(context["queueIndex"], -1),
            "queue" to queue,
        )
    }

    private fun normalizeCarLifeQueueItem(item: Map<*, *>?): Map<String, Any?>? {
        if (item == null) {
            return null
        }
        val id = stringArgument(item["id"])
        val source = stringArgument(item["source"])
        if (id.isEmpty() || source.isEmpty()) {
            return null
        }
        return mapOf(
            "id" to id,
            "source" to source,
            "name" to stringArgument(item["name"]),
            "artist" to stringArgument(item["artist"]),
            "album" to stringArgument(item["album"]),
            "duration" to intArgument(item["duration"], 0),
            "cover" to stringArgument(item["cover"]),
            "audioUrl" to stringArgument(item["audioUrl"]),
        )
    }

    private fun stringArgument(value: Any?): String {
        return value?.toString()?.trim().orEmpty()
    }

    private fun intArgument(value: Any?, defaultValue: Int = 0): Int {
        return when (value) {
            is Int -> value
            is Number -> value.toInt()
            is String -> value.toDoubleOrNull()?.toInt() ?: defaultValue
            else -> defaultValue
        }
    }

    private fun longArgument(value: Any?, defaultValue: Long = 0L): Long {
        return when (value) {
            is Long -> value
            is Number -> value.toLong()
            is String -> value.toDoubleOrNull()?.toLong() ?: defaultValue
            else -> defaultValue
        }
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
        private const val currentCarLifeAlbumId = "music_car_app_current_queue"
        private const val primaryCarLifePackage = "com.baidu.carlife"
        private const val primaryCarLifeService =
            "com.baidu.carlife.platform.service.CLPlatformService"
        private const val primaryCarLifeAction = "com.baidu.carlife.Action.CarlifePlatform"
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
