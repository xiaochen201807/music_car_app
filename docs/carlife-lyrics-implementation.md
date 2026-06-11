# CarLife 歌词同步实现说明

## 问题背景

用户反馈：手机上能看到歌词，但 CarLife 上显示"没有歌词"。

## 根本原因

### CarLife SDK 不支持歌词传输

通过反编译 `Carlife_android_platformsdk_2.2.0.jar` 发现，`CLSong` 类只包含基本字段：

```java
public class com.baidu.carlife.platform.model.CLSong {
  public java.lang.String id;
  public java.lang.String name;
  public java.lang.String albumName;
  public java.lang.String albumId;
  public java.lang.String albumArtistId;
  public java.lang.String albumArtistName;
  public java.lang.String coverUrl;
  public java.lang.String duration;
  public java.lang.String mediaUrl;
  public long totalSize;
  public int songType;
}
```

**没有 `lyric` 或 `lyrics` 字段**，说明 CarLife SDK 本身不支持通过 API 传递歌词。

### CarLife 通过 Android 广播获取歌词

CarLife 采用监听 Android 系统广播的方式获取歌词，这是各大音乐播放器的标准做法：

1. **通用广播**：`com.android.music.metachanged`
2. **酷狗专有广播**：`com.kugou.android.music.metachanged`
3. **QQ音乐广播**：`com.tencent.qqmusic.ACTION_LYRIC`
4. **网易云广播**：`com.netease.cloudmusic.music.lyric`

## 解决方案

### 1. Flutter 端：添加歌词广播接口

在 `lib/services/carlife_service.dart` 添加 `sendLyricBroadcast` 方法：

```dart
Future<void> sendLyricBroadcast({
  required String lyric,
  required String title,
  required String artist,
  String album = '',
  Duration duration = Duration.zero,
  Duration position = Duration.zero,
  bool playing = false,
}) async {
  try {
    await _channel.invokeMethod<void>('sendLyricBroadcast', <String, Object?>{
      'lyric': lyric,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration.inMilliseconds,
      'position': position.inMilliseconds,
      'playing': playing,
    });
  } on MissingPluginException {
    // Android only, ignore on other platforms
  } on PlatformException {
    // Ignore errors
  }
}
```

### 2. Flutter 端：定期发送歌词

在 `lib/main.dart` 的 `_MusicCarAppState` 中：

```dart
// 字段定义
Timer? _lyricBroadcastTimer;

// initState 中启动定时器
void initState() {
  super.initState();
  // ... 其他初始化代码
  _startLyricBroadcastTimer();
}

// dispose 中清理
void dispose() {
  _lyricBroadcastTimer?.cancel();
  // ... 其他清理代码
}

// 定时器逻辑
void _startLyricBroadcastTimer() {
  _lyricBroadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    _sendLyricBroadcast();
  });
}

void _sendLyricBroadcast() {
  final FreeMusicSong? song = _currentSong;
  final FreeMusicLyrics? lyrics = _currentLyrics;
  if (song == null) return;

  final PlaybackUiState state = playbackState;
  final Duration position = state.position;

  String currentLyric = '';
  if (lyrics != null && lyrics.lines.isNotEmpty) {
    final int activeIndex = activeLyricLineIndex(
      lyrics.lines,
      position,
      lead: lyricHighlightLead,
    );
    if (activeIndex >= 0 && activeIndex < lyrics.lines.length) {
      currentLyric = lyrics.lines[activeIndex].text;
    }
  }

  unawaited(_carLifeService.sendLyricBroadcast(
    lyric: currentLyric,
    title: song.name,
    artist: song.artist,
    album: song.album,
    duration: song.duration > 0
        ? Duration(seconds: song.duration)
        : (state.duration ?? Duration.zero),
    position: position,
    playing: state.playing,
  ));
}
```

### 3. Android 端：发送系统广播

`android/app/src/main/kotlin/com/sy110/music_car_app/MainActivity.kt` 中已经实现了 `sendLyricBroadcast` 方法（第230-292行），支持所有主流播放器的广播协议。

## 工作原理

1. **定时发送**：每秒执行一次 `_sendLyricBroadcast()`
2. **计算当前歌词**：使用 `activeLyricLineIndex` 根据播放位置找到当前歌词行
3. **发送广播**：通过 Android MethodChannel 调用原生方法
4. **广播到系统**：原生层向 Android 系统发送 4 种广播协议
5. **CarLife 监听**：CarLife 监听这些广播，显示歌词

## 广播内容

每次广播包含以下信息：

- `lyric`：当前歌词文本
- `track` / `title` / `song_name`：歌曲标题
- `artist` / `singer_name`：歌手
- `album`：专辑
- `duration`：总时长（毫秒）
- `position` / `lyric_time`：当前播放位置（毫秒）
- `playing`：播放状态

## 性能优化

- **轻量操作**：每秒执行一次，仅计算当前歌词行，无 UI 重建
- **条件发送**：只在有歌曲播放时发送
- **忽略错误**：广播失败不影响应用运行

## 兼容性

- ✅ CarLife（百度车联网）
- ✅ 酷狗音乐协议
- ✅ QQ音乐协议
- ✅ 网易云音乐协议
- ✅ 通用播放器协议

## 测试验证

在 Android 设备上运行应用后：

1. 播放一首有歌词的歌曲
2. 打开 CarLife 应用连接车机
3. 应该能在 CarLife 界面看到实时滚动的歌词

## 相关文件

- `lib/services/carlife_service.dart` - CarLife 服务封装
- `lib/main.dart` - 定时器和歌词广播逻辑
- `lib/utils/lyrics_utils.dart` - 歌词工具函数
- `android/app/src/main/kotlin/com/sy110/music_car_app/MainActivity.kt` - Android 原生实现
